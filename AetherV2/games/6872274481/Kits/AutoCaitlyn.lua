run(function()
	local Entity = entitylib
	local LocalPlayer = lplr
	local ReplicatedStorage = replicatedStorage
	local SortList = sortlist
	local SortMethods = sortmethods
	local Store = store
	local VapeEvents = vapeEvents
	local AutoCaitlyn
	local Mode
	local TargetMode
	local Range
	local MinHP
	local TargetPriorities
	local DropContract
	local ActiveSession

	local Success, BloodAssassinUtil = pcall(function()
		return require(ReplicatedStorage.TS.games.bedwars.kit.kits["blood-assassin"]["blood-assassin-util"]).BloodAssassinUtil
	end)
	local AbandonTime: number = Success and BloodAssassinUtil.ABANDON_TIME_SEC or 60

	local function GetValidTargets(WallCheck: boolean)
		local Targets = {}
		for _, v: any in Entity.AllPosition({
			Part = "RootPart",
			Players = true,
			Range = Range.Value,
			Wallcheck = WallCheck
		}) do
			if not (v.Player.Team and v.Player.Team.Name == "Spectators") then
				Targets[v.Player] = v
				Targets[v.Character] = v
			end
		end
		return Targets
	end

	local function GetScore(Session, Contract, Targets)
		local Ent = Targets[Contract.target]
		if not Ent then
			return nil
		end

		local Health: number = Ent.Humanoid.Health
		local Distance: number = (Entity.character.RootPart.Position - Ent.RootPart.Position).Magnitude
		local Score: number = 30 + ((tonumber(Contract.rewardValue) or 0) * 35)
		Score += (1 - math.clamp(Health / math.max(Ent.Humanoid.MaxHealth, 1), 0, 1)) * 35
		Score += math.max(1 - (Distance / Range.Value), 0) * 20

		if Health <= MinHP.Value then
			Score += 20
		end
		if (Session.threats[Ent.Player] or 0) > tick() then
			Score += 30
		end
		if Ent.Character:GetAttribute("BleedSource") == LocalPlayer.UserId then
			Score += 25
		end
		local Success, Team = pcall(bedwars.TeamController.getPlayerTeam, bedwars.TeamController, Ent.Player)
		local TeamId = Success and Team and Team.id or Ent.Player:GetAttribute("Team")
		local Bed = true
		if TeamId ~= nil then
			local Cached = Session.beds[TeamId]
			if Cached and Cached[2] > tick() then
				Bed = Cached[1]
			else
				Success, Team = pcall(bedwars.BedwarsController.getTeamBed, bedwars.BedwarsController, TeamId)
				Bed = not Success or Team and Team.Parent
				Session.beds[TeamId] = {Bed, tick() + 1}
			end
		end

		if not Bed then
			Score += 20
		end

		local Reward = Contract.rewardExplanation
		if type(Reward) == "table" then
			Score += (Reward.assassin and 10 or 0) + (Reward.kitClass and 8 or 0) + (Reward.gear and 6 or 0)
		end
		return Score, Ent
	end

	local function GetPriorityContract(Session, Contracts)
		local Bounty: boolean = false
		for _, v: any in Contracts do
			if v.rewardValue or v.rewardUpgrade then
				Bounty = true
				break
			end
		end
		if not Bounty then
			return nil, false
		end

		local Targets = GetValidTargets(true)
		local Current, CurrentScore
		if Session.priorityId then
			for _, v: any in Contracts do
				if v.id == Session.priorityId then
					Current, CurrentScore = v, GetScore(Session, v, Targets)
					break
				end
			end
		end

		local Best, BestScore
		for _, v: any in Contracts do
			local Score: number? = GetScore(Session, v, Targets)
			if Score and (not BestScore or Score > BestScore) then
				Best, BestScore = v, Score
			end
		end

		if Current and CurrentScore and Best ~= Current and BestScore < CurrentScore + 15 then
			Best = Current
		end

		Session.priorityId = Best and Best.id or nil
		return Best, true
	end

	local function GetNormalContract(Session, Contracts)
		local Offered: {[string]: any} = {}
		for _, v: any in Contracts do
			if v.target then
				Offered[v.target.Name] = v
			end
		end

		for _, v: any in Entity.AllPosition({
			Part = "RootPart",
			Players = true,
			Range = Range.Value,
			Sort = SortMethods[TargetMode.Value]
		}) do
			local Contract = Offered[v.Player.Name]
			if Contract and (Session.hits[v.Character] or 0) > tick() and not (v.Player.Team and v.Player.Team.Name == "Spectators") then
				if Mode.Value ~= "On Low" or v.Humanoid.Health < MinHP.Value then
					return Contract
				end
			end
		end
		return nil
	end

	local function CanDrop(Contract): boolean
		local Activation: number? = tonumber(Contract.activationTime)
		if not Activation or (workspace:GetServerTimeNow() - Activation) < AbandonTime then
			return false
		end

		local Ent = Contract.target and Entity.getEntity(Contract.target)
		if not Ent or Ent.Health <= 0 then
			return true
		end
		return (Ent.RootPart.Position - Entity.character.RootPart.Position).Magnitude > Range.Value
	end

	local function UpdateCaitlyn(Session)
		if not Entity.isAlive or Store.matchState ~= 1 or Store.equippedKit ~= "blood_assassin" then
			table.clear(Session.hits)
			Session.pendingId = nil
			Session.priorityId = nil
			return
		end

		local Kit = bedwars.Store:getState().Kit
		local Active = Kit and Kit.activeContract
		if not Kit or Active then
			Session.pendingId = nil
			Session.priorityId = Active and Active.id or nil
			if Active and DropContract.Enabled and Session.dropUntil <= tick() and CanDrop(Active) then
				bedwars.Handler:Get("BloodAssassinSelectContract"):Fire("SendToServer", {
					contractId = nil
				})
				Session.dropUntil = tick() + 5
			end
			return
		end

		if Session.pendingId and Session.pendingUntil > tick() then
			return
		end
		Session.pendingId = nil

		local Contracts = Kit.availableContracts
		if not Contracts or #Contracts == 0 then
			return
		end

		local Contract
		if TargetPriorities.Enabled then
			local Available
			Contract, Available = GetPriorityContract(Session, Contracts)
			if not Available then
				Contract = GetNormalContract(Session, Contracts)
			end
		else
			Session.priorityId = nil
			Contract = GetNormalContract(Session, Contracts)
		end
		if Contract and not (Session.pendingId == Contract.id and Session.pendingUntil > tick()) then
			bedwars.Handler:Get("BloodAssassinSelectContract"):Fire("SendToServer", {
				contractId = Contract.id
			})
			Session.pendingId = Contract.id
			Session.pendingUntil = tick() + 1
		end
	end

	AutoCaitlyn = kits:CreateModule({
		Name = "AutoCaitlyn",
		Function = function(Callback: boolean)
			if Callback then
				local Session = {
					beds = {},
					dropUntil = 0,
					hits = setmetatable({}, {__mode = "k"}),
					nextUpdate = 0,
					pendingUntil = 0,
					threats = {}
				}
				ActiveSession = Session

				AutoCaitlyn:Clean(VapeEvents.EntityDamageEvent.Event:Connect(function(DamageTable)
					if ActiveSession ~= Session then
						return
					end

					local Source = (typeof(DamageTable.fromEntity) == "Instance" and Entity.getEntity(DamageTable.fromEntity) or nil)
					if DamageTable.entityInstance == LocalPlayer.Character and Source and Source.Player then
						Session.threats[Source.Player] = tick() + 3
					elseif DamageTable.fromEntity == LocalPlayer.Character or DamageTable.fromEntity == LocalPlayer then
						local Victim = (typeof(DamageTable.entityInstance) == "Instance" and Entity.getEntity(DamageTable.entityInstance) or nil)
						if Victim and Victim.Character then
							Session.hits[Victim.Character] = tick() + 1
						end
					end
				end))

				AutoCaitlyn:Clean(VapeEvents.BedwarsBedBreak.Event:Connect(function()
					table.clear(Session.beds)
				end))

				AutoCaitlyn:Clean(Entity.Events.LocalAdded:Connect(function()
					table.clear(Session.hits)
					Session.pendingId = nil
				end))

				AutoCaitlyn:Clean(Entity.Events.LocalRemoved:Connect(function()
					table.clear(Session.hits)
					Session.pendingId = nil
					Session.priorityId = nil
				end))

				repeat
					if tick() >= Session.nextUpdate then
						Session.nextUpdate = tick() + 0.2
						UpdateCaitlyn(Session)
					end
					task.wait(0.05)
				until not AutoCaitlyn.Enabled or ActiveSession ~= Session

				if ActiveSession == Session then
					ActiveSession = nil
				end
			else
				ActiveSession = nil
			end
		end,
		Tooltip = 'Assigns a contract when the chosen action happens'
	})

	Mode = AutoCaitlyn:CreateDropdown({
		Name = "Contract mode",
		List = {"On Hit", "On Low"},
		Function = function(Val: string)
			if MinHP then
				MinHP.Object.Visible = Val == "On Low"
			end
		end,
		Default = "On Low",
		Tooltip = 'When to give a contract: on hit or when the target is low'
	})
	MinHP = AutoCaitlyn:CreateSlider({
		Name = "Minimum Health",
		Tooltip = "How low they have to be before contracting",
		Min = 1,
		Max = 100,
		Default = 30,
		Darker = true,
		Visible = false
	})
	local Methods: {string} = {"Damage", "Distance"}
	for _, v: string in SortList do
		if not table.find(Methods, v) then
			table.insert(Methods, v)
		end
	end
	TargetMode = AutoCaitlyn:CreateDropdown({
		Name = "Target Mode",
		List = Methods,
		Default = "Distance",
		Tooltip = 'Who to prefer when several targets are in range'
	})
	Range = AutoCaitlyn:CreateSlider({
		Name = "Range",
		Min = 1,
		Max = 50,
		Default = 50,
		Suffix = function(Val: number)
			return Val <= 1 and "stud" or "studs"
		end
	})
	TargetPriorities = AutoCaitlyn:CreateToggle({
		Name = "Target Priorities",
		Function = function()
			if ActiveSession then
				ActiveSession.priorityId = nil
			end
		end,
		Tooltip = 'Takes the best contract in range straight away'
	})
	DropContract = AutoCaitlyn:CreateToggle({
		Name = "Drop Contract",
		Tooltip = 'Drops old contracts so you can take a new one'
	})
end)
