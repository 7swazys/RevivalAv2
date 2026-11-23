run(function()
	local AutoMelody
	local Range
	local SelfHeal
	local TeammateHeal
	local UseHotbar
	local SwitchBack

	AutoMelody = kits:CreateModule({
		Name = 'AutoMelody',
		Function = function(callback)
			if callback then
				repeat
					local mag, hp, ent = Range.Value, math.huge, nil
					if entitylib.isAlive then
						local localPosition = entitylib.character.RootPart.Position
						for _, v in entitylib.List do
							if v.Player and (SelfHeal.Enabled or v.Player ~= lplr) and (TeammateHeal.Enabled and v.Player:GetAttribute('Team') == lplr:GetAttribute('Team') or not TeammateHeal.Enabled and SelfHeal.Enabled and v.Player == lplr) then
								local newmag = (localPosition - v.RootPart.Position).Magnitude
								if newmag <= mag and v.Health < hp and v.Health < v.MaxHealth then
									mag, hp, ent = newmag, v.Health, v
								end
							end
						end
					end

					local guitar = ent and getItem('guitar')
					if guitar then
						local previousSlot, previousTool = store.inventory.hotbarSlot, store.hand.tool

						if UseHotbar.Enabled then
							local slot = getHotbar(guitar.tool)
							if slot then
								hotbarSwitch(slot)
							end
						end

						bedwars.Handler:Get('GuitarHeal'):Fire('SendToServer', {
							healTarget = ent.Character
						})

						if UseHotbar.Enabled and SwitchBack.Enabled then
							if previousSlot and previousSlot ~= store.inventory.hotbarSlot then
								hotbarSwitch(previousSlot)
							elseif previousTool then
								switchItem(previousTool)
							end
						end
					end
					task.wait(0.1)
				until not AutoMelody.Enabled
			end
		end,
		Tooltip = 'Uses the guitar to heal your teammates and yourself'
	})
	local HealTargets
	HealTargets = AutoMelody:CreateMultiDropdown({
		Name = 'Heal',
		List = {'Yourself', 'Teammates'},
		Default = {'Yourself', 'Teammates'},
		Tooltip = 'Who gets healed'
	})
	SelfHeal = setmetatable({}, {__index = function(_, key) if key == 'Enabled' then return HealTargets:Has('Yourself') end end})
	TeammateHeal = setmetatable({}, {__index = function(_, key) if key == 'Enabled' then return HealTargets:Has('Teammates') end end})
	Range = AutoMelody:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 30,
		Default = 30,
		Decimal = 4
	})
	UseHotbar = AutoMelody:CreateGroup({
		Name = 'Use hotbar',
		Tooltip = 'Visibly switches items on your hotbar'
	})
	SwitchBack = UseHotbar:CreateToggle({
		Name = 'Switch back',
		Default = true,
		Darker = true,
		Tooltip = 'Switches back to your last item afterwards'
	})
end)
