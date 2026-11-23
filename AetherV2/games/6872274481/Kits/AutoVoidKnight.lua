run(function()

	local util = vape.Libraries.bedwarsutil
	local AutoVoidKnight
	local Iron
	local Emeralds
	local Keep
	local Ascend
	local Range

	local function feed(itemType, ability)
		local item = getItem(itemType)
		if item and item.amount > Keep.Value and bedwars.AbilityController:canUseAbility(ability, {disableBlockedAbilityAlert = true}) then
			bedwars.AbilityController:useAbility(ability)
		end
	end

	AutoVoidKnight = kits:CreateModule({
		Name = 'AutoVoidKnight',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and store.equippedKit == 'void_knight' then
						if Iron.Enabled then
							feed('iron', 'void_knight_consume_iron')
						end

						if Emeralds.Enabled then
							feed('emerald', 'void_knight_consume_emerald')
						end

						if Ascend.Enabled and bedwars.AbilityController:canUseAbility('void_knight_ascend', {disableBlockedAbilityAlert = true}) then
							local near = entitylib.EntityPosition({
								Origin = entitylib.character.RootPart.Position,
								Range = Range.Value,
								Part = 'RootPart',
								Players = true
							})
							if near then
								bedwars.AbilityController:useAbility('void_knight_ascend')
							end
						end
					end
					task.wait(0.2)
				until not AutoVoidKnight.Enabled
			end
		end,
		Tooltip = 'Feeds resources into the void and ascends in fights'
	})
	Keep = AutoVoidKnight:CreateSlider({
		Name = 'Keep',
		Min = 0,
		Max = 64,
		Default = 0,
		Tooltip = 'Resources left untouched in your inventory'
	})
	Range = AutoVoidKnight:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 30,
		Suffix = util.Studs
	})
	local Actions
	Actions = AutoVoidKnight:CreateMultiDropdown({
		Name = 'Use',
		List = {'Feed iron', 'Feed emeralds', 'Ascend'},
		Default = {'Feed iron', 'Feed emeralds', 'Ascend'},
		Tooltip = 'Which abilities it uses for you; Ascend goes off when an enemy is close'
	})
	Iron = setmetatable({}, {__index = function(_, key) if key == 'Enabled' then return Actions:Has('Feed iron') end end})
	Emeralds = setmetatable({}, {__index = function(_, key) if key == 'Enabled' then return Actions:Has('Feed emeralds') end end})
	Ascend = setmetatable({}, {__index = function(_, key) if key == 'Enabled' then return Actions:Has('Ascend') end end})
end)
