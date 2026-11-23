run(function()
	local util = vape.Libraries.bedwarsutil

	local AutoUpgrade

	local SETTLE_TIME = 2

	local catalog = {}
	local toggles = {}
	local pending = {}
	local lastMatchState, lastTeam

	local function liveMeta()
		local module = bedwars.TeamUpgradeUtil
		if type(module) == 'table' and type(module.getTeamUpgradeMetaForQueue) == 'function' then
			local ok, meta = pcall(module.getTeamUpgradeMetaForQueue, store.queueType)
			if ok and type(meta) == 'table' and next(meta) ~= nil then return meta end
		end
		local meta = bedwars.TeamUpgradeMeta
		return type(meta) == 'table' and meta or {}
	end

	local function labelOf(upgrade)
		return upgrade.Name == 'Armor' and 'Protection' or upgrade.Name
	end

	local function liveOffers()
		if not util.Shop.UpgradeScreenOpen() then return nil end
		local app = lplr.PlayerGui:FindFirstChild(util.Shop.UpgradeApp, true)
		if not app then return nil end

		local known, offers, count = {}, {}, 0
		for _, upgrade in catalog do
			known[upgrade.Id] = true
		end
		for _, object in app:GetDescendants() do
			local id = tostring(object.Name):match('^(.+)_ShopItemCard$')
			if id and known[id] and not offers[id] then
				offers[id] = true
				count += 1
			end
		end
		return count > 0 and offers or nil
	end

	local function createToggle(upgrade)
		if toggles[upgrade.Id] then return toggles[upgrade.Id] end
		toggles[upgrade.Id] = AutoUpgrade:CreateToggle({
			Name = 'Buy '..labelOf(upgrade),
			Default = upgrade.Id == 'ARMOR' or upgrade.Id == 'DAMAGE',
			Darker = true,
			Tooltip = 'Buys this upgrade first when you can afford it'
		})
		return toggles[upgrade.Id]
	end

	local function refreshCatalog()
		local list = {}
		for id, upgrade in liveMeta() do
			if type(upgrade) == 'table' and type(upgrade.tiers) == 'table' and #upgrade.tiers > 0 then
				local entry = {
					Id = id,
					Name = tostring(upgrade.name or id),
					Order = tonumber(upgrade.order) or 0,
					Tiers = upgrade.tiers,
					DisabledInQueue = upgrade.disabledInQueue
				}
				table.insert(list, entry)
				createToggle(entry)
			end
		end
		table.sort(list, function(a, b)
			if a.Order ~= b.Order then return a.Order < b.Order end
			return a.Id < b.Id
		end)
		catalog = list
		return list
	end

	local function resetForMatch()
		local team = lplr:GetAttribute('Team')
		if store.matchState ~= lastMatchState or team ~= lastTeam then
			lastMatchState, lastTeam = store.matchState, team
			table.clear(pending)
		end
	end

	local function buyTier(upgrade, tierIndex, diamonds)
		local tier = upgrade.Tiers[tierIndex]
		if type(tier) ~= 'table' then return false end
		if tier.availableOnlyInQueue and not table.find(tier.availableOnlyInQueue, store.queueType) then return false end

		local cost = tonumber(tier.cost) or 0
		if diamonds < cost then return false end

		bedwars.Handler:Get('RequestPurchaseTeamUpgrade'):Fire('CallServerAsync', upgrade.Id):andThen(function(suc)
			if suc then
				util.Utils.Notify('AutoUpgrade', 'Bought '..labelOf(upgrade)..' '..tierIndex, 3)
			end
		end)
		return true, cost
	end

	local function upgradePass()
		local offers = liveOffers()
		local diamondCount = util.Inventory.Amount('diamond')
		local now = tick()
		local currentTiers = util.Shop.TeamUpgrades()

		for _, upgrade in catalog do
			local toggle = toggles[upgrade.Id]
			if toggle and toggle.Enabled then
				local blocked = upgrade.DisabledInQueue and table.find(upgrade.DisabledInQueue, store.queueType or '')
				if not blocked and (not offers or offers[upgrade.Id]) then
					local tier = (currentTiers[upgrade.Id] or 0) + 1
					if tier <= #upgrade.Tiers then
						local waiting = pending[upgrade.Id]
						local settled = not waiting or waiting.Tier ~= tier or (now - waiting.At) >= SETTLE_TIME
						if settled then
							pending[upgrade.Id] = nil
							local bought, cost = buyTier(upgrade, tier, diamondCount)
							if bought then
								diamondCount -= cost
								pending[upgrade.Id] = {Tier = tier, At = tick()}
							end
						end
					end
				end
			end
		end
	end

	AutoUpgrade = vape.Categories.Inventory:CreateModule({
		Name = 'AutoUpgrade',
		Function = function(callback)
			if not callback then return end

			if not util.Queue.Await(AutoUpgrade) then return end

			local nextPass = 0
			repeat
				if util.Utils.Alive() and store.shopLoaded and store.matchState ~= 2 and nextPass <= tick() then
					resetForMatch()
					refreshCatalog()
					if util.Shop.Nearby('upgrade') then
						upgradePass()
						nextPass = tick() + 0.4
					end
				end
				task.wait(util.PollInterval)
			until not AutoUpgrade.Enabled
		end,
		Tooltip = 'Buys the chosen team upgrades at the upgrade shop'
	})

	refreshCatalog()
end)
