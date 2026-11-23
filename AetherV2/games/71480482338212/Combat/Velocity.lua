run(function()
	local Velocity
	local Horizontal
	local Vertical
	local Chance
	local Targeting
	local Direction
	local attribute
	local rand = Random.new()

	local function scaled(velocity)
		if rand:NextNumber(0, 100) > Chance.Value then return velocity end
		if Targeting.Enabled and not entitylib.EntityPosition({Range = 50, Part = 'RootPart', Players = true}) then return velocity end
		local hort, vert = Horizontal.Value / 100, Vertical.Value / 100
		if hort == 0 and vert == 0 then return nil end
		velocity = Vector3.new(velocity.X * hort, velocity.Y * vert, velocity.Z * hort)
		local mode = Direction.Value
		if mode == 'Default' then return velocity end
		if mode == 'Random' then
			mode = ({'Left', 'Right', 'Pull'})[rand:NextInteger(1, 3)]
		end
		local flat = Vector3.new(velocity.X, 0, velocity.Z)
		local size = flat.Magnitude
		if mode == 'Up' then
			return Vector3.new(0, math.max(velocity.Magnitude, 1), 0)
		elseif mode == 'Void' then
			return Vector3.new(0, -math.max(velocity.Magnitude, 1), 0)
		elseif mode == 'Reverse' or mode == 'Pull' then
			return Vector3.new(-velocity.X, velocity.Y, -velocity.Z)
		elseif (mode == 'Left' or mode == 'Right') and entitylib.isAlive then
			local right = entitylib.character.RootPart.CFrame.RightVector * Vector3.new(1, 0, 1)
			if right.Magnitude > 0.01 then
				right = right.Unit * size
				return Vector3.new(0, velocity.Y, 0) + (mode == 'Left' and -right or right)
			end
		end
		return velocity
	end

	Velocity = vape.Categories.Combat:CreateModule({
		Name = 'Velocity',
		Function = function(callback)
			if callback then
				if store.knockbackFilter('Velocity', scaled) then return end

				notif('Velocity', 'Your executor cannot hook the knockback handler, so knockback is removed completely instead of scaled.', 8, 'warning')
				attribute = true
				repeat
					if entitylib.isAlive and not entitylib.character.Humanoid:GetAttribute('KnockbackDisabled') then
						entitylib.character.Humanoid:SetAttribute('KnockbackDisabled', true)
					end
					task.wait(0.2)
				until not Velocity.Enabled
			else
				store.knockbackFilter('Velocity', nil)
				if attribute then
					attribute = nil
					if entitylib.isAlive then
						entitylib.character.Humanoid:SetAttribute('KnockbackDisabled', nil)
					end
				end
			end
		end,
		Tooltip = 'Reduces knockback taken'
	})
	Horizontal = Velocity:CreateSlider({
		Name = 'Horizontal',
		Min = 0,
		Max = 100,
		Default = 0,
		Suffix = '%'
	})
	Vertical = Velocity:CreateSlider({
		Name = 'Vertical',
		Min = 0,
		Max = 100,
		Default = 0,
		Suffix = '%'
	})
	Chance = Velocity:CreateSlider({
		Name = 'Chance',
		Min = 0,
		Max = 100,
		Default = 100,
		Suffix = '%'
	})
	Targeting = Velocity:CreateToggle({Name = 'Only when targeting'})
	Direction = Velocity:CreateDropdown({
		Name = 'Direction',
		List = {'Default', 'Backwards', 'Up', 'Void', 'Left', 'Right', 'Reverse', 'Pull', 'Random'},
		Default = 'Default',
		Tooltip = 'Changes the direction of knockback'
	})
	Velocity:CreateButton({
		Name = 'Reset to default knockback',
		Function = function()
			Horizontal:SetValue(100)
			Vertical:SetValue(100)
			Direction:SetValue('Default')
		end
	})
end)
