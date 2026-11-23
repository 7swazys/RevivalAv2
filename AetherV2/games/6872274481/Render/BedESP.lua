run(function()
	local Camera = gameCamera
	local CollectionService = collectionService
	local Entity = entitylib
	local LocalPlayer = lplr
	local RunService = runService
	local Store = store
	local BedESP
	local Method
	local Color
	local TeamColor
	local BoundingBox
	local Filled
	local HealthBar
	local Name
	local Background
	local HideOwn
	local Distance
	local DistanceLimit
	local Reference = {}
	local BedData = {}
	local Shown: {[Instance]: boolean} = {}
	local MethodUsed: string
	local LastCamera, LastViewport

	local CornerSigns: {Vector3} = {
		Vector3.new(1, 1, 1),
		Vector3.new(1, -1, 1),
		Vector3.new(-1, 1, 1),
		Vector3.new(-1, -1, 1),
		Vector3.new(1, 1, -1),
		Vector3.new(1, -1, -1),
		Vector3.new(-1, 1, -1),
		Vector3.new(-1, -1, -1)
	}

	local function ESPWorldToViewport(Position: Vector3): Vector2
		local ViewportPoint: Vector3 = Camera:WorldToViewportPoint(Position)
		return Vector2.new(ViewportPoint.X, ViewportPoint.Y)
	end

	local function GetBedColor(Bed: Instance)
		local Part: Instance? = Bed:FindFirstChild("Bed")
		return TeamColor.Enabled and Part and Part.Color or Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
	end

	local function GetBedName(Bed: Instance)
		local TeamId: number? = tonumber(Bed:GetAttribute("TeamId"))
		local Queue = bedwars.QueueMeta[Store.queueType]
		local Team = Queue and TeamId and Queue.teams[TeamId]
		return `{Team and Team.displayName or `Team {TeamId or "?"}`} Bed`
	end

	local function GetBedData(Bed: BasePart)
		local Origin: CFrame = Bed.CFrame
		local Min, Max = Vector3.one * math.huge, Vector3.one * -math.huge
		for _, v: Instance in Bed:GetChildren() do
			if v:IsA("BasePart") and v.Name ~= "Blanket" then
				local PartCFrame, HalfSize = Origin:ToObjectSpace(v.CFrame), v.Size / 2
				if v.Name == "Legs" then
					PartCFrame, HalfSize = PartCFrame * CFrame.new(0, -0.4, 0), HalfSize - Vector3.new(0, 0.5, 0)
				end
				for _, Sign: Vector3 in CornerSigns do
					local Position: Vector3 = PartCFrame * (HalfSize * Sign)
					Min, Max = Min:Min(Position), Max:Max(Position)
				end
			end
		end
		if Min.X == math.huge then
			Min, Max = -Bed.Size / 2, Bed.Size / 2
		end

		local Center, Extents = (Min + Max) / 2, (Max - Min) / 2
		local Corners: {Vector3} = {}
		for i: number, Sign: Vector3 in CornerSigns do
			Corners[i] = Origin * (Center + Extents * Sign)
		end

		return {
			Center = Origin * Center,
			Corners = Corners,
			TeamId = tonumber(Bed:GetAttribute("TeamId")),
			BlockPosition = bedwars.BlockController:getBlockPosition(Bed.Position)
		}
	end

	local function GetBedHealth(Bed: BasePart, Data)
		local BlockData = bedwars.BlockController:getStore():getBlockData(Data.BlockPosition)
		local Health: number = BlockData and (BlockData:GetAttribute("1") or BlockData:GetAttribute("Health")) or Bed:GetAttribute("Health") or 1
		return math.clamp(Health / (Bed:GetAttribute("MaxHealth") or 1), 0, 1)
	end

	local function IsHidden(Bed: Instance, Data, LocalPosition: Vector3?, LocalTeam: number?)
		if HideOwn.Enabled and Data.TeamId == LocalTeam then return true end
		if Distance.Enabled then
			local BedDistance: number = LocalPosition and (LocalPosition - Data.Center).Magnitude or math.huge
			return BedDistance < DistanceLimit.ValueMin or BedDistance > DistanceLimit.ValueMax
		end
		return false
	end

	local ESPAdded = {
		Drawing2D = function(Bed: Instance)
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			local BedDrawings = {}
			BedDrawings.Main = Drawing.new("Square")
			BedDrawings.Main.Transparency = BoundingBox.Enabled and 1 or 0
			BedDrawings.Main.ZIndex = 2
			BedDrawings.Main.Filled = false
			BedDrawings.Main.Thickness = 1
			BedDrawings.Main.Color = GetBedColor(Bed)

			if BoundingBox.Enabled then
				BedDrawings.Border = Drawing.new("Square")
				BedDrawings.Border.Transparency = 0.35
				BedDrawings.Border.ZIndex = 1
				BedDrawings.Border.Thickness = 1
				BedDrawings.Border.Filled = false
				BedDrawings.Border.Color = Color3.new()
				BedDrawings.Border2 = Drawing.new("Square")
				BedDrawings.Border2.Transparency = 0.35
				BedDrawings.Border2.ZIndex = 1
				BedDrawings.Border2.Thickness = 1
				BedDrawings.Border2.Filled = Filled.Enabled
				BedDrawings.Border2.Color = Color3.new()
			end

			if HealthBar.Enabled then
				BedDrawings.HealthLine = Drawing.new("Line")
				BedDrawings.HealthLine.Thickness = 1
				BedDrawings.HealthLine.ZIndex = 2
				BedDrawings.HealthBorder = Drawing.new("Line")
				BedDrawings.HealthBorder.Thickness = 3
				BedDrawings.HealthBorder.Transparency = 0.35
				BedDrawings.HealthBorder.ZIndex = 1
				BedDrawings.HealthBorder.Color = Color3.new()
			end

			if Name.Enabled then
				if Background.Enabled then
					BedDrawings.TextBKG = Drawing.new("Square")
					BedDrawings.TextBKG.Transparency = 0.35
					BedDrawings.TextBKG.ZIndex = 0
					BedDrawings.TextBKG.Thickness = 1
					BedDrawings.TextBKG.Filled = true
					BedDrawings.TextBKG.Color = Color3.new()
				end
				BedDrawings.Drop = Drawing.new("Text")
				BedDrawings.Drop.Color = Color3.new()
				BedDrawings.Drop.Text = GetBedName(Bed)
				BedDrawings.Drop.ZIndex = 1
				BedDrawings.Drop.Center = true
				BedDrawings.Drop.Size = 20
				BedDrawings.Text = Drawing.new("Text")
				BedDrawings.Text.Text = BedDrawings.Drop.Text
				BedDrawings.Text.ZIndex = 2
				BedDrawings.Text.Color = BedDrawings.Main.Color
				BedDrawings.Text.Center = true
				BedDrawings.Text.Size = 20
			end
			Reference[Bed] = BedDrawings
		end,
		Drawing3D = function(Bed: Instance)
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			local BedDrawings = {}
			for i: number = 1, 12 do
				BedDrawings[`Line{i}`] = Drawing.new("Line")
			end

			local BedColor: Color3 = GetBedColor(Bed)
			for _, v: any in BedDrawings do
				v.Thickness = 1
				v.Color = BedColor
			end

			Reference[Bed] = BedDrawings
		end
	}

	local function ESPRemoved(Bed: Instance)
		local BedDrawings = Reference[Bed]
		if BedDrawings then
			if vape.ThreadFix then
				setthreadidentity(8)
			end
			Reference[Bed] = nil
			BedData[Bed] = nil
			Shown[Bed] = nil
			for _, v: any in BedDrawings do
				pcall(function()
					v.Visible = false
					v:Remove()
				end)
			end
		end
	end

	local ColorFunc = {
		Drawing2D = function()
			for Bed: Instance, v: any in Reference do
				v.Main.Color = GetBedColor(Bed)
				if v.Text then
					v.Text.Color = v.Main.Color
				end
			end
		end,
		Drawing3D = function()
			for Bed: Instance, v: any in Reference do
				local BedColor: Color3 = GetBedColor(Bed)
				for _, Line: any in v do
					Line.Color = BedColor
				end
			end
		end
	}

	local ESPLoop = {
		Drawing2D = function()
			if vape.ThreadFix then
				setthreadidentity(8)
			end

			local LocalPosition = Entity.isAlive and Entity.character.RootPart.Position
			local LocalTeam: number? = tonumber(LocalPlayer:GetAttribute("Team"))
			local CameraCFrame, Viewport = Camera.CFrame, Camera.ViewportSize
			local Moved = CameraCFrame ~= LastCamera or Viewport ~= LastViewport
			LastCamera, LastViewport = CameraCFrame, Viewport
			local Now = os.clock()

			for Bed: Instance, v: any in Reference do
				local Data = BedData[Bed]
				local RootVisible = Data.OnScreen
				if Moved or RootVisible == nil then
					local _, OnScreen = Camera:WorldToViewportPoint(Data.Center)
					Data.OnScreen, RootVisible = OnScreen, OnScreen
				end
				RootVisible = RootVisible and not IsHidden(Bed, Data, LocalPosition, LocalTeam)
				if Shown[Bed] ~= RootVisible then
					Shown[Bed] = RootVisible
					Data.Box = nil
					for _, Object: any in v do
						Object.Visible = RootVisible
					end
				end
				if not RootVisible then continue end

				local Health = Data.Health
				if v.HealthLine and (not Health or Now - (Data.HealthAt or 0) > 0.25) then
					Data.HealthAt = Now
					Health = GetBedHealth(Bed, Data)
				end
				if not Moved and Data.Box and Health == Data.Health then continue end

				local MinX, MinY, MaxX, MaxY = math.huge, math.huge, -math.huge, -math.huge
				for _, Corner: Vector3 in Data.Corners do
					local Position: Vector3 = Camera:WorldToViewportPoint(Corner)
					MinX, MinY = math.min(MinX, Position.X), math.min(MinY, Position.Y)
					MaxX, MaxY = math.max(MaxX, Position.X), math.max(MaxY, Position.Y)
				end
				local PosX, PosY, SizeX, SizeY = MinX // 1, MinY // 1, (MaxX - MinX) // 1, (MaxY - MinY) // 1
				local Box = Data.Box
				if Box and Box[1] == PosX and Box[2] == PosY and Box[3] == SizeX and Box[4] == SizeY and Health == Data.Health then continue end
				Data.Box = {PosX, PosY, SizeX, SizeY}
				Data.Health = Health
				v.Main.Position = Vector2.new(PosX, PosY) // 1
				v.Main.Size = Vector2.new(SizeX, SizeY) // 1
				if v.Border then
					v.Border.Position = Vector2.new(PosX - 1, PosY - 1) // 1
					v.Border.Size = Vector2.new(SizeX + 2, SizeY + 2) // 1
					v.Border2.Position = Vector2.new(PosX + 1, PosY + 1) // 1
					v.Border2.Size = Vector2.new(SizeX - 2, SizeY - 2) // 1
				end

				if v.HealthLine then
					v.HealthLine.Color = Color3.fromHSV(Health / 2.5, 0.89, 0.75)
					v.HealthLine.From = Vector2.new(PosX - 6, PosY + SizeY) // 1
					v.HealthLine.To = Vector2.new(PosX - 6, PosY + SizeY - (SizeY * Health)) // 1
					v.HealthBorder.From = Vector2.new(PosX - 6, PosY + SizeY + 1) // 1
					v.HealthBorder.To = Vector2.new(PosX - 6, PosY - 1) // 1
				end

				if v.Text then
					local TextPosition: Vector2 = Vector2.new(PosX + (SizeX / 2), PosY - 28) // 1
					v.Text.Position = TextPosition
					v.Drop.Position = TextPosition + Vector2.new(1, 1)
					if v.TextBKG then
						local TextBounds: Vector2 = v.Text.TextBounds
						v.TextBKG.Size = TextBounds + Vector2.new(8, 4)
						v.TextBKG.Position = TextPosition - Vector2.new(4 + (TextBounds.X / 2), 0)
					end
				end
			end
		end,
		Drawing3D = function()
			if vape.ThreadFix then
				setthreadidentity(8)
			end

			local LocalPosition = Entity.isAlive and Entity.character.RootPart.Position
			local LocalTeam: number? = tonumber(LocalPlayer:GetAttribute("Team"))

			local CameraCFrame, Viewport = Camera.CFrame, Camera.ViewportSize
			local Moved = CameraCFrame ~= LastCamera or Viewport ~= LastViewport
			LastCamera, LastViewport = CameraCFrame, Viewport

			for Bed: Instance, v: any in Reference do
				local Data = BedData[Bed]
				local RootVisible = Data.OnScreen
				if Moved or RootVisible == nil then
					local _, OnScreen = Camera:WorldToViewportPoint(Data.Center)
					Data.OnScreen, RootVisible = OnScreen, OnScreen
				end
				RootVisible = RootVisible and not IsHidden(Bed, Data, LocalPosition, LocalTeam)
				local Became = Shown[Bed] ~= RootVisible
				if Became then
					Shown[Bed] = RootVisible
					for _, Object: any in v do
						Object.Visible = RootVisible
					end
				end
				if not RootVisible or not (Moved or Became) then continue end

				local Corners: {Vector3} = Data.Corners
				local Point1: Vector2 = ESPWorldToViewport(Corners[1])
				local Point2: Vector2 = ESPWorldToViewport(Corners[2])
				local Point3: Vector2 = ESPWorldToViewport(Corners[3])
				local Point4: Vector2 = ESPWorldToViewport(Corners[4])
				local Point5: Vector2 = ESPWorldToViewport(Corners[5])
				local Point6: Vector2 = ESPWorldToViewport(Corners[6])
				local Point7: Vector2 = ESPWorldToViewport(Corners[7])
				local Point8: Vector2 = ESPWorldToViewport(Corners[8])
				v.Line1.From = Point1
				v.Line1.To = Point2
				v.Line2.From = Point3
				v.Line2.To = Point4
				v.Line3.From = Point5
				v.Line3.To = Point6
				v.Line4.From = Point7
				v.Line4.To = Point8
				v.Line5.From = Point1
				v.Line5.To = Point3
				v.Line6.From = Point1
				v.Line6.To = Point5
				v.Line7.From = Point5
				v.Line7.To = Point7
				v.Line8.From = Point7
				v.Line8.To = Point3
				v.Line9.From = Point2
				v.Line9.To = Point4
				v.Line10.From = Point2
				v.Line10.To = Point6
				v.Line11.From = Point6
				v.Line11.To = Point8
				v.Line12.From = Point8
				v.Line12.To = Point4
			end
		end
	}

	local function Added(Bed: Instance)
		if not BedESP.Enabled or not Bed.Parent then return end
		if Reference[Bed] then
			ESPRemoved(Bed)
		end
		BedData[Bed] = GetBedData(Bed)
		ESPAdded[MethodUsed](Bed)
	end

	local function Refresh()
		if BedESP.Enabled then
			BedESP:Toggle()
			BedESP:Toggle()
		end
	end

	BedESP = vape.Categories.Render:CreateModule({
		Name = "BedESP",
		Function = function(Callback: boolean)
			if Callback then
				MethodUsed = `Drawing{Method.Value}`
				BedESP:Clean(CollectionService:GetInstanceAddedSignal("bed"):Connect(function(Bed: Instance)
					task.delay(0.2, Added, Bed)
				end))
				BedESP:Clean(CollectionService:GetInstanceRemovedSignal("bed"):Connect(ESPRemoved))
				BedESP:Clean(vape.Categories.Friends.ColorUpdate.Event:Connect(function()
					ColorFunc[MethodUsed]()
				end))
				BedESP:Clean(RunService.RenderStepped:Connect(ESPLoop[MethodUsed]))
				for _, v: Instance in CollectionService:GetTagged("bed") do
					Added(v)
				end
			else
				for Bed: Instance in Reference do
					ESPRemoved(Bed)
				end
			end
		end,
		Tooltip = 'Shows beds through walls'
	})

	Method = BedESP:CreateDropdown({
		Name = "Mode",
		List = {"2D", "3D"},
		Function = function(Val: string)
			Refresh()
			BoundingBox.Object.Visible = (Val == "2D")
			Filled.Object.Visible = (Val == "2D")
			HealthBar.Object.Visible = (Val == "2D")
			Name.Object.Visible = (Val == "2D")
			Background.Object.Visible = Name.Object.Visible and Name.Enabled
		end
	})
	Color = BedESP:CreateColorSlider({
		Name = "Bed Color",
		Function = function()
			if BedESP.Enabled and ColorFunc[MethodUsed] then
				ColorFunc[MethodUsed]()
			end
		end
	})
	TeamColor = BedESP:CreateToggle({
		Name = "Use Team Color",
		Function = function()
			if BedESP.Enabled and ColorFunc[MethodUsed] then
				ColorFunc[MethodUsed]()
			end
		end,
		Default = true,
		Darker = true
	})
	BoundingBox = BedESP:CreateToggle({
		Name = "Bounding Box",
		Function = Refresh,
		Default = true,
		Darker = true
	})
	Filled = BedESP:CreateToggle({
		Name = "Filled",
		Function = Refresh,
		Darker = true
	})
	HealthBar = BedESP:CreateToggle({
		Name = "Health Bar",
		Function = Refresh,
		Darker = true
	})
	Name = BedESP:CreateToggle({
		Name = "Name",
		Function = function(Callback: boolean)
			Refresh()
			Background.Object.Visible = Callback
		end,
		Darker = true
	})
	Background = BedESP:CreateToggle({
		Name = "Show Background",
		Function = Refresh,
		Darker = true
	})
	HideOwn = BedESP:CreateToggle({
		Name = "Hide Own Bed",
		Default = true,
		Tooltip = "Hides your own team's bed"
	})
	Distance = BedESP:CreateGroup({
		Name = "Distance Check",
	})
	DistanceLimit = Distance:CreateTwoSlider({
		Name = "Bed Distance",
		Min = 0,
		Max = 512,
		DefaultMin = 0,
		DefaultMax = 256,
		Darker = true
	})
end)
