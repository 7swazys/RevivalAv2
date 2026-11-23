run(function()
    local KnockbackDelay
    local Chance
    local AirDelay
    local GroundDelay
    local TargetCheck

    local old, hook
    local rand = Random.new()

    local function apply(without, ...)
	local root, mass, dir, knockback = ...
	if not old or typeof(root) ~= 'Instance' or not root.Parent then return end
	knockback = knockback and table.clone(knockback) or {}
	knockback[without] = 0
	return old(root, mass, dir, knockback, select(5, ...))
    end

    KnockbackDelay = vape.Categories.Utility:CreateModule({
	Name = 'KnockbackDelay',
	ExtraText = function() return Chance.Value..'%' end,
	Function = function(callback)
		if callback then
			if hook then return end
			old = bedwars.KnockbackUtil.applyKnockback
			hook = function(...)
				if not KnockbackDelay.Enabled or rand:NextNumber(0, 100) > Chance.Value then
					return old(...)
				end

				local root, mass, dir, knockback = ...
				if not TargetCheck.Enabled or entitylib.EntityPosition({
					Range = 50,
					Part = 'RootPart',
					Players = true,
				}) then
					task.delay(AirDelay:GetRandomValue() / 1000, apply, 'horizontal', root, mass, dir, knockback, select(5, ...))
					task.delay(GroundDelay:GetRandomValue() / 1000, apply, 'vertical', root, mass, dir, knockback, select(5, ...))
					return
				end
				return old(...)
			end
			bedwars.KnockbackUtil.applyKnockback = hook
		elseif hook and bedwars.KnockbackUtil.applyKnockback == hook then
			bedwars.KnockbackUtil.applyKnockback = old
			hook = nil
		end
	end,
	Tooltip = 'Delays the knockback you take'
    })

    Chance = KnockbackDelay:CreateSlider({
	Name = 'Chance',
	Min = 1,
	Max = 100,
	Default = 40,
	Suffix = '%',
    })
    AirDelay = KnockbackDelay:CreateTwoSlider({
	Name = 'Air delay',
	Min = 0,
	Max = 500,
	DefaultMin = 50,
	DefaultMax = 200,
	Tooltip = 'Delay before the upward part of knockback applies',
    })
    GroundDelay = KnockbackDelay:CreateTwoSlider({
	Name = 'Ground delay',
	Min = 0,
	Max = 500,
	DefaultMin = 50,
	DefaultMax = 200,
	Tooltip = 'Delay before the sideways part of knockback applies',
    })
    TargetCheck = KnockbackDelay:CreateToggle({
	Name = 'Target check',
	Tooltip = 'Only delays knockback with a player nearby',
    })
end)
