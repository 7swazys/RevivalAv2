run(function()

	local util = vape.Libraries.bedwarsutil
	local AutoLani
	local Delay
	local UseEnemy
	local Enemy
	local Player

	local Request = bedwars.Handler:Get('PaladinAbilityRequest')

	AutoLani = kits:CreateModule({
		Name = 'AutoLani',
		Function = function(call)
			if call then
				local oldstart

				repeat
					local start = lplr:GetAttribute('PaladinStartTime')
					if oldstart and oldstart ~= start then
						local player = UseEnemy.Enabled and playersService:FindFirstChild(Enemy.Value) or not UseEnemy.Enabled and playersService:FindFirstChild(Player.Value) or nil

						if player then
							task.delay(Delay.Value, function()
								Request:Fire('SendToServer', {target = player})
							end)
						end
					end
					oldstart = start
					task.wait(0.1)
				until not AutoLani.Enabled
			end
		end,
		Tooltip = 'Uses the scepter of light ability'
	})
	local friends, enemies = {'None'}, {'None'}

	local function addConnection(plr, connected)
		local friendly = plr:GetAttribute('Team') == lplr:GetAttribute('Team')

		if not connected then
			vape:Clean(plr:GetAttributeChangedSignal('Team'):Connect(function()
				addConnection(plr, true)
			end))
		end

		if friendly and not table.find(friends, plr.Name) then
			table.insert(friends, plr.Name)
			Player:Change(friends)
		elseif not friendly and plr.Team and plr.Team.Name ~= 'Spectators' and not table.find(enemies, plr.Name) then
			table.insert(enemies, plr.Name)
			Enemy:Change(enemies)
		end
	end

	UseEnemy = AutoLani:CreateGroup({
		Name = 'Use enemy',
		Function = function(call)
			Player.Object.Visible = not call
		end,
		Tooltip = 'Uses the ability on enemies instead of teammates'
	})
	Player = AutoLani:CreateDropdown({
		Name = 'Selected Player',
		List = {},
		Tooltip = 'Player to use the ability on'
	})
	Enemy = UseEnemy:CreateDropdown({
		Name = 'Selected Enemy',
		List = {},
		Tooltip = 'Target to use the ability on'
	})
	Delay = AutoLani:CreateSlider({
		Name = 'Delay',
		Min = 1,
		Max = 20,
		Default = 5,
		Decimal = 10,
		Suffix = util.Seconds,
		Tooltip = 'Delay between triggers'
	})
	for _, v in playersService:GetPlayers() do
		addConnection(v)
	end
	vape:Clean(playersService.PlayerAdded:Connect(addConnection))
end)
