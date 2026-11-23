run(function()
	local util = vape.Libraries.bedwarsutil
	local VulcanAssist
	local Targets
	local Aim
	local Range
	local Sort
	local Mark
	local MarkRange
	local MarkDelay
	local nextMark = 0

	local function show(option, visible)
		if option and option.Object then option.Object.Visible = visible end
	end

	local function aimTurret()
		local turret = entitylib.isAlive and bedwars.Store:getState().Game.selectedTurret
		if not turret then return end
		local origin = turret.Rotate.Position
		local ent = entitylib.EntityMouse({
			Range = Range.Value,
			Origin = origin,
			Wallcheck = Targets.Walls.Enabled or nil,
			Part = 'RootPart',
			Players = Targets.Players.Enabled,
			Priority = Targets.Priority and Targets.Priority.Value,
			NPCs = Targets.NPCs.Enabled,
			Sort = sortmethods[Sort.Value]
		})
		local pos = ent and prediction.SolveTrajectory(origin, 320, 10, ent.RootPart.Position, ent.RootPart.AssemblyLinearVelocity, workspace.Gravity, ent.HipHeight, nil, store.airRay, ent.Humanoid.FloorMaterial == Enum.Material.Air or math.abs(ent.RootPart.AssemblyLinearVelocity.Y) > 0.01, ent.RootPart.Position, ent.RootPart)
		if pos then
			local delta = pos - origin
			bedwars.TurretCameraController.angleX = math.atan2(-delta.X, -delta.Z)
			bedwars.TurretCameraController.angleY = math.clamp(math.atan2(delta.Y, math.sqrt(delta.X ^ 2 + delta.Z ^ 2)), -0.8, 0.8)
		end
	end

	local function markTarget()
		if not (entitylib.isAlive and util.IsKit('vulcan') and tick() >= nextMark and util.Ability.Ready('vulcan_artillery_mark')) then return end
		local target = entitylib.EntityPosition({
			Origin = entitylib.character.RootPart.Position,
			Range = MarkRange.Value,
			Part = 'RootPart',
			Players = true,
			Wallcheck = true
		})
		if target then
			nextMark = tick() + MarkDelay.Value
			util.Ability.Use('vulcan_artillery_mark', {target = target.RootPart.Position})
		end
	end

	VulcanAssist = kits:CreateModule({
		Name = 'VulcanAssist',
		Category = 'Aim',
		Function = function(callback)
			if callback then
				nextMark = 0
				repeat
					if Aim.Enabled then aimTurret() end
					if Mark.Enabled then markTarget() end
					task.wait(0.1)
				until not VulcanAssist.Enabled
			end
		end,
		Tooltip = 'Aims the turret and marks the closest enemy'
	})
	Targets = VulcanAssist:CreateTargets({Walls = true, Players = true})
	Aim = VulcanAssist:CreateToggle({
		Name = 'Aim turret',
		Default = true,
		Function = function(callback)
			show(Sort, callback)
			show(Range, callback)
		end
	})

	local methods = {'Distance', 'Damage'}
	for _, i in sortlist do
		if not table.find(methods, i) then
			table.insert(methods, i)
		end
	end

	Sort = VulcanAssist:CreateDropdown({
		Name = 'Target mode',
		List = methods,
		Default = methods[1],
		Darker = true,
		Tooltip = TARGET_MODE_TOOLTIP
	})
	Range = VulcanAssist:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 1000,
		Default = 500,
		Darker = true
	})
	Mark = VulcanAssist:CreateToggle({
		Name = 'Auto mark',
		Default = false,
		Tooltip = 'Marks the closest enemy when the ability is ready',
		Function = function(callback)
			show(MarkRange, callback)
			show(MarkDelay, callback)
		end
	})
	MarkRange = VulcanAssist:CreateSlider({
		Name = 'Mark range',
		Visible = false,
		Min = 1,
		Max = 150,
		Default = 60,
		Darker = true,
		Suffix = util.Studs
	})
	MarkDelay = VulcanAssist:CreateSlider({
		Name = 'Mark delay',
		Visible = false,
		Min = 0.1,
		Max = 10,
		Default = 2,
		Decimal = 10,
		Darker = true,
		Suffix = util.Seconds
	})
end)
