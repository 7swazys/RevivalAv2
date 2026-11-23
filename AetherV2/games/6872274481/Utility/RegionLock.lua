run(function()
	local HttpService = httpService
	local LocalPlayer = lplr
	local SendNotification = notif
	local Store = store
	local TeleportService = cloneref(game:GetService('TeleportService'))
	local RegionLock
	local Regions
	local Timeout
	local Requeue

	local Status: string = "Next match"
	local ServerRegion: string?
	local Warned: boolean = false
	local Requeued: boolean = false
	local RequeueTries: number = 0
	local RequeueRetry: number = 0
	local Aliases: {[string]: string} = {
		AU = "SEA",
		AUS = "SEA",
		AUSTRALIA = "SEA",
		NZ = "SEA",
		OCE = "SEA",
		OCEANIA = "SEA",
		AS = "SEA",
		ASIA = "SEA",
		SG = "SEA",
		SGP = "SEA",
		US = "NA",
		USA = "NA",
		AMERICA = "NA",
		EUROPE = "EU",
		GB = "EU",
		UK = "EU"
	}

	local function Canonical(Value: string): string
		Value = tostring(Value):gsub("%s+", ""):upper()
		if Value:match("^SG%-%d+$") then
			return "SEA"
		end
		return Aliases[Value] or Value
	end

	local function GetRegion(): string?
		local Display: Instance? = LocalPlayer.PlayerGui:FindFirstChild("ServerRegionDisplay")
		local Label: TextLabel? = Display and Display:FindFirstChild("ServerRegionText")
		local Region: string? = Label and Label.Text:gsub("<[^>]+>", ""):match("REGION:%s*(%S+)") or nil
		if not Region then
			local State = bedwars.Store:getState().Game
			Region = type(State) == "table" and type(State.serverRegion) == "string" and State.serverRegion ~= "" and State.serverRegion or nil
		end
		if Region then
			ServerRegion = Region
		end
		return ServerRegion
	end

	local function IsRegionAllowed(): boolean
		if #Regions.ListEnabled == 0 then
			return true
		end

		local Region = GetRegion()
		if not Region then
			return false
		end

		Region = Canonical(Region)
		for _, v: string in Regions.ListEnabled do
			v = Canonical(v)
			if v ~= "" and Region:sub(1, #v) == v then
				return true
			end
		end
		return false
	end

	local function RequeueMatch(): string?
		local State = bedwars.Store:getState()
		if Requeued or State.Party.queueState ~= 0 then
			Requeued = true
			return "Requeued"
		end

		local Data = TeleportService:GetLocalPlayerTeleportData()
		if (type(Data) == "table" and Data.customMatch) or State.Game.customMatch or State.Party.leader.userId ~= LocalPlayer.UserId then
			return nil
		end

		local Match = type(Data) == "table" and Data.match
		local QueueType: string? = Match and Match.queueType or Store.queueType
		local Meta = QueueType and bedwars.QueueMeta[QueueType]
		if not Meta or Meta.disabled then
			return nil
		end

		if os.clock() >= RequeueRetry then
			if RequeueTries >= 3 then
				return "Requeue failed"
			end
			RequeueTries += 1
			RequeueRetry = os.clock() + 5
			pcall(bedwars.QueueController.joinQueue, bedwars.QueueController, QueueType)
		end
		return "Requeueing"
	end

	local function Release()
		if not getgenv().matchDodgeActive then
			if getgenv().dodged and not Store.readyHold.Remote then
				bedwars.Handler:Get("PlayerConnect"):Fire("SendToServer", TeleportService:GetLocalPlayerTeleportData())
			end
			Store.readyHold.Release()
			getgenv().dodged = false
		end
	end

	RegionLock = vape.Categories.Utility:CreateModule({
		Name = "RegionLock",
		Function = function(Callback: boolean)
			writefile(`aetherv2/profiles/regionlock.txt`, tostring(Callback))
			getgenv().regionLockActive = Callback
			getgenv().regionLockAllowed = not Callback
			if Callback then
				Store.readyHold.Claimed = true
				RegionLock:Clean(coroutine.running())
				Warned = false
				repeat
					if not getgenv().dodged and not Store.readyHold.Held then
						Status = LocalPlayer:GetAttribute("PlayerConnected") and "Loaded" or "Next match"
					else
						local Started: number = Store.readyHold.Started or os.clock()
						getgenv().regionLockAllowed = IsRegionAllowed()
						if getgenv().regionLockAllowed then
							Status = ServerRegion or "Any region"
							Release()
						elseif ServerRegion then
							local RequeueStatus: string? = Requeue.Enabled and RequeueMatch() or nil
							Status = `{RequeueStatus or "Wrong region"} ({ServerRegion})`
						elseif Timeout.Value > 0 and (os.clock() - Started) >= Timeout.Value then
							if not Warned then
								Warned = true
								SendNotification("RegionLock", "Could not read this server region, loading anyway", 8, "warning")
							end
							getgenv().regionLockAllowed = true
							Status = "Unknown region"
							Release()
						else
							Status = "Finding region"
						end
					end
					task.wait(0.5)
				until not RegionLock.Enabled
			else
				Release()
				Status = "Loaded"
				Store.readyHold.Claimed = getgenv().matchDodgeActive
			end
		end,
		Tooltip = 'Skips matches hosted outside your chosen regions',
		ExtraText = function()
			return Status
		end
	})

	Regions = RegionLock:CreateTextList({
		Name = "Regions",
		Placeholder = "NA / EU / SEA",
		Default = {"NA", "EU", "SEA"},
		Function = function()
			if not Regions then
				return
			end
			for i: number, v: string in Regions.List do
				Regions.List[i] = v:gsub("%s+", ""):upper()
			end
			for i: number, v: string in Regions.ListEnabled do
				Regions.ListEnabled[i] = v:gsub("%s+", ""):upper()
			end
		end,
		Tooltip = 'Regions to accept'
	})
	Timeout = RegionLock:CreateSlider({
		Name = "Timeout",
		Min = 0,
		Max = 120,
		Default = 20,
		Suffix = function(Value: number)
			return Value == 1 and "second" or "seconds"
		end,
		Tooltip = 'Loads anyway after this long, 0 waits forever'
	})
	Requeue = RegionLock:CreateToggle({
		Name = "Requeue",
		Tooltip = 'Queues again when the region is wrong'
	})
end)
