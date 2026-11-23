run(function()
	local Main = vape.Libraries.mergedModule(vape.Categories.Utility, {
		Name = 'NameHider',
		Tooltip = 'Changes what your name, nametag and level look like on your screen'
	})
	local LevelHook = {Users = {}}
	function LevelHook.Refresh()
		local needed = next(LevelHook.Users) ~= nil
		if needed and not LevelHook.Old then
			local gamePlayer = bedwars.GamePlayerUtil and bedwars.GamePlayerUtil.getGamePlayer(lplr)
			local meta = gamePlayer and getmetatable(gamePlayer)
			local class = meta and meta.__index
			if type(class) ~= 'table' or type(class.getLevel) ~= 'function' then return end
			local old = class.getLevel
			LevelHook.Old, LevelHook.Class = old, class
			LevelHook.Wrapper = function(self, ...)
				local player = self:getPlayer()
				for _, check in LevelHook.Users do
					if check(player) then
						return -1
					end
				end
				return old(self, ...)
			end
			class.getLevel = LevelHook.Wrapper
		elseif not needed and LevelHook.Old then
			if LevelHook.Class.getLevel == LevelHook.Wrapper then
				LevelHook.Class.getLevel = LevelHook.Old
			end
			LevelHook.Old, LevelHook.Class, LevelHook.Wrapper = nil, nil, nil
		end
	end

run(function()
	local CoreGui = coreGui
	local LocalPlayer = lplr
	local Players = playersService
	local NickHider
	local Replacement
	local ChatTags
	local HideOthers
	local Kit
	local Hidden = setmetatable({}, {__mode = "k"})
	local Swapped = setmetatable({}, {__mode = "k"})
	local Watched = setmetatable({}, {__mode = "k"})
	local Patterns: {string} = {}
	local Plain: {string} = {}
	local Shortest: number = math.huge
	local TextClasses: {[string]: boolean} = {TextLabel = true, TextButton = true, TextBox = true}
	local Fake: string = "hidden"
	local Writing: Instance?
	local OldUsername, OldDisplayName, OldClanTag, OldLevel
	local ChatName
	local SwappedImage = setmetatable({}, {__mode = "k"})
	local WatchedImage = setmetatable({}, {__mode = "k"})
	local Ids: {string} = {}
	local ImageClasses: {[string]: boolean} = {ImageLabel = true, ImageButton = true}
	local TextChat = cloneref(game:GetService("TextChatService"))
	local ChatOld, ChatHook, ChatWarned

	local Refreshing: boolean = false

	local function QueueRefresh()
		if Refreshing or not NickHider or not NickHider.Enabled then
			return
		end
		Refreshing = true

		task.delay(0.35, function()
			Refreshing = false
			if NickHider.Enabled then
				NickHider:Toggle()
				NickHider:Toggle()
			end
		end)
	end

	local function ShouldHidePlayer(Player: Player?)
		return Player and (Player.UserId == LocalPlayer.UserId or HideOthers.Enabled)
	end

	local function AddPlayerNames(Player: Player)
		local Id: string = tostring(Player.UserId)
		if Player.UserId > 0 and not table.find(Ids, Id) then
			table.insert(Ids, Id)
		end
		for _, v: string in {Player.Name, Player.DisplayName, #Id >= 7 and Id or ""} do
			if v ~= "" then
				local LowerName: string = v:lower()
				if not table.find(Plain, LowerName) then
					table.insert(Plain, LowerName)
					Shortest = math.min(Shortest, #LowerName)
				end
			end
			for _, Variant: string in {v, v:lower(), v:upper()} do
				local Pattern: string = (Variant:gsub("%W", "%%%0"))
				if Variant ~= "" and not table.find(Patterns, Pattern) then
					table.insert(Patterns, Pattern)
				end
			end
		end
	end

	local function ReplaceText(Object: Instance)
		if Writing == Object then
			return
		end

		local Text: string = Object.Text
		if type(Text) ~= "string" or #Text < Shortest then
			return
		end

		local Hit: boolean = false
		for _, v: string in Plain do
			if Text:find(v, 1, true) then
				Hit = true
				break
			end
		end
		if not Hit then
			local LowerText: string = Text:lower()
			for _, v: string in Plain do
				if LowerText:find(v, 1, true) then
					Hit = true
					break
				end
			end
		end
		if not Hit then
			return
		end

		local NewText: string = Text
		local Escaped: string = Fake:gsub("%%", "%%%%")
		for _, v: string in Patterns do
			if NewText:find(v) then
				NewText = NewText:gsub(v, Escaped)
			end
		end
		if NewText == Text then
			return
		end

		Swapped[Object] = Text
		Object:SetAttribute("NickHiderOriginalText", Text)
		Writing = Object
		Object.Text = NewText
		Writing = nil

		if not Watched[Object] then
			Watched[Object] = Object:GetPropertyChangedSignal("Text"):Connect(function()
				ReplaceText(Object)
			end)
		end
	end

	local function ReplaceImage(Object: Instance)
		if Writing == Object then
			return
		end
		local Image: string = Object.Image
		if type(Image) ~= "string" or Image == "" then
			return
		end
		local Hit: boolean = false
		for _, Id: string in Ids do
			if Image:find(Id, 1, true) then
				Hit = true
				break
			end
		end
		if not Hit then
			return
		end
		SwappedImage[Object] = Image
		Writing = Object
		Object.Image = ""
		Writing = nil
		if not WatchedImage[Object] then
			WatchedImage[Object] = Object:GetPropertyChangedSignal("Image"):Connect(function()
				ReplaceImage(Object)
			end)
		end
	end

	local function HideObject(Object: Instance)
		local Class: string = Object.ClassName
		if TextClasses[Class] then
			ReplaceText(Object)
		elseif ImageClasses[Class] then
			ReplaceImage(Object)
		end
	end

	local function ScrubChat(Text: string?): (string?, boolean)
		if type(Text) ~= "string" or Text == "" then
			return Text, false
		end
		local NewText: string = Text
		local Escaped: string = Fake:gsub("%%", "%%%%")
		for _, v: string in Patterns do
			if NewText:find(v) then
				NewText = NewText:gsub(v, Escaped)
			end
		end
		return NewText, NewText ~= Text
	end

	local function UnhookChat()
		if not ChatHook then
			return
		end
		local Current = getcallbackvalue and select(2, pcall(getcallbackvalue, TextChat, "OnIncomingMessage"))
		if Current == ChatHook or not getcallbackvalue then
			TextChat.OnIncomingMessage = ChatOld
		end
		ChatHook, ChatOld = nil, nil
	end

	local function HookChat()
		if ChatHook or not (NickHider.Enabled and ChatName.Enabled) then
			return
		end
		if not getcallbackvalue then
			if not ChatWarned then
				ChatWarned = true
				notif("InfoEditor", "Your executor cannot read the chat callback, so your name stays in chat", 6, "warning")
			end
			return
		end
		local Ok, Old = pcall(getcallbackvalue, TextChat, "OnIncomingMessage")
		ChatOld = Ok and type(Old) == "function" and Old or nil
		local Original = ChatOld
		ChatHook = function(Message)
			local Props
			if Original then
				local OkCall, Result = pcall(Original, Message)
				Props = OkCall and Result or nil
			end
			if not (NickHider.Enabled and ChatName.Enabled) then
				return Props
			end
			local Prefix, HidPrefix = ScrubChat(Props and Props.PrefixText ~= "" and Props.PrefixText or Message.PrefixText)
			local Text, HidText = ScrubChat(Props and Props.Text ~= "" and Props.Text or Message.Text)
			if HidPrefix or HidText then
				Props = Props or Instance.new("TextChatMessageProperties")
				if HidPrefix then
					Props.PrefixText = Prefix
				end
				if HidText then
					Props.Text = Text
				end
			end
			return Props
		end
		TextChat.OnIncomingMessage = ChatHook
	end

	local function HideKit(Object: Instance)
		if not Kit.Enabled or Object.Name ~= "PlayerKitFrame" or Hidden[Object] ~= nil then
			return
		end

		task.defer(function()
			local Label = Object.Parent and Object.Parent:FindFirstChild("PlayerName", true)
			if not NickHider.Enabled or not Kit.Enabled or not Label or not Label.Text:find(Fake, 1, true) then
				return
			end

			Hidden[Object] = Object.Visible
			Object.Visible = false
		end)
	end

	local function Watch(Root: Instance?)
		if not Root then
			return
		end

		if vape.ThreadFix then
			setthreadidentity(8)
		end
		NickHider:Clean(Root.DescendantAdded:Connect(function(Object: Instance)
			if NickHider.Enabled then
				HideObject(Object)
				HideKit(Object)
			end
		end))

		local Clock: number = os.clock()
		for _, v: Instance in Root:GetDescendants() do
			HideObject(v)
			HideKit(v)

			if os.clock() - Clock > 0.002 then
				task.wait()
				if not NickHider.Enabled then
					return
				end
				Clock = os.clock()

				if vape.ThreadFix then
					setthreadidentity(8)
				end
			end
		end
	end

	NickHider = Main:Part({
		Label = 'Hide name',
		Name = "NickHider",
		ConfigName = "NameHider",
		Function = function(Callback: boolean)
			if Callback then
				table.clear(Patterns)
				table.clear(Plain)
				table.clear(Ids)
				Shortest = math.huge
				for _, Player: Player in Players:GetPlayers() do
					if Player == LocalPlayer or HideOthers.Enabled then
						AddPlayerNames(Player)
					end
				end

				Fake = Replacement.Value ~= "" and Replacement.Value or "hidden"
				for _, v: string in Patterns do
					if Fake:find(v) then
						Fake = "hidden"
						break
					end
				end

				local GamePlayer = bedwars.GamePlayerUtil and bedwars.GamePlayerUtil.getGamePlayer(LocalPlayer)
				GamePlayer = GamePlayer and getmetatable(GamePlayer)
				GamePlayer = GamePlayer and GamePlayer.__index
				if GamePlayer and not OldUsername then
					OldUsername, OldDisplayName = GamePlayer.getUsername, GamePlayer.getDisplayName
					OldClanTag = GamePlayer.getClanTag
					GamePlayer.getUsername = function(self, ...)
						local Player: Player? = self:getPlayer()
						return ShouldHidePlayer(Player) and Fake or OldUsername(self, ...)
					end
					GamePlayer.getDisplayName = function(self, ...)
						local Player: Player? = self:getPlayer()
						return ShouldHidePlayer(Player) and Fake or OldDisplayName(self, ...)
					end
					GamePlayer.getClanTag = function(self, ...)
						local Player: Player? = self:getPlayer()
						return (Player and Player.UserId == LocalPlayer.UserId) and ChatTags.Enabled and "" or OldClanTag(self, ...)
					end
				end

				LevelHook.Users.HideName = function(Player: Player?)
					return Player ~= nil and HideOthers.Enabled
				end
				LevelHook.Refresh()
				HookChat()
				for _, v: Instance in {LocalPlayer:FindFirstChildOfClass("PlayerGui"), CoreGui, gethui and gethui() or nil, workspace} do
					Watch(v)
				end

				NickHider:Clean(LocalPlayer.CharacterAdded:Connect(function(Character: Model)
					if NickHider.Enabled then
						Watch(Character)
					end
				end))
				NickHider:Clean(Players.PlayerAdded:Connect(function()
					if HideOthers.Enabled then
						QueueRefresh()
					end
				end))
				NickHider:Clean(Players.PlayerRemoving:Connect(function()
					if HideOthers.Enabled then
						QueueRefresh()
					end
				end))
			else
				local GamePlayer = bedwars.GamePlayerUtil and bedwars.GamePlayerUtil.getGamePlayer(LocalPlayer)
				GamePlayer = GamePlayer and getmetatable(GamePlayer)
				GamePlayer = GamePlayer and GamePlayer.__index
				if OldUsername and GamePlayer then
					GamePlayer.getUsername, GamePlayer.getDisplayName = OldUsername, OldDisplayName
					GamePlayer.getClanTag = OldClanTag
					OldUsername, OldDisplayName, OldClanTag, OldLevel = nil, nil, nil, nil
				end
				if vape.ThreadFix then
					setthreadidentity(8)
				end

				for _, v: RBXScriptConnection in Watched do
					v:Disconnect()
				end
				table.clear(Watched)

				for Object: GuiObject, Visible: boolean in Hidden do
					if Object.Parent then
						Object.Visible = Visible
					end
				end
				table.clear(Hidden)

				for Object: Instance, OriginalText: string in Swapped do
					if Object.Parent then
						Writing = Object
						Object.Text = OriginalText
						Object:SetAttribute("NickHiderOriginalText", nil)
					end
				end
				Writing = nil
				table.clear(Swapped)

				LevelHook.Users.HideName = nil
				LevelHook.Refresh()
				UnhookChat()
				for _, v: RBXScriptConnection in WatchedImage do
					v:Disconnect()
				end
				table.clear(WatchedImage)
				for Object: Instance, OriginalImage: string in SwappedImage do
					if Object.Parent then
						Writing = Object
						Object.Image = OriginalImage
					end
				end
				Writing = nil
				table.clear(SwappedImage)
			end
		end,
		Tooltip = 'Replaces your name, user id and avatar picture everywhere on your screen, chat included',
		ExtraText = function()
			return Replacement.Value ~= "" and Replacement.Value or "hidden"
		end
	})

	Replacement = NickHider:CreateTextBox({
		Name = "Name",
		Function = QueueRefresh,
		Default = "hidden"
	})
	ChatName = NickHider:CreateToggle({
		Name = "Change chat name",
		Default = true,
		Function = function(Callback: boolean)
			if not NickHider.Enabled then
				return
			end
			if Callback then
				HookChat()
			else
				UnhookChat()
			end
		end,
		Tooltip = 'Shows the name above instead of yours in new chat messages'
	})
	local Hide = NickHider:CreateMultiDropdown({
		Name = "Hide",
		List = {"Others", "Chat tags", "Kit"},
		Default = {"Chat tags"},
		Function = QueueRefresh,
		Tooltip = 'What to hide on your screen'
	})
	local function flag(name)
		return setmetatable({}, {__index = function(_, key)
			if key == "Enabled" then
				return Hide:Has(name)
			end
		end})
	end
	HideOthers, ChatTags, Kit = flag("Others"), flag("Chat tags"), flag("Kit")
end)

run(function()
	local LevelPart
	local Mode
	local Custom
	local original
	local applying = false
	local hidden = setmetatable({}, {__mode = 'k'})
	local watched = setmetatable({}, {__mode = 'k'})

	local function applyCustom()
		if not (LevelPart.Enabled and Mode.Value == 'Custom') then return end
		applying = true
		lplr:SetAttribute('PlayerLevel', math.floor(Custom.Value))
		applying = false
	end

	local function hideLabel(descendant)
		if LevelPart.Enabled and Mode.Value == 'Hidden' and descendant:IsA('TextLabel') and descendant.Name == 'PlayerLevel' then
			if hidden[descendant] == nil then
				hidden[descendant] = descendant.Visible
			end
			descendant.Visible = false
		end
	end

	local function watchTab(gui)
		if watched[gui] then return end
		watched[gui] = true
		for _, descendant in gui:GetDescendants() do
			hideLabel(descendant)
		end
		LevelPart:Clean(gui.DescendantAdded:Connect(hideLabel))
	end

	local function restore()
		for label, visible in hidden do
			pcall(function()
				label.Visible = visible
			end)
		end
		table.clear(hidden)
		table.clear(watched)
		if original ~= nil then
			applying = true
			lplr:SetAttribute('PlayerLevel', original)
			applying = false
			original = nil
		end
		LevelHook.Users.Level = nil
		LevelHook.Refresh()
	end

	LevelPart = Main:Part({
		Label = 'Change level',
		Default = false,
		Name = 'PlayerLevel',
		Function = function(callback)
			restore()
			if not callback then return end
			if Mode.Value == 'Hidden' then
				LevelHook.Users.Level = function(player)
					return player ~= nil and player.UserId == lplr.UserId
				end
				LevelHook.Refresh()
				local tab = lplr.PlayerGui:FindFirstChild('TabListScreenGui')
				if tab then
					watchTab(tab)
				end
				LevelPart:Clean(lplr.PlayerGui.ChildAdded:Connect(function(gui)
					if gui.Name == 'TabListScreenGui' then
						watchTab(gui)
					end
				end))
			else
				original = lplr:GetAttribute('PlayerLevel')
				applyCustom()
				LevelPart:Clean(lplr:GetAttributeChangedSignal('PlayerLevel'):Connect(function()
					local current = lplr:GetAttribute('PlayerLevel')
					if applying or current == math.floor(Custom.Value) then return end
					original = current
					applyCustom()
				end))
			end
			LevelPart:Clean(restore)
		end,
		Tooltip = 'Hides your level or shows one you pick, only on your screen'
	})
	Mode = LevelPart:CreateDropdown({
		Name = 'Level',
		List = {'Hidden', 'Custom'},
		Default = 'Hidden',
		Function = function()
			if LevelPart.Enabled then
				LevelPart:Toggle()
				LevelPart:Toggle()
			end
		end,
		Tooltip = 'Hidden - no level next to your name and none in the player list\nCustom - shows the level below'
	})
	Custom = LevelPart:CreateSlider({
		Name = 'Custom level',
		Min = 1,
		Max = 1000,
		Default = 1,
		Visible = function()
			return Mode and Mode.Value == 'Custom'
		end,
		Function = function()
			applyCustom()
		end
	})
end)

end)
