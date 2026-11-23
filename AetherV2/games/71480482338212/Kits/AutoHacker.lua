run(function()
	local AutoHacker
	local Targets, Range, Count, Notify
	local NAME = 'AutoHacker'
	local COOLDOWN = 13

	AutoHacker = vape.Categories.Kits:CreateModule({
		Name = NAME,
		Category = 'Ability',
		Function = function(callback)
			if not callback then return end
			local kit = store.kit
			if not kit then return end
			kit.Notify[NAME] = Notify
			local echo = kit.Remote('Hack')
			if echo then
				AutoHacker:Clean(echo.OnClientEvent:Connect(function(_, hacker)
					if hacker == lplr then kit.Confirm(NAME) end
				end))
			end
			local nextAt = 0
			AutoHacker:Clean(runService.Heartbeat:Connect(function()
				local now = tick()
				if now < nextAt then return end
				nextAt = now + 0.1
				if kit.Value() ~= 'Hacker' or not kit.Ready(NAME, COOLDOWN) then return end
				if #kit.Targets(Targets, Range.Value, Count.Value) >= Count.Value then
					kit.Fire(NAME, 'Hack', COOLDOWN, echo and 1.5 or nil)
				end
			end))
		end,
		Tooltip = 'Hacks nearby enemies to lock their abilities'
	})
	Targets = AutoHacker:CreateTargets({Players = true, Walls = true})
	Range = AutoHacker:CreateSlider({
		Name = 'Range',
		Min = 4,
		Max = 40,
		Default = 20,
		Suffix = function(val) return val == 1 and 'stud' or 'studs' end,
		Tooltip = 'How far away an enemy can be'
	})
	Count = AutoHacker:CreateSlider({
		Name = 'Enemies',
		Min = 1,
		Max = 5,
		Default = 1,
		Tooltip = 'How many enemies have to be in range'
	})
	Notify = AutoHacker:CreateToggle({
		Name = 'Notify',
		Tooltip = 'Shows a notification each time the ability is used'
	})
end)
