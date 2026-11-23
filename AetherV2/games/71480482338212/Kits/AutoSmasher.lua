run(function()
	local AutoSmasher
	local Targets, Range, Count, Switch, SwitchBack, Notify
	local NAME = 'AutoSmasher'
	local busy, gen = false, 0

	local function cooldown(name)
		local data = bedfight.SwordsData and bedfight.SwordsData[name]
		return (type(data) == 'table' and data.AbilityCooldown or 8) + 0.1
	end

	local function smash(name, held, target)
		busy = true
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
				if gen ~= my or heldName() ~= name then
					busy = false
					return
				end
				task.wait(0.05)
				if gen ~= my then return end
				if not entitylib.isAlive then
					busy = false
					return
				end
			end
			if target.RootPart and target.RootPart.Parent then
				kit.Turn(target.RootPart.Position)
			end
			kit.Fire(NAME, 'Smash', cooldown(name), 1.5)
			if not held and SwitchBack.Enabled and previous and previous ~= name then
				task.wait(1.2)
				if gen == my and heldName() == name then
					store.hotbarEquip(previous)
				end
			end
			if gen == my then busy = false end
		end)
	end

	AutoSmasher = vape.Categories.Kits:CreateModule({
		Name = NAME,
		Category = 'Ability',
		Function = function(callback)
			busy, gen = false, gen + 1
			if not callback then return end
			local kit = store.kit
			if not kit then return end
			kit.Notify[NAME] = Notify
			local echo = kit.Remote('Smash')
			if echo then
				AutoSmasher:Clean(echo.OnClientEvent:Connect(function(position)
					if typeof(position) ~= 'Vector3' or not entitylib.isAlive then return end
					if kit.Pending[NAME] and (position - entitylib.character.RootPart.Position).Magnitude < 20 then
						kit.Confirm(NAME)
					end
				end))
			end
			local nextAt = 0
			AutoSmasher:Clean(runService.Heartbeat:Connect(function()
				local now = tick()
				if busy or now < nextAt then return end
				nextAt = now + 0.1
				if kit.Value() ~= 'Smasher_3' or not entitylib.isAlive or not kit.Enabled() then return end
				local name, held = kit.Weapon('Smash')
				if not name or (not held and not Switch.Enabled) then return end
				if not kit.Ready(NAME, cooldown(name)) then return end
				local found = kit.Targets(Targets, Range.Value, Count.Value)
				if #found >= Count.Value then
					smash(name, held, found[1])
				end
			end))
		end,
		Tooltip = 'Uses the Smasher mace smash when enemies are around you'
	})
	Targets = AutoSmasher:CreateTargets({Players = true, Walls = true})
	Range = AutoSmasher:CreateSlider({
		Name = 'Range',
		Min = 4,
		Max = 15,
		Default = 13,
		Suffix = function(val) return val == 1 and 'stud' or 'studs' end,
		Tooltip = 'How far away an enemy can be'
	})
	Count = AutoSmasher:CreateSlider({
		Name = 'Enemies',
		Min = 1,
		Max = 5,
		Default = 1,
		Tooltip = 'How many enemies have to be in range'
	})
	Switch = AutoSmasher:CreateGroup({
		Name = 'Auto switch',
		Tooltip = 'Takes the mace out of your hotbar when you hold something else'
	})
	SwitchBack = Switch:CreateToggle({
		Name = 'Switch back',
		Default = true,
		Tooltip = 'Puts back what you held before once the smash is done'
	})
	Notify = AutoSmasher:CreateToggle({
		Name = 'Notify',
		Tooltip = 'Shows a notification each time the ability is used'
	})
end)
