run(function()
	TrapDisabler = vape.Categories.Utility:CreateModule({
		Name = "TrapDisabler",
		Tooltip = 'Stops traps reporting you when you walk into them'
	})

	local Traps
	Traps = TrapDisabler:CreateMultiDropdown({
		Name = 'Traps',
		List = {'Snap traps', 'Landmines', 'Teleport blocks', 'Void portals'},
		Default = {'Snap traps', 'Landmines'},
		Tooltip = 'Which traps stop working on you'
	})
	local TrapSnap = setmetatable({}, {__index = function(_, key) if key == 'Enabled' then return Traps:Has('Snap traps') end end})
	local TrapMine = setmetatable({}, {__index = function(_, key) if key == 'Enabled' then return Traps:Has('Landmines') end end})
	local TrapTeleport = setmetatable({}, {__index = function(_, key) if key == 'Enabled' then return Traps:Has('Teleport blocks') end end})
	local TrapPortal = setmetatable({}, {__index = function(_, key) if key == 'Enabled' then return Traps:Has('Void portals') end end})
	store.trapReports = {
		StepOnSnapTrap = TrapSnap,
		TriggerInvisibleLandmine = TrapMine,
		StepOnTeleportBlock = TrapTeleport,
		StepOnVoidPortal = TrapPortal
	}
end)
