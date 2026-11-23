run(function()
	local util = vape.Libraries.bedwarsutil

	local AutoBuy
	local Buy
	local BedwarsCheck
	local GUI
	local SmartCheck
	local OpenShop
	local ArrowAmount
	local Custom = {}
	local CustomPost = {}
	local Functions, id = {}
	local Callbacks = {Custom, Functions, CustomPost}
	local npctick = tick()

	local swords = {
		'wood_sword',
		'stone_sword',
		'iron_sword',
		'diamond_sword',
		'emerald_sword'
	}

	local armors = {
		'none',
		'leather_chestplate',
		'iron_chestplate',
		'diamond_chestplate',
		'emerald_chestplate'
	}

	local axes = {
		'none',
		'wood_axe',
		'stone_axe',
		'iron_axe',
		'diamond_axe'
	}

	local pickaxes = {
		'none',
		'wood_pickaxe',
		'stone_pickaxe',
		'iron_pickaxe',
		'diamond_pickaxe'
	}

	local function getShopNPC()
		local itemShop = util.Shop.Nearby('item')
		local upgradeShop = util.Shop.Nearby('upgrade')
		local shop = (itemShop or upgradeShop) and true or nil
		return shop, itemShop ~= nil, upgradeShop ~= nil, itemShop and itemShop.Id or nil
	end

	local function canBuy(item, currencytable, amount)
		return util.Shop.CanBuy(item, currencytable, amount)
	end

	local function buyItem(item, currencytable)
		if not id then return end
		util.Shop.Purchase(item, id, currencytable, {Label = 'AutoBuy'})
	end

	local function observedInventory()
		local state = bedwars.Store:getState()
		return state and state.Inventory and state.Inventory.observedInventory
	end

	local function findItem(items, itemType)
		for _, item in items or {} do
			if item.itemType == itemType then return item end
		end
	end

	local function guardHotbar(itemType)
		local inv = observedInventory()
		local family = type(itemType) == 'string' and itemType:match('_(%a+)$')
		if not family or not inv or type(inv.hotbar) ~= 'table' then return end
		local before = {}
		for i, entry in inv.hotbar do before[i] = entry.item and entry.item.itemType or false end
		local suffix = '_'..family..'$'
		local conn
		conn = vapeEvents.InventoryChanged.Event:Connect(function()
			local now = observedInventory()
			if not now or type(now.hotbar) ~= 'table' then return end
			for slot, entry in now.hotbar do
				if entry.item and entry.item.itemType == itemType then
					conn:Disconnect()
					local displaced = before[slot]
					if not displaced or displaced:match(suffix) then return end
					for _, other in now.hotbar do
						if other.item and other.item.itemType == displaced then return end
					end
					local target
					for i, previous in before do
						if previous and previous:match(suffix) then target = i break end
					end
					if not target then
						for i, previous in before do
							if not previous and not (now.hotbar[i] and now.hotbar[i].item) then target = i break end
						end
					end
					pcall(function()
						bedwars.Store:dispatch({type = 'InventoryRemoveFromHotbar', slot = slot - 1})
						local back = findItem(observedInventory().inventory.items, displaced)
						if back then bedwars.Store:dispatch({type = 'InventoryAddToHotbar', item = back, slot = slot - 1}) end
						if target then
							local fresh = observedInventory()
							local bought = findItem(fresh.inventory.items, itemType)
							if bought then
								if fresh.hotbar[target] and fresh.hotbar[target].item then
									bedwars.Store:dispatch({type = 'InventoryRemoveFromHotbar', slot = target - 1})
								end
								bedwars.Store:dispatch({type = 'InventoryAddToHotbar', item = findItem(observedInventory().inventory.items, itemType) or bought, slot = target - 1})
							end
						end
					end)
					return
				end
			end
		end)
		task.delay(4, function()
			if conn.Connected then conn:Disconnect() end
		end)
	end

	local function buyTool(tool, tools, currencytable)
		local bought, buyable = false
		tool = tool and table.find(tools, tool.itemType) and table.find(tools, tool.itemType) + 1 or math.huge

		for i = tool, #tools do
			local v = util.Shop.Item(tools[i])
			if not v then continue end
			if canBuy(v, currencytable) then
				if SmartCheck.Enabled and bedwars.ItemMeta[tools[i]].breakBlock and i > 2 then
					if Buy:Has('Armour') then
						local currentarmor = store.inventory.inventory.armor[2]
						currentarmor = currentarmor and currentarmor ~= 'empty' and currentarmor.itemType or 'none'
						if (table.find(armors, currentarmor) or 3) < 3 then break end
					end
					if Buy:Has('Sword') then
						if store.tools.sword and (table.find(swords, store.tools.sword.itemType) or 2) < 2 then break end
					end
				end
				bought = true
				buyable = v
			end
			if v.nextTier then break end
		end

		if buyable and not util.Shop.Pending(buyable.itemType) then
			guardHotbar(buyable.itemType)
			buyItem(buyable, currencytable)
		end

		return bought
	end

	local function familyList(pattern, exclude)
		local meta = bedwars and bedwars.ItemMeta or {}
		local found = {}
		for name in meta do
			if type(name) == 'string' and name:find(pattern, 1, true) and not (exclude and name:find(exclude, 1, true)) then
				table.insert(found, name)
			end
		end
		return found
	end

	local bows = familyList('bow', 'crossbow')
	local crossbows = familyList('crossbow')
	local shopFiltered = false

	local function filterFamilies()
		if shopFiltered or type(bedwars.ShopItems) ~= 'table' then return end
		local sold = {}
		for _, entry in bedwars.ShopItems do
			if type(entry) == 'table' and entry.itemType then
				sold[entry.itemType] = true
			end
		end
		if next(sold) == nil then return end
		shopFiltered = true
		for _, list in {bows, crossbows} do
			local kept = {}
			for _, name in list do
				if sold[name] then table.insert(kept, name) end
			end
			if #kept > 0 then
				table.clear(list)
				table.move(kept, 1, #kept, 1, list)
			end
		end
	end

	local function ownedOf(pattern, exclude)
		local best
		for _, item in util.Inventory.Items() do
			local itemType = item and tostring(item.itemType) or ''
			if itemType:find(pattern, 1, true) and not (exclude and itemType:find(exclude, 1, true)) then
				best = itemType
			end
		end
		return best
	end

	local function aboveOwned(families, owned)
		if not owned then return families end
		local index = table.find(families, owned)
		if not index then return families end
		local rest = {}
		for i = index + 1, #families do
			table.insert(rest, families[i])
		end
		return rest
	end

	local function buyFamily(families, owned, currencytable)
		filterFamilies()
		for _, name in aboveOwned(families, owned) do
			local item = util.Shop.Item(name)
			if item and canBuy(item, currencytable) then
				if not util.Shop.Pending(item.itemType) then
					buyItem(item, currencytable)
				end
				return true
			end
		end
		return false
	end

	local function topUpArrows(currencytable)
		if not id or not ArrowAmount then return false end
		return util.Refill.TopUp('arrow', ArrowAmount.Value, id, currencytable, 'AutoBuy')
	end

	local function refreshBowPurchase()
		if not Buy then return end
		local bow, crossbow, arrows = Buy:Has('Bow'), Buy:Has('Crossbow'), Buy:Has('Arrows')
		Functions[3] = (bow or crossbow or arrows) and function(currencytable, shop)
			if not shop then return end
			local bought = false
			if bow and buyFamily(bows, ownedOf('bow', 'crossbow'), currencytable) then bought = true end
			if crossbow and buyFamily(crossbows, ownedOf('crossbow'), currencytable) then bought = true end
			if arrows then
				local armed = bought or ownedOf('bow') ~= nil
				if armed and topUpArrows(currencytable) then bought = true end
			end
			return bought
		end or nil
	end

	AutoBuy = vape.Categories.Inventory:CreateModule({
		Name = 'AutoBuy',
		Function = function(callback)
			if callback then					util.Queue.Await()
				if BedwarsCheck.Enabled and not store.queueType:find('bedwars') then return end

				local lastupgrades
				AutoBuy:Clean(vapeEvents.InventoryAmountChanged.Event:Connect(function()
					
					
					
					npctick = math.min(npctick, tick())
				end))

				repeat
					local npc, shop, upgrades, newid = getShopNPC()
					id = newid
					if GUI.Enabled and not util.Shop.BuyScreenOpen() then
						npc = nil
					end

					if npc and lastupgrades ~= upgrades then
						npctick = tick()
						lastupgrades = upgrades
					end

					if npc and npctick <= tick() and store.matchState ~= 2 and store.shopLoaded then
						local currencytable = {}
						local waitcheck
						for _, tab in Callbacks do
							for _, callback in tab do
								local ok, res = pcall(callback, currencytable, shop, upgrades)
								if ok and res then
									waitcheck = true
								end
							end
						end
						
						
						
						
						npctick = tick() + (waitcheck and 0.4 or 0.5)
					end

					task.wait(0.1)
				until not AutoBuy.Enabled
			else
				npctick = tick()
			end
		end,
		Tooltip = 'Buys items for you near the shop'
	})

	local function buySword(currencytable, shop)
		if not shop then return end

		if store.equippedKit == 'dasher' then
			swords = {
				[1] = 'wood_dao',
				[2] = 'stone_dao',
				[3] = 'iron_dao',
				[4] = 'diamond_dao',
				[5] = 'emerald_dao'
			}
		elseif store.equippedKit == 'ice_queen' then
			swords[5] = 'ice_sword'
		elseif store.equippedKit == 'ember' then
			swords[5] = 'infernal_saber'
		elseif store.equippedKit == 'lumen' then
			swords[5] = 'light_sword'
		end

		return buyTool(store.tools.sword, swords, currencytable)
	end

	local function buyArmor(currencytable, shop)
		if not shop then return end
		local currentarmor = store.inventory.inventory.armor[2] ~= 'empty' and store.inventory.inventory.armor[2] or getBestArmor(1)
		currentarmor = currentarmor and currentarmor.itemType or 'none'
		return buyTool({itemType = currentarmor}, armors, currencytable)
	end

	local function buyAxe(currencytable, shop)
		if not shop then return end
		return buyTool(store.tools.wood or {itemType = 'none'}, axes, currencytable)
	end

	local function buyPickaxe(currencytable, shop)
		if not shop then return end
		return buyTool(store.tools.stone, pickaxes, currencytable)
	end

	local function applyBuy()
		Functions[1] = Buy:Has('Sword') and buySword or nil
		Functions[2] = Buy:Has('Armour') and buyArmor or nil
		Functions[4] = Buy:Has('Axe') and buyAxe or nil
		Functions[5] = Buy:Has('Pickaxe') and buyPickaxe or nil
		refreshBowPurchase()
	end

	Buy = AutoBuy:CreateMultiDropdown({
		Name = 'Buy',
		List = {'Sword', 'Armour', 'Bow', 'Crossbow', 'Arrows', 'Axe', 'Pickaxe'},
		Default = {'Armour'},
		Function = function()
			npctick = tick()
			applyBuy()
		end,
		Tooltip = 'What it buys'
	})
	ArrowAmount = AutoBuy:CreateSlider({
		Name = 'Arrow amount',
		Min = 8,
		Max = 256,
		Default = 32,
		Darker = true,
		Visible = function() return Buy:Has('Arrows') end,
		Tooltip = 'How many arrows to keep'
	})
	applyBuy()
	BedwarsCheck = AutoBuy:CreateToggle({
		Name = 'Only Bedwars',
		Function = function()
			if AutoBuy.Enabled then
				AutoBuy:Toggle()
				AutoBuy:Toggle()
			end
		end,
		Default = true
	})
	GUI = AutoBuy:CreateToggle({Name = 'GUI check'})
	SmartCheck = AutoBuy:CreateToggle({
		Name = 'Smart check',
		Default = true,
		Tooltip = 'Buys iron armour before iron axe'
	})
	AutoBuy:CreateTextList({
		Name = 'Item',
		Placeholder = 'priority/item/amount/after',
		Function = function(list)
			table.clear(Custom)
			table.clear(CustomPost)
			for _, entry in list do
				local tab = entry:split('/')
				local ind = tonumber(tab[1])
				if ind then
					(tab[4] and CustomPost or Custom)[ind] = function(currencytable, shop)
						if not shop then return end

						local v = util.Shop.Item(tab[2])
						if v then
							local item = getItem(tab[2] == 'wool_white' and bedwars.Shop.getTeamWool(lplr:GetAttribute('Team')) or tab[2])
							item = (item and tonumber(tab[3]) - item.amount or tonumber(tab[3])) // v.amount
							if item > 0 and not util.Shop.Pending(v.itemType) and canBuy(v, currencytable, item) then
								for _ = 1, item do
									buyItem(v, currencytable)
								end
								return true
							end
						end
					end
				end
			end
		end
	})
end)
