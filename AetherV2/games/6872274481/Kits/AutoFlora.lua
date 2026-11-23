run(function()

	local util = vape.Libraries.bedwarsutil
	local AutoFlora
	local Mode
	local Height
	local nextGlide = 0

	AutoFlora = kits:CreateModule({
		Name = 'AutoFlora',
		Function = function(callback)
			if callback then
				nextGlide = 0

				repeat
					if entitylib.isAlive and store.equippedKit == 'queen_bee' and tick() >= nextGlide and bedwars.AbilityController:canUseAbility('QUEEN_BEE_GLIDE', {disableBlockedAbilityAlert = true}) then
						local root = entitylib.character.RootPart

						local falling
						if Mode.Value == 'Void' then
							falling = store.inVoid(root)
						else
							falling = root.AssemblyLinearVelocity.Y <= -20 and not workspace:Raycast(root.Position, Vector3.new(0, -Height.Value, 0), store.airRay)
						end
						if falling then
							nextGlide = tick() + 1
							bedwars.AbilityController:useAbility('QUEEN_BEE_GLIDE')
						end
					end
					task.wait(0.05)
				until not AutoFlora.Enabled
			end
		end,
		Tooltip = 'Opens the glide the moment you drop with nothing under you'
	})

	Mode = AutoFlora:CreateDropdown({
		Name = 'Mode',
		List = {'Void', 'Any Drop'},
		Default = 'Void',
		Function = function(val)
			Height.Object.Visible = val == 'Any Drop'
		end,
		Tooltip = 'Void - only with no floor under you\nAny Drop - also for long falls'
	})
	Height = AutoFlora:CreateSlider({
		Name = 'Ground check',
		Min = 5,
		Max = 200,
		Default = 40,
		Visible = false,
		Suffix = util.Studs
	})
end)
