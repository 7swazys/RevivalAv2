run(function()
	local Entity = entitylib
	local LocalPlayer = lplr
	local Camera = gameCamera
	local ReplicatedStorage = replicatedStorage
	local GetFontBounds = getfontsize
	local GetHotbar = getHotbar
	local GetItem = getItem
	local HotbarSwitch = hotbarSwitch
	local SwitchItem = switchItem
	local UIPallet = vape.Libraries.uipallet
	local AutoPearl
	local Legit
	local Back
	local Check
	local LandCheck
	local BackDelay
	local Limit
	local ClutchRange
	local Cooldown
	local ShowLanding
	local WarnLost
	local LastThrow: number = 0
	local NextScan: number = 0
	local LastGround: Vector3?
	local VoidLine: number?
	local InFlight
	local Alerted: boolean = false
	local Hope: boolean = false
	local Probe: number = 0
	local Markers: {Part} = {}

	local FireLead: number = 0.02
	local VoidDepth: number = 200
	local PathStep: number = 0.1
	local PathSteps: number = 12
	local FlightStep: number = 0.05
	local MaxFlight: number = 4
	local LandingTolerance: number = 4
	local FloorReach: number = 2
	local ScanGap: number = 0.05
	local RetryGap: number = 0.3
	local EquipGap: number = 0.05
	local VoidMargin: number = 50
	local FallTrigger: number = 120
	local MaxChecks: number = 12
	local ArcSamples: number = 6
	local MarkerCount: number = 4
	local ProbeStride: number = 2
	local EdgePenalty: number = 0.15
	local EdgeProbes: {Vector3} = {
		Vector3.new(2, 0, 2),
		Vector3.new(2, 0, -2),
		Vector3.new(-2, 0, 2),
		Vector3.new(-2, 0, -2)
	}
	local PearlBox: Vector3 = Vector3.new(3, 1, 3)

	local RayCheck: RaycastParams = RaycastParams.new()
	local RayCheckMap
	RayCheck.RespectCanCollide = true
	RayCheck.FilterType = Enum.RaycastFilterType.Include

	local function GetGravity(): number
		return bedwars.ProjectileMeta.telepearl.gravitationalAcceleration or 196.2
	end

	local function PredictLanding(Origin: Vector3, Velocity: Vector3): (Vector3?, Vector3?)
		local Drop: Vector3 = Vector3.new(0, -GetGravity(), 0)
		local Last: Vector3 = Origin
		for Step: number = 1, math.round(MaxFlight / FlightStep) do
			local Time: number = Step * FlightStep
			local Position: Vector3 = Origin + Velocity * Time + Drop * (0.5 * Time * Time)
			local Direction: Vector3 = Position - Last
			local Hit: RaycastResult? = workspace:Blockcast(CFrame.new(Last), PearlBox, Direction, store.airRay)
			if Hit then
				return Last + Direction.Unit * Hit.Distance, Hit.Normal
			end
			Last = Position
		end

		return nil, nil
	end

	local function GetArcs(From: Vector3, Spot: Vector3): {any}
		local Meta = bedwars.ProjectileMeta.telepearl
		local Speed: number = Meta.launchVelocity
		local Gravity: number = GetGravity()
		local Offset: Vector3 = Spot - From
		local Flat: Vector3 = Offset * Vector3.new(1, 0, 1)
		local Discriminant: number = Speed ^ 4 - Gravity * (Gravity * Flat.Magnitude ^ 2 + 2 * Offset.Y * Speed ^ 2)
		local Arcs: {any} = {}
		if Flat.Magnitude < 1 or Discriminant < 0 then
			return Arcs
		end

		for _, v: number in {-1, 1} do
			local Angle: number = math.atan((Speed ^ 2 + v * math.sqrt(Discriminant)) / (Gravity * Flat.Magnitude))
			table.insert(Arcs, {
				velocity = Flat.Unit * (math.cos(Angle) * Speed) + Vector3.new(0, math.sin(Angle) * Speed, 0),
				time = Flat.Magnitude / (math.cos(Angle) * Speed)
			})
		end

		return Arcs
	end

	local function IsArcClear(From: Vector3, Velocity: Vector3, Time: number): boolean
		local Drop: Vector3 = Vector3.new(0, -GetGravity(), 0)
		local Last: Vector3 = From
		for Step: number = 1, ArcSamples do
			local Elapsed: number = Time * Step / ArcSamples
			local Position: Vector3 = From + Velocity * Elapsed + Drop * (0.5 * Elapsed * Elapsed)
			if workspace:Raycast(Last, Position - Last, RayCheck) then
				return false
			end
			Last = Position
		end

		return true
	end

	local function GetSafeLanding(From: Vector3, Velocity: Vector3, Spot: Vector3): Vector3?
		local Landing, Normal = PredictLanding(From, Velocity)
		if not Landing or not Normal or Normal.Y < 0.7 or (Landing - Spot).Magnitude > LandingTolerance then
			return
		end

		return workspace:Raycast(Landing, Vector3.new(0, -FloorReach, 0), RayCheck) and Landing
	end

	local function GetAnchors(Position: Vector3): {Vector3}
		local Anchors: {Vector3} = {Position + Vector3.new(0, 40, 0)}
		if LastGround then
			table.insert(Anchors, LastGround + Vector3.new(0, 5, 0))
		end

		return Anchors
	end

	local function GetVoidLine(): number
		local Engine: number = workspace.FallenPartsDestroyHeight
		if not VoidLine then
			local Lowest: number = math.huge
			for _, v: BasePart in store.blocks do
				Lowest = math.min(Lowest, v.Position.Y - v.Size.Y / 2)
			end
			if Lowest == math.huge then
				return Engine
			end
			VoidLine = Lowest - VoidMargin
		end

		return math.max(VoidLine, Engine)
	end

	local function GetDeadline(Position: Vector3, Speed: number): number
		local Gravity: number = workspace.Gravity
		local Drop: number = Position.Y - GetVoidLine()
		if Drop <= 0 then
			return 0
		end

		return (Speed + math.sqrt(Speed ^ 2 + 2 * Gravity * Drop)) / Gravity
	end

	local function GetSupport(Landing: Vector3): number
		local Support: number = 0
		for _, v: Vector3 in EdgeProbes do
			if workspace:Raycast(Landing + v, Vector3.new(0, -FloorReach - 1, 0), RayCheck) then
				Support += 1
			end
		end

		return Support
	end

	local function FindSpots(From: Vector3, Anchors: {Vector3}, Deadline: number): ({any}, number)
		local Candidates: {any} = {}
		local Seen: {[string]: boolean} = {}
		local Ground: number = 0
		for _, Anchor: Vector3 in Anchors do
			for Radius: number = 2, ClutchRange.Value, 3 do
				local Count: number = math.max(8, math.ceil(2 * math.pi * Radius / 6))
				for i: number = 1, Count do
					local Angle: number = 2 * math.pi * i / Count
					local Start: Vector3 = Anchor + Vector3.new(math.cos(Angle) * Radius, 3, math.sin(Angle) * Radius)
					local Ray: RaycastResult? = workspace:Raycast(Start, Vector3.new(0, -120, 0), RayCheck)
					if not Ray or Ray.Normal.Y < 0.7 then
						continue
					end

					local Key: string = `{math.round(Ray.Position.X)},{math.round(Ray.Position.Y)},{math.round(Ray.Position.Z)}`
					if Seen[Key] then
						continue
					end
					Seen[Key] = true
					Ground += 1

					for _, Arc: any in GetArcs(From, Ray.Position + Vector3.new(0, 0.5, 0)) do
						if Arc.time + EquipGap < Deadline and IsArcClear(From, Arc.velocity, Arc.time) then
							table.insert(Candidates, {spot = Ray.Position, velocity = Arc.velocity, time = Arc.time})
						end
					end
				end
			end
		end

		table.sort(Candidates, function(A: any, B: any): boolean
			return A.time < B.time
		end)

		local Spots: {any} = {}
		local Landed: {[string]: boolean} = {}
		for i: number = 1, math.min(#Candidates, MaxChecks) do
			local Landing: Vector3? = GetSafeLanding(From, Candidates[i].velocity, Candidates[i].spot)
			if not Landing then
				continue
			end

			local Key: string = `{math.round(Landing.X / 3)},{math.round(Landing.Y / 3)},{math.round(Landing.Z / 3)}`
			if Landed[Key] then
				continue
			end
			Landed[Key] = true

			Candidates[i].landing = Landing
			Candidates[i].score = Candidates[i].time + (#EdgeProbes - GetSupport(Landing)) * EdgePenalty
			table.insert(Spots, Candidates[i])
		end

		table.sort(Spots, function(A: any, B: any): boolean
			return A.score < B.score
		end)

		return Spots, Ground
	end

	local function IsVoidFall(Root: BasePart): (boolean, {Vector3})
		local Path: {Vector3} = {}
		local Velocity: Vector3 = Root.AssemblyLinearVelocity
		if Velocity.Y > -FallTrigger or workspace:Raycast(Root.Position, Vector3.new(0, -VoidDepth, 0), RayCheck) then
			return false, Path
		end

		local Position: Vector3 = Root.Position
		local Gravity: number = workspace.Gravity
		for _ = 1, PathSteps do
			local Next: Vector3 = Position + Velocity * PathStep - Vector3.new(0, Gravity * 0.5 * PathStep * PathStep, 0)
			local Hit: RaycastResult? = workspace:Raycast(Position, Next - Position, RayCheck)
			if Hit then
				if Hit.Normal.Y >= 0.7 then
					return false, Path
				end
				Velocity = Vector3.new(0, Velocity.Y, 0)
				Next = Hit.Position + Hit.Normal * 0.5
			end
			Velocity -= Vector3.new(0, Gravity * PathStep, 0)
			Position = Next
			table.insert(Path, Position)
		end

		return true, Path
	end

	local function GetFirePosition(Root: BasePart): Vector3
		return Root.Position + Root.AssemblyLinearVelocity * FireLead - Vector3.new(0, workspace.Gravity * 0.5 * FireLead * FireLead, 0)
	end

	local function CreateMarker(Index: number): Part
		local Color: Color3 = Index == 1 and Color3.fromRGB(90, 255, 120) or Color3.new(1, 1, 1)
		local TagSize: Vector2 = GetFontBounds("Best landing 000 studs 0.00s", 14, UIPallet.Font)
		local Marker: Part = Instance.new("Part")
		Marker.Size = Vector3.new(3, 0.2, 3)
		Marker.Anchored = true
		Marker.CanCollide = false
		Marker.CanQuery = false
		Marker.CanTouch = false
		Marker.CastShadow = false
		Marker.Transparency = 1
		local Selection: SelectionBox = Instance.new("SelectionBox")
		Selection.Adornee = Marker
		Selection.LineThickness = 0.04
		Selection.Color3 = Color
		Selection.SurfaceColor3 = Color
		Selection.SurfaceTransparency = 0.75
		Selection.Parent = Marker
		local Billboard: BillboardGui = Instance.new("BillboardGui")
		Billboard.Name = "Tag"
		Billboard.Size = UDim2.fromOffset(TagSize.X + 8, TagSize.Y + 7)
		Billboard.StudsOffsetWorldSpace = Vector3.new(0, 2, 0)
		Billboard.AlwaysOnTop = true
		Billboard.Parent = Marker
		local Label: TextLabel = Instance.new("TextLabel")
		Label.Name = "Label"
		Label.Size = Billboard.Size
		Label.BackgroundColor3 = Color3.new()
		Label.BackgroundTransparency = 0.5
		Label.BorderSizePixel = 0
		Label.FontFace = UIPallet.Font
		Label.TextSize = 14
		Label.TextColor3 = Color
		Label.Parent = Billboard

		return Marker
	end

	local function HideSpots(): ()
		for _, v: Part in Markers do
			if v.Parent then
				v.Parent = nil
			end
		end
	end

	local function ShowSpots(Spots: {any}, Position: Vector3): ()
		if not ShowLanding.Enabled then
			return
		end

		for i: number = 1, MarkerCount do
			local Info: any = Spots[i]
			local Marker: Part? = Markers[i]
			if not Info then
				if Marker and Marker.Parent then
					Marker.Parent = nil
				end
				continue
			end

			if not Marker then
				Marker = CreateMarker(i)
				Markers[i] = Marker
			end

			local Distance: number = math.round((Info.landing - Position).Magnitude)
			local Text: string = `{i == 1 and "Best landing " or ""}{Distance} studs {math.round(Info.time * 100) / 100}s`
			Marker.CFrame = CFrame.new(Info.landing - Vector3.new(0, 0.4, 0))
			if Marker.Tag.Label.Text ~= Text then
				Marker.Tag.Label.Text = Text
			end
			if Marker.Parent ~= Camera then
				Marker.Parent = Camera
			end
		end
	end

	local function ClearFall(): ()
		Alerted, Hope, Probe = false, false, 0
		HideSpots()
	end

	local function Lost(Reason: string): ()
		if Alerted then
			return
		end

		Alerted = true
		if WarnLost.Enabled then
			vape:CreateNotification("AutoPearl", `Can't clutch, {Reason}`, 5, "warning")
		end
	end

	local function LookAhead(Path: {Vector3}, Ground: number, Deadline: number): ()
		Probe += 1
		local Sample: Vector3? = Path[Probe * ProbeStride]
		if Sample then
			if #FindSpots(Sample, GetAnchors(Sample), Deadline - Probe * ProbeStride * PathStep) > 0 then
				Hope = true
			end
			return
		end

		if not Hope then
			local Reason: string = "your pearl can't reach any ground in time"
			if Ground == 0 then
				Reason = `no ground within {ClutchRange.Value} studs`
			end
			Lost(Reason)
		end
		Probe, Hope = 0, false
	end

	local function GetHeld(): string
		local HandValue: ObjectValue? = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HandInvItem") or nil
		return HandValue and HandValue.Value and HandValue.Value.Name or "nothing"
	end

	local function FirePearl(Shot: any, Origin: Vector3, Item): boolean
		if not Entity.isAlive then
			return false
		end

		local Hotbar, OldHand = GetHotbar(Item.tool), store.hand
		local PreviousThrow: number = LastThrow
		local ThrowUntil: number = tick() + Cooldown.Value
		LastThrow = ThrowUntil

		SwitchItem(Item.tool, EquipGap)

		local Position: Vector3? = Entity.isAlive and Origin or nil
		local Direction: Vector3? = Position and Shot.velocity or nil
		local Landed: boolean = false

		if Position and Direction then
			local Meta = bedwars.ProjectileMeta.telepearl
			local Id: string = bedwars.IdUtil.generateId(8)
			local ShotData = bedwars.getShotData("telepearl")
			local Projectile = bedwars.ProjectileController:createLocalProjectile(Meta, "telepearl", "telepearl", Position, Id, Direction, ShotData)
			InFlight = Projectile
			local Tracked = Projectile
			local Pending: boolean = Projectile == nil

			bedwars.Handler:Get("ProjectileFire"):Fire("CallServerAsync",
				Item.tool,
				"telepearl",
				"telepearl",
				Position,
				Position,
				Direction,
				Id,
				ShotData,
				workspace:GetServerTimeNow() - 0.045
			):andThen(function(Result)
				Pending = false
				if type(Result) == "table" and Result.accepted then
					if Projectile == nil and typeof(Result.model) == "Instance" then
						Tracked, InFlight = Result.model, Result.model
					elseif Result.model and Result.model.Parent then
						Result.model.Parent = ReplicatedStorage
					end
					return
				end

				warn(`AutoPearl throw refused, holding {GetHeld()}`)
				if Projectile then
					Projectile:Destroy()
				end
				if LastThrow == ThrowUntil then
					LastThrow = PreviousThrow
				end
				if InFlight == Projectile then
					InFlight = nil
				end
				NextScan = 0
			end)

			task.spawn(function()
				local Timeout: number = tick() + 10
				repeat
					task.wait()
				until not AutoPearl.Enabled or tick() >= Timeout or (not Pending and (not Tracked or not Tracked.Parent))
				Landed = true
				HideSpots()
			end)
		else
			if LastThrow == ThrowUntil then
				LastThrow = PreviousThrow
			end
			NextScan = tick() + RetryGap
			Landed = true
			HideSpots()
		end

		if Legit.Enabled and Hotbar then
			HotbarSwitch(Hotbar)
		end

		if Back.Enabled and LandCheck.Enabled then
			repeat
				task.wait()
			until Landed or not AutoPearl.Enabled
		end

		if Back.Enabled and OldHand and OldHand.tool then
			task.wait(BackDelay:GetRandomValue())
			SwitchItem(OldHand.tool)
			if Legit.Enabled and GetHotbar(OldHand.tool) then
				HotbarSwitch(GetHotbar(OldHand.tool))
			end
		end

		return Direction ~= nil
	end

	local function Rescue(Root: BasePart, Path: {Vector3}): ()
		if Check.Enabled and InFlight and InFlight.Parent then
			HideSpots()
			return
		end

		local Item = GetItem("telepearl")
		if not Item then
			HideSpots()
			Lost("you have no telepearl")
			return
		end

		local Deadline: number = GetDeadline(Root.Position, Root.AssemblyLinearVelocity.Y)
		local From: Vector3 = GetFirePosition(Root)
		local Spots: {any}, Ground: number = FindSpots(From, GetAnchors(Root.Position), Deadline)
		NextScan = tick() + ScanGap
		if #Spots == 0 then
			HideSpots()
			if not Alerted then
				LookAhead(Path, Ground, Deadline)
			end
			return
		end

		Probe, Hope = 0, false
		local Success, Result = pcall(ShowSpots, Spots, Root.Position)
		if not Success then
			warn(`AutoPearl landing boxes failed: {Result}`)
		end
		if Limit.Enabled and not (store.hand.tool and store.hand.tool.Name == "telepearl") then
			return
		end

		FirePearl(Spots[1], From, Item)
	end

	AutoPearl = vape.Categories.Utility:CreateModule({
		Name = "AutoPearl",
		Function = function(Callback: boolean)
			if Callback then
				VoidLine = nil
				local Connection = bedwars.SyncEvents.ProjectileLaunched:connect(function(Event)
					if Event.projectileType ~= "telepearl" or typeof(Event.projectile) ~= "Instance" or not Event.projectile:IsA("PVInstance") or not Entity.isAlive then
						return
					end
					if Event.shooter == Entity.character.Character then
						InFlight = Event.projectile
					end
				end)

				AutoPearl:Clean(function()
					Connection:Destroy()
					ClearFall()
					for _, v: Part in Markers do
						v:Destroy()
					end
					table.clear(Markers)
				end)

				repeat
					if store.map and store.airRay then
						if RayCheckMap ~= store.map then
							RayCheckMap = store.map
							RayCheck.FilterDescendantsInstances = {store.map}
						end
						local Group = Entity.isAlive and Entity.character.RootPart.CollisionGroup or ""
						if RayCheck.CollisionGroup ~= Group then
							RayCheck.CollisionGroup = Group
						end

						local Root = Entity.isAlive and Entity.character.RootPart
						if Root and Entity.character.Humanoid.FloorMaterial ~= Enum.Material.Air then
							LastGround = Root.Position
						end

						if not Root then
							ClearFall()
						elseif tick() >= NextScan and tick() >= LastThrow then
							local Falling: boolean, Path: {Vector3} = IsVoidFall(Root)
							if Falling then
								Rescue(Root, Path)
							else
								ClearFall()
							end
						end
					end

					task.wait()
				until not AutoPearl.Enabled
			else
				InFlight = nil
				LastGround = nil
			end
		end,
		Tooltip = "Throws a pearl onto nearby ground when you are falling into the void"
	})

	Legit = AutoPearl:CreateToggle({
		Name = "Legit Switch",
		Tooltip = "Visualizes the switching clientside",
		Default = true
	})
	Back = AutoPearl:CreateGroup({
		Name = "Switch back",
		Default = true,
		Tooltip = "Switches back to the last slot before pearl"
	})
	LandCheck = Back:CreateToggle({
		Name = "Only after landed",
		Tooltip = "Only switches back after your pearl landed",
		Darker = true
	})
	Check = AutoPearl:CreateToggle({
		Name = "Pearl check",
		Default = true,
		Tooltip = "Doesn't throw a pearl while one of yours is still in the air, including ones you threw yourself"
	})
	BackDelay = Back:CreateTwoSlider({
		Name = "Switch Back Delay",
		Min = 0,
		Max = 2,
		DefaultMin = 0.1,
		DefaultMax = 0.2,
		Darker = true
	})
	ClutchRange = AutoPearl:CreateSlider({
		Name = "Clutch range",
		Min = 10,
		Max = 100,
		Default = 24,
		Suffix = "studs",
		Tooltip = "How far away a block can be for a void save, blocks your pearl cannot reach are skipped"
	})
	Cooldown = AutoPearl:CreateSlider({
		Name = "Cooldown",
		Min = 0,
		Max = 5,
		Default = 1,
		Decimal = 10,
		Suffix = "seconds",
		Tooltip = "Minimum gap between two throws"
	})
	Limit = AutoPearl:CreateToggle({
		Name = "Limit to item",
		Tooltip = "Only throws pearl when holding a pearl"
	})
	ShowLanding = AutoPearl:CreateToggle({
		Name = "Show landing",
		Function = function(Callback: boolean)
			if not Callback then
				HideSpots()
			end
		end,
		Default = true,
		Tooltip = "Boxes the ground your pearl can reach while you fall, green is the best spot"
	})
	WarnLost = AutoPearl:CreateToggle({
		Name = "Warn when lost",
		Default = true,
		Tooltip = "Warns you when no pearl throw can save you from the void"
	})
end)
