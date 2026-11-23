run(function()
	local AutoSpecter
	local Targets, Gap, Distance, Escape, EscapeHealth, EscapeRange, VoidCheck, Notify
	local NAME = 'AutoSpecter'
	local COOLDOWN = 10
	local FLAT = Vector3.new(1, 0, 1)
	local remote

	local function safe(from, dir)
		if not VoidCheck.Enabled then return true end
		local kit = store.kit
		return kit.Ground(from + dir * 14, 40) or kit.Ground(from + dir * 20, 40)
	end

	local function leap(at)
		local kit = store.kit
		kit.Turn(at)
		kit.Fire(NAME, 'Leap', COOLDOWN, remote and 1.5 or nil)
	end

	AutoSpecter = vape.Categories.Kits:CreateModule({
		Name = NAME,
		Category = 'Ability',
		Function = function(callback)
			if not callback then return end
			local kit = store.kit
			if not kit then return end
			kit.Notify[NAME] = Notify
			remote = kit.Remote('Leap')
			if remote then
				AutoSpecter:Clean(remote.OnClientEvent:Connect(function(userId)
					if userId == lplr.UserId then kit.Confirm(NAME) end
				end))
			end
			local nextAt = 0
			AutoSpecter:Clean(runService.Heartbeat:Connect(function()
				local now = tick()
				if now < nextAt then return end
				nextAt = now + 0.1
				if kit.Value() ~= 'Specter' or not kit.Ready(NAME, COOLDOWN) then return end
				local root = entitylib.character.RootPart
				if Escape.Enabled and kit.Health() * 100 <= EscapeHealth.Value then
					local threat = kit.Targets(Targets, EscapeRange.Value, 1)[1]
					if threat then
						local away = (root.Position - threat.RootPart.Position) * FLAT
						if away.Magnitude > 0.1 and safe(root.Position, away.Unit) then
							leap(root.Position + away.Unit * 10)
						end
						return
					end
				end
				if not Gap.Enabled then return end
				local target = kit.Targets(Targets, Distance.ValueMax, 1)[1]
				if not target then return end
				local delta = target.RootPart.Position - root.Position
				local flat = delta * FLAT
				if flat.Magnitude < Distance.ValueMin or math.abs(delta.Y) > 10 then return end
				if safe(root.Position, flat.Unit) then
					leap(target.RootPart.Position)
				end
			end))
		end,
		Tooltip = 'Uses the Specter leap to close in on enemies or get away at low health'
	})
	Targets = AutoSpecter:CreateTargets({Players = true, Walls = true})
	Gap = AutoSpecter:CreateGroup({
		Name = 'Gap close',
		Default = true,
		Tooltip = 'Leaps at an enemy who is just out of reach'
	})
	Distance = Gap:CreateTwoSlider({
		Name = 'Leap distance',
		Min = 4,
		Max = 40,
		DefaultMin = 10,
		DefaultMax = 25,
		Suffix = function(val) return val == 1 and 'stud' or 'studs' end,
		Tooltip = 'How far away an enemy has to be to leap at them'
	})
	Escape = AutoSpecter:CreateGroup({
		Name = 'Escape',
		Default = true,
		Tooltip = 'Leaps away from the nearest enemy when your health is low'
	})
	EscapeHealth = Escape:CreateSlider({
		Name = 'Escape health',
		Min = 5,
		Max = 90,
		Default = 30,
		Suffix = '%',
		Tooltip = 'Health at or below which you leap away'
	})
	EscapeRange = Escape:CreateSlider({
		Name = 'Escape range',
		Min = 4,
		Max = 30,
		Default = 12,
		Suffix = function(val) return val == 1 and 'stud' or 'studs' end,
		Tooltip = 'How close an enemy has to be before you leap away'
	})
	VoidCheck = AutoSpecter:CreateToggle({
		Name = 'Void check',
		Default = true,
		Tooltip = 'Only leaps when there is ground where you would land'
	})
	Notify = AutoSpecter:CreateToggle({
		Name = 'Notify',
		Tooltip = 'Shows a notification each time the ability is used'
	})
end)
