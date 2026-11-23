run(function()
	local AutoAgni
	local Targets, Range, OnlySwinging, Clutch, Escape, EscapeHealth
	local swingMarker, swingSeenAt = nil, -math.huge

	local function updateSwing()
		local value = bedwars.SwordController and bedwars.SwordController.lastSwing or 0
		if value ~= swingMarker then
			swingMarker, swingSeenAt = value, os.clock()
		end
	end

	local function voidFall(root)
		return root ~= nil and store.inVoid(root)
	end

	local function abilityController()
		return bedwars.AbilityController
			or (bedwars.Knit and bedwars.Knit.Controllers and bedwars.Knit.Controllers.AbilityController)
	end

	local function activate()
		local controller = abilityController()
		if not controller then return false end
		if type(controller.canUseAbility) == 'function' then
			local ok, ready = pcall(controller.canUseAbility, controller, 'rocket_detonate', {disableBlockedAbilityAlert = true})
			if not ok or ready == false or ready == nil then return false end
		end
		if type(controller.useAbility) ~= 'function' then return false end
		local used, result = pcall(controller.useAbility, controller, 'rocket_detonate')
		return used and result ~= false
	end

	AutoAgni = kits:CreateModule({
		Name = 'AutoAgni',
		Category = 'Auto',
		Function = function(callback)
			if not callback then return end
			swingMarker, swingSeenAt = bedwars.SwordController and bedwars.SwordController.lastSwing or 0, -math.huge
			local nextUse = 0
			repeat
				if entitylib.isAlive and store.equippedKit == 'agni' then
					local root = entitylib.character.RootPart
					updateSwing()
					if root and Clutch.Enabled and voidFall(root) then
						if os.clock() >= nextUse and activate() then nextUse = os.clock() + 0.5 end

						local land = getNearGround(30)
						local humanoid = entitylib.character.Humanoid
						if land and humanoid then
							local delta = Vector3.new(land.X - root.Position.X, 0, land.Z - root.Position.Z)
							if delta.Magnitude > 0.05 then humanoid:Move(delta.Unit, false) end
						end
					elseif not OnlySwinging.Enabled or os.clock() - swingSeenAt <= 0.3 or (Escape.Enabled and entitylib.character.Humanoid.Health <= entitylib.character.Humanoid.MaxHealth * (EscapeHealth.Value / 100)) then
						local target = entitylib.EntityPosition({
							Range = Range.Value,
							Part = 'RootPart',
							Players = Targets.Players.Enabled,
							Priority = Targets.Priority and Targets.Priority.Value,
							NPCs = Targets.NPCs.Enabled,
							Wallcheck = Targets.Walls.Enabled or nil,
							Sort = sortmethods.Distance
						})
						if target and os.clock() >= nextUse and activate() then nextUse = os.clock() + 0.5 end
					end
				end
				task.wait(0.03)
			until not AutoAgni.Enabled
		end,
		Tooltip = 'Uses Agni\'s rocket boost near targets and to save void falls'
	})
	Targets = AutoAgni:CreateTargets({Players = true, NPCs = true, Walls = true})
	Range = AutoAgni:CreateSlider({Name = 'Range', Min = 1, Max = 40, Default = 12, Suffix = ' studs'})
	OnlySwinging = AutoAgni:CreateToggle({Name = 'Only while swinging'})
	Clutch = AutoAgni:CreateToggle({Name = 'Clutch', Default = true, Tooltip = 'Uses Agni when falling into the void'})
	Escape = AutoAgni:CreateGroup({Name = 'Escape', Default = true, Tooltip = 'Boosts away once you are low and someone is on you, even while not swinging'})
	EscapeHealth = Escape:CreateSlider({Name = 'Health', Min = 1, Max = 100, Default = 35, Suffix = '%'})
end)
