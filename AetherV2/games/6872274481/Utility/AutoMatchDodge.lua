run(function()
	local v2 = httpService
	local v3 = playersService
	local v4 = replicatedStorage
	local v5 = runService
	local v6 = inputService
	local v7 = tweenService
	local v8 = collectionService
	local v9 = guiService
	local v10 = game:GetService('TeleportService')
	local obj = debug
	local currentCamera = gameCamera
	local localPlayer = lplr
	local entity = entitylib
	local getfontbounds = getfontsize
	local getvapeasset = getcustomasset
	if not store.readyHold then
		store.readyHold = { Claimed = false, Held = false, Started = nil, Remote = nil }
		store.readyHold.Release = function(self)
			local target = type(self) == 'table' and self or store.readyHold
			target.Held = false
			target.Claimed = false
		end
	end
	local LocalPlayer = lplr
	local Players = playersService
	local TeleportService = v10
	local Weights = {Win = 1, Combat = 0.5, Rank = 2, Kit = 1, KitPlays = 0.2, Experience = 0.15, Streak = 0.25, FinalKills = 0.5, BedBreaks = 0.5, Level = 0.2, Device = 0.4, Recent = 0.5}
	local DefenderClass = 2
	local HoverOption = 0
	local RoleThreat = {Juggernaut = 1, Breaker = 0.8, Defender = 0.6, Cycler = 0.5, Support = 0.4}
	local KitRoles = {
		Defender = {"black_market_trader", "slime_tamer", "hannah", "fisherman", "farmer_cletus", "spirit_gardener"},
		Cycler = {"fisherman", "metal_detector", "beekeeper", "cowgirl", "farmer_cletus", "steam_engineer", "spirit_gardener", "davey", "miner"},
		Breaker = {"davey", "oil_man", "santa", "dino_tamer", "smoke", "yeti", "glacial_skater", "elk_master", "mimic", "shielder", "airbender"},
		Support = {"baker", "soul_broker", "oasis", "melody", "hatter"},
		Juggernaut = {"frost_hammer_kit", "axolotl", "summoner", "bigman", "pinata", "tinker", "blood_assassin", "miner", "aery", "nazar", "barbarian", "ice_queen", "block_kicker", "seahorse", "void_knight"}
	}
	local DeviceThreat = {PC = 1, GAMEPAD = 0.5, MOBILE = 0}
	local Ignored = {none = true, random = true, [""] = true}
	local PriorMatches = 10
	local FetchTimeout = 10
	local MaxTries = 3

	local HasAdvantage
	do
		local Profiles = {}
		local KitValue: {[string]: number} = {}
		for Role: string, List: {string} in KitRoles do
			for _, Kit: string in List do
				KitValue[Kit] = math.max(KitValue[Kit] or 0, RoleThreat[Role])
			end
		end

		for Kit: string, Meta: any in bedwars.BedwarsKitMeta or {} do
			if Meta.kitClass == DefenderClass then
				KitValue[Kit] = math.max(KitValue[Kit] or 0, RoleThreat.Defender)
			end
		end

		local TopDivision: number?

		local function GetRows(Data: any): {any}
			local Rows = {}
			for _, Match: any in Data.matchHistory or {} do
				if Match.matchCancelled then
					continue
				end

				for _, Row: any in Match.players or {} do
					if Row.playerInfo and Row.playerInfo.userId == Data.userId then
						table.insert(Rows, {Queue = Match.queueType, Outcome = Row.generic and Row.generic.matchOutcome, Kit = Row.bedwars and Row.bedwars.kit})
						break
					end
				end
			end

			return Rows
		end

		local function Fetch(Player: Player)
			local Entry = Profiles[Player]
			if not Entry then
				Entry = {Tries = 0, Retry = 0, Started = 0}
				Profiles[Player] = Entry
			end

			local Now: number = os.clock()
			if Entry.Done or (Entry.Pending and Now - Entry.Started < FetchTimeout) or (not Entry.Pending and Now < Entry.Retry) then
				return Entry
			end

			if Entry.Tries >= MaxTries then
				Entry.Done = true
				return Entry
			end

			Entry.Pending, Entry.Started, Entry.Tries = true, Now, Entry.Tries + 1
			local Try: number = Entry.Tries
			task.spawn(function()
				local Success, Data = pcall(function()
					return bedwars.Handler:Get("RequestProfileData"):Fire("CallServer", Player)
				end)

				local RankSuccess, Rank = pcall(store.rank[Player].async)
				if Entry.Tries ~= Try then
					return
				end

				Entry.Pending = false
				Entry.Retry = os.clock() + 5

				if Success and typeof(Data) == "table" and typeof(Data.queues) == "table" then
					Entry.Data, Entry.Rank, Entry.Rows, Entry.Done = Data, RankSuccess and Rank or nil, GetRows(Data), true
				end
			end)

			return Entry
		end

		local function GetRoster()
			local State = bedwars.Store:getState().Game
			local Assigned = {}
			for _, v: any in State.teams or {} do
				for Index: any, Member: any in v.members or {} do
					Assigned[tonumber(Member.userId or Index)] = tostring(v.id)
				end
			end

			local Team: number? = LocalPlayer:GetAttribute("Team") or (State.myTeam and State.myTeam.id) or Assigned[LocalPlayer.UserId]
			if not Team then
				return nil
			end

			Team = tostring(Team)

			local Allies, Opponents, Pending = {LocalPlayer}, {}, false
			for _, v: Player in Players:GetPlayers() do
				if v == LocalPlayer or v:GetAttribute("Spectator") then
					continue
				end

				local Other = v:GetAttribute("Team") or Assigned[v.UserId]
				if Other then
					table.insert(tostring(Other) == Team and Allies or Opponents, v)
				else
					Pending = true
				end
			end

			for UserId: number in Assigned do
				if UserId ~= LocalPlayer.UserId and not Players:GetPlayerByUserId(UserId) then
					Pending = true
				end
			end

			return Allies, Opponents, Pending
		end

		local function GetRecent(Rows: {any}, Queue: string): (number, number)
			local Wins, Losses = 0, 0
			for _, Row: any in Rows do
				if Row.Queue == Queue then
					Wins += Row.Outcome == "win" and 1 or 0
					Losses += Row.Outcome == "loss" and 1 or 0
				end
			end

			return Wins, Losses
		end

		local function PredictKit(Entry: any, Bans: {[string]: {string}}): (string?, number)
			local Banned: {[string]: boolean} = {}
			for _, Kits: {string} in Bans do
				for _, v: string in Kits do
					Banned[v] = true
				end
			end

			local Counts: {[string]: number} = {}
			for Kit: string, Plays: number in Entry.Data.favoriteKitData or {} do
				Counts[Kit] = Plays
			end

			for _, Row: any in Entry.Rows do
				if Row.Kit then
					Counts[Row.Kit] = (Counts[Row.Kit] or 0) + 1
				end
			end

			local Best: string?
			local BestPlays: number, Total: number = 0, 0
			for Kit: string, Plays: number in Counts do
				if Ignored[Kit] then
					continue
				end

				Total += Plays
				if not Banned[Kit] and Plays > BestPlays then
					Best, BestPlays = Kit, Plays
				end
			end

			return Best, BestPlays / (Total + PriorMatches)
		end

		local function GetKit(Player: Player, Entry: any, Context: any): (string?, number)
			local Kit: string? = Player:GetAttribute("PlayingAsKits")
			if Kit and not Ignored[Kit] then
				return Kit, 1
			end

			local UserId: string = tostring(Player.UserId)
			local Pick: any = Context.Draft.teamData.kitSelection[UserId]
			if not Pick then
				for _, Team: any in Context.Draft.enemyTeamData do
					Pick = Team.kitSelection and Team.kitSelection[UserId]
					if Pick then
						break
					end
				end
			end

			if Pick and Pick.kit and Pick.selectorOption ~= HoverOption and not Ignored[Pick.kit] then
				return Pick.kit, 1
			end

			if Context.Ranked and Entry.Data then
				return PredictKit(Entry, Context.Draft.sharedData.kitBans)
			end

			return nil, 0
		end

		local function Score(Player: Player, Entry: any, Context: any): number
			local Data = Entry.Data
			if not Data then
				return 0
			end

			if not TopDivision then
				TopDivision = 1

				for Division: any in bedwars.RankMeta do
					if type(Division) == "number" and Division > TopDivision then
						TopDivision = Division
					end
				end
			end

			local Baseline: number = Context.Baseline
			local Stats = Data.queues[Context.Queue] or {}
			local Wins, Losses = Stats.wins or 0, Stats.losses or 0
			local Rate: number = (Wins + Baseline * PriorMatches) / (Wins + Losses + PriorMatches)
			local RecentWins, RecentLosses = GetRecent(Entry.Rows, Context.Queue)
			local RecentRate: number = (RecentWins + Baseline * PriorMatches) / (RecentWins + RecentLosses + PriorMatches)
			local Matches: number = (Stats.matches or 0) + PriorMatches
			local Kit, Confidence = GetKit(Player, Entry, Context)
			local Device: string? = Player:GetAttribute("UserInputType") or Data.platform

			local Parts = {
				Win = math.log(Rate * (1 - Baseline) / ((1 - Rate) * Baseline)),
				Combat = math.log(((Stats.kills or 0) + PriorMatches) / ((Stats.deaths or 0) + PriorMatches)),
				Rank = (Entry.Rank or 0) / TopDivision,
				Kit = (KitValue[Kit] or 0) * Confidence,
				KitPlays = math.log(1 + (Data.favoriteKitData and Data.favoriteKitData[Kit] or 0)) * Confidence,
				Experience = math.log(1 + (Data.globalStats and Data.globalStats.matches or 0)),
				Streak = math.log(1 + (Stats.currentWinStreak or 0)),
				FinalKills = math.log(1 + (Stats.finalKills or 0) / Matches),
				BedBreaks = math.log(1 + (Stats.bedBreaks or 0) / Matches),
				Level = math.log(1 + (Data.level or 0)),
				Device = DeviceThreat[Device] or 0,
				Recent = math.log(RecentRate * (1 - Baseline) / ((1 - RecentRate) * Baseline))
			}

			local Total: number = 0
			for Name: string, Value: number in Parts do
				Total += Value * Weights[Name]
			end

			return Total
		end

		local function Average(List: {Player}, Entries: {[Player]: any}, Context: any): number
			local Sum: number = 0
			for _, v: Player in List do
				Sum += Score(v, Entries[v], Context)
			end

			return Sum / #List
		end

		HasAdvantage = function(Target: Player?): (boolean?, string)
			local Allies, Opponents, Pending
			if Target then
				if Target == LocalPlayer then
					return nil, "Pick another player"
				end

				if not Target:IsDescendantOf(Players) then
					return nil, "Player left"
				end
			else
				Allies, Opponents, Pending = GetRoster()
				if not Allies or #Opponents == 0 or Pending then
					return nil, "Waiting for teams"
				end
			end

			local Data = TeleportService:GetLocalPlayerTeleportData()
			local Match = type(Data) == "table" and (Data.match or Data.customMatch)
			local Queue: string = Match and Match.queueType or store.queueType
			local Meta = bedwars.QueueMeta[Queue]
			local Baseline: number = 1 / math.max(Meta and Meta.teams and #Meta.teams or 2, 2)

			local Context = {Queue = Queue, Baseline = Baseline, Ranked = Meta ~= nil and Meta.rankCategory ~= nil, Draft = bedwars.Store:getState().Draft}
			local Entries, Loaded, Unknown = {}, 0, 0
			local Groups: {{Player}} = Target and {{LocalPlayer, Target}} or {Allies, Opponents}
			for _, List: {Player} in Groups do
				for _, v: Player in List do
					local Entry = Fetch(v)
					Entries[v] = Entry
					if Entry.Done then
						Loaded += 1
						Unknown += Entry.Data and 0 or 1
					end
				end
			end

			local Total: number = Target and 2 or #Allies + #Opponents
			if Loaded < Total then
				return nil, `Waiting for stats ({Loaded}/{Total})`
			end

			local You: number = Score(LocalPlayer, Entries[LocalPlayer], Context)
			if Target then
				local Them: number = Score(Target, Entries[Target], Context)
				return You > Them, string.format("You %.2f, %s %.2f%s", You, Target.Name, Them, Unknown > 0 and `, {Unknown} without stats` or "")
			end

			local Own, Enemy = Average(Allies, Entries, Context), Average(Opponents, Entries, Context)
			return Own > Enemy, string.format("You %.2f, team %.2f, enemies %.2f%s", You, Own, Enemy, Unknown > 0 and `, {Unknown} without stats` or "")
		end
	end


		local SkillCheck, PlayerWhitelist
		local v12 = nil
		local v13 = nil
		local v14 = nil
		local v15 = nil
		local v16 = nil
		local v17 = nil
		local v18 = nil
		local v19 = nil
		local v20 = nil
		local v21 = nil
		local v22 = nil
		local v23 = nil
		local v24 = nil
		local v25 = nil
		local v26 = nil
		local v27 = nil
		local tbl3 = { "Bronze", "Silver", "Gold", "Platinum", "Diamond", "Emerald", "Nightmare" }
		local tbl4 = {}
		local str = "Next match"

		local function fn5(arg)
			local tbl5 = tbl4[arg]

			if not tbl5 then
				tbl5 = { retry = 0 }
				tbl4[arg] = tbl5
			end

			local flag = not tbl5.pending and not tbl5.value

			if flag then
				local retry = tbl5.retry
				flag = os.clock() >= retry
			end

			if flag then
				tbl5.pending = true

				task.spawn(function()
					local ok, value = pcall(store.rank[arg].async)

					if tbl4[arg] == tbl5 then
						tbl5.pending = false
						tbl5.retry = os.clock() + 5

						if ok and type(value) == "number" and bedwars.RankMeta[value] then
							tbl5.value = value
						end
					end
				end)
			end

			return tbl5.value
		end

		local function fn6(arg)
			local game_ = bedwars.Store:getState().Game
			local tbl5 = {}
			local tbl6 = {}
			local teamLeaderUserId = type(arg) == "table" and arg.match and arg.match.teamLeaderUserId
			local teams = game_.teams or {}

			for _, v28 in teams, nil, nil do
				local members = v28.members or {}

				for k, v29 in members, nil, nil do
					tbl6[tonumber(v29.userId or k)] = tostring(v28.id)
				end
			end

			local attribute = localPlayer:GetAttribute("Team") or game_.myTeam and game_.myTeam.id or tbl6[localPlayer.UserId] or tbl6[teamLeaderUserId]
			if not attribute then
				return nil
			end
			local str2 = tostring(attribute)
			local tbl7 = { allies = { localPlayer }, opponents = {}, alliesLoaded = 1, opponentsLoaded = 0, pending = false }

			local whitelisted = {}
			for _, name in (PlayerWhitelist and PlayerWhitelist.ListEnabled or {}) do
				whitelisted[tostring(name):lower()] = true
			end
			for _, v28 in v3:GetPlayers() do
				tbl5[v28.UserId] = true
				if v28 ~= localPlayer and whitelisted[v28.Name:lower()] and not v28:GetAttribute("Spectator") then
					table.insert(tbl7.allies, v28)
					if v28:GetAttribute("PlayerConnected") then
						tbl7.alliesLoaded = tbl7.alliesLoaded + 1
					end
					continue
				end

				if not (v28 == localPlayer or v28:GetAttribute("Spectator")) then
					local attribute2 = v28:GetAttribute("Team") or tbl6[v28.UserId]

					if attribute2 then
						local flag = tostring(attribute2) == str2
						table.insert(flag and tbl7.allies or tbl7.opponents, v28)

						if v28:GetAttribute("PlayerConnected") then
							if flag then
								tbl7.alliesLoaded = tbl7.alliesLoaded + 1
							else
								tbl7.opponentsLoaded = tbl7.opponentsLoaded + 1
							end
						else
							tbl7.pending = true
						end
					else
						tbl7.pending = true
					end
				end
			end

			for k in tbl6, nil, nil do
				if k ~= localPlayer.UserId and not tbl5[k] then
					tbl7.pending = true
				end
			end

			return tbl7
		end

		local v28, v29

		v12 = vape.Categories.Utility:CreateModule({
			Name = "AutoMatchDodge",
			Function = function(matchDodgeActive)
				writefile("aetherv2/profiles/matchdodge.txt", tostring(matchDodgeActive))
				getgenv().matchDodgeActive = matchDodgeActive

				if matchDodgeActive then
					store.readyHold.Claimed = true
					v12:Clean(coroutine.running())
					local started = nil

					while true do
						if not getgenv().dodged and not store.readyHold.Held then
							str = localPlayer:GetAttribute("PlayerConnected") and "Loaded" or "Next match"
							started = nil
						else
							started = started or store.readyHold.Started or os.clock()
							local localPlayerTeleportData = v10:GetLocalPlayerTeleportData()
							local match = type(localPlayerTeleportData) == "table" and (localPlayerTeleportData.match or localPlayerTeleportData.customMatch)
							local v30 = bedwars.QueueMeta[match and match.queueType or store.queueType]

							if getgenv().regionLockActive and not getgenv().regionLockAllowed then
								str = "Waiting for RegionLock"
							elseif v13.Enabled and v30 and not v30.rankCategory then
								if getgenv().dodged and not store.readyHold.Remote then
									bedwars.Handler:Get("PlayerConnect"):Fire("SendToServer", localPlayerTeleportData)
								end

								store.readyHold.Release()
								getgenv().dodged = false
								str = "Loaded"
							elseif v14.Enabled then
								local v31 = fn6(localPlayerTeleportData)
								local flag = v20.Value > 0

								if flag then
									local value = v20.Value
									flag = os.clock() - started >= value
								end

								if not flag then
									flag = v15.Value == "Latency"

									if flag then
										local max = math.max
										local incoming = store.ping.incoming or 0
										local total = store.ping.total or 0
										local value = v17.Value
										flag = max(incoming, total) * 1000 >= value
									end
								end

								flag = flag or v15.Value == "Rank" and v31 and #v31.opponents > 0 and not v31.pending
								local flag2 = v30 and v30.teams and #v30.teams == 2 and v30.teams[1].maxPlayers == 5 and v30.teams[2].maxPlayers == 5
								local enabled = v19.Enabled or v21.Enabled and v27.Enabled
								local str2 = nil

								if enabled then
									if not v30 then
										str2 = "Waiting for queue"
									elseif not flag2 and v21.Enabled and v27.Enabled then
										str2 = "Requires a 5v5 queue"
									elseif flag2 and (not v31 or v31.pending or #v31.opponents == 0) then
										str2 = "Waiting for teams"
									elseif flag2 and v19.Enabled and v31.alliesLoaded < v31.opponentsLoaded then
										str2 = "4v5 Check"
									else
										local flag3 = flag2 and v21.Enabled and v27.Enabled and (store.matchState ~= 1 or v31.alliesLoaded ~= 5 or v31.opponentsLoaded ~= 4)
										str2 = nil

										if flag3 then
											str2 = "Waiting for 5v4"
										end
									end
								end

								local enabled2 = v29.Enabled
								local flag3

								if enabled2 then
									flag3 = enabled2
								else
									flag3 = v15.Value == "Rank" and #v16.ListEnabled > 0
								end

								flag3 = flag3 or v21.Enabled and (v22.Enabled or v25.Enabled)

								if flag3 or v21.Enabled and v23.Enabled then
									if not v31 or #v31.opponents == 0 or v31.pending then
										str2 = str2 or "Waiting for teams"
									else
										local n = 0

										for _, v32 in v31.opponents, nil, nil do
											if flag3 then
												local v33 = fn5(v32)

												if v33 == nil then
													str2 = str2 or "Waiting for ranks"
												else
													local tier = bedwars.RankMeta[v33].tier
													local v34 = nil

													for k, v35 in tbl3, nil, nil do
														if v35:lower() == tier then
															v34 = k
															break
														else
															v34 = nil
														end
													end

													n += v33

													if not v34 then
														str2 = str2 or "Unknown rank"
													elseif v29.Enabled and v34 >= table.find(tbl3, v28.Value) then
														str2 = str2 or "Rank Veto"
													elseif v15.Value == "Rank" and table.find(v16.ListEnabled, tier) then
														str2 = str2 or "Rank Blacklist"
													elseif v21.Enabled and v25.Enabled and v34 > table.find(tbl3, v26.Value) then
														str2 = str2 or "Low Rank"
													end
												end
											end

											if v21.Enabled and v23.Enabled then
												local attribute = v32:GetAttribute("UserInputType")

												if not (attribute == v24.Value:upper() or v24.Value == "Mobile / Gamepad" and (attribute == "MOBILE" or attribute == "GAMEPAD")) then
													str2 = str2 or attribute and "Device Check" or "Waiting for devices"
												end
											end
										end

										if v21.Enabled and v22.Enabled then
											local n2 = 0

											for _, v32 in v31.allies, nil, nil do
												local v33 = fn5(v32)

												if v33 == nil then
													str2 = str2 or "Waiting for ranks"
												else
													n2 += v33
												end
											end

											if n2 / #v31.allies <= n / #v31.opponents then
												str2 = str2 or "Rank Advantage"
											end
										end
									end
								end

								if SkillCheck.Enabled and not str2 and v31 and not v31.pending and #v31.opponents > 0 then
									local better = 0
									for _, v32 in v31.opponents do
										local ok, advantage = pcall(HasAdvantage, v32)
										if ok and advantage == false then
											better += 1
											if better > 1 then break end
										end
									end
									if better > 1 then
										str2 = "Skill check"
									end
								end

								str = str2 or v15.Value == "Latency" and "Waiting for ping" or "Waiting for opponents"

								if flag and not str2 then
									if getgenv().dodged and not store.readyHold.Remote then
										bedwars.Handler:Get("PlayerConnect"):Fire("SendToServer", localPlayerTeleportData)
									end

									store.readyHold.Release()
									getgenv().dodged = false
									str = "Loaded"
								end
							else
								str = "Waiting for Load"
							end
						end

						task.wait(0.5)
						if v12.Enabled then
							continue
						end
						break
					end
				else
					if not getgenv().regionLockActive or getgenv().regionLockAllowed then
						if getgenv().dodged and not store.readyHold.Remote then
							bedwars.Handler:Get("PlayerConnect"):Fire("SendToServer", v10:GetLocalPlayerTeleportData())
						end

						store.readyHold.Release()
						getgenv().dodged = false
					end

					str = "Loaded"
					store.readyHold.Claimed = getgenv().regionLockActive
					table.clear(tbl4)
				end
			end,
			Tooltip = "Waits before loading a match until your chosen checks pass",
			ExtraText = function()
				return str
			end,
		})

		v12:CreateButton({
			Name = "Load",
			Function = function()
				if getgenv().dodged and not store.readyHold.Remote then
					bedwars.Handler:Get("PlayerConnect"):Fire("SendToServer", v10:GetLocalPlayerTeleportData())
				end

				store.readyHold.Release()
				getgenv().dodged = false
				str = "Loaded"
			end,
			Tooltip = "Loads this match now, ignoring the automatic checks",
		})

		v13 = v12:CreateToggle({ Name = "Rank only", Tooltip = "Loads straight away when the match is not ranked" })

		v14 = v12:CreateGroup({
			Name = "Auto Undodge",
			Function = function(visible)

				if v16 then
					v16.Object.Visible = visible and v15.Value == "Rank"
				end

				if v17 then
					v17.Object.Visible = visible and v15.Value == "Latency"
				end
			end,
			Tooltip = 'Loads when the selected checks pass',
		})

		v15 = v14:CreateDropdown({
			Name = "Mode",
			List = { "Rank", "Latency" },
			Function = function(arg)
				if v16 then
					v16.Object.Visible = v14.Enabled and arg == "Rank"
				end

				if v17 then
					v17.Object.Visible = v14.Enabled and arg == "Latency"
				end
			end,
			Darker = true,
			Tooltip = 'Rank - waits for opponents to load\nLatency - waits for your ping to rise',
		})

		v16 = v12:CreateTextList({
			Name = "Rank Blacklist",
			Placeholder = "bronze / silver / gold / platinum / diamond / emerald / nightmare",
			Darker = true,
			Visible = false,
			Function = function()
				for k, v30 in v16.List, nil, nil do
					v16.List[k] = v30:lower()
				end

				for k, v30 in v16.ListEnabled, nil, nil do
					v16.ListEnabled[k] = v30:lower()
				end
			end,
		})

		v17 = v12:CreateSlider({
			Name = "Ping",
			Min = 50,
			Max = 1000,
			Default = 200,
			Darker = true,
			Visible = false,
			Suffix = "ms",
			Tooltip = "How high your ping has to be before loading",
		})

		v29 = v12:CreateGroup({
			Name = "Rank Veto",
			Tooltip = 'Keeps dodging opponents at or above this rank',
		})

		v28 = v29:CreateDropdown({
			Name = "Veto At",
			List = tbl3,
			Default = "Diamond",
			Darker = true,
			Tooltip = "The lowest enemy rank that blocks automatic loading",
		})

		v19 = v12:CreateToggle({
			Name = "4v5 Check",
			Tooltip = 'In 5v5 queues, waits if your team has fewer players loaded',
		})
		PlayerWhitelist = v12:CreateTextList({
			Name = "Players Whitelist",
			Darker = true,
			Tooltip = 'Players that count as your team whenever they are in the server'
		})
		SkillCheck = v12:CreateToggle({
			Name = "Skill check",
			Tooltip = 'Waits while more than one opponent looks better than you from their stats (not always accurate)'
		})

		v20 = v12:CreateSlider({
			Name = "Max Wait",
			Min = 0,
			Max = 120,
			Function = function(value)
				if v18 then
					v18.Value = value
				end
			end,
			Default = 20,
			Suffix = function(arg)
				return arg == 1 and "second" or "seconds"
			end,
			Tooltip = 'Stops waiting after this long, 0 waits forever',
		})

		v18 = v12:CreateSlider({
			Name = "Timeout",
			Min = 0,
			Max = 120,
			Function = function(arg)
				v20:SetValue(arg)
			end,
			Default = 20,
			Visible = false,
		})

		v21 = v12:CreateToggle({
			Name = "Advanced",
			Function = function(visible)
				for _, v30 in { v22, v23, v25, v27 }, nil, nil do
					v30.Object.Visible = visible
				end

				if v24 then
					v24.Object.Visible = visible and v23.Enabled
				end

				if v26 then
					v26.Object.Visible = visible and v25.Enabled
				end
			end,
			Tooltip = 'Adds extra conditions for loading automatically',
		})

		v22 = v12:CreateToggle({
			Name = "Rank Advantage",
			Darker = true,
			Visible = false,
			Tooltip = "Requires your team, including you, to have a higher average rank division",
		})

		v23 = v12:CreateToggle({
			Name = "Device Check",
			Function = function(arg)
				if v24 then
					v24.Object.Visible = v21.Enabled and arg
				end
			end,
			Darker = true,
			Visible = false,
			Tooltip = "Requires every opponent to use one of the selected devices",
		})

		v24 = v12:CreateDropdown({
			Name = "Device",
			List = { "Mobile / Gamepad", "Mobile", "Gamepad", "PC" },
			Darker = true,
			Visible = false,
		})

		v25 = v12:CreateToggle({
			Name = "Low Rank",
			Function = function(arg)
				if v26 then
					v26.Object.Visible = v21.Enabled and arg
				end
			end,
			Darker = true,
			Visible = false,
			Tooltip = "Requires every opponent to be at or below the selected rank",
		})

		v26 = v12:CreateDropdown({ Name = "Low Rank At", List = tbl3, Default = "Gold", Darker = true, Visible = false })

		v27 = v12:CreateToggle({
			Name = "Guaranteed 5v4",
			Darker = true,
			Visible = false,
			Tooltip = 'Waits for a full 5v4 start with nobody loading',
		})

		task.spawn(function()
			while true do
				task.wait()
				if not (vape.Loaded or vape.Loaded == nil) then
					continue
				end
				break
			end

			local json = isfile("aetherv2/profiles/matchdodge.json") and readfile("aetherv2/profiles/matchdodge.json")

			if vape.Loaded and json then
				local ok, result = pcall(v2.JSONDecode, v2, json)

				if ok and type(result) == "table" then
					if result.Options and result.Options["Max Wait"] then
						result.Options.Timeout = result.Options["Max Wait"]
					end

					if type(v12.Load) == 'function' then v12:Load(result) end
				end
			end

			while true do
				if vape.Loaded then
					local tbl5 = {}
					if type(v12.Save) == 'function' then
						v12:Save(tbl5)
					else
						tbl5.AutoMatchDodge = {}
					end
					if tbl5.AutoMatchDodge then
						tbl5.AutoMatchDodge.Favorited = nil
						local json2 = v2:JSONEncode(tbl5.AutoMatchDodge)

						if json2 ~= json then
							writefile("aetherv2/profiles/matchdodge.json", json2)
							json = json2
						end
					end
				end

				task.wait(1)
				if vape.Loaded ~= nil then
					continue
				end
				break
			end
		end)
	end)
