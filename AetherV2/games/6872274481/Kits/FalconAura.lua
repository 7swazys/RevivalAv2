run(function()

	local util = vape.Libraries.bedwarsutil
	local FalconAura
	local Range
	local Delay
	local Recall
	local RecallDelay
	local nextSend, nextRecall = 0, 0

	FalconAura = kits:CreateModule({
		Name = 'FalconAura',
		Category = 'Aim',
		Function = function(callback)
			if callback then
				nextSend, nextRecall = 0, 0
				repeat
					if entitylib.isAlive and util.IsKit('falconer') then
						local target = entitylib.EntityPosition({
							Origin = entitylib.character.RootPart.Position,
							Range = Range.Value,
							Part = 'RootPart',
							Players = true,
							Wallcheck = true
						})

						if target and tick() >= nextSend and util.Ability.Ready('SEND_FALCON') then
							nextSend = tick() + Delay.Value
							util.Ability.Use('SEND_FALCON')
						elseif not target and Recall.Enabled and tick() >= nextRecall and util.Ability.Ready('RECALL_FALCON') then
							nextRecall = tick() + RecallDelay.Value
							util.Ability.Use('RECALL_FALCON')
						end
					end
					task.wait(0.1)
				until not FalconAura.Enabled
			end
		end,
		Tooltip = 'Sends the falcon at nearby enemies and calls it back after'
	})
	Range = FalconAura:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 150,
		Default = 80,
		Suffix = util.Studs
	})
	Delay = FalconAura:CreateSlider({
		Name = 'Delay',
		Min = 0.1,
		Max = 5,
		Default = 1,
		Decimal = 10,
		Suffix = util.Seconds
	})
	Recall = FalconAura:CreateGroup({
		Name = 'Recall when clear',
		Default = true,
		Tooltip = 'Calls the falcon back once nobody is in range',
	})
	RecallDelay = Recall:CreateSlider({
		Name = 'Recall delay',
		Min = 0.1,
		Max = 5,
		Default = 1,
		Decimal = 10,
		Darker = true,
		Suffix = util.Seconds
	})
end)
