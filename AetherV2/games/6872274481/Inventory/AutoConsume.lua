run(function()
	local AutoConsume
	local Health
	local Consume
	local MushroomKinds
	local MushroomRange
	local MushroomAnimation
	local Items
	local Combat
	local Delay

	local HEALTH_PRIORITY = {'golden_apple', 'big_apple', 'orange', 'apple'}
	local consumeCooldown = {}
	local CONSUME_COOLDOWN = 0.4

	local function itemMeta(id)
		return bedwars.ItemMeta and bedwars.ItemMeta[id] or nil
	end

	local function isConsumable(id)
		local meta = itemMeta(id)
		return meta and type(meta.consumable) == 'table' or false
	end

	local function classOf(id)
		if not isConsumable(id) then return nil end
		local lower = id:lower()
		local consumable = itemMeta(id).consumable or {}
		local effect = consumable.statusEffect and tostring(consumable.statusEffect.statusEffectType or ''):lower() or ''
		if lower:find('shield', 1, true) or effect:find('shield') then return 'shield' end
		if lower:find('mushroom', 1, true) then return 'mushroom' end
		if lower:find('speed', 1, true) or effect:find('speed') then return 'speed' end
		if lower:find('apple', 1, true) or lower:find('orange', 1, true) or lower:find('heal', 1, true) or consumable.requiresMissingHealth or effect:find('health') then return 'health' end
		return 'other'
	end

	local function inventoryItems()
		local inventory = store.inventory and store.inventory.inventory
		return inventory and inventory.items or {}
	end

	local function pick(predicate)
		local chosen
		for _, item in inventoryItems() do
			if item and item.itemType and predicate(item.itemType) then
				chosen = chosen or item
			end
		end
		return chosen
	end

	local function best(class)
		if class == 'health' then
			for _, name in HEALTH_PRIORITY do
				local found = pick(function(id) return id == name end)
				if found then return found end
			end
			return pick(function(id) return classOf(id) == 'health' end)
		end
		return pick(function(id) return classOf(id) == class end)
	end

	local function use(item, key)
		if not item or not item.tool then return false end
		local now = os.clock()
		key = key or item.itemType
		if (consumeCooldown[key] or 0) > now then return false end
		consumeCooldown[key] = now + CONSUME_COOLDOWN
		return pcall(function()
			bedwars.Client:Get(remotes.ConsumeItem):CallServer({item = item.tool})
		end)
	end

	local function consumeClass(class)
		return use(best(class), class)
	end

	local function healthPercent(character)
		local health = tonumber(character:GetAttribute('Health')) or 0
		local maxHealth = tonumber(character:GetAttribute('MaxHealth')) or 100
		return maxHealth > 0 and (health / maxHealth) * 100 or 100
	end

	local function check(attribute)
		if not entitylib.isAlive or not lplr.Character then return end
		local character = lplr.Character

		if not attribute or attribute:find('Health') then
			if healthPercent(character) <= Health.Value then
				local used = Consume:Has('Health items') and consumeClass('health')
				if not used and Consume:Has('Mushrooms') then
					consumeClass('mushroom')
				end
			end
		end

		if Consume:Has('Shield potions') and (not attribute or attribute:find('Shield')) then
			if (tonumber(character:GetAttribute('Shield_POTION')) or 0) == 0 then
				consumeClass('shield')
			end
		end

		if Consume:Has('Speed potions') and (not attribute or attribute == 'StatusEffect_speed') then
			if not character:GetAttribute('StatusEffect_speed') then
				consumeClass('speed')
			end
		end

		if Consume:Has('Other consumables') then
			for _, item in inventoryItems() do
				local id = item and item.itemType
				local meta = id and itemMeta(id)
				local effect = meta and meta.consumable and meta.consumable.statusEffect
				local effectType = effect and effect.statusEffectType
				if effectType and classOf(id) == 'other' and not character:GetAttribute('StatusEffect_'..tostring(effectType)) then
					use(item, id)
				end
			end
		end
	end

	local MUSHROOM_KINDS = {[0] = 'heal', [1] = 'shield', [2] = 'speed', [3] = 'dizzy'}
	local eaten = setmetatable({}, {__mode = 'k'})

	local function wantsMushroom(kind, character)
		local name = MUSHROOM_KINDS[kind]
		if not name then return false end
		local listed = false
		for _, v in MushroomKinds.ListEnabled do
			local entry = v:lower()
			if entry == name or (name == 'heal' and entry == 'health') then
				listed = true
				break
			end
		end
		if not listed then return false end
		if name == 'heal' then
			return healthPercent(character) <= Health.Value
		end
		return true
	end

	local function forestLoop()
		repeat
			local character = lplr.Character
			if Consume:Has('Forest mushrooms') and entitylib.isAlive and character then
				local origin = entitylib.character.RootPart.Position
				local now = tick()
				for _, v in collectionService:GetTagged('forest_environment_plant') do
					local part = v:IsA('Model') and v.PrimaryPart or v
					local id = v:GetAttribute('Id')
					if id and part and now > (eaten[v] or 0) and (origin - part.Position).Magnitude <= MushroomRange.Value and wantsMushroom(v:GetAttribute('MushroomType'), character) then
						eaten[v] = now + 1
						if MushroomAnimation.Enabled then
							pcall(function()
								bedwars.GameAnimationUtil:playAnimation(character, bedwars.AnimationType.PUNCH)
								bedwars.ViewmodelController:playAnimation(bedwars.AnimationType.FP_USE_ITEM)
							end)
						end
						bedwars.Handler:Get('CollectCollectableEntity'):Fire('SendToServer', {
							id = id,
							collectableName = v.Name
						})
					end
				end
				task.wait(0.1)
			else
				task.wait(0.5)
			end
		until not AutoConsume.Enabled
	end

	local function buffLoop()
		repeat
			local character = lplr.Character
			if Consume:Has('Buff list') and entitylib.isAlive and character and store.matchState == 1 and not isCasting() and (not Combat.Enabled or (workspace:GetServerTimeNow() - (character:GetAttribute('LastDamageTakenTime') or 0)) < 6) then
				for _, v in Items.ListEnabled do
					local item = getItem(v)
					local consumable = item and itemMeta(v) and itemMeta(v).consumable
					if consumable then
						local effect = consumable.statusEffect and consumable.statusEffect.statusEffectType or ({v:gsub('_potion', '')})[1]
						if not character:GetAttribute(`StatusEffect_{effect}`) then
							bedwars.Handler:Get('ConsumeItem'):Fire('CallServerAsync', {item = item.tool})
							task.wait(consumable.consumeTime or 1)
							break
						end
					end
				end
			end
			task.wait(Delay.Value)
		until not AutoConsume.Enabled
	end

	AutoConsume = vape.Categories.Inventory:CreateModule({
		Name = 'AutoConsume',
		Function = function(callback)
			if callback then
				AutoConsume:Clean(vapeEvents.InventoryAmountChanged.Event:Connect(check))
				AutoConsume:Clean(vapeEvents.AttributeChanged.Event:Connect(function(attribute)
					if attribute:find('Shield') or attribute:find('Health') or attribute == 'StatusEffect_speed' then
						check(attribute)
					end
				end))
				check()
				AutoConsume:Clean(task.spawn(buffLoop))
				AutoConsume:Clean(task.spawn(forestLoop))
			else
				table.clear(eaten)
			end
		end,
		Tooltip = 'Uses healing, shield, speed and utility items for you'
	})
	Health = AutoConsume:CreateSlider({
		Name = 'Health Percent',
		Min = 1,
		Max = 99,
		Default = 70,
		Suffix = '%'
	})
	Consume = AutoConsume:CreateMultiDropdown({
		Name = 'Consume',
		List = {'Health items', 'Mushrooms', 'Shield potions', 'Speed potions', 'Other consumables', 'Forest mushrooms', 'Buff list'},
		Default = {'Health items', 'Shield potions', 'Speed potions'},
		Tooltip = 'What it uses'
	})
	MushroomKinds = AutoConsume:CreateMultiDropdown({
		Name = 'Mushroom kinds',
		List = {'Speed', 'Heal', 'Shield', 'Dizzy'},
		Default = {'Speed', 'Heal', 'Shield'},
		Darker = true,
		Visible = function() return Consume:Has('Forest mushrooms') end,
		Tooltip = 'Which forest mushrooms to eat'
	})
	MushroomRange = AutoConsume:CreateSlider({
		Name = 'Mushroom range',
		Min = 1,
		Max = 12,
		Default = 10,
		Darker = true,
		Visible = function() return Consume:Has('Forest mushrooms') end,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end,
		Tooltip = 'How close something must be to collect it'
	})
	MushroomAnimation = AutoConsume:CreateToggle({
		Name = 'Pickup animation',
		Default = true,
		Darker = true,
		Visible = function() return Consume:Has('Forest mushrooms') end,
		Tooltip = 'Plays the pickup animation'
	})
	Items = AutoConsume:CreateItemPicker({
		Name = 'Items',
		Multi = true,
		Items = bedwars.itemPickerList(function(_, meta)
			return type(meta.consumable) == 'table'
		end),
		Default = {'fury_potion', 'crit_star', 'vitality_star', 'pie'},
		Darker = true,
		Visible = function() return Consume:Has('Buff list') end,
		Tooltip = 'Items to use, such as fury_potion or pie'
	})
	Combat = AutoConsume:CreateToggle({
		Name = 'In combat only',
		Darker = true,
		Visible = function() return Consume:Has('Buff list') end,
		Tooltip = 'Only uses the listed items when recently hit'
	})
	Delay = AutoConsume:CreateSlider({
		Name = 'Delay',
		Min = 0.1,
		Max = 5,
		Default = 0.5,
		Decimal = 10,
		Darker = true,
		Visible = function() return Consume:Has('Buff list') end,
		Suffix = 'seconds'
	})
end)
