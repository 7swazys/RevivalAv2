run(function()
	local AutoRhino
	local Targets, Distance, Steer, VoidCheck, Notify
	local NAME = 'AutoRhino'
	local COOLDOWN = 14
	local CHARGE = 4.2
	local FLAT = Vector3.new(1, 0, 1)
	local state = {Target = nil, Seen = false, Was = false, Until = 0}

	local function charging()
		local character = lplr.Character
		return character ~= nil and character:GetAttribute('Charging') == true
	end

	local function stop()
		if state.Target then
			store.kit.StopSteer()
		end
		state.Target, state.Until = nil, 0
	end

	AutoRhino = vape.Categories.Kits:CreateModule({
		Name = NAME,
		Category = 'Ability',
		Function = function(callback)
			if not callback then
				if store.kit then stop() end
				return
			end
			local kit = store.kit
			if not kit then return end
			kit.Notify[NAME] = Notify
			state.Was = false
			local nextAt = 0
			AutoRhino:Clean(runService.Heartbeat:Connect(function()
				local now = tick()
				local on = charging()
				if on and not state.Was then
					kit.Confirm(NAME)
					state.Seen = true
				end
				state.Was = on
				if state.Target then
					local alive = state.Target.RootPart and state.Target.RootPart.Parent and state.Target.Health > 0
					if not alive or now > state.Until or (state.Seen and not on) or (not state.Seen and now > state.Until - CHARGE + 1) then
						stop()
					end
				end
				if now < nextAt then return end
				nextAt = now + 0.1
				if on or kit.Value() ~= 'Rhino' or not kit.Ready(NAME, COOLDOWN) then return end
				local root = entitylib.character.RootPart
				local target = kit.Targets(Targets, Distance.ValueMax, 1)[1]
				if not target then return end
				local delta = target.RootPart.Position - root.Position
				local flat = delta * FLAT
				if flat.Magnitude < Distance.ValueMin or math.abs(delta.Y) > 8 then return end
				if VoidCheck.Enabled and not (kit.Ground(target.RootPart.Position, 30) and kit.Ground(root.Position + flat * 0.5, 30)) then return end
				kit.Turn(target.RootPart.Position)
				if Steer.Enabled then
					state.Target, state.Seen, state.Until = target, false, now + CHARGE
					kit.Steer(function()
						local ent = state.Target
						return ent and ent.RootPart and ent.RootPart.Position or nil
					end, CHARGE)
				end
				kit.Fire(NAME, 'Charge', COOLDOWN, 1.5)
			end))
		end,
		Tooltip = 'Uses the Rhino charge on enemies in range and keeps it pointed at them'
	})
	Targets = AutoRhino:CreateTargets({Players = true, Walls = true})
	Distance = AutoRhino:CreateTwoSlider({
		Name = 'Charge distance',
		Min = 4,
		Max = 40,
		DefaultMin = 8,
		DefaultMax = 30,
		Suffix = function(val) return val == 1 and 'stud' or 'studs' end,
		Tooltip = 'How far away an enemy has to be to charge at them'
	})
	Steer = AutoRhino:CreateToggle({
		Name = 'Steer',
		Default = true,
		Tooltip = 'Turns your camera to keep the charge on the target until it ends'
	})
	VoidCheck = AutoRhino:CreateToggle({
		Name = 'Void check',
		Default = true,
		Tooltip = 'Only charges when there is ground between you and the target'
	})
	Notify = AutoRhino:CreateToggle({
		Name = 'Notify',
		Tooltip = 'Shows a notification each time the ability is used'
	})
end)
