run(function()
	local AutoBrute
	local Targets, Distance, Switch, SwitchBack, Notify
	local NAME = 'AutoBrute'
	local FLAT = Vector3.new(1, 0, 1)
	local AIM = 1.5
	local busy, gen = false, 0
	local throw = {Target = nil, Name = nil}

	local function data(name)
		local entry = bedfight.SwordsData and bedfight.SwordsData[name]
		return type(entry) == 'table' and entry or nil
	end

	local function cooldown(name)
		local entry = data(name)
		return (entry and entry.AbilityCooldown or 9) + 0.1
	end

	local function aimAt()
		local ent = throw.Target
		if not (ent and ent.RootPart and ent.RootPart.Parent and entitylib.isAlive) then return nil end
		local root = entitylib.character.RootPart
		local entry = data(throw.Name)
		local speed = entry and (entry.ThrowDistance or 33) / (entry.ThrowDuration or 0.5) or 66
		local distance = (ent.RootPart.Position - root.Position).Magnitude
		return ent.RootPart.Position + store.motion(ent) * FLAT * (distance / speed + math.min(lplr:GetNetworkPing(), 0.3))
	end

	local function pitch()
		local at = aimAt()
		if not at then return nil end
		local origin = entitylib.character.RootPart.Position + Vector3.new(0, 2, 0)
		local dir = at - origin
		if dir.Magnitude < 0.5 then return nil end
		return math.asin(math.clamp(dir.Unit.Y, -1, 1))
	end

	local function finish(my)
		if gen ~= my then return end
		local kit = store.kit
		if kit then
			kit.StopFace()
			kit.StopSteer()
		end
		throw.Target = nil
	end

	local function start(name, held, target)
		busy = true
		gen += 1
		local my = gen
		task.spawn(function()
			local kit = store.kit
			local previous = heldName()
			if not held then
				if not store.hotbarEquip(name) then
					busy = false
					return
				end
				local deadline = tick() + 1
				repeat task.wait() until gen ~= my or (heldName() == name and serverTool() == name) or tick() > deadline
				if gen ~= my then return end
				if heldName() ~= name then
					busy = false
					return
				end
				task.wait(0.05)
				if gen ~= my then return end
			end
			throw.Target, throw.Name = target, name
			kit.Face(aimAt, AIM)
			kit.Steer(aimAt, AIM, pitch)
			kit.Fire(NAME, 'ThrowSword', cooldown(name), 1.5)
			local deadline = tick() + AIM
			repeat task.wait() until gen ~= my or not throw.Target or tick() > deadline
			finish(my)
			if gen ~= my then return end
			if not held and SwitchBack.Enabled and previous and previous ~= name then
				task.wait(0.6)
				if gen == my and heldName() == name then
					store.hotbarEquip(previous)
				end
			end
			if gen == my then busy = false end
		end)
	end

	AutoBrute = vape.Categories.Kits:CreateModule({
		Name = NAME,
		Category = 'Ability',
		Function = function(callback)
			finish(gen)
			busy, gen = false, gen + 1
			if not callback then return end
			local kit = store.kit
			if not kit then return end
			kit.Notify[NAME] = Notify
			local signal = bedfight.Signals and bedfight.Signals.ThrowSword
			if type(signal) == 'table' and type(signal.Connect) == 'function' then
				local ok, conn = pcall(signal.Connect, signal, function(owner, name)
					if owner == nil and name ~= nil and throw.Target then
						kit.Confirm(NAME)
						throw.Target = nil
					end
				end)
				if ok and conn then
					AutoBrute:Clean(function()
						pcall(function() conn:Disconnect() end)
					end)
				end
			end
			local nextAt = 0
			AutoBrute:Clean(runService.Heartbeat:Connect(function()
				local now = tick()
				if busy or now < nextAt then return end
				nextAt = now + 0.1
				if kit.Value() ~= 'Brute' or not entitylib.isAlive or not kit.Enabled() then return end
				local name, held = kit.Weapon('Throw')
				if not name or (not held and not Switch.Enabled) then return end
				if not kit.Ready(NAME, cooldown(name)) then return end
				local root = entitylib.character.RootPart
				for _, ent in kit.Targets(Targets, Distance.ValueMax, 3) do
					local delta = ent.RootPart.Position - root.Position
					if (delta * FLAT).Magnitude >= Distance.ValueMin and math.abs(delta.Y) <= 12 then
						start(name, held, ent)
						return
					end
				end
			end))
		end,
		Tooltip = 'Throws the Brute battle axe at enemies outside sword reach'
	})
	Targets = AutoBrute:CreateTargets({Players = true, Walls = true})
	Distance = AutoBrute:CreateTwoSlider({
		Name = 'Throw distance',
		Min = 4,
		Max = 36,
		DefaultMin = 6,
		DefaultMax = 30,
		Suffix = function(val) return val == 1 and 'stud' or 'studs' end,
		Tooltip = 'How far away an enemy has to be to throw at them'
	})
	Switch = AutoBrute:CreateGroup({
		Name = 'Auto switch',
		Tooltip = 'Takes the battle axe out of your hotbar when you hold something else'
	})
	SwitchBack = Switch:CreateToggle({
		Name = 'Switch back',
		Default = true,
		Tooltip = 'Puts back what you held before once the axe is thrown'
	})
	Notify = AutoBrute:CreateToggle({
		Name = 'Notify',
		Tooltip = 'Shows a notification each time the ability is used'
	})
end)
