run(function()
	local GetItem = getItem
	local LocalPlayer = lplr
	local AutoAdetunde
	local GUI
	local Last

	local Upgrades: {string} = {}
	for Upgrade: string in bedwars.AdetundeUpgradeMeta do
		table.insert(Upgrades, Upgrade)
	end
	table.sort(Upgrades)

	local function GetBuyOrder(Tiers: {[string]: number}): {string}
		local LastUpgrade: string? = Last.Value ~= "None" and Last.Value or nil
		local Order, Waiting = {}, false
		for _, v: string in Upgrades do
			if Tiers[v] == nil or v == LastUpgrade then
				continue
			end
			table.insert(Order, v)
			if AutoAdetunde.Options.Buy:Has(v) and bedwars.AdetundeUpgradeMeta[v].tiers[Tiers[v] + 1] then
				Waiting = true
			end
		end
		if LastUpgrade and Tiers[LastUpgrade] and not Waiting then
			table.insert(Order, LastUpgrade)
		end
		return Order
	end

	AutoAdetunde = kits:CreateModule({
		Name = "AutoAdetunde",
		Function = function(Callback: boolean)
			if Callback then
				repeat
					if not GUI.Enabled or bedwars.AppController:isAppOpen("FrostyHammerApp") then
						local Tiers: {[string]: number} = bedwars.AdetundeUtil.getUpgradesFromHammer(LocalPlayer) or {}
						for _, Upgrade: string in GetBuyOrder(Tiers) do
							local Crystal = GetItem("frost_crystal")
							if not Crystal then
								break
							end

							local NextUpgrade = AutoAdetunde.Options.Buy:Has(Upgrade) and bedwars.AdetundeUpgradeMeta[Upgrade].tiers[Tiers[Upgrade] + 1]
							if NextUpgrade and Crystal.amount >= NextUpgrade.price then
								bedwars.Handler:Get("UpgradeFrostyHammer"):Fire("CallServer", Upgrade)
								task.wait(0.1)
							end
						end
					end
					task.wait(0.5)
				until not AutoAdetunde.Enabled
			end
		end,
		Tooltip = "Upgrades your frosty hammer automatically"
	})

	AutoAdetunde:CreateMultiDropdown({
		Name = "Buy",
		List = table.clone(Upgrades),
		Default = table.clone(Upgrades),
		Tooltip = "Hammer upgrades it buys"
	})

	local LastList: {string} = {"None"}
	for _, v: string in Upgrades do
		table.insert(LastList, v)
	end
	Last = AutoAdetunde:CreateDropdown({
		Name = "Last upgrade",
		List = LastList,
		Default = "None",
		Tooltip = 'Buys this upgrade last'
	})

	GUI = AutoAdetunde:CreateToggle({
		Name = "GUI Check",
		Tooltip = "Only upgrades while the frosty hammer menu is open"
	})
end)
