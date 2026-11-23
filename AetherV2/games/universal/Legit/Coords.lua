run(function()
	local Entity = entitylib
	local GetFontBounds = getfontsize
	local GetVapeAsset = getcustomasset
	local UIPallet = vape.Libraries.uipallet
	local RunService = runService
	local Camera = gameCamera
	local Coords
	local DisplayType
	local Background
	local BackgroundColor
	local HorizontalAxes = {}
	local VerticalAxes = {}
	local CoordText: {string} = {}
	local Positives: {[number]: boolean} = {}
	local Last = {}
	local PositiveColor: Color3 = Color3.fromRGB(5, 134, 105)
	local NegativeColor: Color3 = Color3.fromRGB(250, 50, 56)
	local TriangleArrow: string = GetVapeAsset(`aetherv2/assets/new/triangle.png`)
	local DigitWidth: number = GetFontBounds("0", 19, UIPallet.Font).X
	local Holder, Horizontal, Vertical
	local HorizontalMaterial, VerticalMaterial

	local function AddLabel(Parent: Instance, TextSize: number, TextColor: Color3): TextLabel
		local Label: TextLabel = Instance.new("TextLabel")
		Label.BackgroundTransparency = 1
		Label.FontFace = UIPallet.Font
		Label.Size = UDim2.fromOffset(200, 20)
		Label.TextColor3 = TextColor
		Label.TextSize = TextSize
		Label.TextXAlignment = Enum.TextXAlignment.Left
		Label.Parent = Parent

		return Label
	end

	local function AddArrow(Parent: Instance)
		local Box: Frame = Instance.new("Frame")
		Box.BackgroundColor3 = Color3.fromRGB(26, 25, 26)
		Box.BackgroundTransparency = 0.431
		Box.Size = UDim2.fromOffset(16, 16)
		Box.Parent = Parent
		local Corner: UICorner = Instance.new("UICorner")
		Corner.CornerRadius = UDim.new(0, 3)
		Corner.Parent = Box
		local Triangle: ImageLabel = Instance.new("ImageLabel")
		Triangle.BackgroundTransparency = 1
		Triangle.Image = TriangleArrow
		Triangle.Size = UDim2.fromOffset(8, 4)
		Triangle.Parent = Box

		return Box, Triangle
	end

	local function AddDivider(Parent: Instance, Size: UDim2): Frame
		local Divider: Frame = Instance.new("Frame")
		Divider.BackgroundColor3 = Color3.new(1, 1, 1)
		Divider.BackgroundTransparency = 0.8
		Divider.BorderSizePixel = 0
		Divider.Size = Size
		Divider.Parent = Parent

		return Divider
	end

	local function Update()
		if vape.ThreadFix then
			setthreadidentity(8)
		end

		if not Entity.isAlive then
			return
		end

		local Position: Vector3 = Entity.character.RootPart.Position
		local Look: Vector3 = Camera.CFrame.LookVector
		local Material: string = Entity.character.Humanoid.FloorMaterial.Name
		local X, Y, Z = math.round(Position.X), math.round(Position.Y), math.round(Position.Z)
		local PositiveX, PositiveZ = Look.X > 0, Look.Z > 0
		if Last.x == X and Last.y == Y and Last.z == Z and Last.positivex == PositiveX and Last.positivez == PositiveZ and Last.material == Material and Last.display == DisplayType.Value then
			return
		end

		Last.x, Last.y, Last.z, Last.positivex, Last.positivez, Last.material, Last.display = X, Y, Z, PositiveX, PositiveZ, Material, DisplayType.Value
		CoordText[1] = tostring(X)
		CoordText[2] = tostring(Y)
		CoordText[3] = tostring(Z)
		Positives[1] = PositiveX
		Positives[3] = PositiveZ

		if DisplayType.Value == "Vertical" then
			for i: number, v: any in VerticalAxes do
				v.Value.Text = CoordText[i]

				if v.Triangle then
					v.Triangle.ImageColor3 = Positives[i] and PositiveColor or NegativeColor
					v.Triangle.Position = UDim2.fromOffset(4, Positives[i] and 5 or 6)
					v.Triangle.Rotation = Positives[i] and 180 or 0
				end
			end

			VerticalMaterial.Text = Material
			return
		end

		local Offset: number = 20

		for i: number, v: any in HorizontalAxes do
			v.Label.Position = UDim2.fromOffset(Offset, 16)
			Offset += v.Width + 5
			v.Value.Text = CoordText[i]
			v.Value.Position = UDim2.fromOffset(Offset, 13)
			Offset += math.max(44, 10 + DigitWidth * #CoordText[i])

			if v.Triangle then
				v.Arrow.Position = UDim2.fromOffset(Offset - 8, 18)
				v.Triangle.ImageColor3 = Positives[i] and PositiveColor or NegativeColor
				v.Triangle.Position = UDim2.fromOffset(4, Positives[i] and 5 or 6)
				v.Triangle.Rotation = Positives[i] and 180 or 0
			end

			if v.Divider then
				Offset += v.Triangle and 20 or 0
				v.Divider.Position = UDim2.fromOffset(Offset - 1, 18)
				Offset += 20
			end
		end

		HorizontalMaterial.Text = Material
		Holder.Size = UDim2.fromOffset(Offset + 24, 70)
	end

	Coords = vape.Categories.Legit:CreateModule({
		Name = "Coords",
		Category = "HUD",
		Function = function(Callback: boolean)
			if Callback then
				Coords:Clean(RunService.RenderStepped:Connect(Update))
			end
		end,
		Size = UDim2.fromOffset(280, 70),
		Tooltip = "Shows your current XYZ coordinates"
	})

	DisplayType = Coords:CreateDropdown({
		Name = "Display Type",
		List = {"Horizontal", "Vertical"},
		Function = function(Value: string)
			if Holder then
				Horizontal.Visible = Value == "Horizontal"
				Vertical.Visible = Value == "Vertical"
				Holder.Size = UDim2.fromOffset(Value == "Vertical" and 140 or 280, Value == "Vertical" and 180 or 70)
			end
		end
	})
	Background = Coords:CreateToggle({
		Name = "Render background",
		Function = function(Callback: boolean)
			if BackgroundColor then
				Holder.BackgroundTransparency = Callback and 1 - BackgroundColor.Opacity or 1
				BackgroundColor.Object.Visible = Callback
			end
		end,
		Default = true
	})
	BackgroundColor = Coords:CreateColorSlider({
		Name = "Background Color",
		DefaultHue = 0.8333,
		DefaultSat = 0.0385,
		DefaultValue = 0.102,
		DefaultOpacity = 0.4,
		Function = function(Hue: number, Sat: number, Val: number, Opacity: number)
			if Holder then
				Holder.BackgroundColor3 = Color3.fromHSV(Hue, Sat, Val)
				Holder.BackgroundTransparency = Background.Enabled and 1 - Opacity or 1
			end
		end,
		Darker = true
	})
	Holder = Coords.Children
	Holder.BackgroundColor3 = Color3.fromRGB(26, 25, 26)
	Holder.BackgroundTransparency = 0.6
	local HolderCorner: UICorner = Instance.new("UICorner")
	HolderCorner.CornerRadius = UDim.new(0, 4)
	HolderCorner.Parent = Holder
	Horizontal = Instance.new("Frame")
	Horizontal.BackgroundTransparency = 1
	Horizontal.Name = "Horizontal"
	Horizontal.Size = UDim2.fromScale(1, 1)
	Horizontal.Parent = Holder
	Vertical = Instance.new("Frame")
	Vertical.BackgroundTransparency = 1
	Vertical.Name = "Vertical"
	Vertical.Size = UDim2.fromScale(1, 1)
	Vertical.Visible = false
	Vertical.Parent = Holder
	for i: number, Axis: string in {"X", "Y", "Z"} do
		local Entry = {Width = GetFontBounds(Axis, 12, UIPallet.Font).X}
		Entry.Label = AddLabel(Horizontal, 12, Color3.new(1, 1, 1))
		Entry.Label.Text = Axis
		Entry.Value = AddLabel(Horizontal, 19, Color3.new(1, 1, 1))

		if Axis ~= "Y" then
			Entry.Arrow, Entry.Triangle = AddArrow(Horizontal)
		end

		if Axis ~= "Z" then
			Entry.Divider = AddDivider(Horizontal, UDim2.fromOffset(2, 16))
		end

		HorizontalAxes[i] = Entry
	end
	for i: number, Axis: string in {"X", "Y", "Z"} do
		local Entry = {}
		Entry.Label = AddLabel(Vertical, 11, Color3.new(1, 1, 1))
		Entry.Label.Text = Axis
		Entry.Label.Position = UDim2.fromOffset(16, 16 + (i - 1) * 45)
		Entry.Value = AddLabel(Vertical, 17, Color3.new(1, 1, 1))
		Entry.Value.Position = UDim2.fromOffset(21 + GetFontBounds(Axis, 11, UIPallet.Font).X, 13 + (i - 1) * 45)

		if Axis ~= "Y" then
			Entry.Arrow, Entry.Triangle = AddArrow(Vertical)
			Entry.Arrow.Position = UDim2.fromOffset(108, Axis == "X" and 18 or 105)
		end

		VerticalAxes[i] = Entry
	end
	for i: number = 1, 3 do
		local Divider: Frame = AddDivider(Vertical, UDim2.fromOffset(110, 2))
		Divider.Position = UDim2.fromOffset(16, 2 + i * 45)
	end
	local HorizontalLabel: TextLabel = AddLabel(Horizontal, 12, Color3.new(1, 1, 1))
	HorizontalLabel.Text = "MATERIAL:"
	HorizontalLabel.Position = UDim2.fromOffset(20, 41)
	HorizontalMaterial = AddLabel(Horizontal, 12, Color3.fromRGB(255, 160, 84))
	HorizontalMaterial.Position = UDim2.fromOffset(20 + GetFontBounds("MATERIAL: ", 12, UIPallet.Font).X, 41)
	local VerticalLabel: TextLabel = AddLabel(Vertical, 11, Color3.new(1, 1, 1))
	VerticalLabel.Text = "MATERIAL:"
	VerticalLabel.Position = UDim2.fromOffset(16, 146)
	VerticalMaterial = AddLabel(Vertical, 11, Color3.fromRGB(255, 160, 84))
	VerticalMaterial.Position = UDim2.fromOffset(24 + GetFontBounds("MATERIAL:", 11, UIPallet.Font).X, 146)
end)
