run(function()
	local Sides = sides
	local AddBlur = addBlur
	local Camera = gameCamera
	local CollectionService = collectionService
	local Color = color
	local Entity = entitylib
	local GetPlacedBlock = getPlacedBlock
	local GetVapeAsset = getcustomasset
	local LocalPlayer = lplr
	local RoundPosition = roundPos
	local RunService = runService
	local Store = store
	local UIPallet = uipallet
	local UserInputService = inputService
	local VapeEvents = vapeEvents
	local BedDefense
	local Target
	local MaxLayers
	local View
	local ShowBed
	local AutoRotate
	local RotateSpeed
	local Transparency
	local Holder, Viewport, ViewportCamera, Empty, ButtonRow, BedLabel
	local Layers, Buttons, Tracked = {}, {}, {}
	local TrackedCount, Detected = 0, 0
	local Current, Manual, BedClone
	local Accent
	local Yaw, Pitch, Radius, Center, Zoom = 0, math.rad(28), 12, Vector3.zero, 1
	local Dragging, LastDrag, Pending = nil, Vector3.zero, false
	local Touches, PinchDistance = {}, nil

	local function CloneModel(Object: Instance)
		local Clone: Instance? = Object:Clone()
		if not Clone then return end
		for _, Tag: string in Clone:GetTags() do
			Clone:RemoveTag(Tag)
		end
		for _, v: Instance in Clone:GetDescendants() do
			for _, Tag: string in v:GetTags() do
				v:RemoveTag(Tag)
			end
		end
		return Clone
	end

	local function GetBeds()
		local Beds: {Instance} = {}
		local Team: string = tostring(LocalPlayer:GetAttribute("Team"))
		for _, Bed: Instance in CollectionService:GetTagged("bed") do
			if Bed:IsDescendantOf(workspace) and tostring(Bed:GetAttribute("TeamId")) ~= Team and not table.find(Beds, Bed) then
				table.insert(Beds, Bed)
			end
		end
		table.sort(Beds, function(A: Instance, B: Instance)
			return (tonumber(A:GetAttribute("TeamId")) or 0) < (tonumber(B:GetAttribute("TeamId")) or 0)
		end)
		return Beds
	end

	local function GetBedName(Bed: Instance)
		local TeamId: number? = tonumber(Bed:GetAttribute("TeamId"))
		local Queue = bedwars.QueueMeta[Store.queueType]
		local Team = Queue and TeamId and Queue.teams[TeamId]
		return `{Team and Team.displayName or `Team {TeamId or "?"}`} Bed`
	end

	local function GetTargetBed()
		local Beds: {Instance} = GetBeds()
		if Target.Value == "Manual" then
			return Manual and Manual.Parent and Manual or Beds[1]
		end

		local Origin: Vector3 = Entity.isAlive and Entity.character.RootPart.Position or Camera.CFrame.Position
		local Best, BestScore
		for _, Bed: BasePart in Beds do
			local Score: number = Target.Value == "Crosshair" and -Camera.CFrame.LookVector:Dot((Bed.Position - Camera.CFrame.Position).Unit) or (Bed.Position - Origin).Magnitude
			if not BestScore or Score < BestScore then
				Best, BestScore = Bed, Score
			end
		end
		return Best
	end

	local function ScanLayers(Bed: BasePart)
		local Depth, Queue, BlockLayers = {}, {}, {}
		for _, v: Vector3 in {RoundPosition(Bed.Position), RoundPosition(Bed.CFrame * Vector3.new(0, 0, 3))} do
			Depth[v] = 0
			table.insert(Queue, v)
		end

		local Head: number = 0
		while Head < #Queue do
			Head += 1
			local Position: Vector3 = Queue[Head]
			local Level: number = Depth[Position]
			if Level >= MaxLayers.Value then continue end

			for _, Side: Vector3 in Sides do
				local NextPosition: Vector3 = Position + Side
				if Depth[NextPosition] ~= nil then continue end
				local Block: Instance? = GetPlacedBlock(NextPosition)
				if Block and Block ~= Bed and Block.Name ~= "bed" and not Block:GetAttribute("NoBreak") then
					Depth[NextPosition] = Level + 1
					BlockLayers[Level + 1] = BlockLayers[Level + 1] or {}
					table.insert(BlockLayers[Level + 1], Block)
					table.insert(Queue, NextPosition)
				else
					Depth[NextPosition] = false
				end
			end
		end

		return BlockLayers
	end

	local function GetSelected()
		local Index: number? = tonumber(View.Value:match("%d+"))
		return Index and Index <= Detected and Index or nil
	end

	local function UpdateCamera()
		local Distance: number = Radius / math.tan(math.rad(ViewportCamera.FieldOfView / 2)) * 1.15 * Zoom
		ViewportCamera.CFrame = CFrame.new(Center) * CFrame.Angles(0, Yaw, 0) * CFrame.Angles(-Pitch, 0, 0) * CFrame.new(0, 0, Distance)
	end

	local function SetZoom(Value: number)
		Zoom = math.clamp(Value, 0.35, 3)
		UpdateCamera()
	end

	local function GetPinchDistance()
		return (Touches[1].Position - Touches[2].Position).Magnitude
	end

	local function GetAccent()
		return Color3.fromHSV(vape.GUIColor.Hue, vape.GUIColor.Sat, vape.GUIColor.Value)
	end

	local function UpdateButtons()
		local Selected: number? = GetSelected()
		Accent = GetAccent()
		for Name: string, Button: TextButton in Buttons do
			local Active: boolean = Selected and Name == `Layer {Selected}` or not Selected and Name == "All"
			Button.BackgroundColor3 = Active and Accent or Color.Light(UIPallet.Main, 0.034)
			Button.Label.TextColor3 = Active and UIPallet.Text or Color.Dark(UIPallet.Text, 0.16)
		end
	end

	local function AddShadow(Label: TextLabel)
		local Shadow: TextLabel = Label:Clone()
		Shadow.Name = "Shadow"
		Shadow.Position = Label.Position + UDim2.fromOffset(1, 1)
		Shadow.TextColor3 = Color3.new()
		Shadow.TextTransparency = 0.65
		Shadow.ZIndex = Label.ZIndex - 1
		Shadow.Parent = Label.Parent
		Label:GetPropertyChangedSignal("Text"):Connect(function()
			Shadow.Text = Label.Text
		end)
		Label:GetPropertyChangedSignal("Visible"):Connect(function()
			Shadow.Visible = Label.Visible
		end)
	end

	local function BuildButtons()
		if not ButtonRow then return end
		for _, Button: TextButton in Buttons do
			Button:Destroy()
		end
		table.clear(Buttons)

		local Names: {string} = {}
		for i: number = 1, Detected do
			table.insert(Names, `Layer {i}`)
		end
		table.insert(Names, "All")

		for i: number, Name: string in Names do
			local Button: TextButton = Instance.new("TextButton")
			Button.Name = Name
			Button.AutoButtonColor = false
			Button.BorderSizePixel = 0
			Button.LayoutOrder = i
			Button.Size = UDim2.new(1 / #Names, -4, 1, 0)
			Button.Text = ""
			Button.Parent = ButtonRow
			local Corner: UICorner = Instance.new("UICorner")
			Corner.CornerRadius = UDim.new(0, 4)
			Corner.Parent = Button
			local Label: TextLabel = Instance.new("TextLabel")
			Label.Name = "Label"
			Label.BackgroundTransparency = 1
			Label.FontFace = UIPallet.Font
			Label.Size = UDim2.fromScale(1, 1)
			Label.Text = Detected > 3 and Name ~= "All" and Name:match("%d+") or Name
			Label.TextSize = 12
			Label.ZIndex = 2
			Label.Parent = Button
			AddShadow(Label)
			Button.MouseButton1Click:Connect(function()
				View:SetValue(Name)
			end)
			Buttons[Name] = Button
		end

		UpdateButtons()
	end

	local function UpdateView()
		if not Viewport then return end
		local Selected: number? = GetSelected()
		local Min, Max = Vector3.one * math.huge, Vector3.one * -math.huge
		local Shown: number = 0

		for i: number, Folder: Folder in Layers do
			local Visible: boolean = not Selected or i == Selected
			Folder.Parent = Visible and Viewport or nil
			if Visible then
				for _, Part: BasePart in Folder:QueryDescendants("BasePart") do
					Min, Max = Min:Min(Part.Position - Part.Size / 2), Max:Max(Part.Position + Part.Size / 2)
					Shown += 1
				end
			end
		end

		if BedClone then
			BedClone.Parent = ShowBed.Enabled and Viewport or nil
			Min, Max = Min:Min(Current.Position - Vector3.one * 3), Max:Max(Current.Position + Vector3.one * 3)
		end

		if Min.X ~= math.huge then
			Center = (Min + Max) / 2
			Radius = math.max((Max - Min).Magnitude / 2, 6)
		end

		local BedPart: Instance? = Current and Current:FindFirstChild("Bed")
		BedLabel.Text = Current and GetBedName(Current) or "No bed"
		BedLabel.TextColor3 = BedPart and BedPart.Color or Color.Dark(UIPallet.Text, 0.16)
		Empty.Visible = not Current or Shown == 0
		Empty.Text = not Current and "No bed found" or Selected and `Layer {Selected} is empty` or "No defense"
		UpdateButtons()
		UpdateCamera()
	end

	local function IsUnchanged(BlockLayers)
		local Count: number = 0
		for Level: number, List: {Instance} in BlockLayers do
			for _, Block: Instance in List do
				if Tracked[Block] ~= Level then return false end
				Count += 1
			end
		end
		return Count == TrackedCount
	end

	local function Rebuild(Bed: Instance?, BlockLayers)
		if vape.ThreadFix then
			setthreadidentity(8)
		end
		Pending = false

		for _, Folder: Folder in Layers do
			Folder:Destroy()
		end
		table.clear(Layers)
		table.clear(Tracked)
		TrackedCount = 0
		if BedClone then
			BedClone:Destroy()
			BedClone = nil
		end

		Current = Bed or GetTargetBed()
		BlockLayers = Current and (BlockLayers or ScanLayers(Current)) or {}
		if Detected ~= #BlockLayers then
			Detected = #BlockLayers
			BuildButtons()
		end
		if Current then
			for i: number = 1, Detected do
				local Folder: Folder = Instance.new("Folder")
				Folder.Name = `Layer{i}`
				for _, Block: Instance in BlockLayers[i] or {} do
					Tracked[Block] = i
					TrackedCount += 1
					local Clone: Instance? = CloneModel(Block)
					if Clone then
						Clone.Parent = Folder
					end
				end
				Layers[i] = Folder
			end
			BedClone = CloneModel(Current)
		end

		UpdateView()
	end

	local function CycleBed(Step: number)
		local Beds: {Instance} = GetBeds()
		if #Beds == 0 then return end

		local Index: number = table.find(Beds, Current) or 0
		Manual = Beds[((Index - 1 + Step) % #Beds) + 1]

		if Target.Value ~= "Manual" then
			Target:SetValue("Manual")
		elseif BedDefense.Button.Enabled then
			Rebuild()
		end
	end

	local function RefreshNear(Data)
		if not Current then return end

		local Position = Data and Data.blockRef and Data.blockRef.blockPosition
		if Position and ((Position * 3) - Current.Position).Magnitude <= 30 then
			Pending = true
		end
	end

	local function CreateArrow(Position: UDim2, Step: number)
		local Button: TextButton = Instance.new("TextButton")
		Button.AnchorPoint = Vector2.new(0.5, 0.5)
		Button.AutoButtonColor = false
		Button.BackgroundColor3 = Color.Light(UIPallet.Main, 0.034)
		Button.BorderSizePixel = 0
		Button.Name = Step < 0 and "Previous" or "Next"
		Button.Position = Position
		Button.Size = UDim2.fromOffset(22, 22)
		Button.Text = ""
		Button.Parent = Holder
		local Corner: UICorner = Instance.new("UICorner")
		Corner.CornerRadius = UDim.new(0, 4)
		Corner.Parent = Button
		local Arrow: ImageLabel = Instance.new("ImageLabel")
		Arrow.AnchorPoint = Vector2.new(0.5, 0.5)
		Arrow.BackgroundTransparency = 1
		Arrow.Image = GetVapeAsset(`aetherv2/assets/new/expandright.png`)
		Arrow.ImageColor3 = Color.Dark(UIPallet.Text, 0.16)
		Arrow.Position = UDim2.fromScale(0.5, 0.5)
		Arrow.Rotation = Step < 0 and 180 or 0
		Arrow.Size = UDim2.fromOffset(6, 12)
		Arrow.Parent = Button
		Button.MouseButton1Click:Connect(function()
			CycleBed(Step)
		end)
		Button.MouseEnter:Connect(function()
			Button.BackgroundColor3 = Color.Light(UIPallet.Main, 0.1)
			Arrow.ImageColor3 = UIPallet.Text
		end)
		Button.MouseLeave:Connect(function()
			Button.BackgroundColor3 = Color.Light(UIPallet.Main, 0.034)
			Arrow.ImageColor3 = Color.Dark(UIPallet.Text, 0.16)
		end)
	end

	BedDefense = vape:CreateOverlay({
		Name = "Bed Defense",
		Icon = GetVapeAsset(`aetherv2/assets/new/legit_bedalarm.png`),
		Size = UDim2.fromOffset(16, 16),
		Position = UDim2.fromOffset(12, 13),
		CategorySize = 240,
		Function = function(Callback: boolean)
			if Callback then
				BedDefense:Clean(VapeEvents.PlaceBlockEvent.Event:Connect(RefreshNear))
				BedDefense:Clean(VapeEvents.BreakBlockEvent.Event:Connect(RefreshNear))
				BedDefense:Clean(UserInputService.InputChanged:Connect(function(Input: InputObject)
					if PinchDistance and table.find(Touches, Input) then
						local Distance: number = GetPinchDistance()
						if Distance > 0 then
							SetZoom(Zoom * PinchDistance / Distance)
							PinchDistance = Distance
						end
						return
					end
					if not Dragging then return end
					if Input == Dragging or Input.UserInputType == Enum.UserInputType.MouseMovement and Dragging.UserInputType == Enum.UserInputType.MouseButton1 then
						local Delta: Vector3 = Input.Position - LastDrag
						LastDrag = Input.Position
						Yaw -= Delta.X * 0.01
						Pitch = math.clamp(Pitch + Delta.Y * 0.01, math.rad(-80), math.rad(80))
						UpdateCamera()
					end
				end))
				BedDefense:Clean(UserInputService.InputEnded:Connect(function(Input: InputObject)
					local Index: number? = table.find(Touches, Input)
					if Index then
						table.remove(Touches, Index)
						PinchDistance = nil
					end
					if Dragging and (Input == Dragging or Input.UserInputType == Enum.UserInputType.MouseButton1) then
						Dragging = nil
					end
				end))
				BedDefense:Clean(RunService.RenderStepped:Connect(function(DeltaTime: number)
					if AutoRotate.Enabled and not Dragging and not PinchDistance and Holder.AbsoluteSize.X > 0 and BedDefense.Children.Parent.Visible then
						Yaw += DeltaTime * math.rad(RotateSpeed.Value)
						UpdateCamera()
					end
				end))

				Rebuild()

				local Checked: number = tick()
				repeat
					if GetAccent() ~= Accent then
						UpdateButtons()
					end
					local Bed: Instance? = GetTargetBed()
					if Pending or Bed ~= Current then
						Rebuild(Bed)
					elseif Bed and (tick() - Checked) > 0.5 then
						Checked = tick()
						local BlockLayers = ScanLayers(Bed)
						if not IsUnchanged(BlockLayers) then
							Rebuild(Bed, BlockLayers)
						end
					end
					task.wait(0.1)
				until not BedDefense.Button.Enabled
			else
				Dragging, Pending, PinchDistance = nil, false, nil
				table.clear(Touches)
				for _, Folder: Folder in Layers do
					Folder:Destroy()
				end
				table.clear(Layers)
				if BedClone then
					BedClone:Destroy()
					BedClone = nil
				end
				Current = nil
			end
		end
	})

	local OldColor = BedDefense.Color
	function BedDefense:Color(Hue: number, Sat: number, Val: number, IsRainbow: boolean)
		OldColor(self, Hue, Sat, Val, IsRainbow)
		if Holder then
			UpdateButtons()
		end
	end

	Target = BedDefense:CreateDropdown({
		Name = "Bed",
		List = {"Nearest", "Crosshair", "Manual"},
		Function = function()
			if BedDefense.Button.Enabled then
				Rebuild()
			end
		end,
		Tooltip = 'Nearest - the closest enemy bed\nCrosshair - the one you look at\nManual - the one you pick with the arrows'
	})
	View = BedDefense:CreateDropdown({
		Name = "View",
		List = {"All", "Layer 1", "Layer 2", "Layer 3", "Layer 4", "Layer 5", "Layer 6", "Layer 7", "Layer 8", "Layer 9", "Layer 10"},
		Function = function()
			UpdateView()
		end,
		Tooltip = 'Which layer of the defense to show'
	})
	MaxLayers = BedDefense:CreateSlider({
		Name = "Max layers",
		Min = 1,
		Max = 10,
		Default = 6,
		Function = function()
			if Holder and BedDefense.Button.Enabled then
				Rebuild()
			end
		end,
		Tooltip = 'How many layers to scan out from the bed'
	})
	ShowBed = BedDefense:CreateToggle({
		Name = "Show bed",
		Function = function()
			UpdateView()
		end,
		Default = true
	})
	AutoRotate = BedDefense:CreateGroup({
		Name = "Auto rotate",
		Default = true
	})
	RotateSpeed = AutoRotate:CreateSlider({
		Name = "Rotate speed",
		Min = 5,
		Max = 90,
		Default = 20,
		Darker = true,
		Suffix = "Â°/s"
	})
	Transparency = BedDefense:CreateSlider({
		Name = "Transparency",
		Min = 0,
		Max = 1,
		Default = 0.5,
		Decimal = 10,
		Function = function(Val: number)
			if Holder then
				Holder.BackgroundTransparency = Val
			end
		end
	})

	Holder = Instance.new("Frame")
	Holder.BackgroundColor3 = Color.Dark(UIPallet.Main, 0.1)
	Holder.BackgroundTransparency = Transparency.Value
	Holder.ClipsDescendants = true
	Holder.Size = UDim2.fromOffset(240, 246)
	Holder.Parent = BedDefense.Children
	AddBlur(Holder)
	local Corner: UICorner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(0, 5)
	Corner.Parent = Holder

	BedLabel = Instance.new("TextLabel")
	BedLabel.BackgroundTransparency = 1
	BedLabel.FontFace = UIPallet.Font
	BedLabel.Position = UDim2.fromOffset(32, 0)
	BedLabel.Size = UDim2.new(1, -64, 0, 32)
	BedLabel.Text = "No bed"
	BedLabel.TextColor3 = Color.Dark(UIPallet.Text, 0.16)
	BedLabel.TextSize = 13
	BedLabel.TextTruncate = Enum.TextTruncate.AtEnd
	BedLabel.Parent = Holder
	AddShadow(BedLabel)

	CreateArrow(UDim2.fromOffset(16, 16), -1)
	CreateArrow(UDim2.new(1, -16, 0, 16), 1)

	local TopDivider: Frame = Instance.new("Frame")
	TopDivider.BackgroundColor3 = Color.Light(UIPallet.Main, 0.04)
	TopDivider.BorderSizePixel = 0
	TopDivider.Position = UDim2.fromOffset(0, 32)
	TopDivider.Size = UDim2.new(1, 0, 0, 1)
	TopDivider.Parent = Holder

	Viewport = Instance.new("ViewportFrame")
	Viewport.Ambient = Color3.fromRGB(170, 170, 170)
	Viewport.BackgroundTransparency = 1
	Viewport.LightColor = Color3.new(1, 1, 1)
	Viewport.LightDirection = Vector3.new(-0.4, -1, -0.3)
	Viewport.Position = UDim2.fromOffset(0, 33)
	Viewport.Size = UDim2.new(1, 0, 0, 176)
	Viewport.Parent = Holder
	ViewportCamera = Instance.new("Camera")
	ViewportCamera.FieldOfView = 40
	ViewportCamera.Parent = Viewport
	Viewport.CurrentCamera = ViewportCamera

	local Capture: TextButton = Instance.new("TextButton")
	Capture.BackgroundTransparency = 1
	Capture.Position = Viewport.Position
	Capture.Size = Viewport.Size
	Capture.Text = ""
	Capture.Parent = Holder
	Capture.InputBegan:Connect(function(Input: InputObject)
		if Input.UserInputType == Enum.UserInputType.Touch then
			table.insert(Touches, Input)
			if #Touches == 2 then
				Dragging, PinchDistance = nil, GetPinchDistance()
				return
			end
		end
		if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
			Dragging, LastDrag = Input, Input.Position
		end
	end)
	Capture.InputChanged:Connect(function(Input: InputObject)
		if Input.UserInputType == Enum.UserInputType.MouseWheel then
			SetZoom(Zoom * (1 - Input.Position.Z * 0.12))
		end
	end)

	Empty = Instance.new("TextLabel")
	Empty.BackgroundTransparency = 1
	Empty.FontFace = UIPallet.Font
	Empty.Position = UDim2.fromOffset(0, 186)
	Empty.Size = UDim2.new(1, 0, 0, 20)
	Empty.Text = "No bed found"
	Empty.TextColor3 = Color.Dark(UIPallet.Text, 0.16)
	Empty.TextSize = 12
	Empty.ZIndex = 2
	Empty.Parent = Holder
	AddShadow(Empty)

	local BottomDivider: Frame = TopDivider:Clone()
	BottomDivider.Position = UDim2.fromOffset(0, 209)
	BottomDivider.Parent = Holder

	ButtonRow = Instance.new("Frame")
	ButtonRow.BackgroundTransparency = 1
	ButtonRow.Position = UDim2.fromOffset(4, 214)
	ButtonRow.Size = UDim2.new(1, -8, 0, 26)
	ButtonRow.Parent = Holder
	local Layout: UIListLayout = Instance.new("UIListLayout")
	Layout.FillDirection = Enum.FillDirection.Horizontal
	Layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	Layout.Padding = UDim.new(0, 4)
	Layout.SortOrder = Enum.SortOrder.LayoutOrder
	Layout.Parent = ButtonRow
	BuildButtons()
end)
