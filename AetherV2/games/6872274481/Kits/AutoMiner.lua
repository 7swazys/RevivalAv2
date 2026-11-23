run(function()
	local AutoMiner
	local Range, Delay, Animation, Legit

	local LEGIT_RANGE = getFunctionRange(bedwars.MinerController and bedwars.MinerController.setupMinerPrompts) or 8

	local function petrifiedRoot(part)
		if not part or not part.Parent then return nil end
		local root = part:IsA('Model') and part.PrimaryPart or part
		if not root then return nil end
		return root
	end

	local function promptFor(part)
		local prompt
		if part:IsA('Model') then
			prompt = part:FindFirstChildWhichIsA('ProximityPrompt', true)
		else
			prompt = part:FindFirstChildWhichIsA('ProximityPrompt')
		end
		return prompt
	end

	local function holdPrompt(part, prompt)
		pcall(function()
			prompt:InputHoldBegin()
		end)
		local deadline = os.clock() + math.max(tonumber(prompt.HoldDuration) or 0.5, 0.2) + 1
		repeat
			task.wait(0.05)
		until not prompt.Parent or not part.Parent or os.clock() >= deadline
		pcall(function()
			if prompt.Parent then
				prompt:InputHoldEnd()
			end
		end)
	end

	AutoMiner = kits:CreateModule({
		Name = 'AutoMiner',
		Category = 'Auto',
		Function = function(callback)
			if not callback then return end
			local petrified = collection('petrified-player', AutoMiner)
			local cooldown = 0

			repeat
				if entitylib.isAlive and store.equippedKit == 'miner' and tick() - cooldown >= math.max(Delay.Value, 0.25) then
					local localPosition = entitylib.character.RootPart.Position
					for _, v in petrified do
						local root = petrifiedRoot(v)
						if root and (localPosition - root.Position).Magnitude <= Range.Value then
							if Legit.Enabled then
								local prompt = promptFor(v)
								if prompt and prompt.Enabled then
									holdPrompt(v, prompt)
									cooldown = tick()
									break
								end
							else
								local petrifyId = v:GetAttribute('PetrifyId')
								if petrifyId then
									if Animation.Enabled then
										bedwars.GameAnimationUtil:playAnimation(lplr.Character, bedwars.AnimationType.MINER_MINE_STONE)
									end

									task.delay(Delay.Value, function()
										if AutoMiner.Enabled and v.Parent then
											bedwars.Handler:Get('DestroyPetrifiedPlayer'):Fire('SendToServer', {
												petrifyId = petrifyId
											})
										end
									end)
									cooldown = tick()
									break
								end
							end
						end
					end
				end
				task.wait(0.1)
			until not AutoMiner.Enabled
		end,
		Tooltip = 'Mines petrified players in range'
	})

	Range = AutoMiner:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 30,
		Default = 12,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	AutoMiner:CreateButton({
		Name = 'Sync to legit range',
		Function = function()
			Range:SetValue(LEGIT_RANGE)
		end,
		Tooltip = 'Limits the range to what the game allows'
	})
	Legit = AutoMiner:CreateToggle({
		Name = 'Legit',
		Tooltip = 'Mines by holding the prompt like a player would'
	})
	Delay = AutoMiner:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 2,
		Default = 0.1,
		Decimal = 10,
		Suffix = 'seconds'
	})
	Animation = AutoMiner:CreateToggle({
		Name = 'Animation',
		Default = true,
		Tooltip = 'Plays the mining swing'
	})
end)
