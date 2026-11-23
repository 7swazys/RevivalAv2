run(function()
	local BedAlarm
	local Range
	local Banner
	local Sound
	local Arrow
	local Notify
	local HighlightOpt
	local PearlOpt
	local Volume
	local highlights = {}
	local orbThreat = {}
	local baseVolume
	local uipallet = vape.Libraries.uipallet
	local soundService = cloneref(game:GetService('SoundService'))
	local ALARM = Color3.fromRGB(255, 90, 90)
	local inside = {}
	local threats = {}
	local ui = {}
	local shownText, bannerOn, arrowOn, turned
	local soundAt = 0

	local function ownBed()
		local container = workspace:FindFirstChild('BedsContainer')
		local mine = lplr.Team and lplr.Team.Name
		if not (container and mine) or mine == 'Spectators' then return nil end
		for _, bed in container:GetChildren() do
			if bed:GetAttribute('Team') == mine then
				local box = bed:FindFirstChild('BedHitbox')
				if box and box:IsA('BasePart') then
					return box
				end
			end
		end
	end

	local function setBanner(text)
		local on = text ~= nil and Banner.Enabled
		if on ~= bannerOn then
			bannerOn = on
			if ui.Banner then
				ui.Banner.Visible = on
			end
		end
		if on and text ~= shownText and ui.Label then
			shownText = text
			ui.Label.Text = text
		end
	end

	local function setArrow(on)
		on = on and Arrow.Enabled
		if on ~= arrowOn then
			arrowOn = on
			if ui.Arrow then
				ui.Arrow.Visible = on
			end
		end
	end

	local function alarm()
		if not Sound.Enabled or tick() - soundAt < 3 then return end
		soundAt = tick()
		local sound = ui.Sound
		if not sound then
			local source = soundService:FindFirstChild('BedBreakWarning')
			sound = source and source:IsA('Sound') and source:Clone() or Instance.new('Sound')
			if sound.SoundId == '' then
				sound.SoundId = 'rbxassetid://9114221327'
			end
			sound.Name = 'AetherBedAlarm'
			sound.Parent = soundService
			BedAlarm:Clean(sound)
			ui.Sound = sound
			baseVolume = sound.Volume
		end
		sound.Volume = (baseVolume or 0.5) * Volume.Value
		sound:Play()
	end

	local function build()
		local banner = Instance.new('Frame')
		banner.Name = 'BedAlarm'
		banner.Size = UDim2.fromOffset(300, 34)
		banner.Position = UDim2.new(0.5, -150, 0, 124)
		banner.BackgroundColor3 = uipallet.Main
		banner.BackgroundTransparency = 0.1
		banner.BorderSizePixel = 0
		banner.Visible = false
		banner.Parent = vape.gui
		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(0, 5)
		corner.Parent = banner
		local stroke = Instance.new('UIStroke')
		stroke.Color = ALARM
		stroke.Thickness = 1.5
		stroke.Parent = banner
		local label = Instance.new('TextLabel')
		label.Size = UDim2.new(1, -16, 1, 0)
		label.Position = UDim2.fromOffset(8, 0)
		label.BackgroundTransparency = 1
		label.TextColor3 = ALARM
		label.TextSize = 14
		label.TextTruncate = Enum.TextTruncate.AtEnd
		label.FontFace = uipallet.Font
		label.Text = ''
		label.Parent = banner
		BedAlarm:Clean(banner)

		local arrow = Instance.new('ImageLabel')
		arrow.Name = 'BedAlarmArrow'
		arrow.Size = UDim2.fromOffset(256, 256)
		arrow.Position = UDim2.fromScale(0.5, 0.5)
		arrow.AnchorPoint = Vector2.new(0.5, 0.5)
		arrow.BackgroundTransparency = 1
		arrow.Image = vape.Libraries.getcustomasset('aetherv2/assets/new/arrowmodule.png')
		arrow.ImageColor3 = ALARM
		arrow.Visible = false
		arrow.Parent = vape.gui
		BedAlarm:Clean(arrow)

		ui.Banner, ui.Label, ui.Arrow = banner, label, arrow
		shownText, bannerOn, arrowOn, turned = nil, false, false, nil
	end

	local function highlight(list)
		local want = {}
		if HighlightOpt.Enabled then
			for _, v in list do
				local char = v.Player.Character
				if char then want[char] = true end
			end
		end
		for char, light in highlights do
			if not want[char] then
				light:Destroy()
				highlights[char] = nil
			end
		end
		for char in want do
			if not highlights[char] then
				local light = Instance.new('Highlight')
				light.Adornee = char
				light.FillColor = ALARM
				light.OutlineColor = ALARM
				light.FillTransparency = 0.6
				light.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				light.Parent = gameCamera
				highlights[char] = light
			end
		end
	end

	local function orbLands(origin, velocity, bed)
		local data = bedfight.ProjectilesData and bedfight.ProjectilesData.Teleorb
		local gravity = data and typeof(data.Gravity) == 'Vector3' and data.Gravity or Vector3.new(0, -100, 0)
		local best = math.huge
		for t = 0, 6, 0.05 do
			local point = origin + velocity * t + gravity * (t * t / 2)
			best = math.min(best, (point - bed).Magnitude)
			if point.Y < bed.Y - 40 then break end
		end
		return best <= Range.Value
	end

	local function scan()
		local box = ownBed()
		table.clear(threats)
		for player, untilAt in orbThreat do
			if untilAt < tick() then orbThreat[player] = nil end
		end
		if box then
			local bed = box.Position
			for _, ent in entitylib.List do
				local player = ent.Player
				if player and ent.Targetable and ent.RootPart and ent.Health > 0 and not (player.Team and player.Team.Name == 'Spectators') then
					local distance = (ent.RootPart.Position - bed).Magnitude
					if distance <= Range.Value then
						table.insert(threats, {Player = player, Distance = distance})
					end
				end
			end
			for player in orbThreat do
				local listed = false
				for _, v in threats do
					if v.Player == player then listed = true break end
				end
				local root = not listed and player.Character and player.Character:FindFirstChild('HumanoidRootPart')
				if root then
					table.insert(threats, {Player = player, Distance = (root.Position - bed).Magnitude})
				end
			end
			table.sort(threats, function(a, b)
				return a.Distance < b.Distance
			end)
		end
		highlight(threats)

		local fresh = false
		local seen = {}
		for _, v in threats do
			seen[v.Player] = true
			if not inside[v.Player] then
				fresh = true
				if Notify.Enabled then
					notif('BedAlarm', v.Player.Name..' is near your bed ('..math.floor(v.Distance)..' studs)', 3, 'warning')
				end
			end
		end
		table.clear(inside)
		for player in seen do
			inside[player] = true
		end
		if fresh then
			alarm()
		end

		if #threats == 0 then
			setBanner(nil)
			setArrow(false)
			return nil
		end
		local names = {}
		for i, v in threats do
			if i > 3 then
				table.insert(names, '+'..(#threats - 3))
				break
			end
			table.insert(names, v.Player.Name..' '..math.floor(v.Distance))
		end
		setBanner('Near your bed: '..table.concat(names, ', '))
		return box
	end

	BedAlarm = vape.Categories.Utility:CreateModule({
		Name = 'BedAlarm',
		Function = function(callback)
			if callback then
				build()
				local remote = replicatedStorage:FindFirstChild('Remotes')
				remote = remote and remote:FindFirstChild('ReplicateProjectile')
				if remote then
					BedAlarm:Clean(remote.OnClientEvent:Connect(function(userId, _, name, origin, speed, unit)
						if not PearlOpt.Enabled or name ~= 'Teleorb' or userId == lplr.UserId then return end
						if typeof(origin) ~= 'Vector3' or typeof(unit) ~= 'Vector3' or type(speed) ~= 'number' then return end
						local player = playersService:GetPlayerByUserId(userId)
						if not player or (player.Team and lplr.Team and player.Team == lplr.Team) then return end
						local bed = ownBed()
						if bed and orbLands(origin, unit * speed, bed.Position) then
							if not orbThreat[player] and Notify.Enabled then
								notif('BedAlarm', player.Name..' threw a teleorb at your bed', 3, 'warning')
							end
							orbThreat[player] = tick() + 4
							soundAt = 0
							alarm()
						end
					end))
				end
				local box
				BedAlarm:Clean(runService.RenderStepped:Connect(function()
					if not (box and arrowOn ~= nil and Arrow.Enabled and #threats > 0 and box.Parent) then
						if arrowOn then
							setArrow(false)
						end
						return
					end
					local _, visible = gameCamera:WorldToScreenPoint(box.Position)
					setArrow(not visible)
					if visible then return end
					local dir = CFrame.lookAlong(gameCamera.CFrame.Position, gameCamera.CFrame.LookVector * Vector3.new(1, 0, 1)):PointToObjectSpace(box.Position)
					local rotation = math.floor(math.deg(math.atan2(dir.Z, dir.X)) * 2 + 0.5) / 2
					if rotation ~= turned then
						turned = rotation
						ui.Arrow.Rotation = rotation
					end
				end))
				repeat
					box = scan()
					task.wait(0.2)
				until not BedAlarm.Enabled
			else
				table.clear(inside)
				table.clear(threats)
				table.clear(ui)
				table.clear(orbThreat)
				for _, light in highlights do
					light:Destroy()
				end
				table.clear(highlights)
			end
		end,
		Tooltip = 'Warns you when an enemy gets close to your bed'
	})
	Range = BedAlarm:CreateSlider({
		Name = 'Range',
		Min = 10,
		Max = 100,
		Default = 30,
		Suffix = function(value)
			return value == 1 and 'stud' or 'studs'
		end,
		Tooltip = 'How close to your bed an enemy has to be'
	})
	local BannerState
	local BannerChanged = function()
			bannerOn, shownText = nil, nil
		end
	local Alerts
	Alerts = BedAlarm:CreateMultiDropdown({
		Name = 'Alerts',
		List = {'Banner', 'Sound', 'Arrow', 'Notification'},
		Default = {'Banner', 'Sound', 'Arrow'},
		Function = function()
			local on = Alerts:Has('Banner')
			if BannerState ~= on then
				BannerState = on
				BannerChanged(on)
			end
		end,
		Tooltip = 'How you are told someone is at your bed'
	})
	BannerState = Alerts:Has('Banner')
	Banner = setmetatable({}, {__index = function(_, key) if key == 'Enabled' then return Alerts:Has('Banner') end end})
	Sound = setmetatable({}, {__index = function(_, key) if key == 'Enabled' then return Alerts:Has('Sound') end end})
	Arrow = setmetatable({}, {__index = function(_, key) if key == 'Enabled' then return Alerts:Has('Arrow') end end})
	Notify = setmetatable({}, {__index = function(_, key) if key == 'Enabled' then return Alerts:Has('Notification') end end})
	HighlightOpt = BedAlarm:CreateToggle({
		Name = 'Highlight intruders',
		Default = true,
		Tooltip = 'Highlights enemies near your bed through walls'
	})
	PearlOpt = BedAlarm:CreateToggle({
		Name = 'Pearl detection',
		Default = true,
		Tooltip = 'Also warns when an enemy teleorb is heading for your bed'
	})
	Volume = BedAlarm:CreateSlider({
		Name = 'Volume multiplier',
		Min = 0.1,
		Max = 2,
		Default = 1,
		Decimal = 100
	})
end)
