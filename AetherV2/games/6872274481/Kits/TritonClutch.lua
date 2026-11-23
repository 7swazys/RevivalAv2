run(function()
	local Entity = entitylib
	local GetHotbar = getHotbar
	local GetItem = getItem
	local HotbarSwitch = hotbarSwitch
	local PredictionLib = prediction
	local ReplicatedStorage = replicatedStorage
	local Store = store
	local SwitchItem = switchItem
	local TritonClutch
	local Legit
	local Back
	local LandCheck
	local BackDelay
	local Limit
	local Search
	local Recall
	local NextFire: number = 0
	local virtualInputManager = cloneref(game:GetService('VirtualInputManager'))

	local RayCheck: RaycastParams = RaycastParams.new()
	RayCheck.RespectCanCollide = true
	RayCheck.FilterType = Enum.RaycastFilterType.Include

	local function GetHarpoon()
		return GetItem("harpoon") or GetItem("triton_harpoon") or GetItem("trident")
	end

	local function IsHarpoon(tool)
		local name = tool and tool.Name and tool.Name:lower()
		return name == "harpoon" or name == "trident" or name == "triton_harpoon"
	end

	local function GetNearGround(Origin: Vector3)
		for Step: number = 1, Search.Value do
			for _, v: Vector3 in {Vector3.xAxis, Vector3.zAxis, -Vector3.xAxis, -Vector3.zAxis} do
				local RayResult: RaycastResult? = workspace:Raycast((Origin + Vector3.new(0, 3, 0)) + (v * Step), Vector3.new(0, -80, 0), RayCheck)
				if RayResult then
					return RayResult.Position
				end
			end
		end
		return nil
	end

	local function WaitForClutch()
		local started = tick()
		repeat
			task.wait()
			local root = Entity.isAlive and Entity.character.RootPart
			if root and root.AssemblyLinearVelocity.Y > -10 then
				return true
			end
		until not TritonClutch.Enabled or tick() - started > 3
		return false
	end

	local function RecallHome()
		task.wait(1.25)
		virtualInputManager:SendKeyEvent(true, Enum.KeyCode.C, false, game)
		task.wait()
		virtualInputManager:SendKeyEvent(false, Enum.KeyCode.C, false, game)
		local started, lastPosition, stable = tick(), nil, 0
		repeat
			task.wait(0.1)
			local root = Entity.isAlive and Entity.character.RootPart
			if root then
				local moved = lastPosition and (root.Position - lastPosition).Magnitude or math.huge
				if tick() - started > 0.75 and moved < 1 and root.AssemblyLinearVelocity.Magnitude < 8 then
					stable += 0.1
					if stable >= 0.3 then return true end
				else
					stable = 0
				end
				lastPosition = root.Position
			end
		until not TritonClutch.Enabled or tick() - started > 7
		return false
	end

	local function FireHarpoon(Item, Spot: Vector3)
		local Meta = bedwars.ProjectileMeta.harpoon_projectile
		local Source = bedwars.ItemMeta[Item.itemType].projectileSource
		local Origin: Vector3 = Entity.character.RootPart.Position
		local Speed, Gravity = Meta.launchVelocity, Meta.gravitationalAcceleration or 196.2
		local ShootPosition: Vector3 = (CFrame.new(Origin, Spot) * CFrame.new(Vector3.new(-bedwars.BowConstantsTable.RelX, -bedwars.BowConstantsTable.RelY, -bedwars.BowConstantsTable.RelZ))).Position
		local AimPoint: Vector3? = PredictionLib.SolveTrajectory(ShootPosition, Speed, Gravity, Spot, Vector3.zero, workspace.Gravity, 0, nil, nil, false, Spot)
		if not AimPoint then
			return false
		end

		local Hotbar, Previous = GetHotbar(Item.tool), Store.hand.tool
		SwitchItem(Item.tool)
		if Legit.Enabled and Hotbar then
			HotbarSwitch(Hotbar)
		end

		NextFire = tick() + (Source and Source.fireDelaySec or 8)
		bedwars.Handler:Get("ProjectileFire"):Fire("CallServerAsync",
			Item.tool,
			nil,
			Source and Source.projectileType(Item.itemType) or "harpoon_projectile",
			ShootPosition,
			Origin,
			CFrame.lookAt(ShootPosition, AimPoint).LookVector * Speed,
			bedwars.IdUtil.generateId(8),
			bedwars.getShotData(Item.itemType),
			workspace:GetServerTimeNow() - 0.045
		):andThen(function(Result)
			if type(Result) == "table" and Result.accepted and Result.model then
				Result.model.Parent = ReplicatedStorage
			end
		end)

		if Back.Enabled and Previous then
			if LandCheck.Enabled then WaitForClutch() end
			if Recall.Enabled then
				RecallHome()
			else
				task.wait(BackDelay:GetRandomValue())
			end
			SwitchItem(Previous)
			if Legit.Enabled and GetHotbar(Previous) then
				HotbarSwitch(GetHotbar(Previous))
			end
		elseif Recall.Enabled then
			task.spawn(RecallHome)
		end
		return true
	end

	TritonClutch = kits:CreateModule({
		Name = "TritonClutch",
		Category = "Ability",
		Function = function(Callback: boolean)
			if Callback then
				NextFire = 0
				local LastGround: Vector3?

				repeat
					if Entity.isAlive and tick() >= NextFire and (not Limit.Enabled or IsHarpoon(Store.hand.tool)) then
						local Root: BasePart = Entity.character.RootPart
						local Harpoon = GetHarpoon()
						RayCheck.FilterDescendantsInstances = {Store.map}
						RayCheck.CollisionGroup = Root.CollisionGroup

						if Entity.character.Humanoid.FloorMaterial ~= Enum.Material.Air then
							LastGround = Root.Position
						end

						if Harpoon and Store.inVoid(Root) then
							local Spot: Vector3? = GetNearGround(Root.Position + Vector3.new(0, 40, 0)) or LastGround and GetNearGround(LastGround + Vector3.new(0, 5, 0))
							if Spot then
								FireHarpoon(Harpoon, Spot)
							end
						end
					end
					task.wait(0.1)
				until not TritonClutch.Enabled
			end
		end,
		Tooltip = 'Throws the harpoon onto nearby ground when falling into the void'
	})

	Search = TritonClutch:CreateSlider({
		Name = "Search range",
		Min = 4,
		Max = 60,
		Default = 40,
		Suffix = function(Val: number)
			return Val <= 1 and "stud" or "studs"
		end,
		Tooltip = 'How far it looks for ground to land on'
	})
	Legit = TritonClutch:CreateToggle({
		Name = "Legit Switch",
		Default = true,
		Tooltip = 'Visibly switches items on your hotbar'
	})
	Back = TritonClutch:CreateGroup({
		Name = "Switch back",
		Default = true,
		Tooltip = 'Switches back to your last item afterwards'
	})
	LandCheck = Back:CreateToggle({
		Name = "Only after clutch",
		Darker = true,
		Tooltip = 'Only switches back after a clutch'
	})
	BackDelay = Back:CreateTwoSlider({
		Name = "Switch Back Delay",
		Min = 0,
		Max = 2,
		DefaultMin = 0.1,
		DefaultMax = 0.2,
		Darker = true
	})
	Limit = TritonClutch:CreateToggle({
		Name = "Limit to items",
		Tooltip = 'Only works while holding the item it uses'
	})
	Recall = TritonClutch:CreateToggle({
		Name = "Recall",
		Tooltip = 'Recalls to base after a clutch'
	})
end)
