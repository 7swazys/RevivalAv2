run(function()
	local AutoRamil
	local Range
	local Sorts
	local Targets
	local UseTornado
	local TornadoRange

	AutoRamil = kits:CreateModule({
		Name = 'AutoRamil',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and store.equippedKit == 'airbender' then
						local localPosition = entitylib.character.RootPart.Position
						local ent = entitylib.EntityPosition({
							Origin = localPosition,
							Range = UseTornado.Enabled and TornadoRange.Value > Range.Value and TornadoRange.Value or Range.Value,
							Wallcheck = Targets.Walls.Enabled,
							Players = Targets.Players.Enabled,
							Priority = Targets.Priority and Targets.Priority.Value,
							NPCs = Targets.NPCs.Enabled,
							Sort = sortmethods[Sorts.Value]
						})
						local mag = ent and (localPosition - ent.RootPart.Position).Magnitude or math.huge

						if mag <= Range.Value and bedwars.AbilityController:canUseAbility('airbender_tornado', {disableBlockedAbilityAlert = true}) then
							bedwars.AbilityController:useAbility('airbender_tornado')
						end

						if UseTornado.Enabled and mag <= TornadoRange.Value and bedwars.AbilityController:canUseAbility('airbender_moving_tornado', {disableBlockedAbilityAlert = true}) then
							bedwars.AbilityController:useAbility('airbender_moving_tornado')
						end
					end
					task.wait()
				until not AutoRamil.Enabled
			end
		end,
		Tooltip = 'Uses Ramil\'s abilities when conditions are met'
	})
	Targets = AutoRamil:CreateTargets({
		Players = true,
		NPCs = false
	})
	Sorts = AutoRamil:CreateDropdown({
		Name = 'Target Mode',
		List = table.clone(sortlist),
		Default = 'Distance',
		Tooltip = TARGET_MODE_TOOLTIP
	})
	Range = AutoRamil:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 25,
		Default = 25,
		Suffix = function(val)
			return val >= 1 and 'studs' or 'stud'
		end
	})
	UseTornado = AutoRamil:CreateGroup({
		Name = 'Use Moving Tornado',
	})
	TornadoRange = UseTornado:CreateSlider({
		Name = 'Tornado Range',
		Min = 1,
		Max = 35,
		Default = 25,
		Darker = true,
		Suffix = function(val)
			return val >= 1 and 'studs' or 'stud'
		end
	})
end)
