run(function()
	local Sides = sides
	local AddBlur = addBlur
	local CollectionService = collectionService
	local GetPlacedBlock = getPlacedBlock
	local VapeEvents = vapeEvents
	local ItemPlates
	local Whitelist
	local Background
	local Color = {}
	local Reference = {}
	local Folder: Folder = Instance.new("Folder")
	if vape.ThreadFix then
		setthreadidentity(8)
	end
	Folder.Parent = vape.gui

	local function ScanSide(self, Start: Vector3, Found: {string})
		for _, v: Vector3 in Sides do
			for i: number = 1, 15 do
				local Block: Instance? = GetPlacedBlock(Start + (v * i))
				if not Block or Block == self then break end
				if not Block:GetAttribute("NoBreak") and not table.find(Found, Block.Name) then
					table.insert(Found, Block.Name)
				end
			end
		end
	end

	local function RefreshAdornee(Billboard: BillboardGui)
		local Adornee: Instance? = Billboard.Adornee
		if not Adornee or not Adornee.Parent then
			Billboard.Enabled = false
			return
		end

		for _, v: Instance in Billboard.Frame:GetChildren() do
			if v:IsA("ImageLabel") then
				v:Destroy()
			end
		end

		local AlreadyGot: {string} = {}
		ScanSide(Adornee, Adornee.Position, AlreadyGot)
		ScanSide(Adornee, Adornee.Position + Vector3.new(0, 0, 3), AlreadyGot)
		table.sort(AlreadyGot, function(A: string, B: string)
			local First = bedwars.ItemMeta[A]
			local Second = bedwars.ItemMeta[B]
			return (First and First.block and First.block.health or 0) > (Second and Second.block and Second.block.health or 0)
		end)
		Billboard.Enabled = #AlreadyGot > 0

		for _, v: string in AlreadyGot do
			local BlockImage: ImageLabel = Instance.new("ImageLabel")
			BlockImage.Size = UDim2.fromOffset(32, 32)
			BlockImage.BackgroundTransparency = 1
			BlockImage.Image = bedwars.getIcon({itemType = v}, true)
			BlockImage.Parent = Billboard.Frame
		end
	end

	local function Added(Part: Instance)
		if not table.find(Whitelist.ListEnabled, Part.Name) or Reference[Part] then return end

		local Billboard: BillboardGui = Instance.new("BillboardGui")
		Billboard.Parent = Folder
		Billboard.Name = "bed"
		Billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		Billboard.Size = UDim2.fromOffset(36, 36)
		Billboard.AlwaysOnTop = true
		Billboard.ClipsDescendants = false
		Billboard.Adornee = Part
		local Blur: ImageLabel = AddBlur(Billboard)
		Blur.Visible = Background.Enabled
		local Frame: Frame = Instance.new("Frame")
		Frame.Size = UDim2.fromScale(1, 1)
		Frame.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		Frame.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
		Frame.Parent = Billboard
		local Layout: UIListLayout = Instance.new("UIListLayout")
		Layout.FillDirection = Enum.FillDirection.Horizontal
		Layout.Padding = UDim.new(0, 4)
		Layout.VerticalAlignment = Enum.VerticalAlignment.Center
		Layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			Billboard.Size = UDim2.fromOffset(math.max(Layout.AbsoluteContentSize.X + 4, 36), 36)
		end)
		Layout.Parent = Frame
		local Corner: UICorner = Instance.new("UICorner")
		Corner.CornerRadius = UDim.new(0, 4)
		Corner.Parent = Frame
		Reference[Part] = Billboard
		RefreshAdornee(Billboard)
	end

	ItemPlates = vape.Categories.Render:CreateModule({
		Name = "ItemPlates",
		Function = function(Callback: boolean)
			if Callback then
				for _, v: Instance in CollectionService:GetTagged("block") do
					task.spawn(Added, v)
				end
				ItemPlates:Clean(VapeEvents.PlaceBlockEvent.Event:Connect(function(Data)
					local Position: Vector3 = Data.blockRef.blockPosition * 3
					for Block: BasePart, v: BillboardGui in Reference do
						if (Position - Block.Position).Magnitude <= 30 then
							RefreshAdornee(v)
						end
					end
				end))
				ItemPlates:Clean(VapeEvents.BreakBlockEvent.Event:Connect(function(Data)
					local Position: Vector3 = Data.blockRef.blockPosition * 3
					for Block: BasePart, v: BillboardGui in Reference do
						if (Position - Block.Position).Magnitude <= 30 then
							RefreshAdornee(v)
						end
					end
				end))
				ItemPlates:Clean(CollectionService:GetInstanceAddedSignal("block"):Connect(Added))
				ItemPlates:Clean(CollectionService:GetInstanceRemovedSignal("block"):Connect(function(Part: Instance)
					if Reference[Part] then
						Reference[Part]:Destroy()
						Reference[Part] = nil
					end
				end))
			else
				table.clear(Reference)
				Folder:ClearAllChildren()
			end
		end,
		Tooltip = 'Shows the blocks around each item'
	})

	Whitelist = ItemPlates:CreateItemPicker({
		Name = "Whitelist",
		Multi = true,
		Items = bedwars.itemPickerList(function(_, meta) return meta.block ~= nil end, {Relevant = {'shop', 'wool'}}),
		Default = {"beehive"},
		Function = function()
			if ItemPlates.Enabled then
				ItemPlates:Toggle()
				ItemPlates:Toggle()
			end
		end
	})
	Background = ItemPlates:CreateGroup({
		Name = "Background",
		Function = function(Callback: boolean)
			if Color and Color.Object then
			end
			for _, v: BillboardGui in Reference do
				v.Frame.BackgroundTransparency = 1 - (Callback and Color.Opacity or 0)
				v.Blur.Visible = Callback
			end
		end,
		Default = true
	})
	Color = Background:CreateColorSlider({
		Name = "Background Color",
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(Hue: number, Sat: number, Val: number, Opacity: number)
			for _, v: BillboardGui in Reference do
				v.Frame.BackgroundColor3 = Color3.fromHSV(Hue, Sat, Val)
				v.Frame.BackgroundTransparency = 1 - (Background.Enabled and Opacity or 0)
			end
		end,
		Darker = true
	})
end)
