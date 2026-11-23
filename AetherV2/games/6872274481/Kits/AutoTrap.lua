run(function()
	local function CanPlace() return not bedwars.BlockPlacementController.disabled and not isCasting() end
	local Camera = gameCamera
	local Collection = collection
	local CollectionService = collectionService
	local Entity = entitylib
	local GetHotbar = getHotbar
	local GetItem = getItem
	local GetPlacedBlock = getPlacedBlock
	local HotbarSwitch = hotbarSwitch
	local LocalPlayer = lplr
	local ReplicatedStorage = replicatedStorage
	local RoundPosition = roundPos
	local SendNotification = notif
	local SortMethods = sortmethods
	local Store = store
	local AutoTrap
	local Mode
	local Targets
	local TrapType
	local Traps
	local Target
	local Radius
	local Range
	local Amount
	local PlaceRange
	local Delay
	local IgnoreWalls
	local Switch
	local Notify
	local Detonate

	local TrapperFolder: Folder = ReplicatedStorage.TS.games.bedwars.kit.kits.trapper
	local Constants = require(TrapperFolder["trapper-constants"])
	local TrapperUtil = require(TrapperFolder["trapper-util"])
	local TrapState = require(TrapperFolder["snap-trap-state"]).SnapTrapState
	local Balance = Constants.TrapperBalance
	local TrapNames: {[string]: string} = {Snap = "snap_trap", Venom = "venom_trap", Explosive = "explosive_trap"}
	local Placed: {[Vector3]: number} = {}
	local NextThrow: number = 0
	local NextSwitch: number = 0
	local NextDetonate: number = 0
	local BedCount: number = 0
	local Session: number = 0
	local RayFilter: {Instance} = {}
	local SightParams: RaycastParams = RaycastParams.new()
	SightParams.FilterType = Enum.RaycastFilterType.Exclude

	local function UpdateFilter()
		local Filter: {Instance} = {Camera, Entity.character.Character}
		for _, v: any in Entity.List do
			table.insert(Filter, v.Character)
		end
		for _, v: Instance in CollectionService:GetTagged("DontBlockAbilityRaycast") do
			table.insert(Filter, v)
		end
		RayFilter = Filter
	end

	local function Raycast(Origin: Vector3, Direction: Vector3): RaycastResult?
		SightParams.FilterDescendantsInstances = RayFilter
		return bedwars.QueryUtil:raycast(Origin, Direction, SightParams)
	end

	local function HasStock(Item: string): boolean
		local Meta = Constants.TrapperTrapMeta[Item]
		return Meta ~= nil and bedwars.TrapperController:canUseAbilities() and TrapperUtil.getTrapCount(LocalPlayer, Item) > 0 and TrapperUtil.getPlacedTrapCount(LocalPlayer, Item) < Meta.maxPlaced
	end

	local function GetTrap(EnemyMode: boolean): string?
		local Wanted: string? = TrapNames[TrapType.Value]
		if Wanted then
			return HasStock(Wanted) and Wanted or nil
		end

		if EnemyMode then
			local Selected: string = TrapperUtil.getSelectedTrap(LocalPlayer)
			if HasStock(Selected) then
				return Selected
			end
			for _, v: string in Constants.TrapperTraps do
				if HasStock(v) then
					return v
				end
			end
		else
			for _, v: string in Traps.ListEnabled do
				if TrapperUtil.isTrapperTrap(v) and HasStock(v) or not TrapperUtil.isTrapperTrap(v) and GetItem(v) then
					return v
				end
			end
		end
		return nil
	end

	local function GetGround(Position: Vector3): Vector3?
		local Hit: RaycastResult? = Raycast(Position + Vector3.new(0, 3, 0), Vector3.new(0, -24, 0))
		if Hit and Hit.Normal.Y > 0.99 then
			return RoundPosition(Hit.Position + Vector3.new(0, 0.15, 0))
		end
		return nil
	end

	local function IsValid(Position: Vector3, Item: string): boolean
		if tick() < (Placed[Position] or 0) or GetPlacedBlock(Position) then
			return false
		end

		local Origin: Vector3 = Entity.character.RootPart.Position + Vector3.new(0, 1, 0)
		if (Position - Origin).Magnitude > math.min(PlaceRange.Value, Balance.ThrowRange) then
			return false
		end

		if TrapperUtil.isTrapperTrap(Item) then
			return TrapperUtil.canThrowTrap(Origin, Position, Raycast, Vector3.yAxis)
		end
		return GetPlacedBlock(Position - Vector3.new(0, 3, 0)) ~= nil and CanPlace()
	end

	local function PlaceTrap(Position: Vector3, Item: string): boolean
		if not IsValid(Position, Item) then
			return false
		end

		if TrapperUtil.isTrapperTrap(Item) then
			if not HasStock(Item) or bedwars.TrapperController.currentAim then
				return false
			end

			if TrapperUtil.getSelectedTrap(LocalPlayer) ~= Item then
				if tick() >= NextSwitch and bedwars.AbilityController:canUseAbility("trapper_switch", {disableBlockedAbilityAlert = true}) then
					NextSwitch = tick() + math.max(Balance.SwitchCooldown, 0.25)
					bedwars.AbilityController:useAbility("trapper_switch", nil, {trapType = Item})
				end
				return false
			end

			local Controller = bedwars.TrapperController
			local Aim = {
				character = LocalPlayer.Character,
				trapType = Item,
				source = "binding",
				released = true,
				payload = {trapType = Item, target = Position, normal = Vector3.yAxis}
			}
			Controller.currentAim = Aim
			local Success, Fired = pcall(function(): boolean
				if not bedwars.AbilityController:canUseAbility("trapper_throw", {disableBlockedAbilityAlert = true}) then
					return false
				end
				bedwars.AbilityController:useAbility("trapper_throw", nil, Aim.payload)
				return true
			end)
			if Controller.currentAim == Aim then
				Controller:cancelAim()
			end
			if not Success then
				error(Fired)
			end
			if not Fired then
				return false
			end
		else
			local Previous: number? = Switch.Enabled and Store.hand.tool and GetHotbar(Store.hand.tool) or nil
			bedwars.placeBlock(Position, Item)
			if Previous then
				HotbarSwitch(Previous)
			end
		end

		Placed[Position] = tick() + 2
		if Notify.Enabled then
			SendNotification("AutoTrap", `Placed {Item}`, 3)
		end
		return true
	end

	local function GetBed(): BasePart?
		local Own: string = `Team{LocalPlayer:GetAttribute("Team") or -1}NoBreak`
		local Closest, ClosestDistance = nil, Range.Value
		for _, v: BasePart in CollectionService:GetTagged("bed") do
			local Mine: boolean = v:GetAttribute(Own) and true or false
			if Mine ~= (Target.Value == "Your bed") then
				continue
			end

			local Distance: number = (Entity.character.RootPart.Position - v.Position).Magnitude
			if Distance < ClosestDistance then
				Closest, ClosestDistance = v, Distance
			end
		end
		return Closest
	end

	local function TrapBed(Item: string): boolean
		local Bed: BasePart? = GetBed()
		if not Bed then
			return false
		end

		local Step: number = Radius.Value * 3
		for X: number = -Step, Step, 3 do
			for Z: number = -Step, Step, 3 do
				if math.abs(X) ~= Step and math.abs(Z) ~= Step then
					continue
				end

				local Position: Vector3? = GetGround(Bed.Position + Vector3.new(X, 0, Z))
				if Position and PlaceTrap(Position, Item) then
					return true
				end
			end
		end
		return false
	end

	local function GetEnemies(): {any}
		return Entity.AllPosition({
			Range = Detonate.Enabled and TrapperUtil.getArmedTrapCount(LocalPlayer, "explosive_trap") > 0 and math.huge or PlaceRange.Value + 15,
			Part = "RootPart",
			Players = Targets.Players.Enabled,
			NPCs = Targets.NPCs.Enabled,
			Wallcheck = (IgnoreWalls.Enabled or Targets.Walls.Enabled) and true or nil,
			Sort = SortMethods.Distance
		})
	end

	local function TrapEnemies(Item: string, Enemies: {any}): boolean
		local Origin: Vector3 = Entity.character.RootPart.Position + Vector3.new(0, 1, 0)
		for _, v: any in Enemies do
			local Position: Vector3 = v.RootPart.Position
			local Velocity: Vector3 = v.RootPart.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
			local Duration: number = TrapperUtil.trapThrowDuration(Origin, Position) + Balance.SettleTime + Constants.TrapperTrapMeta[Item].setupTime + (Store.ping.total or 0)
			local Lead: Vector3 = Velocity * Duration
			if Lead.Magnitude > 18 then
				Lead = Lead.Unit * 18
			end

			for _, Factor: number in {1, 0.5, 0} do
				local Ground: Vector3? = GetGround(Position + Lead * Factor - Vector3.new(0, v.HipHeight - 1.5, 0))
				if Ground and PlaceTrap(Ground, Item) then
					return true
				end
			end
		end
		return false
	end

	local function DetonateTraps(PlacedTraps: {BasePart}, Enemies: {any})
		if not Detonate.Enabled or tick() < NextDetonate or TrapperUtil.getArmedTrapCount(LocalPlayer, "explosive_trap") == 0 or not bedwars.TrapperController:canUseAbilities() or not bedwars.AbilityController:canUseAbility("trapper_detonate", {disableBlockedAbilityAlert = true}) then
			return
		end

		for _, v: BasePart in PlacedTraps do
			if v.Name ~= "explosive_trap" or v:GetAttribute("PlacedByUserId") ~= LocalPlayer.UserId or v:GetAttribute("SnapTrapState") ~= TrapState.ACTIVE then
				continue
			end

			local Normal: Vector3 = v:GetAttribute("TrapperSurfaceNormal") or Vector3.yAxis
			local Center: Vector3 = TrapperUtil.trapSurfacePosition(v.Position, Normal)
			for _, Ent: any in Enemies do
				local Predicted: Vector3 = Ent.RootPart.Position + Ent.RootPart.AssemblyLinearVelocity * Balance.ExplosionDelay
				if (Ent.RootPart.Position - Center).Magnitude <= Balance.ExplosionRadius and (Predicted - Center).Magnitude <= Balance.ExplosionRadius then
					NextDetonate = tick() + math.max(Balance.DetonateCooldown, Balance.ExplosionDelay)
					bedwars.AbilityController:useAbility("trapper_detonate")
					return
				end
			end
		end
	end

	AutoTrap = kits:CreateModule({
		Name = "AutoTrap",
		Function = function(Callback: boolean)
			Session += 1
			if Callback then
				local CurrentSession: number = Session
				table.clear(Placed)
				NextThrow, NextSwitch, NextDetonate, BedCount = 0, 0, 0, 0
				local PlacedTraps: {BasePart} = Collection("trapper_trap", AutoTrap)

				repeat
					if Entity.isAlive then
						local Enemies: {any} = GetEnemies()
						DetonateTraps(PlacedTraps, Enemies)
						if tick() >= NextThrow then
							local EnemyMode: boolean = Mode.Value == "Enemies"
							local Item: string? = GetTrap(EnemyMode)
							if Item then
								UpdateFilter()
								local Success: boolean = EnemyMode and TrapEnemies(Item, Enemies) or not EnemyMode and TrapBed(Item)
								if Success then
									BedCount = EnemyMode and 0 or BedCount + 1
									local Pause: boolean = EnemyMode or BedCount >= Amount.Value
									NextThrow = tick() + math.max(Balance.ThrowCooldown, Pause and Delay.Value or 0)
									if Pause then
										BedCount = 0
									end
								end
							end
						end
					end

					for Position: Vector3, Expiry: number in Placed do
						if tick() >= Expiry then
							Placed[Position] = nil
						end
					end
					task.wait(0.1)
				until not AutoTrap.Enabled or CurrentSession ~= Session
			end
		end,
		Tooltip = 'Throws traps at enemies or around a bed and detonates explosives'
	})

	Mode = AutoTrap:CreateDropdown({
		Name = "Mode",
		List = {"Bed ring", "Enemies"},
		Function = function(Val: string)
			if Traps then
				local EnemyMode: boolean = Val == "Enemies"
				Target.Object.Visible = not EnemyMode
				Radius.Object.Visible = not EnemyMode
				Range.Object.Visible = not EnemyMode
				Amount.Object.Visible = not EnemyMode
				Traps.Object.Visible = not EnemyMode
				IgnoreWalls.Object.Visible = EnemyMode
			end
			BedCount = 0
		end,
		Tooltip = 'Bed ring - surrounds a bed\nEnemies - throws ahead of nearby targets'
	})
	Targets = AutoTrap:CreateTargets({Players = true})
	TrapType = AutoTrap:CreateDropdown({
		Name = "Trap type",
		List = {"Auto", "Snap", "Venom", "Explosive"},
		Tooltip = 'Which trap to use'
	})
	Target = AutoTrap:CreateDropdown({
		Name = "Target",
		List = {"Your bed", "Enemy bed"}
	})
	Radius = AutoTrap:CreateSlider({
		Name = "Radius",
		Min = 1,
		Max = 5,
		Default = 2,
		Suffix = "blocks"
	})
	Range = AutoTrap:CreateSlider({
		Name = "Range",
		Min = 4,
		Max = 60,
		Default = 20,
		Suffix = "studs",
		Tooltip = "How close the bed has to be before placing"
	})
	Amount = AutoTrap:CreateSlider({
		Name = "Amount",
		Min = 1,
		Max = 8,
		Default = 3,
		Suffix = "traps",
		Tooltip = 'Traps to throw at a time'
	})
	PlaceRange = AutoTrap:CreateSlider({
		Name = "Place Range",
		Min = 1,
		Max = 45,
		Default = 30,
		Suffix = "studs",
		Tooltip = 'How far it can throw'
	})
	Delay = AutoTrap:CreateSlider({
		Name = "Delay",
		Min = 0.35,
		Max = 10,
		Default = 0.5,
		Decimal = 100,
		Suffix = "seconds",
		Tooltip = 'Time between throws'
	})
	IgnoreWalls = AutoTrap:CreateToggle({
		Name = "Ignore behind walls",
		Visible = false,
		Tooltip = 'Skips enemies you cannot see'
	})
	Detonate = AutoTrap:CreateToggle({
		Name = "Auto detonate",
		Default = true,
		Tooltip = 'Detonates your explosives when an enemy is in the blast'
	})
	Switch = AutoTrap:CreateToggle({
		Name = "Switch back",
		Default = true,
		Tooltip = 'Switches back to your last item afterwards'
	})
	Notify = AutoTrap:CreateToggle({Name = "Notify"})
	Traps = AutoTrap:CreateTextList({
		Name = "Traps",
		Default = {"snap_trap", "venom_trap", "explosive_trap", "invisible_landmine", "spike_trap", "tesla_trap", "grave_trap", "lucky_block_trap"},
		Darker = true,
		Placeholder = "item",
		Tooltip = 'Traps to use, in order'
	})
end)
