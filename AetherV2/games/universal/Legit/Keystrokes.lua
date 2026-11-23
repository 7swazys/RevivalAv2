run(function()
	local GetFontBounds = getfontsize
	local GetVapeAsset = getcustomasset
	local UIPallet = vape.Libraries.uipallet
	local RunService = runService
	local Tween = vape.Libraries.tween
	local UserInputService = inputService
	local Keystrokes
	local KeyStyle
	local MouseStyle
	local ShowSpacebar
	local ShowCpsOnly
	local ColourMode
	local PartColours = {}
	local Keys = {}
	local LeftClicks: {number} = {}
	local RightClicks: {number} = {}
	local ArrowIcons: {[string]: string} = {
		W = GetVapeAsset(`aetherv2/assets/new/key_up.png`),
		A = GetVapeAsset(`aetherv2/assets/new/key_left.png`),
		S = GetVapeAsset(`aetherv2/assets/new/key_down.png`),
		D = GetVapeAsset(`aetherv2/assets/new/key_right.png`)
	}
	local Keybinds: {[Enum.KeyCode]: string} = {
		[Enum.KeyCode.W] = "W",
		[Enum.KeyCode.A] = "A",
		[Enum.KeyCode.S] = "S",
		[Enum.KeyCode.D] = "D",
		[Enum.KeyCode.Space] = "Space"
	}
	local ReleasedBackground: Color3 = Color3.fromRGB(20, 20, 20)
	local PressedText: Color3 = Color3.fromRGB(20, 20, 20)
	local KeyTween: TweenInfo = TweenInfo.new(0.05, Enum.EasingStyle.Linear)
	local Holder, MouseIcons, CpsHolder, CpsBackground, CpsDivider, CpsLeft, CpsRight, CpsLabel
	local LeftMouseIcon, RightMouseIcon, MiddleMouseIcon
	local ShownLeft, ShownRight

	local function PickColour(Part: string, Default: Color3, DefaultTransparency: number): (Color3, number)
		local Slider = ColourMode and (ColourMode:Has(Part) and PartColours[Part] or ColourMode:Has("Everything") and PartColours.Everything)
		if Slider then
			return Color3.fromHSV(Slider.Hue, Slider.Sat, Slider.Value), DefaultTransparency
		end
		return Default, DefaultTransparency
	end

	local function KeyColours(Pressed: boolean): (Color3, number, Color3)
		local Text: Color3 = PickColour("Text", Color3.new(1, 1, 1), 0)
		if Pressed then
			local Fill: Color3, Transparency: number = PickColour("Pressed key", Color3.new(1, 1, 1), 0)
			return Fill, Transparency, PressedText
		end
		local Fill: Color3, Transparency: number = PickColour("Key background", ReleasedBackground, 0.294)
		return Fill, Transparency, Text
	end

	local function AddLabel(Parent: Instance, Name: string, Text: string): TextLabel
		local Label: TextLabel = Instance.new("TextLabel")
		Label.BackgroundTransparency = 1
		Label.FontFace = UIPallet.FontDisplay
		Label.Name = Name
		Label.Size = UDim2.fromOffset(200, 22)
		Label.Text = Text
		Label.TextColor3 = Color3.fromRGB(209, 209, 209)
		Label.TextSize = 16 * UIPallet.DisplayScale
		Label.Parent = Parent

		return Label
	end

	local function PlaceCps(Label: TextLabel, X: number, CenterY: number, Alignment: Enum.TextXAlignment)
		Label.Position = UDim2.fromOffset(Alignment == Enum.TextXAlignment.Right and X - 200 or X, CenterY - 11)
		Label.TextXAlignment = Alignment
	end

	local function PlaceKey(Entry, X: number, Y: number, Width: number, Height: number)
		Entry.Object.Position = UDim2.fromOffset(X, Y - 1)
		Entry.Object.Size = UDim2.fromOffset(Width, Height + 1)
		Entry.Label.Position = UDim2.fromOffset((Width / 2) - 100, 5.75)
		Entry.Icon.Position = UDim2.fromOffset((Width / 2) - 4.4, 6)
	end

	local function PressKey(Entry, Pressed: boolean)
		if Entry.Pressed == Pressed then
			return
		end

		Entry.Pressed = Pressed
		Entry.Shadow.Enabled = Pressed
		local Fill: Color3, Transparency: number, Text: Color3 = KeyColours(Pressed)

		Tween:Tween(Entry.Object, KeyTween, {
			BackgroundColor3 = Fill,
			BackgroundTransparency = Transparency
		})

		Tween:Tween(Entry.Bar, KeyTween, {
			BackgroundColor3 = Text
		})

		Tween:Tween(Entry.Icon, KeyTween, {
			ImageColor3 = Text
		})

		Tween:Tween(Entry.Label, KeyTween, {
			TextColor3 = Text
		})

		if Entry.Mouse then
			Tween:Tween(Entry.Mouse, KeyTween, {
				ImageColor3 = Fill,
				ImageTransparency = Transparency
			})
		end
	end

	local function ApplyColours()
		if not (Holder and CpsBackground) then
			return
		end

		for _, Entry: any in Keys do
			local Fill: Color3, Transparency: number, Text: Color3 = KeyColours(Entry.Pressed)
			Entry.Object.BackgroundColor3 = Fill
			Entry.Object.BackgroundTransparency = Transparency
			Entry.Bar.BackgroundColor3 = Text
			Entry.Icon.ImageColor3 = Text
			Entry.Label.TextColor3 = Text
			if Entry.Mouse then
				Entry.Mouse.ImageColor3 = Fill
				Entry.Mouse.ImageTransparency = Transparency
			end
		end

		local CpsFill: Color3, CpsTransparency: number = PickColour("CPS box", ReleasedBackground, 0.294)
		CpsBackground.BackgroundColor3 = CpsFill
		CpsBackground.BackgroundTransparency = CpsTransparency
		local CpsText: Color3 = PickColour("Text", Color3.fromRGB(209, 209, 209), 0)
		CpsDivider.BackgroundColor3 = CpsText
		CpsLeft.TextColor3 = CpsText
		CpsRight.TextColor3 = CpsText
		CpsLabel.TextColor3 = CpsText
	end

	local function CountClicks(Clicks: {number}): number
		local Now: number = tick()
		while Clicks[1] and Clicks[1] < Now do
			table.remove(Clicks, 1)
		end

		return #Clicks
	end

	local function RefreshLayout()
		if not Holder then
			return
		end

		local IconStyle: boolean = MouseStyle.Value == "Icon"
		local ArrowStyle: boolean = KeyStyle.Value == "Arrow"
		local Spacebar: boolean = ShowSpacebar.Enabled

		for KeyName: string, v: any in Keys do
			v.Object.Visible = not ShowCpsOnly.Enabled and (KeyName ~= "Space" or Spacebar) and not (IconStyle and (KeyName == "LMB" or KeyName == "RMB"))
			v.Label.Visible = not ArrowStyle or KeyName == "LMB" or KeyName == "RMB" or KeyName == "Space"
			v.Icon.Visible = ArrowStyle and ArrowIcons[KeyName] ~= nil
			v.Icon.Image = ArrowIcons[KeyName] or ""
		end

		MouseIcons.Visible = IconStyle and not ShowCpsOnly.Enabled
		CpsDivider.Visible = not ShowCpsOnly.Enabled
		CpsLabel.Visible = ShowCpsOnly.Enabled
		CpsRight.Visible = not ShowCpsOnly.Enabled

		if ShowCpsOnly.Enabled then
			Holder.Size = UDim2.fromOffset(150, 40)
			CpsHolder.Position = UDim2.fromOffset(0, 0)
			CpsHolder.Size = UDim2.fromOffset(110, 20)
			CpsBackground.Position = UDim2.fromOffset(0, 0)
			CpsBackground.Size = UDim2.fromOffset(39 + GetFontBounds("CPS", 16 * UIPallet.DisplayScale, UIPallet.FontDisplay).X, 24)
			PlaceCps(CpsLeft, 22, 14, Enum.TextXAlignment.Right)
			PlaceCps(CpsLabel, 25, 14, Enum.TextXAlignment.Left)

			return
		end

		local KeysY: number = IconStyle and 8 or 4
		local MouseX: number = IconStyle and 122 or 0
		local MouseY: number = (IconStyle and KeysY - 12 or KeysY + 80) + (Spacebar and 28 or 0)
		local CpsWidth: number = IconStyle and 80 or 110
		Holder.Size = UDim2.fromOffset(108 + (IconStyle and 96 or 0), (IconStyle and 80 or 144) + (Spacebar and 28 or 0))
		PlaceKey(Keys.W, 38, KeysY - 4, 34, 34)
		PlaceKey(Keys.A, 0, KeysY + 38, 34, 34)
		PlaceKey(Keys.S, 38, KeysY + 38, 34, 34)
		PlaceKey(Keys.D, 76, KeysY + 38, 34, 34)
		PlaceKey(Keys.Space, 0, KeysY + 79, 110.5, 22)
		PlaceKey(Keys.LMB, MouseX, MouseY, 52.7, 32)
		PlaceKey(Keys.RMB, MouseX + 56.7, MouseY, 52.7, 32)
		MouseIcons.Position = UDim2.fromOffset(MouseX - 4, MouseY)
		CpsHolder.Position = UDim2.fromOffset(MouseX, MouseY + (IconStyle and 44 or 34))
		CpsHolder.Size = UDim2.fromOffset(CpsWidth, 20)
		CpsBackground.Position = UDim2.fromOffset(0, 4)
		CpsBackground.Size = UDim2.fromOffset(CpsWidth, 24)
		CpsDivider.Position = UDim2.fromOffset(CpsWidth / 2, 8)
		PlaceCps(CpsLeft, 10, 16, Enum.TextXAlignment.Left)
		PlaceCps(CpsRight, CpsWidth - 10, 16, Enum.TextXAlignment.Right)
	end

	local function Update()
		if vape.ThreadFix then
			setthreadidentity(8)
		end

		local LeftCount: number = CountClicks(LeftClicks)
		if LeftCount ~= ShownLeft then
			ShownLeft = LeftCount
			CpsLeft.Text = tostring(LeftCount)
		end

		local RightCount: number = CountClicks(RightClicks)
		if RightCount ~= ShownRight then
			ShownRight = RightCount
			CpsRight.Text = tostring(RightCount)
		end
	end

	local function InputChanged(Input: InputObject, Pressed: boolean)
		if vape.ThreadFix then
			setthreadidentity(8)
		end

		local Name: string? = Keybinds[Input.KeyCode]
		if Input.UserInputType == Enum.UserInputType.MouseButton1 then
			Name = "LMB"

			if Pressed then
				table.insert(LeftClicks, tick() + 1)
			end
		elseif Input.UserInputType == Enum.UserInputType.MouseButton2 then
			Name = "RMB"

			if Pressed then
				table.insert(RightClicks, tick() + 1)
			end
		end

		if Name and Keys[Name] then
			PressKey(Keys[Name], Pressed)
		end
	end

	Keystrokes = vape.Categories.Legit:CreateModule({
		Name = "Keystrokes",
		Category = "HUD",
		Function = function(Callback: boolean)
			if Callback then
				Keystrokes:Clean(UserInputService.InputBegan:Connect(function(Input: InputObject)
					InputChanged(Input, true)
				end))

				Keystrokes:Clean(UserInputService.InputEnded:Connect(function(Input: InputObject)
					InputChanged(Input, false)
				end))

				Keystrokes:Clean(RunService.RenderStepped:Connect(Update))
			else
				for _, v: any in Keys do
					PressKey(v, false)
				end
			end
		end,
		Size = UDim2.fromOffset(108, 172),
		Tooltip = "Shows when your movement keys or mouse buttons are pressed, as well as mouse clicks per second"
	})

	KeyStyle = Keystrokes:CreateDropdown({
		Name = "Key Style",
		List = {"Keyboard", "Arrow"},
		Function = function()
			RefreshLayout()
		end
	})
	MouseStyle = Keystrokes:CreateDropdown({
		Name = "Mouse Style",
		List = {"Button", "Icon"},
		Function = function()
			RefreshLayout()
		end
	})
	ShowSpacebar = Keystrokes:CreateToggle({
		Name = "Show Spacebar",
		Function = function()
			RefreshLayout()
		end,
		Default = true
	})
	ShowCpsOnly = Keystrokes:CreateToggle({
		Name = "Show CPS Only",
		Function = function()
			RefreshLayout()
		end
	})
	ColourMode = Keystrokes:CreateMultiDropdown({
		Name = "Colour Mode",
		List = {"Everything", "Key background", "Pressed key", "Text", "CPS box"},
		Default = {},
		Function = function()
			ApplyColours()
		end,
		Tooltip = "Parts that use your own colour. Everything colours every part without its own pick"
	})
	for _, v: {string} in {
		{"Everything", "Colour"},
		{"Key background", "Key background colour"},
		{"Pressed key", "Pressed key colour"},
		{"Text", "Text colour"},
		{"CPS box", "CPS box colour"}
	} do
		local Part: string = v[1]
		PartColours[Part] = Keystrokes:CreateColorSlider({
			Name = v[2],
			Function = function()
				ApplyColours()
			end,
			Visible = function()
				return ColourMode:Has(Part)
			end
		})
	end
	Holder = Keystrokes.Children
	for _, v: string in {"W", "A", "S", "D", "Space", "LMB", "RMB"} do
		local Name: string = v
		local Key: Frame = Instance.new("Frame")
		Key.BackgroundColor3 = ReleasedBackground
		Key.BackgroundTransparency = 0.294
		Key.BorderSizePixel = 0
		Key.Name = Name
		Key.Parent = Holder
		local Corner: UICorner = Instance.new("UICorner")
		Corner.CornerRadius = UDim.new(0, 5)
		Corner.Parent = Key
		local Shadow: UIShadow = Instance.new("UIShadow")
		Shadow.BlurRadius = UDim.new(0, 6)
		Shadow.Color = Color3.new()
		Shadow.Enabled = false
		Shadow.Offset = UDim2.new()
		Shadow.Spread = UDim2.new()
		Shadow.Transparency = 0.404
		Shadow.Parent = Key
		local Label: TextLabel = Instance.new("TextLabel")
		Label.BackgroundTransparency = 1
		Label.FontFace = UIPallet.FontBold
		Label.Name = "Label"
		Label.Size = UDim2.fromOffset(200, 20)
		Label.Text = Name == "Space" and "" or Name
		Label.TextColor3 = Color3.new(1, 1, 1)
		Label.TextSize = 14
		Label.Parent = Key
		local Icon: ImageLabel = Instance.new("ImageLabel")
		Icon.BackgroundTransparency = 1
		Icon.Name = "Icon"
		Icon.Size = UDim2.fromOffset(8.8, 8.8)
		Icon.Visible = false
		Icon.Parent = Key
		local Bar: Frame = Instance.new("Frame")
		Bar.AnchorPoint = Vector2.new(0.5, 0)
		Bar.BackgroundColor3 = Color3.new(1, 1, 1)
		Bar.BorderSizePixel = 0
		Bar.Name = "Bar"
		Bar.Position = UDim2.new(0.5, 0, 0, 4)
		Bar.Size = UDim2.fromOffset(60, 3)
		Bar.Visible = Name == "Space"
		Bar.Parent = Key
		Keys[Name] = {Object = Key, Label = Label, Icon = Icon, Bar = Bar, Shadow = Shadow, Pressed = false}
	end
	MouseIcons = Instance.new("Frame")
	MouseIcons.BackgroundTransparency = 1
	MouseIcons.Name = "MouseIcons"
	MouseIcons.Size = UDim2.fromOffset(96, 48)
	MouseIcons.Visible = false
	MouseIcons.Parent = Holder
	LeftMouseIcon = Instance.new("ImageLabel")
	LeftMouseIcon.BackgroundTransparency = 1
	LeftMouseIcon.Image = GetVapeAsset(`aetherv2/assets/new/key_lmb.png`)
	LeftMouseIcon.ImageColor3 = ReleasedBackground
	LeftMouseIcon.Name = "LMB"
	LeftMouseIcon.Size = UDim2.fromOffset(50.2, 48)
	LeftMouseIcon.Parent = MouseIcons
	RightMouseIcon = LeftMouseIcon:Clone()
	RightMouseIcon.Image = GetVapeAsset(`aetherv2/assets/new/key_rmb.png`)
	RightMouseIcon.Name = "RMB"
	RightMouseIcon.Position = UDim2.fromOffset(40, 0)
	RightMouseIcon.Parent = MouseIcons
	MiddleMouseIcon = Instance.new("ImageLabel")
	MiddleMouseIcon.BackgroundTransparency = 1
	MiddleMouseIcon.Image = GetVapeAsset(`aetherv2/assets/new/key_mmb.png`)
	MiddleMouseIcon.ImageColor3 = Color3.fromRGB(225, 225, 225)
	MiddleMouseIcon.Name = "MMB"
	MiddleMouseIcon.Position = UDim2.fromOffset(43, 14)
	MiddleMouseIcon.Size = UDim2.fromOffset(3.9, 13.8)
	MiddleMouseIcon.Parent = MouseIcons
	CpsHolder = Instance.new("Frame")
	CpsHolder.BackgroundTransparency = 1
	CpsHolder.Name = "CPS"
	CpsHolder.Size = UDim2.fromOffset(110, 20)
	CpsHolder.Parent = Holder
	CpsBackground = Instance.new("Frame")
	CpsBackground.BackgroundColor3 = ReleasedBackground
	CpsBackground.BackgroundTransparency = 0.294
	CpsBackground.BorderSizePixel = 0
	CpsBackground.Name = "Background"
	CpsBackground.ZIndex = 0
	CpsBackground.Parent = CpsHolder
	local CpsCorner: UICorner = Instance.new("UICorner")
	CpsCorner.CornerRadius = UDim.new(0, 5)
	CpsCorner.Parent = CpsBackground
	CpsDivider = Instance.new("Frame")
	CpsDivider.BackgroundColor3 = Color3.fromRGB(209, 209, 209)
	CpsDivider.BorderSizePixel = 0
	CpsDivider.Name = "Divider"
	CpsDivider.Size = UDim2.fromOffset(2, 18)
	CpsDivider.Parent = CpsHolder
	CpsLeft = AddLabel(CpsHolder, "Left", "0")
	CpsRight = AddLabel(CpsHolder, "Right", "0")
	CpsLabel = AddLabel(CpsHolder, "Label", "CPS")
	CpsLabel.Visible = false
	Keys.LMB.Mouse = LeftMouseIcon
	Keys.RMB.Mouse = RightMouseIcon
	RefreshLayout()
	ApplyColours()
end)
