run(function()
	local Main = vape.Libraries.mergedModule(kits, {
		Name = 'HarvestAura',
		Category = 'Auto',
		Tooltip = 'Harvests ripe crops and collects what your farm drops'
	})

run(function()

	local util = vape.Libraries.bedwarsutil
	local AutoFarmer
	local Range
	local Switch
	local Delay
	local nextHarvest = 0

	AutoFarmer = Main:Part({
		Label = 'Harvest crops',
		Name = 'AutoFarmer',
		Function = function(callback)
			if callback then
				nextHarvest = 0

				repeat
					if entitylib.isAlive and store.equippedKit == 'farmer_cletus' and tick() >= nextHarvest then
						local origin = entitylib.character.RootPart.Position
						for _, v in collectionService:GetTagged('HarvestableCrop') do
							if v:IsA('BasePart') and (v.Position - origin).Magnitude <= Range.Value then
								nextHarvest = tick() + Delay.Value
								bedwars.breakBlock(v, true, true, nil, Switch.Enabled)
								break
							end
						end
					end
					task.wait(0.1)
				until not AutoFarmer.Enabled
			end
		end,
		Tooltip = 'Harvests your crops when they are ripe'
	})
	Range = AutoFarmer:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 25,
		Suffix = util.Studs
	})
	Delay = AutoFarmer:CreateSlider({
		Name = 'Delay',
		Min = 0.1,
		Max = 3,
		Default = 0.3,
		Decimal = 10,
		Suffix = util.Seconds
	})
	Switch = AutoFarmer:CreateToggle({
		Name = 'Auto Switch',
		Default = true,
		Tooltip = 'Swaps to the right tool before harvesting'
	})
end)

run(function()

	local util = vape.Libraries.bedwarsutil
	local AutoFarmerCletus
	local Range
	local Delay
	local nextPickup = 0

	local crops = {
		carrot = true,
		carrot_seeds = true,
		melon = true,
		melon_seeds = true,
		watermelon = true,
		pumpkin = true,
		pumpkin_block = true,
		pumpkin_seeds = true
	}

	local Pickup = bedwars.Handler:Get('PickupItemDrop')

	AutoFarmerCletus = Main:Part({
		Label = 'Collect drops',
		Name = 'AutoFarmerCletus',
		Function = function(callback)
			if callback then
				nextPickup = 0

				repeat
					if entitylib.isAlive and store.equippedKit == 'farmer_cletus' and tick() >= nextPickup then
						local origin = entitylib.character.RootPart.Position
						for _, v in collectionService:GetTagged('ItemDrop') do
							if crops[v.Name] and (v:GetAttribute('PickupReadyTime') or math.huge) < workspace:GetServerTimeNow() and (v.Position - origin).Magnitude <= Range.Value then
								nextPickup = tick() + Delay.Value
								Pickup:Fire('CallServerAsync', {itemDrop = v})
								break
							end
						end
					end
					task.wait(0.1)
				until not AutoFarmerCletus.Enabled
			end
		end,
		Tooltip = 'Collects the crops and seeds your farm drops'
	})
	Range = AutoFarmerCletus:CreateSlider({
		Name = 'Collect Range',
		Min = 1,
		Max = 60,
		Default = 25,
		Suffix = util.Studs
	})
	AutoFarmerCletus:CreateButton({
		Name = 'Sync to legit range',
		Function = function()
			Range:SetValue(6)
		end
	})
	Delay = AutoFarmerCletus:CreateSlider({
		Name = 'Collect delay',
		Min = 0.05,
		Max = 2,
		Default = 0.15,
		Decimal = 100,
		Suffix = util.Seconds
	})
end)

end)
