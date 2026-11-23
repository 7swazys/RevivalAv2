run(function()

	local util = vape.Libraries.bedwarsutil
	local AutoEnchant
	local Wanted
	local Repair
	local Legit
	local Range
	local Delay

	local Research = bedwars.Handler:Get('ResearchEnchant')
	local Fix = bedwars.Handler:Get('RepairEnchantTable')
	local learned

	local function findRepairPrompt(table)
		local part = table:IsA('Model') and (table.PrimaryPart or table:FindFirstChildWhichIsA('BasePart')) or table
		local prompt = part and part:FindFirstChildWhichIsA('ProximityPrompt')
		if not prompt and table:IsA('Model') then
			prompt = table:FindFirstChildWhichIsA('ProximityPrompt', true)
		end
		return prompt, part
	end

	local function legitRepair(table, localPosition)
		local prompt, part = findRepairPrompt(table)
		if not prompt or not prompt.Enabled then return false end
		if part and (localPosition - part.Position).Magnitude > (prompt.MaxActivationDistance or 10) then return false end
		local hold = tonumber(prompt.HoldDuration) or 0
		prompt:InputHoldBegin()
		task.wait(hold + 0.05)
		prompt:InputHoldEnd()
		task.wait(0.1)
		return true
	end

	AutoEnchant = vape.Categories.Utility:CreateModule({
		Name = 'AutoEnchant',
		Function = function(callback)
			if callback then
				learned = nil

				repeat
					if entitylib.isAlive and entitylib.character and entitylib.character.RootPart and not table.find(Wanted.ListEnabled, learned) then
						local localPosition = entitylib.character.RootPart.Position
						local emeralds = getItem('emerald')
						local diamonds = getItem('diamond')

						for _, v in store.enchant do
							local part = v:IsA('Model') and v.PrimaryPart or v
							if not part or not part.Position then continue end
							if (localPosition - part.Position).Magnitude > Range.Value then continue end

							if v:HasTag('broken-enchant-table') then
								if Repair.Enabled and diamonds and diamonds.amount >= 8 then
									if Legit.Enabled then
										if legitRepair(v, localPosition) then break end
									else
										Fix:Fire('CallServer', v)
										break
									end
								end
							elseif emeralds and emeralds.amount >= 2 then
								local enchant = Research:Fire('CallServer', {enchantTable = v})
								learned = typeof(enchant) == 'table' and enchant.enchantType or learned
								if learned then
									local meta = bedwars.EnchantMeta and bedwars.EnchantMeta[learned]
									notif('AutoEnchant', 'Researched '..tostring(meta and (meta.name or meta.displayName) or learned), 3)
								end
								break
							end
						end
					end
					task.wait(Delay.Value)
				until not AutoEnchant.Enabled
			end
		end,
		Tooltip = 'Rerolls the enchant table until you get a chosen enchant'
	})

	Range = AutoEnchant:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 30,
		Default = 12,
		Suffix = util.Studs
	})
	Delay = AutoEnchant:CreateSlider({
		Name = 'Delay',
		Min = 0.1,
		Max = 3,
		Default = 0.5,
		Decimal = 10,
		Suffix = 'seconds',
		Tooltip = 'Time between rerolls'
	})
	Repair = AutoEnchant:CreateGroup({
		Name = 'Repair tables',
		Default = true,
		Tooltip = 'Repairs a broken enchant table before rerolling'
	})
	Legit = Repair:CreateToggle({
		Name = 'Legit mode',
		Darker = true,
		Tooltip = 'Repairs by holding the prompt like a player would'
	})
	local enchantList = {}
	for id in bedwars.EnchantMeta or {} do
		if type(id) == 'string' then
			table.insert(enchantList, id)
		end
	end
	table.sort(enchantList)
	for _, id in {'critical_strike', 'execute', 'soul_reaver'} do
		if not table.find(enchantList, id) then
			table.insert(enchantList, id)
		end
	end
	Wanted = AutoEnchant:CreateMultiDropdown({
		Name = 'Enchants',
		List = enchantList,
		Default = {'critical_strike', 'execute', 'soul_reaver'},
		Darker = true,
		Tooltip = 'Stops rerolling once one of these is researched'
	})
end)
