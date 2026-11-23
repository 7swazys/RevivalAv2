run(function()
	local httpService   = httpService
	local playersService = playersService
	local replicatedStorage = replicatedStorage
	local runService    = runService
	local inputService  = inputService
	local tweenService  = tweenService
	local collectionService = collectionService
	local guiService    = guiService
	local teleportService = game:GetService('TeleportService')
	local obj           = debug
	local currentCamera = gameCamera
	local localPlayer   = lplr
	local entity        = entitylib
	local getfontbounds = getfontsize
	local getvapeasset  = getcustomasset

	local function connectRemote(name, callback)
		local remote = bedwars.Handler:Get(name).Remote
		if remote then
			return remote:Connect(callback)
		end
		return { Disconnect = function() end }
	end

	local kitSpyModule        = nil
	local expandedBeeToggle, expandedMetalToggle
	local viewerToggle        = nil
	local notificationsToggle = nil
	local ignoreTeammatesToggle = nil
	local ignoreYourselfToggle  = nil
	local rangeSlider         = nil
	local windowSlider        = nil
	local delaySlider         = nil
	local itemsList           = nil
	local collectablesList    = nil
	local kitToggles          = {}

	local collectableLabels = {
		alchemist_ingedients = "ingredient",
		alchemy_crystal = "crystal",
		crystalheart_seed = "crystalheart seed",
		forest_environment_plant = "plant",
		ghost = "ghost",
		murder_coin = "coin",
		shadow_coin = "shadow coin",
		soulvine_seed = "soulvine seed",
		spirit_gardener_energy = "energy",
		spirit_gardener_seeds = "seed",
		tearbloom_seed = "tearbloom seed",
	}

	local totals        = {}
	local viewerButton  = nil
	local viewerLabel   = nil
	local viewerExpanded = false
	local shovelDigAnimationId
	pcall(function()
		shovelDigAnimationId = bedwars.GameAnimationUtil:getAssetId(bedwars.AnimationType.SHOVEL_DIG)
	end)

	local digWatches = setmetatable({}, { __mode = "k" })

	local beeTotals   = {}
	local beeSeen     = setmetatable({}, { __mode = "k" })
	local beeGone     = {}
	local beePanel    = nil
	local beeLabel    = nil
	local beeExpanded = false

	local metalWatches = setmetatable({}, { __mode = "k" })

	local function getDisplayName(plr)
		if plr then
			plr = plr.DisplayName or plr.Name
		end
		return plr or "someone"
	end

	local function isIgnored(plr)
		if plr == localPlayer then
			return ignoreYourselfToggle.Enabled
		end
		return ignoreTeammatesToggle.Enabled and plr.Team == localPlayer.Team
	end

	local function pluralize(count, noun)
		return ("%* %*%*"):format(count, noun, count == 1 and "" or "s")
	end

	local function refreshViewer()
		if not viewerButton then
			return
		end
		local entries = {}

		for plr, categories in totals do
			local parts = {}
			local total = 0

			for category, count in categories do
				total += count
				table.insert(parts, pluralize(count, category))
			end

			table.sort(parts)
			table.insert(entries, { Name = getDisplayName(plr), Total = total, Text = table.concat(parts, ", ") })
		end

		table.sort(entries, function(a, b)
			return a.Total > b.Total
		end)

		local lines = { "KitSpy" }

		if #entries == 0 then
			table.insert(lines, "Nothing spotted yet")
		else
			for i, entry in entries do
				if not viewerExpanded and i > 5 then
					table.insert(lines, ("+%* more"):format(#entries - 5))
					break
				else
					table.insert(lines, ("%*: %*"):format(entry.Name, entry.Text))
				end
			end
		end

		viewerLabel.Text = table.concat(lines, "\n")
		local textSize = viewerLabel.TextSize
		local fontFace = viewerLabel.FontFace
		local bounds   = getfontbounds(removeTags(viewerLabel.Text), textSize, fontFace)
		local height   = bounds.Y + 16
		viewerButton.Size = UDim2.fromOffset(
			math.max(
				bounds.X,
				getfontbounds(
					"KitSpy",
					viewerLabel.TextSize,
					Font.new(viewerLabel.FontFace.Family, Enum.FontWeight.Bold)
				).X
			) + 16,
			height
		)
		viewerButton.Visible = viewerToggle.Enabled
	end

	local function addTotal(plr, category, amount)
		local categories = totals[plr] or {}
		categories[category] = (categories[category] or 0) + amount
		totals[plr] = categories
		refreshViewer()
		return categories[category]
	end

	local function ensureViewer()
		if viewerButton then
			return
		end
		viewerButton = Instance.new("TextButton")
		viewerButton.Name = "KitSpyViewer"
		viewerButton.Position = UDim2.fromOffset(12, 260)
		viewerButton.BackgroundColor3 = Color3.new()
		viewerButton.BackgroundTransparency = 0.5
		viewerButton.Text = ""
		viewerButton.AutoButtonColor = false
		viewerButton.Visible = false
		viewerButton.Parent = vape.gui.ScaledGui
		addBlur(viewerButton)
		local uiCorner = Instance.new("UICorner")
		uiCorner.CornerRadius = UDim.new(0, 5)
		uiCorner.Parent = viewerButton
		viewerLabel = Instance.new("TextLabel")
		viewerLabel.Size = UDim2.new(1, -16, 1, -16)
		viewerLabel.Position = UDim2.fromOffset(8, 8)
		viewerLabel.BackgroundTransparency = 1
		viewerLabel.TextXAlignment = Enum.TextXAlignment.Left
		viewerLabel.TextYAlignment = Enum.TextYAlignment.Top
		viewerLabel.TextSize = 16
		viewerLabel.TextColor3 = Color3.new(1, 1, 1)
		viewerLabel.TextStrokeColor3 = Color3.new()
		viewerLabel.TextStrokeTransparency = 0.8
		viewerLabel.Font = Enum.Font.Arial
		viewerLabel.RichText = true
		viewerLabel.Parent = viewerButton

		viewerButton.MouseButton1Click:Connect(function()
			viewerExpanded = not viewerExpanded
			refreshViewer()
		end)
	end

	local function countItem(plr, itemType)
		local items = (store.inventories[plr] or { items = {} }).items
		local total = 0

		for _, item in items do
			if item.itemType == itemType then
				total += item.amount or 1
			end
		end

		return total
	end

	local function recentItems(plr, filterList)
		local serverTimeNow = workspace:GetServerTimeNow()
		local lines         = {}
		local inventory     = store.inventories[plr] or { items = {} }

		for _, item in inventory.items do
			if not (windowSlider.Value < serverTimeNow - (item.addedToBackpackTime or 0)) then
				if not (filterList and #itemsList.ListEnabled > 0 and not table.find(itemsList.ListEnabled, item.itemType)) then
					local meta = bedwars.ItemMeta[item.itemType]
					table.insert(lines, ("%*%*"):format(
						(item.amount or 1) > 1 and ("%*x "):format(item.amount) or "",
						meta and meta.displayName or item.itemType
					))
				end
			end
		end

		return lines
	end

	local function reportDig(plr, prefix, filterList)
		local items = recentItems(plr, filterList)
		if #items == 0 then
			return
		end
		notif("KitSpy", ("%* %* %*"):format(getDisplayName(plr), prefix, table.concat(items, ", ")), 8, "info")
	end

	local function findNearbyPlayer(position)
		local bestDistance = rangeSlider.Value
		local bestPlayer   = nil

		for _, ent in entity.List do
			if not (not ent.Player or isIgnored(ent.Player)) then
				local distance = (ent.RootPart.Position - position).Magnitude
				if distance <= bestDistance then
					bestPlayer   = ent.Player
					bestDistance = distance
				end
			end
		end

		return bestPlayer
	end

	local function reportPickup(plr, category, amount)
		local newTotal = addTotal(plr, category, amount)

		if notificationsToggle.Enabled then
			notif("KitSpy", ("%* picked up %* (%* total)"):format(
				getDisplayName(plr), pluralize(amount, category), newTotal
			), 5, "info")
		end
	end

	local function trackKitPickups(tag, category, itemType, labelMap)
		local positions   = {}
		local disappeared = {}
		local seenCounts  = {}

		local tracked = collection(tag, kitSpyModule, function(list, obj)
			table.insert(list, obj)
			local part = obj:IsA("Model")
					and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true))
				or obj
			if part then
				positions[obj] = part.Position
			end
		end, function(list, obj, name)
			local idx = table.find(list, obj)
			if idx then
				table.remove(list, idx)
			end

			local lastPos = positions[obj]
			positions[obj] = nil
			if not lastPos then
				return
			end

			if not itemType then
				local blamed = findNearbyPlayer(lastPos)
				if blamed then
					reportPickup(blamed, labelMap and labelMap[name] or category, 1)
				end
				return
			end

			table.insert(disappeared, { Position = lastPos, Time = tick() })
		end)

		if itemType then
			for _, ent in entity.List do
				if ent.Player then
					seenCounts[ent.Player] = countItem(ent.Player, itemType)
				end
			end
		end

		while true do
			local now = tick()

			for _, obj in tracked do
				local part = obj:IsA("Model")
						and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true))
					or obj
				if part then
					positions[obj] = part.Position
				end
			end

			for i = #disappeared, 1, -1 do
				if now - disappeared[i].Time > windowSlider.Value then
					table.remove(disappeared, i)
				end
			end

			if itemType then
				for _, ent in entity.List do
					local plr = ent.Player
					if not (not plr or isIgnored(plr)) then
						local newCount = countItem(plr, itemType)
						local oldCount = seenCounts[plr]
						seenCounts[plr] = newCount

						if not (not oldCount or newCount <= oldCount or not ent.RootPart) then
							for i = #disappeared, 1, -1 do
								if not (rangeSlider.Value < (ent.RootPart.Position - disappeared[i].Position).Magnitude) then
									table.remove(disappeared, i)
									reportPickup(plr, category, newCount - oldCount)
									break
								end
							end
						end
					end
				end
			end

			task.wait(0.2)
			if kitSpyModule.Enabled then
				continue
			end
			break
		end
	end

	local function watchMetalDetectorDigs()
		local function onEntity(ent)
			if not ent.Player or isIgnored(ent.Player) then
				return
			end
			local animator = ent.Humanoid:FindFirstChildOfClass("Animator")
			if not animator or digWatches[animator] then
				return
			end

			digWatches[animator] = animator.AnimationPlayed:Connect(function(anim)
				if anim.Animation.AnimationId ~= shovelDigAnimationId then
					return
				end
				task.delay(delaySlider.Value, reportDig, ent.Player, "dug up", true)
			end)
		end

		kitSpyModule:Clean(entity.Events.EntityAdded:Connect(onEntity))

		kitSpyModule:Clean(function()
			for _, conn in digWatches do
				conn:Disconnect()
			end
			table.clear(digWatches)
		end)

		for _, ent in entity.List do
			onEntity(ent)
		end
	end

	local function beeCount(plr)
		local items = (store.inventories[plr] or { items = {} }).items
		local total = 0

		for _, item in items do
			if item.itemType == "bee" then
				total += item.amount or 1
			end
		end

		return total
	end

	local function refreshBeePanel()
		if not beePanel then
			return
		end
		local entries = {}

		for plr, total in beeTotals do
			table.insert(entries, { Name = plr.Name, Total = total })
		end

		table.sort(entries, function(a, b)
			return a.Total > b.Total
		end)

		local lines = { "BeekeeperSpy" }

		if #entries == 0 then
			table.insert(lines, "No bees collected yet")
		else
			for i, entry in entries do
				if not beeExpanded and i > 5 then
					table.insert(lines, ("+%* more"):format(#entries - 5))
					break
				else
					table.insert(lines, ("%*: %* bee%*"):format(
						entry.Name, entry.Total, entry.Total == 1 and "" or "s"
					))
				end
			end
		end

		beeLabel.Text = table.concat(lines, "\n")
		local bounds = getfontbounds(removeTags(beeLabel.Text), beeLabel.TextSize, beeLabel.FontFace)
		beePanel.Size = UDim2.fromOffset(
			math.max(
				bounds.X,
				getfontbounds(
					"BeekeeperSpy",
					beeLabel.TextSize,
					Font.new(beeLabel.FontFace.Family, Enum.FontWeight.Bold)
				).X
			) + 16,
			bounds.Y + 16
		)
	end

	local function ensureBeePanel()
		if beePanel then
			return
		end

		beePanel = Instance.new("TextButton")
		beePanel.Name = "BeekeeperSpyViewer"
		beePanel.Position = UDim2.fromOffset(12, 260)
		beePanel.BackgroundColor3 = Color3.new()
		beePanel.BackgroundTransparency = 0.5
		beePanel.Text = ""
		beePanel.AutoButtonColor = false
		beePanel.Visible = false
		beePanel.Parent = vape.gui.ScaledGui
		addBlur(beePanel)

		local uiCorner = Instance.new("UICorner")
		uiCorner.CornerRadius = UDim.new(0, 5)
		uiCorner.Parent = beePanel

		beeLabel = Instance.new("TextLabel")
		beeLabel.Size = UDim2.new(1, -16, 1, -16)
		beeLabel.Position = UDim2.fromOffset(8, 8)
		beeLabel.BackgroundTransparency = 1
		beeLabel.TextXAlignment = Enum.TextXAlignment.Left
		beeLabel.TextYAlignment = Enum.TextYAlignment.Top
		beeLabel.TextSize = 16
		beeLabel.TextColor3 = Color3.new(1, 1, 1)
		beeLabel.TextStrokeColor3 = Color3.new()
		beeLabel.TextStrokeTransparency = 0.8
		beeLabel.Font = Enum.Font.Arial
		beeLabel.RichText = true
		beeLabel.Parent = beePanel

		beePanel.MouseButton1Click:Connect(function()
			beeExpanded = not beeExpanded
			refreshBeePanel()
		end)
	end

	local function runBeekeeperSpy()
		ensureBeePanel()
		table.clear(beeGone)

		for _, ent in entity.List do
			if ent.Player then
				beeTotals[ent.Player] = beeCount(ent.Player)
			end
		end

		refreshBeePanel()

		local bees = collection("bee", kitSpyModule, function(list, obj)
			table.insert(list, obj)
			local part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
			if part then
				beeSeen[obj] = part.Position
			end
		end, function(list, obj)
			local idx = table.find(list, obj)
			if idx then
				table.remove(list, idx)
			end

			local lastPos = beeSeen[obj]
			beeSeen[obj] = nil
			if not lastPos then
				return
			end
			table.insert(beeGone, { Position = lastPos, Time = tick() })
		end)

		while true do
			local now = tick()

			for _, obj in bees do
				local part = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
				if part then
					beeSeen[obj] = part.Position
				end
			end

			for i = #beeGone, 1, -1 do
				if now - beeGone[i].Time > ignoreTeammatesToggle.Value then
					table.remove(beeGone, i)
				end
			end

			for _, ent in entity.List do
				local plr = ent.Player
				if not (not plr or plr == localPlayer or isIgnored(plr)) then
					local current = beeCount(plr)
					local previous = beeTotals[plr]
					beeTotals[plr] = current

					if not (not previous or current <= previous or not ent.RootPart) then
						local gained = current - previous

						for i = #beeGone, 1, -1 do
							if not (rangeSlider.Value < (ent.RootPart.Position - beeGone[i].Position).Magnitude) then
								table.remove(beeGone, i)
								beeTotals[plr] = current

								if notificationsToggle.Enabled then
									notif(
										"BeekeeperSpy",
										("%* picked up %* bee%* (%* total)"):format(
											plr.Name,
											gained,
											gained == 1 and "" or "s",
											current
										),
										5,
										"info"
									)
								end

								refreshBeePanel()
							break
							end
						end
					end
				end
		end

			task.wait(0.2)
			if kitSpyModule.Enabled then
				continue
			end

			break
		end
	end		

	local function watchDigs()
		local function onEntity(ent)
			if not ent.Player or ent.Player == localPlayer or isIgnored(ent.Player) then
				return
			end

			local animator = ent.Humanoid:FindFirstChildOfClass("Animator")
			if not animator or metalWatches[animator] then
				return
			end

			metalWatches[animator] = animator.AnimationPlayed:Connect(function(anim)
				if anim.Animation.AnimationId ~= shovelDigAnimationId then
					return
				end
				task.delay(delaySlider.Value, reportDig, ent.Player, "dug up", true)
			end)
		end

		kitSpyModule:Clean(entity.Events.EntityAdded:Connect(onEntity))

		kitSpyModule:Clean(function()
			for _, conn in metalWatches do
				conn:Disconnect()
			end
			table.clear(metalWatches)
		end)

		for _, ent in entity.List do
			onEntity(ent)
		end
	end

	local kitHandlers = {
		beekeeper = function()
			trackKitPickups("bee", "bee", "bee")
		end,
		bigman = function()
			trackKitPickups("treeOrb", "tree orb")
		end,
		bounty_hunter = function()
			local bounties = {}

			kitSpyModule:Clean(function()
				table.clear(bounties)
			end)

			kitSpyModule:Clean(connectRemote("BountyHunterTargetChanged", function(payload)
				local hunter = typeof(payload) == "table" and payload.hunter
				if typeof(hunter) ~= "Instance" or not hunter:IsA("Player") then
					return
				end
				local target = payload.newTargetUserId ~= 0
						and playersService:GetPlayerByUserId(payload.newTargetUserId)
					or nil
				bounties[hunter] = target

				if target and notificationsToggle.Enabled and not isIgnored(hunter) then
					notif("KitSpy", ("%* is now hunting %*"):format(
						getDisplayName(hunter), getDisplayName(target)
					), 12, "info")
				end
			end))

			kitSpyModule:Clean(vapeEvents.EntityDeathEvent.Event:Connect(function(payload)
				local victim = playersService:GetPlayerFromCharacter(payload.entityInstance)
				local killer = playersService:GetPlayerFromCharacter(payload.fromEntity)
				if not victim or not killer or bounties[killer] ~= victim then
					return
				end
				bounties[killer] = nil
				if isIgnored(killer) then
					return
				end
				addTotal(killer, "bounty", 1)
				notif(
					"KitSpy",
					("%* claimed their bounty on %*"):format(
						getDisplayName(killer), getDisplayName(victim)
					),
					20,
					"alert"
				)
				task.delay(delaySlider.Value, reportDig, killer, "looted", false)
			end))

			kitSpyModule:Clean(playersService.PlayerRemoving:Connect(function(plr)
				bounties[plr] = nil
				for hunter, target in bounties do
					if target == plr then
						bounties[hunter] = nil
					end
				end
			end))
		end,
		farmer_cletus = function()
			trackKitPickups("HarvestableCrop", "crop")
		end,
		fisherman = function()
			kitSpyModule:Clean(connectRemote("FishCaught", function(payload)
				local catcher = typeof(payload) == "table" and payload.catchingPlayer
				if not catcher or not payload.dropData or not payload.dropData.drops or isIgnored(catcher) then
					return
				end
				local lines = {}

				for _, drop in payload.dropData.drops do
					local meta = bedwars.ItemMeta[drop.itemType]
					table.insert(lines, pluralize(
						drop.amount,
						(meta and meta.displayName or drop.itemType):lower()
					))
				end

				if #lines == 0 then
					return
				end
				addTotal(catcher, "catch", 1)

				if notificationsToggle.Enabled then
					notif(
						"KitSpy",
						("%* caught %*"):format(getDisplayName(catcher), table.concat(lines, ", ")),
						20,
						"info"
					)
				end
			end))
		end,
		jailor = function()
			trackKitPickups("jailor_soul", "soul")
		end,
		metal_detector = function()
			trackKitPickups("hidden-metal", "metal")
			watchMetalDetectorDigs()
		end,
		spirit_assassin = function()
			trackKitPickups("EvelynnSoul", "spirit")
		end,
		star_collector = function()
			trackKitPickups("stars", "star")
		end,
	}

	kitSpyModule = vape.Categories.Kits:CreateModule({
		Name = "KitSpy",
		Category = "Visual",
		Function = function(enabled)
			if enabled then
				ensureViewer()
				refreshViewer()

				for kitName, handler in kitHandlers do
					if kitToggles[kitName].Enabled then
						task.spawn(handler)
					end
				end

				if #collectablesList.ListEnabled > 0 then
					task.spawn(trackKitPickups, collectablesList.ListEnabled, "collectable", nil, collectableLabels)
				end

				if expandedBeeToggle.Enabled then
					task.spawn(runBeekeeperSpy)
				end

				if expandedMetalToggle.Enabled then
					watchDigs()
				end
			elseif viewerButton then
				viewerButton.Visible = false

				if beePanel then
					beePanel.Visible = false
				end
			end
		end,
		Tooltip = 'Reports what other players are doing with their kits',
	})

	viewerToggle = kitSpyModule:CreateToggle({
		Name = "Viewer",
		Function = function()
			refreshViewer()
		end,
		Tooltip = 'Shows a panel of what each player has picked up',
		Default = true,
	})

	notificationsToggle = kitSpyModule:CreateToggle({
		Name = "Notifications",
		Default = true,
		Tooltip = 'Tells you when someone uses their kit',
	})

	ignoreTeammatesToggle = kitSpyModule:CreateToggle({ Name = "Ignore teammates", Default = true })
	ignoreYourselfToggle  = kitSpyModule:CreateToggle({ Name = "Ignore yourself", Default = true })

	rangeSlider = kitSpyModule:CreateSlider({
		Name = "Range",
		Min = 1,
		Max = 40,
		Default = 25,
		Suffix = function(value)
			return value <= 1 and "stud" or "studs"
		end,
		Tooltip = 'How close a player must be to count as taking it',
	})

	windowSlider = kitSpyModule:CreateSlider({
		Name = "Window",
		Min = 1,
		Max = 10,
		Default = 3,
		Suffix = function(value)
			return value > 1 and "secs" or "sec"
		end,
		Tooltip = 'How recently it must have happened to count',
	})

	delaySlider = kitSpyModule:CreateSlider({
		Name = "Delay",
		Min = 0,
		Max = 2,
		Default = 0.5,
		Decimal = 100,
		Suffix = function(value)
			return value == 1 and "sec" or "secs"
		end,
		Tooltip = 'Delay before reading their inventory',
	})

	itemsList = kitSpyModule:CreateTextList({
		Name = "Items",
		Placeholder = "item type (iron_ingot)",
		Darker = true,
		Tooltip = 'Items to report, empty reports everything',
	})

	collectablesList = kitSpyModule:CreateTextList({
		Name = "Collectables",
		Default = {
			"alchemist_ingedients",
			"alchemy_crystal",
			"crystalheart_seed",
			"ghost",
			"murder_coin",
			"shadow_coin",
			"soulvine_seed",
			"spirit_gardener_energy",
			"spirit_gardener_seeds",
			"tearbloom_seed",
		},
		Darker = true,
		Tooltip = 'Extra collectables to watch',
	})

	kitSpyModule:CreateButton({
		Name = "Reset totals",
		Function = function()
			table.clear(totals)
			refreshViewer()

			table.clear(beeTotals)
			refreshBeePanel()
		end,
	})

	local function kitDisplayName(kitName)
		local meta = bedwars.BedwarsKitMeta[kitName]
		return meta and meta.name or kitName
	end

	local sortedKits = {}

	for kitName in kitHandlers do
		table.insert(sortedKits, kitName)
	end

	table.sort(sortedKits, function(a, b)
		return kitDisplayName(a) < kitDisplayName(b)
	end)

	local kitNames = {}
	for _, kitName in sortedKits do
		table.insert(kitNames, kitDisplayName(kitName))
	end
	local kitPick = kitSpyModule:CreateMultiDropdown({
		Name = 'Kits',
		List = kitNames,
		Default = table.clone(kitNames),
		Tooltip = 'Which kits are watched'
	})
	for _, kitName in sortedKits do
		local display = kitDisplayName(kitName)
		kitToggles[kitName] = setmetatable({}, {__index = function(_, key) if key == 'Enabled' then return kitPick:Has(display) end end})
	end

	expandedBeeToggle = kitSpyModule:CreateToggle({
		Name = "BeekeeperSpy",
		Default = false,
		Tooltip = 'Tracks which players collect bees and how many',
	})

	local expandedBeeViewer = kitSpyModule:CreateToggle({
		Name = "BeekeeperSpy viewer",
		Default = true,
		Darker = true,
		Function = function(visible)
			if beePanel then
				beePanel.Visible = visible and expandedBeeToggle.Enabled
			end
		end,
		Tooltip = 'Shows everyone\'s total bees in a panel',
	})

	expandedBeeToggle.Function = function(enabled)
		if beePanel then
			beePanel.Visible = enabled and expandedBeeViewer.Enabled
		end

		if enabled and kitSpyModule.Enabled then
			task.spawn(runBeekeeperSpy)
		end
	end

	expandedMetalToggle = kitSpyModule:CreateToggle({
		Name = "MetalDetectorSpy",
		Default = false,
		Tooltip = 'Reports what other players dig up',
	})

	expandedMetalToggle.Function = function(enabled)
		if enabled and kitSpyModule.Enabled then
			watchDigs()
		end
	end
end)