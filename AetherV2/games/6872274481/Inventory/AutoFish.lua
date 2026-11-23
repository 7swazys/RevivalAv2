run(function()
	local AutoFish
	local Show
	local Blacklist
	local Minigame
	local MinigameMode = {}
	local CompleteDelay = {}
	local Reaction = {}
	local Clicks = {}
	local Cast
	local CastDelay = {}
	local GUI
	local rejects = {}

	local function menuOpen()
		if not (GUI and GUI.Enabled) then return false end
		local ok, open = pcall(function()
			return bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN)
		end)
		return ok and open or false
	end
	
	local old
	
	local function getCastSpot()
		local localPosition = entitylib.character.RootPart.Position
		local open
	
		for dist = 5, 17, 3 do
			for angle = 0, 330, 30 do
				local spot = localPosition + (CFrame.Angles(0, math.rad(angle), 0).LookVector * dist)
				local ray = workspace:Raycast(spot + Vector3.new(0, 8, 0), Vector3.new(0, -26, 0), store.airRay)
				local check = ray and ray.Position or spot
				local rejected = false
				for _, v in rejects do
					if (v - check).Magnitude < 4 then
						rejected = true
						break
					end
				end
	
				if not ray then
					if not open and not rejected then
						open = spot
					end
				elseif ray.Material == Enum.Material.Water and not rejected then
					return ray.Position
				end
			end
		end
		return open
	end
	
	local function playMinigame()
		local util = bedwars.FishermanUtil
		if not util or util.startingMarkerIncrementSpeed == nil then return end
		local marker, zone
		local deadline = tick() + 3
		repeat
			for _, v in lplr.PlayerGui:GetDescendants() do
				if v.Name == 'Marker' and v.Parent and v.Parent.Name == 'Minigame' then
					local found = v.Parent:FindFirstChild('FishZone')
					if found then
						marker, zone = v, found
						break
					end
				end
			end
			if not marker then task.wait(0.1) end
		until marker or tick() > deadline
		if not marker then return end
	
		local speed, aim = util.startingMarkerIncrementSpeed, 0
		repeat
			if not marker.Parent or not zone.Parent then return end
			if menuOpen() then
				tweenService:Create(marker, TweenInfo.new(util.totalDecaySpeedSec * (marker.Position.X.Scale + marker.Size.X.Scale), Enum.EasingStyle.Linear), {
					Position = UDim2.new(0, 2, 0.5, 0)
				}):Play()
				speed = util.startingMarkerIncrementSpeed
				repeat
					task.wait(0.1)
				until not menuOpen() or not marker.Parent or not AutoFish.Enabled or not Minigame.Enabled
				continue
			end
	
			local width = marker.AbsoluteSize.X
			local center = marker.AbsolutePosition.X + (width / 2)
			local delta = ((zone.AbsolutePosition.X + (zone.AbsoluteSize.X / 2) + aim) - center) / math.max(width, 1)
			if delta > 0.2 then
				tweenService:Create(marker, TweenInfo.new(math.max(speed, util.holdMinimumMarkerIncrementSpeed), Enum.EasingStyle.Linear), {
					Position = UDim2.new(math.min(marker.Position.X.Scale + util.markerIncrementAmount, 1 - marker.Size.X.Scale), 0, 0.5, 0)
				}):Play()
				speed -= 0.01
				task.wait(0.05)
			elseif delta < -0.2 then
				tweenService:Create(marker, TweenInfo.new(util.totalDecaySpeedSec * (marker.Position.X.Scale + marker.Size.X.Scale), Enum.EasingStyle.Linear), {
					Position = UDim2.new(0, 2, 0.5, 0)
				}):Play()
				speed = util.startingMarkerIncrementSpeed
				aim = (math.random() - 0.5) * width * 0.1
				task.wait(Reaction:GetRandomValue())
			else
				local period = 1 / Clicks:GetRandomValue()
				tweenService:Create(marker, TweenInfo.new(math.max(util.startingMarkerIncrementSpeed, util.holdMinimumMarkerIncrementSpeed), Enum.EasingStyle.Linear), {
					Position = UDim2.new(math.min(marker.Position.X.Scale + util.markerIncrementAmount, 1 - marker.Size.X.Scale), 0, 0.5, 0)
				}):Play()
				task.wait(period * (0.35 + (math.random() * 0.25)))
				tweenService:Create(marker, TweenInfo.new(util.totalDecaySpeedSec * (marker.Position.X.Scale + marker.Size.X.Scale), Enum.EasingStyle.Linear), {
					Position = UDim2.new(0, 2, 0.5, 0)
				}):Play()
				speed = util.startingMarkerIncrementSpeed
				aim = (math.random() - 0.5) * width * 0.1
				task.wait(period * (0.35 + (math.random() * 0.25)))
			end
		until not AutoFish.Enabled or not Minigame.Enabled
	end
	
	AutoFish = vape.Categories.Inventory:CreateModule({
		Name = 'AutoFish',
		Function = function(callback)
			if callback then
				old = bedwars.FishingMinigameController.startMinigame
				bedwars.FishingMinigameController.startMinigame = function(...)
					if Minigame.Enabled and MinigameMode.Value == 'Instant' then
						local deadline = tick() + (bedwars.FishermanUtil and bedwars.FishermanUtil.minigameDuration or 10)
						while menuOpen() and tick() < deadline do
							task.wait(0.1)
						end
						task.wait(CompleteDelay:GetRandomValue())
						return select(3, ...)({win = true})
					end
	
					local call = (old or bedwars.FishingMinigameController.startMinigame)(...)
					if Minigame.Enabled then
						task.spawn(playMinigame)
					end
					return call
				end
	
				AutoFish:Clean(bedwars.Handler:Get('FishFound').Remote:Connect(function(data)
					local reroll = #Blacklist.ListEnabled > 0
					for _, v in data.dropData.drops do
						local amount = tonumber(v.amount) or 0
						if Show.Enabled then
							local itemDisplay = bedwars.ItemMeta[v.itemType] and bedwars.ItemMeta[v.itemType].displayName or v.itemType
							notif('AutoFish', `You can get {amount} {itemDisplay:lower()}{amount >= 2 and 's' or ''} on ur next fish`, 20, 'info')
						end
						if not table.find(Blacklist.ListEnabled, v.itemType) then
							reroll = false
						end
					end
	
					if reroll and entitylib.isAlive then
						lplr.Character.Humanoid.Jump = true
					end
				end))
				repeat
					local bait
					for _, v in workspace:GetChildren() do
						if v.Name == 'fisherman_bobber' and v:GetAttribute('ProjectileShooter') == lplr.UserId then
							bait = v
							break
						end
					end
	
					if entitylib.isAlive and Cast.Enabled and (store.hand.tool and store.hand.tool.Name == 'fishing_rod') and not bait and not menuOpen() then
						local spot = getCastSpot()
						if not spot and #rejects > 0 then
							table.clear(rejects)
							spot = getCastSpot()
						end
	
						if spot then
							task.wait(CastDelay:GetRandomValue())
							if AutoFish.Enabled and not menuOpen() then
								local item = bedwars.FishingRodController:getHandItem()
								if item and not bedwars.FishingRodController.projectileHandler and bedwars.FishingRodController:canLaunch() then
									bedwars.FishingRodController:beginHolding(item, nil, bedwars.FishingRodController.aimingMaid, false)
									task.wait()
									local handler = bedwars.FishingRodController.projectileHandler
									if handler then
										local meta = bedwars.ProjectileMeta.fisherman_bobber
										local origin = (bedwars.ProjectileController:getLaunchPosition(item.tool) or entitylib.character.RootPart.Position) + handler.fromPositionOffset
										handler.targetPoint = prediction.SolveTrajectory(origin, meta.launchVelocity, meta.gravitationalAcceleration, spot, Vector3.zero, workspace.Gravity, 0, 0, nil, false, spot, nil, nil, true) or spot
									end
									bedwars.FishingRodController:releaseChargeInput(bedwars.FishingRodController.aimingMaid, function()
										return true
									end, nil)
								end
	
								task.wait(2.5)
								local cast
								for _, v in workspace:GetChildren() do
									if v.Name == 'fisherman_bobber' and v:GetAttribute('ProjectileShooter') == lplr.UserId then
										cast = v
										break
									end
								end
								if not cast or not cast:GetAttribute('WaitingForFish') then
									table.insert(rejects, spot)
								end
							end
						end
					end
					task.wait(0.1)
				until not AutoFish.Enabled
			else
				table.clear(rejects)
				if old then
					bedwars.FishingMinigameController.startMinigame = old
					old = nil
				end
			end
		end,
		Tooltip = 'Fishes for you with the fishing rod'
	})
	
	Blacklist = AutoFish:CreateItemPicker({
		Name = 'Blacklisted loot',
		Multi = true,
		Items = bedwars.itemPickerList(nil, {Relevant = {'fish'}}),
		Default = {'iron'},
		Tooltip = 'Cancels the catch when every drop is blacklisted'
	})
	Show = AutoFish:CreateToggle({
		Name = 'Show loot drops',
		Tooltip = 'Tells you what your next catches will be'
	})
	Minigame = AutoFish:CreateGroup({
		Name = 'Auto Minigame',
		Function = function(callback)
			if MinigameMode and MinigameMode.Object then
				if CompleteDelay and MinigameMode then CompleteDelay.Object.Visible = callback and MinigameMode.Value == 'Instant' end
				if MinigameMode and Reaction then Reaction.Object.Visible = callback and MinigameMode.Value == 'Legit' end
				if Clicks and MinigameMode then Clicks.Object.Visible = callback and MinigameMode.Value == 'Legit' end
			end
		end,
		Default = true,
		Tooltip = 'Automatically completes the minigame'
	})
	MinigameMode = Minigame:CreateDropdown({
		Name = 'Minigame mode',
		List = {'Instant', 'Legit'},
		Darker = true,
		Function = function(value)
			if CompleteDelay.Object then
				CompleteDelay.Object.Visible = Minigame.Enabled and value == 'Instant'
				Reaction.Object.Visible = Minigame.Enabled and value == 'Legit'
				Clicks.Object.Visible = Minigame.Enabled and value == 'Legit'
			end
		end,
		Tooltip = 'Instant wins at once, Legit plays it out'
	})
	CompleteDelay = AutoFish:CreateTwoSlider({
		Name = 'Complete delay',
		Min = 0,
		Max = 25,
		Decimal = 5,
		DefaultMin = 0.1,
		DefaultMax = 0.9,
		Darker = true
	})
	Reaction = AutoFish:CreateTwoSlider({
		Name = 'Reaction',
		Min = 0,
		Max = 1,
		Decimal = 100,
		DefaultMin = 0.06,
		DefaultMax = 0.19,
		Darker = true,
		Visible = false,
		Tooltip = 'How long it takes to react to the fish moving'
	})
	Clicks = AutoFish:CreateTwoSlider({
		Name = 'Clicks',
		Min = 3,
		Max = 20,
		DefaultMin = 8,
		DefaultMax = 13,
		Darker = true,
		Visible = false,
		Suffix = 'cps',
		Tooltip = 'How fast it taps to keep the bar on the fish'
	})
	Cast = AutoFish:CreateGroup({
		Name = 'Auto Cast',
		Function = function(callback)
			if CastDelay.Object then
			end
		end,
		Tooltip = 'Finds a spot to fish and casts there, wherever your camera looks'
	})
	CastDelay = Cast:CreateTwoSlider({
		Name = 'Cast delay',
		Min = 0,
		Max = 5,
		Decimal = 5,
		DefaultMin = 0.3,
		DefaultMax = 1.2,
		Darker = true
	})
	GUI = AutoFish:CreateToggle({
		Name = 'GUI Check',
		Tooltip = 'Waits while a game menu like the shop or your inventory is open'
	})
end)
