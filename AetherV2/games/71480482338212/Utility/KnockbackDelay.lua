run(function()
	local KnockbackDelay
	local AirDelay
	local GroundDelay
	local Chance
	local TargetCheck
	local rand = Random.new()

	local function delayed(velocity)
		if rand:NextNumber(0, 100) > Chance.Value then return velocity, 0 end
		if TargetCheck.Enabled and not entitylib.EntityPosition({Range = 50, Part = 'RootPart', Players = true}) then return velocity, 0 end
		local air = entitylib.isAlive and entitylib.character.Humanoid.FloorMaterial == Enum.Material.Air
		return velocity, (air and AirDelay or GroundDelay):GetRandomValue() / 1000
	end

	KnockbackDelay = vape.Categories.Utility:CreateModule({
		Name = 'KnockbackDelay',
		Function = function(callback)
			if callback then
				if not store.knockbackFilter('KnockbackDelay', delayed) then
					store.knockbackFilter('KnockbackDelay', nil)
					notif('KnockbackDelay', 'Your executor cannot hook the knockback handler.', 6, 'warning')
					KnockbackDelay:Toggle()
				end
			else
				store.knockbackFilter('KnockbackDelay', nil)
			end
		end,
		Tooltip = 'Delays the knockback you take'
	})
	AirDelay = KnockbackDelay:CreateTwoSlider({
		Name = 'Air delay',
		Min = 0,
		Max = 500,
		DefaultMin = 100,
		DefaultMax = 200,
		Tooltip = 'Delay for knockback taken in the air, in ms'
	})
	GroundDelay = KnockbackDelay:CreateTwoSlider({
		Name = 'Ground delay',
		Min = 0,
		Max = 500,
		DefaultMin = 100,
		DefaultMax = 200,
		Tooltip = 'Delay for knockback taken on the ground, in ms'
	})
	Chance = KnockbackDelay:CreateSlider({
		Name = 'Chance',
		Min = 0,
		Max = 100,
		Default = 100,
		Suffix = '%'
	})
	TargetCheck = KnockbackDelay:CreateToggle({
		Name = 'Target check',
		Tooltip = 'Only delays knockback with a player nearby'
	})
end)
