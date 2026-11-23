run(function()
	local Main = vape.Libraries.mergedModule(vape.Categories.Legit, {
		Name = 'Interface',
		Tooltip = 'Restyles the hotbar and health bar and cleans up the UI'
	})

run(function()
	local Interface
	local HotbarOpenInventory = ({pcall(function()
		return require(lplr.PlayerScripts.TS.controllers.global.hotbar.ui['hotbar-open-inventory']).HotbarOpenInventory
	end)})[2]
	local HotbarHealthbar = ({pcall(function()
		return require(lplr.PlayerScripts.TS.controllers.global.hotbar.ui.healthbar['hotbar-healthbar']).HotbarHealthbar
	end)})[2]
	local HotbarApp = ({pcall(function()
		return getRoactRender(require(lplr.PlayerScripts.TS.controllers.global.hotbar.ui['hotbar-app']).HotbarApp.render)
	end)})[2]
	local old, new = {}, {}
	local madeHotbar, madeHealth = {}, {}
	local hotbarTextConnection, healthTextConnection
	local HotbarGuiSync, HotbarSlotColor, HotbarGradient, HotbarRounding, HotbarHighlight, HotbarHideNums
	local HotbarColorA, HotbarColorB, HotbarOutlineColor, HotbarRoundSize
	local HealthGuiSync, HealthMainOn, HealthGradOn, HealthBgOn, HealthRoundOn, HealthStrokeOn, HealthTextOn, HealthFontOn
	local HealthMainCol, HealthGradCol, HealthBgCol, HealthStrokeCol, HealthTextCol, HealthRoundSize, HealthFontDrop, HealthTextList

	vape:Clean(function()
		for _, v in new do
			table.clear(v)
		end
		for _, v in old do
			table.clear(v)
		end
		table.clear(new)
		table.clear(old)
	end)

	local function modifyconstant(func, ind, val)
		if not func then return end
		if not old[func] then old[func] = {} end
		if not new[func] then new[func] = {} end
		if not old[func][ind] then
			old[func][ind] = debug.getconstant(func, ind)
		end
		if typeof(old[func][ind]) ~= typeof(val) then return end
		new[func][ind] = val

		if Interface.Enabled then
			if val then
				debug.setconstant(func, ind, val)
			else
				debug.setconstant(func, ind, old[func][ind])
				old[func][ind] = nil
			end
		end
	end

	local function guiColor()
		local ok, hue = pcall(function()
			return vape.GUIColor and vape.GUIColor.Hue or 0.6
		end)
		if not ok then hue = 0.6 end
		return Color3.fromHSV(hue, 1, 1)
	end

	local function isAlive()
		local character = lplr.Character
		local humanoid = character and character:FindFirstChildOfClass('Humanoid')
		return humanoid ~= nil and humanoid.Health > 0
	end

	local function hotbarIcons()
		local icons = ({pcall(function()
			return lplr.PlayerGui.hotbar['1'].ItemsHotbar
		end)})[2]
		return typeof(icons) == 'Instance' and icons or nil
	end

	local function paintHotbar()
		local icons = hotbarIcons()
		if not icons then return end
		local sync = HotbarGuiSync and HotbarGuiSync.Enabled
		local synced = sync and guiColor() or nil
		for _, slot in ipairs(icons:GetChildren()) do
			local button = slot:FindFirstChildWhichIsA('ImageButton')
			local label = button and button:FindFirstChildWhichIsA('TextLabel')
			if not label then continue end
			if sync then
				button.BackgroundColor3 = synced
			elseif HotbarSlotColor and HotbarSlotColor.Enabled and not (HotbarGradient and HotbarGradient.Enabled) then
				local c = HotbarColorA
				button.BackgroundColor3 = c and Color3.fromHSV(c.Hue or 0, c.Sat or 0, c.Value or 1) or synced
			end
			if HotbarGradient and HotbarGradient.Enabled and not sync then
				button.BackgroundColor3 = Color3.new(1, 1, 1)
				if not button:FindFirstChildWhichIsA('UIGradient') then
					local g = Instance.new('UIGradient')
					local a = HotbarColorA and Color3.fromHSV(HotbarColorA.Hue or 0, HotbarColorA.Sat or 0, HotbarColorA.Value or 1) or Color3.fromRGB(80, 160, 255)
					local b = HotbarColorB and Color3.fromHSV(HotbarColorB.Hue or 0.7, HotbarColorB.Sat or 0.8, HotbarColorB.Value or 1) or Color3.fromRGB(180, 80, 255)
					g.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, a), ColorSequenceKeypoint.new(1, b)})
					g.Parent = button
					table.insert(madeHotbar, g)
				end
			end
			if HotbarRounding and HotbarRounding.Enabled and not button:FindFirstChildWhichIsA('UICorner') then
				local c = Instance.new('UICorner')
				c.CornerRadius = UDim.new(0, HotbarRoundSize and HotbarRoundSize.Value or 8)
				c.Parent = button
				table.insert(madeHotbar, c)
			end
			if HotbarHighlight and HotbarHighlight.Enabled and not button:FindFirstChildWhichIsA('UIStroke') then
				local s = Instance.new('UIStroke')
				s.Thickness = 1.3
				s.Color = synced
					or (HotbarOutlineColor and Color3.fromHSV(HotbarOutlineColor.Hue or 0, HotbarOutlineColor.Sat or 0, HotbarOutlineColor.Value or 1))
					or Color3.new(1, 1, 1)
				s.Parent = button
				table.insert(madeHotbar, s)
			end
			if HotbarHideNums and HotbarHideNums.Enabled then
				label.Visible = false
			end
		end
	end

	local paintQueued, healthQueued = false, false
	local applyHealthbar
	local function queuePaint()
		if paintQueued then return end
		paintQueued = true
		task.delay(0.1, function()
			paintQueued = false
			if Interface and Interface.Enabled then paintHotbar() end
		end)
	end
	local function queueHealth()
		if healthQueued then return end
		healthQueued = true
		task.delay(0.15, function()
			healthQueued = false
			if Interface and Interface.Enabled then applyHealthbar() end
		end)
	end

	local function clearHotbar()
		for _, o in ipairs(madeHotbar) do
			pcall(function() o:Destroy() end)
		end
		table.clear(madeHotbar)
		pcall(function()
			local icons = hotbarIcons()
			for _, slot in ipairs(icons and icons:GetChildren() or {}) do
				local btn = slot:FindFirstChildWhichIsA('ImageButton')
				if btn then
					btn.BackgroundColor3 = Color3.fromRGB(29, 36, 46)
					local lab = btn:FindFirstChildWhichIsA('TextLabel')
					if lab then lab.Visible = true end
				end
			end
		end)
	end

	function applyHealthbar()
		if not Interface or not Interface.Enabled then return end
		local bar = ({pcall(function()
			return lplr.PlayerGui.hotbar['1'].HotbarHealthbarContainer.HealthbarProgressWrapper['1']
		end)})[2]
		if typeof(bar) ~= 'Instance' then return end

		if HealthGuiSync and HealthGuiSync.Enabled then
			bar.BackgroundColor3 = guiColor()
		elseif HealthMainOn and HealthMainOn.Enabled then
			bar.BackgroundColor3 = HealthMainCol and Color3.fromHSV(HealthMainCol.Hue or 0, HealthMainCol.Sat or 0.8, HealthMainCol.Value or 1) or Color3.fromRGB(203, 54, 36)
			if HealthGradOn and HealthGradOn.Enabled then
				bar.BackgroundColor3 = Color3.new(1, 1, 1)
				local g = bar:FindFirstChildWhichIsA('UIGradient') or Instance.new('UIGradient', bar)
				local a = HealthMainCol and Color3.fromHSV(HealthMainCol.Hue or 0, HealthMainCol.Sat or 0.8, HealthMainCol.Value or 1) or Color3.fromRGB(203, 54, 36)
				local b = HealthGradCol and Color3.fromHSV(HealthGradCol.Hue or 0.05, HealthGradCol.Sat or 0.8, HealthGradCol.Value or 1) or Color3.fromRGB(255, 160, 40)
				g.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, a), ColorSequenceKeypoint.new(1, b)})
				table.insert(madeHealth, g)
			end
		end

		local bg = bar.Parent and bar.Parent.Parent
		if typeof(bg) == 'Instance' then
			if HealthBgOn and HealthBgOn.Enabled then
				bg.BackgroundColor3 = HealthBgCol and Color3.fromHSV(HealthBgCol.Hue or 0.6, HealthBgCol.Sat or 0.2, HealthBgCol.Value or 0.2) or Color3.fromRGB(41, 51, 65)
			end
			if HealthStrokeOn and HealthStrokeOn.Enabled and not bg:FindFirstChildWhichIsA('UIStroke') then
				local s = Instance.new('UIStroke')
				s.Thickness = 1.6
				s.Color = HealthStrokeCol and Color3.fromHSV(HealthStrokeCol.Hue or 0, HealthStrokeCol.Sat or 0, HealthStrokeCol.Value or 1) or Color3.new(1, 1, 1)
				s.Parent = bg
				table.insert(madeHealth, s)
			end
			if HealthRoundOn and HealthRoundOn.Enabled then
				for _, f in ipairs(bar.Parent:GetChildren()) do
					if f:IsA('Frame') and not f:FindFirstChildWhichIsA('UICorner') then
						local c = Instance.new('UICorner')
						c.CornerRadius = UDim.new(0, HealthRoundSize and HealthRoundSize.Value or 4)
						c.Parent = f
						table.insert(madeHealth, c)
					end
				end
				if not bg:FindFirstChildWhichIsA('UICorner') then
					local c = Instance.new('UICorner')
					c.CornerRadius = UDim.new(0, HealthRoundSize and HealthRoundSize.Value or 4)
					c.Parent = bg
					table.insert(madeHealth, c)
				end
			end

			local label = bg:FindFirstChild('1')
			if typeof(label) == 'Instance' and label:IsA('TextLabel') then
				if HealthTextCol and HealthTextOn and HealthTextOn.Enabled then
					label.TextColor3 = Color3.fromHSV(HealthTextCol.Hue or 0, HealthTextCol.Sat or 0, HealthTextCol.Value or 1)
				end
				if HealthFontOn and HealthFontOn.Enabled and HealthFontDrop then
					pcall(function() label.Font = Enum.Font[HealthFontDrop.Value] end)
				end
				local function rewrite()
					local custom = ''
					if HealthTextList and HealthTextList.ObjectList and #HealthTextList.ObjectList > 0 then
						custom = HealthTextList.ObjectList[math.random(1, #HealthTextList.ObjectList)]
					end
					local hp = isAlive() and tostring(math.floor(lplr.Character:GetAttribute('Health') or 0)) or '0'
					if HealthTextOn and HealthTextOn.Enabled and custom ~= '' then
						label.Text = custom:gsub('<health>', hp)
					else
						label.Text = hp
					end
				end
				rewrite()
				if healthTextConnection then healthTextConnection:Disconnect() end
				healthTextConnection = label:GetPropertyChangedSignal('Text'):Connect(rewrite)
			end
		end
	end

	local function clearHealthbar()
		if healthTextConnection then healthTextConnection:Disconnect() end
		healthTextConnection = nil
		for _, o in ipairs(madeHealth) do
			pcall(function() o:Destroy() end)
		end
		table.clear(madeHealth)
		pcall(function()
			local bar = lplr.PlayerGui.hotbar['1'].HotbarHealthbarContainer.HealthbarProgressWrapper['1']
			bar.BackgroundColor3 = Color3.fromRGB(203, 54, 36)
			bar.Parent.Parent.BackgroundColor3 = Color3.fromRGB(41, 51, 65)
		end)
	end

	Interface = Main:Part({
		Label = 'Restyle UI',
		Name = 'Interface',
		Function = function(callback)
			for i, v in (callback and new or old) do
				for i2, v2 in v do
					debug.setconstant(i, i2, v2)
				end
			end
			if callback then
				Interface:Clean(lplr.PlayerGui.DescendantAdded:Connect(function(v)
					if v.Name == 'hotbar' then
						queuePaint()
					elseif v.Name == 'HotbarHealthbarContainer' then
						queueHealth()
					end
				end))
				paintHotbar()
				applyHealthbar()
			else
				clearHotbar()
				clearHealthbar()
			end
		end,
		Tooltip = 'Restyles the hotbar and health bar and cleans up the UI',
		Category = 'Hud'
	})


	local HotbarGuiSyncState
	local HotbarSlotColorState
	local HotbarGradientState
	local HotbarRoundingState
	local HotbarHighlightState
	local HotbarGuiSyncChanged = function() if Interface.Enabled then clearHotbar(); paintHotbar() end end
	local HotbarSlotColorChanged = function() if Interface.Enabled then clearHotbar(); paintHotbar() end end
	local HotbarGradientChanged = function() if Interface.Enabled then clearHotbar(); paintHotbar() end end
	local HotbarRoundingChanged = function() if Interface.Enabled then clearHotbar(); paintHotbar() end end
	local HotbarHighlightChanged = function() if Interface.Enabled then clearHotbar(); paintHotbar() end end
	local HotbarStyle
	HotbarStyle = Interface:CreateMultiDropdown({
		Name = 'Hotbar style',
		List = {'Match GUI colour', 'Slot colour', 'Gradient', 'Rounding', 'Outline'},
		Default = {},
		Function = function()
			local on = HotbarStyle:Has('Match GUI colour')
			if HotbarGuiSyncState ~= on then
				HotbarGuiSyncState = on
				HotbarGuiSyncChanged(on)
			end
			local on = HotbarStyle:Has('Slot colour')
			if HotbarSlotColorState ~= on then
				HotbarSlotColorState = on
				HotbarSlotColorChanged(on)
			end
			local on = HotbarStyle:Has('Gradient')
			if HotbarGradientState ~= on then
				HotbarGradientState = on
				HotbarGradientChanged(on)
			end
			local on = HotbarStyle:Has('Rounding')
			if HotbarRoundingState ~= on then
				HotbarRoundingState = on
				HotbarRoundingChanged(on)
			end
			local on = HotbarStyle:Has('Outline')
			if HotbarHighlightState ~= on then
				HotbarHighlightState = on
				HotbarHighlightChanged(on)
			end
		end,
		Tooltip = 'How the hotbar is restyled; the colours below go with these'
	})
	HotbarGuiSyncState = HotbarStyle:Has('Match GUI colour')
	HotbarSlotColorState = HotbarStyle:Has('Slot colour')
	HotbarGradientState = HotbarStyle:Has('Gradient')
	HotbarRoundingState = HotbarStyle:Has('Rounding')
	HotbarHighlightState = HotbarStyle:Has('Outline')
	HotbarGuiSync = setmetatable({}, {__index = function(_, key) if key == 'Enabled' then return HotbarStyle:Has('Match GUI colour') end end})
	HotbarSlotColor = setmetatable({}, {__index = function(_, key) if key == 'Enabled' then return HotbarStyle:Has('Slot colour') end end})
	HotbarGradient = setmetatable({}, {__index = function(_, key) if key == 'Enabled' then return HotbarStyle:Has('Gradient') end end})
	HotbarRounding = setmetatable({}, {__index = function(_, key) if key == 'Enabled' then return HotbarStyle:Has('Rounding') end end})
	HotbarHighlight = setmetatable({}, {__index = function(_, key) if key == 'Enabled' then return HotbarStyle:Has('Outline') end end})
	HotbarRoundSize = Interface:CreateSlider({Name = 'Hotbar round radius', Min = 1, Max = 16, Default = 8})
	HotbarColorA = Interface:CreateColorSlider({Name = 'Hotbar colour 1'})
	HotbarColorB = Interface:CreateColorSlider({Name = 'Hotbar gradient 2'})
	HotbarOutlineColor = Interface:CreateColorSlider({Name = 'Hotbar outline colour'})

	local HealthGuiSyncState
	local HealthMainOnState
	local HealthGradOnState
	local HealthBgOnState
	local HealthRoundOnState
	local HealthStrokeOnState
	local HealthTextOnState
	local HealthGuiSyncChanged = function() if Interface.Enabled then clearHealthbar(); applyHealthbar() end end
	local HealthMainOnChanged = function() if Interface.Enabled then applyHealthbar() end end
	local HealthGradOnChanged = function() if Interface.Enabled then applyHealthbar() end end
	local HealthBgOnChanged = function() if Interface.Enabled then applyHealthbar() end end
	local HealthRoundOnChanged = function() if Interface.Enabled then clearHealthbar(); applyHealthbar() end end
	local HealthStrokeOnChanged = function() if Interface.Enabled then clearHealthbar(); applyHealthbar() end end
	local HealthTextOnChanged = function() if Interface.Enabled then applyHealthbar() end end
	local HealthStyle
	HealthStyle = Interface:CreateMultiDropdown({
		Name = 'Healthbar style',
		List = {'Match GUI colour', 'Main colour', 'Gradient', 'Background', 'Rounding', 'Outline', 'Custom text', 'Custom font'},
		Default = {'Main colour'},
		Function = function()
			local on = HealthStyle:Has('Match GUI colour')
			if HealthGuiSyncState ~= on then
				HealthGuiSyncState = on
				HealthGuiSyncChanged(on)
			end
			local on = HealthStyle:Has('Main colour')
			if HealthMainOnState ~= on then
				HealthMainOnState = on
				HealthMainOnChanged(on)
			end
			local on = HealthStyle:Has('Gradient')
			if HealthGradOnState ~= on then
				HealthGradOnState = on
				HealthGradOnChanged(on)
			end
			local on = HealthStyle:Has('Background')
			if HealthBgOnState ~= on then
				HealthBgOnState = on
				HealthBgOnChanged(on)
			end
			local on = HealthStyle:Has('Rounding')
			if HealthRoundOnState ~= on then
				HealthRoundOnState = on
				HealthRoundOnChanged(on)
			end
			local on = HealthStyle:Has('Outline')
			if HealthStrokeOnState ~= on then
				HealthStrokeOnState = on
				HealthStrokeOnChanged(on)
			end
			local on = HealthStyle:Has('Custom text')
			if HealthTextOnState ~= on then
				HealthTextOnState = on
				HealthTextOnChanged(on)
			end
		end,
		Tooltip = 'How the health bar is restyled; the colours, font and text below go with these'
	})
	HealthGuiSyncState = HealthStyle:Has('Match GUI colour')
	HealthMainOnState = HealthStyle:Has('Main colour')
	HealthGradOnState = HealthStyle:Has('Gradient')
	HealthBgOnState = HealthStyle:Has('Background')
	HealthRoundOnState = HealthStyle:Has('Rounding')
	HealthStrokeOnState = HealthStyle:Has('Outline')
	HealthTextOnState = HealthStyle:Has('Custom text')
	HealthGuiSync = setmetatable({}, {__index = function(_, key) if key == 'Enabled' then return HealthStyle:Has('Match GUI colour') end end})
	HealthMainOn = setmetatable({}, {__index = function(_, key) if key == 'Enabled' then return HealthStyle:Has('Main colour') end end})
	HealthGradOn = setmetatable({}, {__index = function(_, key) if key == 'Enabled' then return HealthStyle:Has('Gradient') end end})
	HealthBgOn = setmetatable({}, {__index = function(_, key) if key == 'Enabled' then return HealthStyle:Has('Background') end end})
	HealthRoundOn = setmetatable({}, {__index = function(_, key) if key == 'Enabled' then return HealthStyle:Has('Rounding') end end})
	HealthStrokeOn = setmetatable({}, {__index = function(_, key) if key == 'Enabled' then return HealthStyle:Has('Outline') end end})
	HealthTextOn = setmetatable({}, {__index = function(_, key) if key == 'Enabled' then return HealthStyle:Has('Custom text') end end})
	HealthFontOn = setmetatable({}, {__index = function(_, key) if key == 'Enabled' then return HealthStyle:Has('Custom font') end end})
	HealthRoundSize = Interface:CreateSlider({Name = 'Healthbar round size', Min = 1, Max = 16, Default = 4})
	local fonts = {'LuckiestGuy', 'GothamBold', 'SourceSansBold', 'Arcade', 'Fantasy'}
	HealthFontDrop = Interface:CreateDropdown({Name = 'Healthbar font', List = fonts, Default = 'LuckiestGuy'})
	HealthTextList = Interface:CreateTextList({Name = 'Healthbar text', TempText = 'use <health>'})
	HealthMainCol = Interface:CreateColorSlider({Name = 'Healthbar colour'})
	HealthGradCol = Interface:CreateColorSlider({Name = 'Healthbar secondary'})
	HealthBgCol = Interface:CreateColorSlider({Name = 'Healthbar background colour'})
	HealthStrokeCol = Interface:CreateColorSlider({Name = 'Healthbar outline colour'})
	HealthTextCol = Interface:CreateColorSlider({Name = 'Healthbar text colour'})
end)

run(function()
	local GetRoactRender = getRoactRender
	local function CreateGuiOverrides()
		local Objects = {}
		local function Restore()
			for Object, Saved in Objects do
				Saved.Destroying:Disconnect()
				for Property, Value in Saved.Properties do
					Value.Connection:Disconnect()
					if Object.Parent and Object[Property] == Value.Applied then
						Object[Property] = Value.Original
					end
				end
			end
			table.clear(Objects)
		end
		local function Apply(Object, Properties)
			local Saved = Objects[Object]
			if not Saved then
				Saved = {Properties = {}}
				Objects[Object] = Saved
				Saved.Destroying = Object.Destroying:Connect(function()
					Objects[Object] = nil
				end)
			end
			for Property, Applied in Properties do
				local Value = Saved.Properties[Property]
				if not Value then
					Value = {Original = Object[Property], Applied = Applied}
					Saved.Properties[Property] = Value
					Value.Connection = Object:GetPropertyChangedSignal(Property):Connect(function()
						if Objects[Object] == Saved and Object[Property] ~= Value.Applied then
							Value.Original = Object[Property]
							Object[Property] = Value.Applied
						end
					end)
				end
				Value.Applied = Applied
				Object[Property] = Applied
			end
		end
		return {Apply = Apply, Restore = Restore}
	end
	local GetVapeAsset = getcustomasset
	local LocalPlayer = lplr
	local StarterGui = starterGui
	local UICleanup
	local OpenInventory
	local KillFeed
	local OldTabList
	local ResizeHealth
	local NoNumbers
	local OriginalPlayerList: boolean?
	local HotbarApp = canDebug and GetRoactRender(require(LocalPlayer.PlayerScripts.TS.controllers.global.hotbar.ui["hotbar-app"]).HotbarApp.render)
	local HotbarOpenInventory = canDebug and require(LocalPlayer.PlayerScripts.TS.controllers.global.hotbar.ui["hotbar-open-inventory"]).HotbarOpenInventory
	local OldConstants, NewConstants = {}, {}
	local Indices: {[any]: {[string]: number}} = {}
	local OldKillFeed
	local GuiOverrides = CreateGuiOverrides()

	local function Added(Object: Instance)
		if not UICleanup.Enabled then
			return
		end
		if Object:IsA("ScreenGui") and Object.Name == "KillFeedGui" and KillFeed.Enabled then
			GuiOverrides.Apply(Object, {Enabled = false})
		elseif Object:IsA("GuiObject") and Object:FindFirstAncestor("hotbar") then
			if Object.Name == "HotbarHealthbarContainer" and ResizeHealth.Enabled then
				GuiOverrides.Apply(Object, {Size = UDim2.new(1, 0, Object.Size.Y.Scale, Object.Size.Y.Offset)})
			elseif Object.Parent.Name == "ItemsHotbar" and Object.Name == "10" and OpenInventory.Enabled then
				GuiOverrides.Apply(Object, {Visible = false})
			elseif Object:IsA("TextLabel") and Object.Parent:IsA("ImageButton") and Object:FindFirstAncestor("ItemsHotbar") and NoNumbers.Enabled then
				GuiOverrides.Apply(Object, {Visible = false})
			end
		end
	end

	local function Refresh()
		GuiOverrides.Restore()
		if UICleanup.Enabled then
			for _, v: Instance in LocalPlayer.PlayerGui:GetDescendants() do
				Added(v)
			end
		end
	end

	vape:Clean(function()
		for _, v: {[number]: any} in NewConstants do
			table.clear(v)
		end
		for _, v: {[number]: any} in OldConstants do
			table.clear(v)
		end
		table.clear(NewConstants)
		table.clear(OldConstants)
		table.clear(Indices)
	end)

	local function FindComponent(Name: string)
		if not HotbarApp then
			return nil
		end
		for Index: number = 1, 64 do
			local Success, Value = pcall(debug.getupvalue, HotbarApp, Index)
			if not Success then
				break
			end
			if type(Value) == "table" and rawget(Value, "__componentName") == Name then
				return Value
			end
		end
		return nil
	end

	local function Resolve(Function, Key: string, Value: any, After: any?): number?
		if typeof(Function) ~= "function" then
			return nil
		end
		local Known: {[string]: number}? = Indices[Function]
		if Known and Known[Key] then
			return Known[Key]
		end
		local Index: number?
		local Valid, Constants = pcall(debug.getconstants, Function)
		if Valid and type(Constants) == "table" then
			local Seen = After == nil
			for I = 1, table.maxn(Constants) do
				local Constant = Constants[I]
				if not Seen then
					Seen = Constant == After
				elseif Constant == Value then
					Index = I
					break
				end
			end
		end
		if Index then
			Indices[Function] = Known or {}
			Indices[Function][Key] = Index
		end
		return Index
	end

	local function ModifyConstant(Function, Index: number?, Value)
		if not Function or not Index then
			return
		end
		local Saved: {[number]: any}? = OldConstants[Function]
		local Original: any = Saved and Saved[Index]
		if Original == nil then
			if Value == nil then
				return
			end
			local Valid: boolean
			Valid, Original = pcall(debug.getconstant, Function, Index)
			if not Valid or typeof(Original) ~= typeof(Value) then
				return
			end
		end

		OldConstants[Function] = Saved or {}
		NewConstants[Function] = NewConstants[Function] or {}
		OldConstants[Function][Index] = Original
		NewConstants[Function][Index] = Value
		if UICleanup.Enabled then
			if Value then
				debug.setconstant(Function, Index, Value)
			else
				debug.setconstant(Function, Index, Original)
				OldConstants[Function][Index] = nil
			end
		end
	end

	UICleanup = Main:Part({
		Label = 'Clean up UI',
		Default = false,
		Name = "UICleanup",
		Category = "Game",
		Function = function(Callback: boolean)
			if not canDebug then
				if Callback then
					OriginalPlayerList = StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.PlayerList)
					UICleanup:Clean(GuiOverrides.Restore)
					UICleanup:Clean(LocalPlayer.PlayerGui.DescendantAdded:Connect(Added))
					StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, OldTabList.Enabled)
				elseif OriginalPlayerList ~= nil then
					StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, OriginalPlayerList)
					OriginalPlayerList = nil
				end
				Refresh()
				return
			end

			for Function: (...any) -> ...any, Constants: {[number]: any} in (Callback and NewConstants or OldConstants) do
				for i: number, Value: any in Constants do
					debug.setconstant(Function, i, Value)
				end
			end
			if Callback then
				if OpenInventory.Enabled then
					oldinvrender = HotbarOpenInventory.render
					HotbarOpenInventory.render = function()
						return bedwars.Roact.createElement("TextButton", {Visible = false}, {})
					end
				end

				if KillFeed.Enabled then
					OldKillFeed = bedwars.KillFeedController.addToKillFeed
					bedwars.KillFeedController.addToKillFeed = function() end
				end

				if OldTabList.Enabled then
					StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
				end
			else
				if oldinvrender then
					HotbarOpenInventory.render = oldinvrender
					oldinvrender = nil
				end

				if KillFeed.Enabled then
					bedwars.KillFeedController.addToKillFeed = OldKillFeed
					OldKillFeed = nil
				end

				if OldTabList.Enabled then
					StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
				end
			end
		end,
		Tooltip = 'Keeps popups and extra buttons off your screen'
	})

	ResizeHealth = UICleanup:CreateToggle({
		Name = "Resize Health",
		Function = function(Callback: boolean)
			if not canDebug then
				Refresh()
				return
			end
			local Healthbar = FindComponent("HotbarHealthbar")
			local Tile = FindComponent("HotbarTile")
			ModifyConstant(HotbarApp, Resolve(HotbarApp, "Width", 0.6), Callback and 1 or nil)
			ModifyConstant(Healthbar and Healthbar.render, Healthbar and Resolve(Healthbar.render, "Width", 0.85), Callback and 1 or nil)
			ModifyConstant(Tile and Tile.tweenPosition, Tile and Resolve(Tile.tweenPosition, "Lift", -0.075), Callback and 0 or nil)
		end,
		Default = true
	})
	NoNumbers = UICleanup:CreateToggle({
		Name = "No Hotbar Numbers",
		Function = function(Callback: boolean)
			if not canDebug then
				Refresh()
				return
			end
			local Tile = FindComponent("HotbarTile")
			local InventoryRender = oldinvrender or HotbarOpenInventory.render
			ModifyConstant(Tile and Tile.render, Tile and Resolve(Tile.render, "Number", 0.23, "Keybind"), Callback and 0 or nil)
			ModifyConstant(InventoryRender, Resolve(InventoryRender, "Number", 0.23), Callback and 0 or nil)
		end,
		Default = true
	})
	OpenInventory = UICleanup:CreateToggle({
		Name = "No Inventory Button",
		Function = function(Callback: boolean)
			if not canDebug then
				Refresh()
				return
			end
			if UICleanup.Enabled then
				if Callback then
					oldinvrender = HotbarOpenInventory.render
					HotbarOpenInventory.render = function()
						return bedwars.Roact.createElement("TextButton", {Visible = false}, {})
					end
				else
					HotbarOpenInventory.render = oldinvrender
					oldinvrender = nil
				end
			end
		end,
		Default = true
	})
	KillFeed = UICleanup:CreateToggle({
		Name = "No Kill Feed",
		Function = function(Callback: boolean)
			if not canDebug then
				Refresh()
				return
			end
			if UICleanup.Enabled then
				if Callback then
					OldKillFeed = bedwars.KillFeedController.addToKillFeed
					bedwars.KillFeedController.addToKillFeed = function() end
				else
					bedwars.KillFeedController.addToKillFeed = OldKillFeed
					OldKillFeed = nil
				end
			end
		end,
		Default = true
	})
	OldTabList = UICleanup:CreateToggle({
		Name = "Old Player List",
		Function = function(Callback: boolean)
			if UICleanup.Enabled then
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, Callback)
			end
		end,
		Default = true
	})
	UICleanup:CreateToggle({
		Name = "Fix Queue Card",
		Function = function(Callback: boolean)
			if not canDebug then
				return
			end
			ModifyConstant(bedwars.QueueCard.render, Resolve(bedwars.QueueCard.render, "Card", 0.01), Callback and 0.1 or nil)
		end,
		Visible = canDebug,
		Default = true
	})
end)

end)
