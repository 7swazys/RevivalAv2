run(function()
	local Entity = entitylib
	local GetHotbar = getHotbar
	local GetItem = getItem
	local HotbarSwitch = hotbarSwitch
	local ReplicatedStorage = replicatedStorage
	local Store = store
	local SwitchItem = switchItem
	local AutoPearlAggro
	local Legit
	local Back
	local Check
	local LandCheck
	local BackDelay
	local Limit
	local Distance
	local MinHealth
	local Cooldown
	local LastThrow: number = 0
	local InFlight

	local FollowMinimum: number = 12
	local LandingTolerance: number = 4
	local FlightStep: number = 0.05
	local MaxFlight: number = 4
	local PearlBox: Vector3 = Vector3.new(3, 1, 3)

	local function PredictLanding(Origin: Vector3, Velocity: Vector3, Gravity: number): Vector3?
		local Drop: Vector3 = Vector3.new(0, -Gravity, 0)
		local Last: Vector3 = Origin
		for Step: number = 1, math.round(MaxFlight / FlightStep) do
			local Time: number = Step * FlightStep
			local Position: Vector3 = Origin + Velocity * Time + Drop * (0.5 * Time * Time)
			local Direction: Vector3 = Position - Last
			local Hit: RaycastResult? = workspace:Blockcast(CFrame.new(Last), PearlBox, Direction, Store.airRay)
			if Hit then
				return Last + Direction.Unit * Hit.Distance
			end
			Last = Position
		end

		return nil
	end

	local function GetLaunch(From: Vector3, Spot: Vector3): Vector3?
		local Meta = bedwars.ProjectileMeta.telepearl
		local Speed: number = Meta.launchVelocity
		local Gravity: number = Meta.gravitationalAcceleration or 196.2
		local Offset: Vector3 = Spot - From
		local Flat: Vector3 = Offset * Vector3.new(1, 0, 1)
		local Discriminant: number = Speed ^ 4 - Gravity * (Gravity * Flat.Magnitude ^ 2 + 2 * Offset.Y * Speed ^ 2)
		if Flat.Magnitude < 1 or Discriminant < 0 then
			return nil
		end

		for _, v: number in {-1, 1} do
			local Angle: number = math.atan((Speed ^ 2 + v * math.sqrt(Discriminant)) / (Gravity * Flat.Magnitude))
			local Velocity: Vector3 = Flat.Unit * (math.cos(Angle) * Speed) + Vector3.new(0, math.sin(Angle) * Speed, 0)
			local Landing: Vector3? = PredictLanding(From, Velocity, Gravity)
			if Landing and (Landing - Spot).Magnitude <= LandingTolerance then
				return Velocity
			end
		end

		return nil
	end

	local function FirePearl(Spot: Vector3, Item): boolean
		if not Entity.isAlive or not GetLaunch(Entity.character.RootPart.Position, Spot) then
			return false
		end

		local Hotbar, OldHand = GetHotbar(Item.tool), Store.hand
		local PreviousThrow: number = LastThrow
		local ThrowUntil: number = tick() + Cooldown.Value
		LastThrow = ThrowUntil

		SwitchItem(Item.tool)
		if Legit.Enabled and Hotbar then
			HotbarSwitch(Hotbar)
		end

		local Position: Vector3 = Entity.character.RootPart.Position
		local Direction: Vector3? = Entity.isAlive and GetLaunch(Position, Spot) or nil
		local Landed: boolean = false

		if Direction then
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
					elseif Result.model then
						Result.model.Parent = ReplicatedStorage
					end
					return
				end

				if LastThrow == ThrowUntil then
					LastThrow = PreviousThrow
				end
				if InFlight == Projectile then
					InFlight = nil
				end
			end)

			task.spawn(function()
				local Timeout: number = tick() + 10
				repeat
					task.wait()
				until not AutoPearlAggro.Enabled or tick() >= Timeout or (not Pending and (not Tracked or not Tracked.Parent))
				Landed = true
			end)
		else
			if LastThrow == ThrowUntil then
				LastThrow = PreviousThrow
			end
			Landed = true
		end

		if Back.Enabled and LandCheck.Enabled then
			repeat
				task.wait()
			until Landed or not AutoPearlAggro.Enabled
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

	local function Follow(Origin: Vector3, Velocity: Vector3)
		if not Entity.isAlive or not Store.airRay then
			return
		end

		local Meta = bedwars.ProjectileMeta.telepearl
		local Spot: Vector3? = PredictLanding(Origin, Velocity, Meta.gravitationalAcceleration or 196.2)
		if not Spot or not AutoPearlAggro.Enabled or not Entity.isAlive then
			return
		end

		local Position: Vector3 = Entity.character.RootPart.Position
		local Gap: number = (Spot - Position).Magnitude
		if Gap > Distance.Value or Gap < FollowMinimum or Gap < (Origin - Position).Magnitude then
			return
		end
		if tick() < LastThrow or (Check.Enabled and InFlight and InFlight.Parent) then
			return
		end
		if MinHealth.Value > 0 and Entity.character.Health < MinHealth.Value then
			return
		end
		if Limit.Enabled and not (Store.hand.tool and Store.hand.tool.Name == "telepearl") then
			return
		end

		local Item = GetItem("telepearl")
		if Item then
			FirePearl(Spot, Item)
		end
	end

	local function HandleLaunch(Event)
		if Event.projectileType ~= "telepearl" or not Entity.isAlive then
			return
		end
		if Event.shooter == Entity.character.Character then
			if typeof(Event.projectile) == "Instance" and Event.projectile:IsA("PVInstance") then
				InFlight = Event.projectile
			end
			return
		end
		if typeof(Event.origin) ~= "Vector3" or typeof(Event.launchVelocity) ~= "Vector3" then
			return
		end

		for _, v: any in Entity.List do
			if v.Character == Event.shooter then
				if v.Targetable then
					task.spawn(Follow, Event.origin, Event.launchVelocity)
				end
				break
			end
		end
	end

	AutoPearlAggro = vape.Categories.Utility:CreateModule({
		Name = "AutoPearlAggro",
		Function = function(Callback: boolean)
			if Callback then
				local Connection = bedwars.SyncEvents.ProjectileLaunched:connect(HandleLaunch)

				AutoPearlAggro:Clean(function()
					Connection:Destroy()
				end)

				if not canDebug then
					bedwars.Client:WaitFor("ProjectileLaunchClient"):andThen(function(Remote)
						if not Remote or not AutoPearlAggro.Enabled then
							return
						end

						AutoPearlAggro:Clean(Remote:Connect(function(Data)
							if type(Data) ~= "table" then
								return
							end

							local Shooter = Data.shooter
							if typeof(Shooter) == "Instance" and Shooter:IsA("Player") then
								Shooter = Shooter.Character
							end
							HandleLaunch({
								projectileType = Data.projectileType,
								shooter = Shooter,
								origin = Data.positionFrom,
								launchVelocity = Data.initialVelocity
							})
						end))
					end)
				end
			else
				InFlight = nil
			end
		end,
		Tooltip = 'Throws your pearl to where an enemy pearl will land'
	})

	Legit = AutoPearlAggro:CreateToggle({
		Name = "Legit Switch",
		Tooltip = 'Visibly switches items on your hotbar',
		Default = true
	})
	Back = AutoPearlAggro:CreateGroup({
		Name = "Switch back",
		Default = true,
		Tooltip = 'Switches back to your last item afterwards'
	})
	LandCheck = Back:CreateToggle({
		Name = "Only after landed",
		Tooltip = "Only switches back after your pearl landed",
		Darker = true
	})
	Check = AutoPearlAggro:CreateToggle({
		Name = "Pearl check",
		Default = true,
		Tooltip = 'Does not throw while one of yours is in the air'
	})
	BackDelay = Back:CreateTwoSlider({
		Name = "Switch Back Delay",
		Min = 0,
		Max = 2,
		DefaultMin = 0.1,
		DefaultMax = 0.2,
		Darker = true
	})
	Distance = AutoPearlAggro:CreateSlider({
		Name = "Distance limit",
		Min = 10,
		Max = 200,
		Default = 150,
		Suffix = "studs",
		Tooltip = 'How far away an enemy pearl can land and still be followed'
	})
	MinHealth = AutoPearlAggro:CreateSlider({
		Name = "Min health",
		Min = 0,
		Max = 100,
		Default = 0,
		Tooltip = 'Does not follow below this health'
	})
	Cooldown = AutoPearlAggro:CreateSlider({
		Name = "Cooldown",
		Min = 0,
		Max = 5,
		Default = 1,
		Decimal = 10,
		Suffix = "seconds",
		Tooltip = "Minimum gap between two throws"
	})
	Limit = AutoPearlAggro:CreateToggle({
		Name = "Limit to item",
		Tooltip = 'Only works while holding the item it uses'
	})
end)
