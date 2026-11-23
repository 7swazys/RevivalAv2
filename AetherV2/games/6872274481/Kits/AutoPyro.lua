run(function()
	local AutoPyro
	local Delay

	local list = {'Range', 'Heat', 'Power'}

	AutoPyro = kits:CreateModule({
		Name = 'AutoPyro',
		Function = function(callback)
			if callback then
				repeat
					local flamethrower = getItem('flamethrower')
					if flamethrower then
						for _, v in list do
							local upgrade = v:lower()
							local value = flamethrower.tool:GetAttribute(upgrade) or -1
							local nextUpgrade = AutoPyro.Options.Buy:Has(v) and value < 3 and bedwars.PyroUpgradeMeta[upgrade].tiers[value + 2]

							if nextUpgrade then
								local currency = getItem(nextUpgrade.currency)
								if currency and currency.amount >= nextUpgrade.price then
									bedwars.Handler:Get('UpgradeFlamethrower'):Fire('CallServer', upgrade)
									task.wait(Delay.Value)
								end
							end
						end
					end
					task.wait(0.1)
				until not AutoPyro.Enabled
			end
		end,
		Tooltip = 'Upgrades your flamethrower'
	})
	Delay = AutoPyro:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 2,
		Default = 0.1,
		Decimal = 100,
		Suffix = 'seconds',
		Tooltip = 'Wait between each upgrade it buys'
	})
	AutoPyro:CreateMultiDropdown({
		Name = 'Buy',
		List = table.clone(list),
		Default = table.clone(list),
		Tooltip = 'Flamethrower upgrades it buys'
	})
end)
