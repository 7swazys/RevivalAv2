run(function()
	local CoreGui = cloneref(game:GetService('CoreGui'))
	local LocalPlayer = lplr
	local Players = playersService
	local NameHider
	local Replacement
	local ChatTags
	local Level
	local HideOthers
	local Swapped: {[Instance]: string} = setmetatable({}, {__mode = "k"})
	local Watched: {[Instance]: RBXScriptConnection} = setmetatable({}, {__mode = "k"})
	local Patterns: {string} = {}
	local Plain: {string} = {}
	local Shortest: number = math.huge
	local TextClasses: {[string]: boolean} = {TextLabel = true, TextButton = true, TextBox = true}
	local FakeName: string = "hidden"
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
		if Refreshing or not NameHider or not NameHider.Enabled then
			return
		end
		Refreshing = true

		task.delay(0.35, function()
			Refreshing = false
			if NameHider.Enabled then
				NameHider:Toggle()
				NameHider:Toggle()
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

	local function IsLocal(GamePlayer): boolean
		local Player: Player? = GamePlayer:getPlayer()
		return Player ~= nil and Player.UserId == LocalPlayer.UserId
	end

	local function GetGamePlayerClass()
		local GamePlayer = bedwars.GamePlayerUtil and bedwars.GamePlayerUtil.getGamePlayer(LocalPlayer)
		local Meta = GamePlayer and getmetatable(GamePlayer)
		return Meta and Meta.__index
	end

	local function HasPlayerName(Object: Instance)
		local Ancestor: Instance? = Object.Parent
		for _ = 1, 3 do
			if not Ancestor then
				return nil
			end
			local Label = Ancestor:FindFirstChild("PlayerName", true)
			if Label then
				return Label
			end
			Ancestor = Ancestor.Parent
		end
		return nil
	end

	local function HideLevelObject(Object: Instance)
		if not (Level.Enabled or HideOthers.Enabled) or not TextClasses[Object.ClassName] then
			return
		end
		if not Object.Name:lower():find("level", 1, true) then
			return
		end
		local PlayerName = HasPlayerName(Object)
		if not PlayerName or (not HideOthers.Enabled and not PlayerName.Text:find(FakeName, 1, true)) then
			return
		end

		local function Apply()
			if Writing == Object or not Object.Parent then
				return
			end
			local Text = Object.Text
			if type(Text) ~= "string" or Text == "" then
				return
			end

			Swapped[Object] = Swapped[Object] or Text
			Writing = Object
			Object.Text = ""
			Writing = nil
		end

		Apply()
		if not Watched[Object] then
			Watched[Object] = Object:GetPropertyChangedSignal("Text"):Connect(Apply)
		end
	end

	local function HideLevelSiblings(Object: Instance?)
		if not Object then
			return
		end
		for _, v: Instance in Object:GetDescendants() do
			HideLevelObject(v)
		end
	end

	local function ReplaceText(Object: Instance)
		if Writing == Object then
			return
		end

		local Text = Object.Text
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
		local Escaped: string = FakeName:gsub("%%", "%%%%")
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
		HideLevelSiblings(Object.Parent)

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
		local Escaped: string = FakeName:gsub("%%", "%%%%")
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
		if ChatHook or not (NameHider.Enabled and ChatName.Enabled) then
			return
		end
		if not getcallbackvalue then
			if not ChatWarned then
				ChatWarned = true
				vape:CreateNotification("NameHider", "Your executor cannot read the chat callback, so your name stays in chat", 6, "warning")
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
			if not (NameHider.Enabled and ChatName.Enabled) then
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

	local function Watch(Root: Instance?)
		if not Root then
			return
		end

		if vape.ThreadFix then
			setthreadidentity(8)
		end
		NameHider:Clean(Root.DescendantAdded:Connect(function(Object: Instance)
			if NameHider.Enabled then
				HideObject(Object)
				HideLevelObject(Object)
			end
		end))

		local Clock: number = os.clock()
		for _, v: Instance in Root:GetDescendants() do
			HideObject(v)
			HideLevelObject(v)

			if os.clock() - Clock > 0.002 then
				task.wait()
				if not NameHider.Enabled then
					return
				end
				Clock = os.clock()

				if vape.ThreadFix then
					setthreadidentity(8)
				end
			end
		end
	end

	NameHider = vape.Categories.Utility:CreateModule({
		Name = "NameHider",
		ConfigName = "NameHider",
		Function = function(Callback: boolean)
			if Callback then
				table.clear(Patterns)
				table.clear(Plain)
				table.clear(Ids)
				Shortest = math.huge
				for _, v: Player in Players:GetPlayers() do
					if v == LocalPlayer or HideOthers.Enabled then
						AddPlayerNames(v)
					end
				end

				FakeName = Replacement.Value ~= "" and Replacement.Value or "hidden"
				for _, v: string in Patterns do
					if FakeName:find(v) then
						FakeName = "hidden"
						break
					end
				end

				local GamePlayer = GetGamePlayerClass()
				if GamePlayer and not OldUsername then
					OldUsername, OldDisplayName = GamePlayer.getUsername, GamePlayer.getDisplayName
					OldClanTag, OldLevel = GamePlayer.getClanTag, GamePlayer.getLevel
					GamePlayer.getUsername = function(self, ...)
						local Player: Player? = self:getPlayer()
						return ShouldHidePlayer(Player) and FakeName or OldUsername(self, ...)
					end
					GamePlayer.getDisplayName = function(self, ...)
						local Player: Player? = self:getPlayer()
						return ShouldHidePlayer(Player) and FakeName or OldDisplayName(self, ...)
					end
					GamePlayer.getClanTag = function(self, ...)
						return IsLocal(self) and ChatTags.Enabled and "" or OldClanTag(self, ...)
					end
					GamePlayer.getLevel = function(self, ...)
						local Player: Player? = self:getPlayer()
						if Player and (HideOthers.Enabled or (Player.UserId == LocalPlayer.UserId and Level.Enabled)) then
							return -1
						end
						return OldLevel(self, ...)
					end
				end

				HookChat()
				for _, v: Instance? in {LocalPlayer:FindFirstChildOfClass("PlayerGui"), CoreGui, gethui and gethui() or nil, workspace} do
					Watch(v)
				end

				NameHider:Clean(LocalPlayer.CharacterAdded:Connect(function(Character: Model)
					if NameHider.Enabled then
						Watch(Character)
					end
				end))
				NameHider:Clean(Players.PlayerAdded:Connect(function()
					if HideOthers.Enabled then
						QueueRefresh()
					end
				end))
				NameHider:Clean(Players.PlayerRemoving:Connect(function()
					if HideOthers.Enabled then
						QueueRefresh()
					end
				end))
			else
				local GamePlayer = GetGamePlayerClass()
				if OldUsername and GamePlayer then
					GamePlayer.getUsername, GamePlayer.getDisplayName = OldUsername, OldDisplayName
					GamePlayer.getClanTag, GamePlayer.getLevel = OldClanTag, OldLevel
					OldUsername, OldDisplayName, OldClanTag, OldLevel = nil, nil, nil, nil
				end
				if vape.ThreadFix then
					setthreadidentity(8)
				end

				for _, v: RBXScriptConnection in Watched do
					v:Disconnect()
				end
				table.clear(Watched)

				for Object: Instance, v: string in Swapped do
					if Object.Parent then
						Writing = Object
						Object.Text = v
						Object:SetAttribute("NickHiderOriginalText", nil)
					end
				end
				Writing = nil
				table.clear(Swapped)

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

	Replacement = NameHider:CreateTextBox({
		Name = "Name",
		Function = QueueRefresh,
		Default = "hidden"
	})
	ChatName = NameHider:CreateToggle({
		Name = "Change chat name",
		Default = true,
		Function = function(Callback: boolean)
			if not NameHider.Enabled then
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
	local Hide = NameHider:CreateMultiDropdown({
		Name = "Hide",
		List = {"Others", "Chat tags", "Level"},
		Default = {"Chat tags", "Level"},
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
	HideOthers, ChatTags, Level = flag("Others"), flag("Chat tags"), flag("Level")
end)
