run(function()

	local util = vape.Libraries.bedwarsutil
	local AutoBee
	local Collect
	local CollectRange
	local CollectDelay
	local Switch
	local LimitCollect
	local Deposit
	local DepositRange
	local DepositDelay

	AutoBee = kits:CreateModule({
		Name = 'AutoBeekeeper',
		Function = function(callback)
			if callback then
				local hives = collection('beehive', AutoBee)

				repeat
					if entitylib.isAlive then
						local localPosition = entitylib.character.RootPart.Position

						if Collect.Enabled and (not LimitCollect.Enabled or store.hand.tool and store.hand.tool.Name == 'bee_net') then
							for _, v in collectionService:GetTagged('bee') do
								local root = v.PrimaryPart or v:FindFirstChild('Root')
								if root and (localPosition - root.Position).Magnitude <= CollectRange.Value then
									local net = Switch.Enabled and getItem('bee_net')
									if net then
										switchItem(net.tool)
									end
									bedwars.Handler:Get('PickUpBee'):Fire('SendToServer', {
										beeId = v:GetAttribute('BeeId')
									})

									if CollectDelay.Value > 0 then
										task.wait(CollectDelay.Value)
									end
								end
							end
						end

						if Deposit.Enabled and getItem('bee') then
							for _, v in hives do
								if not getItem('bee') then
									break
								end

								local prompt = v:FindFirstChildWhichIsA('ProximityPrompt')
								if prompt and (v:GetAttribute('Level') or 0) < 10 and v:GetAttribute('PlacedByUserId') == lplr.UserId and (localPosition - v.Position).Magnitude <= DepositRange.Value then
									task.spawn(fireproximityprompt, prompt)

									if DepositDelay.Value > 0 then
										task.wait(DepositDelay.Value)
									end
								end
							end
						end
					end
					task.wait(0.1)
				until not AutoBee.Enabled
			end
		end,
		Tooltip = 'Collects nearby bees and deposits them'
	})
	Collect = AutoBee:CreateGroup({
		Name = 'Collect bees',
		Default = true,
		Function = function(call)
			if CollectRange then
			end
		end
	})
	CollectRange = Collect:CreateSlider({
		Name = 'Collect Range',
		Min = 1,
		Max = 22,
		Default = 20,
		Darker = true,
		Suffix = util.Studs
	})
	CollectDelay = Collect:CreateSlider({
		Name = 'Collect delay',
		Min = 0,
		Max = 2,
		Default = 0.1,
		Decimal = 100,
		Darker = true
	})
	Switch = Collect:CreateToggle({
		Name = 'Auto Switch',
		Default = true,
		Darker = true,
		Tooltip = 'Puts the bee net in your hand before catching, the server ignores a catch without it'
	})
	LimitCollect = Collect:CreateToggle({
		Name = 'Limit to item',
		Darker = true
	})
	Deposit = AutoBee:CreateGroup({
		Name = 'Deposit bees',
		Function = function(call)
			if DepositRange then
			end
		end,
		Tooltip = 'Automatically puts the bees into a beehive'
	})
	DepositRange = Deposit:CreateSlider({
		Name = 'Deposit Range',
		Min = 1,
		Max = 14,
		Default = 14,
		Darker = true,
		Suffix = util.Studs
	})
	DepositDelay = Deposit:CreateSlider({
		Name = 'Deposit Delay',
		Min = 0,
		Max = 2,
		Default = 0.1,
		Decimal = 100,
		Darker = true
	})
end)
