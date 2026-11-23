run(function()
	local util = vape.Libraries.bedwarsutil

	local AutoTaliyah
	local Emerald
	local Diamond
	local Iron
	local Amount

	local function getShopId()
		return util.Shop.Id('item')
	end

	AutoTaliyah = kits:CreateModule({
		Name = 'AutoTaliyah',
		Function = function(callback)
			if callback then
				local item

				repeat
					item = item or util.Shop.Item('chicken_shop_item')
					local id = item and getShopId()
					if id then
						local chickenData = bedwars.TaliyahUtil:getPrice()
						if (chickenData.currency == 'emerald' and Emerald.Enabled or chickenData.currency == 'iron' and Iron.Enabled or chickenData.currency == 'diamond' and Diamond.Enabled) and chickenData.price >= Amount.Value then
							util.Shop.Purchase(item, id)
						end
					end
					task.wait(0.1)
				until not AutoTaliyah.Enabled
			end
		end,
		Tooltip = 'Buys chickens when they sell for emeralds'
	})
	local Currencies
	Currencies = AutoTaliyah:CreateMultiDropdown({
		Name = 'Currencies',
		List = {'Iron', 'Emerald', 'Diamond'},
		Default = {'Iron', 'Emerald', 'Diamond'},
		Tooltip = 'Sells your chicken when it sells for one of these'
	})
	Iron = setmetatable({}, {__index = function(_, key) if key == 'Enabled' then return Currencies:Has('Iron') end end})
	Emerald = setmetatable({}, {__index = function(_, key) if key == 'Enabled' then return Currencies:Has('Emerald') end end})
	Diamond = setmetatable({}, {__index = function(_, key) if key == 'Enabled' then return Currencies:Has('Diamond') end end})
	Amount = AutoTaliyah:CreateSlider({
		Name = 'Amount',
		Min = 1,
		Max = 1000,
		Default = 2,
		Tooltip = 'Only sells at the selected price'
	})
end)
