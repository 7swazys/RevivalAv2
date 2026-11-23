run(function()
	local Entity = entitylib
	local LocalPlayer = lplr
	local Camera = gameCamera
	local CollectionService = collectionService
	local Players = playersService
	local RunService = runService
	local GetFontBounds = getfontsize
	local UIPallet = vape.Libraries.uipallet
	local TrapESP
	local Traps
	local Distance
	local Owner
	local Transparency
	local Scale
	local Color = {}
	local Reference = {}
	local Folder: Folder?

	local Names: {[string]: string} = {
		["glue_trap"] = "Gloop",
		["grave_trap"] = "Grave",
		["grave_trap_block"] = "Grave",
		["invisible_landmine"] = "Landmine",
		["lucky_block_trap"] = "Lucky Trap",
		["snap_trap"] = "Snap Trap",
		["spike_trap"] = "Spikes",
		["tesla_trap"] = "Tesla"
	}

	local function Added(Block: Instance)
		if Reference[Block] or not Block:IsA("BasePart") then return end

		local Label: string? = Names[Block.Name]
		if not Label or not table.find(Traps.ListEnabled, Label) then return end

		local NameTag: TextLabel = Instance.new("TextLabel")
		NameTag.Name = Label
		NameTag.Text = Label
		NameTag.TextSize = 14 * Scale.Value
		NameTag.FontFace = UIPallet.Font
		local Size: Vector2 = GetFontBounds(NameTag.Text, NameTag.TextSize, NameTag.FontFace)
		NameTag.Size = UDim2.fromOffset(Size.X + 8, Size.Y + 7)
		NameTag.AnchorPoint = Vector2.new(0.5, 1)
		NameTag.BackgroundColor3 = Color3.new()
		NameTag.BackgroundTransparency = Transparency.Value
		NameTag.BorderSizePixel = 0
		NameTag.Visible = false
		NameTag.TextColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		NameTag.Parent = Folder
		Reference[Block] = NameTag
	end

	local MineCache = setmetatable({}, {__mode = 'k'})
	local Shown = setmetatable({}, {__mode = 'k'})
	local Placed = setmetatable({}, {__mode = 'k'})
	local function IsMineNow(Block: Instance)
		local UserId: number? = Block:GetAttribute("PlacedByUserId")
		if not UserId or UserId == 0 then
			return false
		end
		if UserId == LocalPlayer.UserId then
			return true
		end

		local Placer: Player? = Players:GetPlayerByUserId(UserId)
		return Placer ~= nil and Placer:GetAttribute("Team") == LocalPlayer:GetAttribute("Team")
	end

	local function IsMine(Block: Instance)
		local Entry = MineCache[Block]
		local Now = os.clock()
		if not Entry or Now > Entry.Until then
			Entry = {Value = IsMineNow(Block), Until = Now + 2}
			MineCache[Block] = Entry
		end
		return Entry.Value
	end

	TrapESP = vape.Categories.Render:CreateModule({
		Name = "TrapESP",
		Function = function(Callback: boolean)
			if Callback then
				if not Folder then
					if vape.ThreadFix then
						setthreadidentity(8)
					end
					Folder = Instance.new("Folder")
					if vape.ThreadFix then
						setthreadidentity(8)
					end
					Folder.Parent = vape.gui
				end

				for _, v: Instance in CollectionService:GetTagged("block") do
					Added(v)
				end

				TrapESP:Clean(CollectionService:GetInstanceAddedSignal("block"):Connect(Added))
				TrapESP:Clean(CollectionService:GetInstanceRemovedSignal("block"):Connect(function(Block: Instance)
					if Reference[Block] then
						Reference[Block]:Destroy()
						Reference[Block] = nil
					end
				end))

				TrapESP:Clean(RunService.PreRender:Connect(function()
					local LocalPosition = Entity.isAlive and Entity.character.RootPart.Position
					for Block: BasePart, NameTag: TextLabel in Reference do
						if not Block.Parent then
							NameTag:Destroy()
							Reference[Block] = nil
							continue
						end

						if not Owner.Enabled and IsMine(Block) then
							if Shown[NameTag] ~= false then
								Shown[NameTag] = false
								NameTag.Visible = false
							end
							continue
						end

						local ScreenPos, Visible = Camera:WorldToViewportPoint(Block.Position + Vector3.new(0, 2, 0))
						if Shown[NameTag] ~= Visible then
							Shown[NameTag] = Visible
							NameTag.Visible = Visible
						end
						if not Visible then continue end

						local Text: string = Distance.Enabled and LocalPosition and `{NameTag.Name} | {((LocalPosition - Block.Position).Magnitude) // 1}m` or NameTag.Name
						if NameTag.Text ~= Text then
							NameTag.Text = Text
							local Size: Vector2 = GetFontBounds(Text, NameTag.TextSize, NameTag.FontFace)
							NameTag.Size = UDim2.fromOffset(Size.X + 8, Size.Y + 7)
						end
						local PX, PY = ScreenPos.X // 1, ScreenPos.Y // 1
						local Last = Placed[NameTag]
						if not Last or Last.X ~= PX or Last.Y ~= PY then
							Placed[NameTag] = {X = PX, Y = PY}
							NameTag.Position = UDim2.fromOffset(PX, PY)
						end
					end
				end))
			else
				for Block: Instance, NameTag: TextLabel in Reference do
					NameTag:Destroy()
					Reference[Block] = nil
				end
			end
		end,
		Tooltip = "Shows every trap on the map through walls, landmines included, which have no visual at all"
	})

	Distance = TrapESP:CreateToggle({
		Name = "Distance",
		Default = true
	})
	Owner = TrapESP:CreateToggle({
		Name = "Your traps",
		Default = true,
		Tooltip = "Also shows the ones your own team placed"
	})
	Scale = TrapESP:CreateSlider({
		Name = "Scale",
		Min = 0.5,
		Max = 3,
		Default = 1,
		Decimal = 10,
		Function = function(Value: number)
			for _, v: TextLabel in Reference do
				v.TextSize = 14 * Value
				local Size: Vector2 = GetFontBounds(v.Text, v.TextSize, v.FontFace)
				v.Size = UDim2.fromOffset(Size.X + 8, Size.Y + 7)
			end
		end
	})
	Transparency = TrapESP:CreateSlider({
		Name = "Transparency",
		Min = 0,
		Max = 1,
		Default = 0.5,
		Decimal = 100,
		Function = function(Value: number)
			for _, v: TextLabel in Reference do
				v.BackgroundTransparency = Value
			end
		end
	})
	Color = TrapESP:CreateColorSlider({
		Name = "Text Color",
		Function = function(Hue: number, Sat: number, Val: number)
			for _, v: TextLabel in Reference do
				v.TextColor3 = Color3.fromHSV(Hue, Sat, Val)
			end
		end,
		DefaultHue = 0,
		DefaultSat = 0.75,
		Darker = true
	})
	Traps = TrapESP:CreateTextList({
		Name = "Traps",
		Function = function()
			if TrapESP.Enabled then
				TrapESP:Toggle()
				TrapESP:Toggle()
			end
		end,
		Default = {
			"Gloop",
			"Grave",
			"Landmine",
			"Lucky Trap",
			"Snap Trap",
			"Spikes",
			"Tesla"
		},
		Darker = true
	})
end)
