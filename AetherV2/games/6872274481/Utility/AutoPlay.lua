run(function()
	local AutoPlay
	local RandomMode

	local function joinQueue()
		local ok, state = pcall(function()
			return bedwars.Store:getState()
		end)
		if not ok or type(state) ~= 'table' then return end
		local match, party = state.Game, state.Party
		if type(party) ~= 'table' or (type(match) == 'table' and match.customMatch) then return end
		if not (party.leader and party.leader.userId == lplr.UserId) or party.queueState ~= 0 then return end

		if RandomMode.Enabled then
			local listofmodes = {}
			for i, v in bedwars.QueueMeta do
				if not v.disabled and not v.voiceChatOnly and not v.rankCategory then
					table.insert(listofmodes, i)
				end
			end
			if #listofmodes > 0 then
				bedwars.QueueController:joinQueue(listofmodes[math.random(1, #listofmodes)])
				return
			end
		end
		if store.queueType then
			bedwars.QueueController:joinQueue(store.queueType)
		end
	end

	AutoPlay = vape.Categories.Utility:CreateModule({
		Name = 'AutoPlay',
		Function = function(callback)
			if callback then
				AutoPlay:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(deathTable)
					if deathTable.finalKill and deathTable.entityInstance == lplr.Character and #bedwars.Store:getState().Party.members <= 0 and store.matchState ~= 2 then
						joinQueue()
					end
				end))
				AutoPlay:Clean(vapeEvents.MatchEndEvent.Event:Connect(joinQueue))
			end
		end,
		Tooltip = 'Queues for the next match when one ends'
	})
	RandomMode = AutoPlay:CreateToggle({
		Name = 'Random',
		Tooltip = 'Chooses a random mode'
	})
end)
