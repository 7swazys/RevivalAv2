run(function()

    local util = vape.Libraries.bedwarsutil
    local AutoRelease
    local Percentage
    local Delay

    local launchHook, last = nil, 0
    local charge = 0

    local function canRelease()
	if type(mouse1click) ~= 'function' then return false end
	local focused = (isrbxactive or iswindowactive)
	if type(focused) == 'function' and not focused() then return false end
	if inputService:GetFocusedTextBox() then return false end
	return not vape.gui.ScaledGui.ClickGui.Visible
    end

    AutoRelease = vape.Categories.Utility:CreateModule({
	Name = 'AutoRelease',
	Function = function(call)
		if call then
			if type(mouse1click) ~= 'function' then
				notif('AutoRelease', 'Your executor has no mouse1click, so AutoRelease cannot let go for you.', 6, 'warning')
				AutoRelease:Toggle()
				return
			end
			launchHook = bedwars.ProjectileLaunchHook:Add('AutoRelease', 20, function(nextLaunch, ...)
				local projmeta = select(2, ...)
				local multiplier = type(projmeta) == 'table' and tonumber(projmeta.velocityMultiplier)
				if multiplier then
					charge = multiplier * 100
					last = os.clock() + 0.1
				end

				return nextLaunch(...)
			end)

			repeat
				if last > os.clock() and charge >= Percentage.Value then
					task.wait(Delay.Value)
					if AutoRelease.Enabled and canRelease() then
						mouse1click()
					end
					task.wait(0.2)
				end
				task.wait()
			until not AutoRelease.Enabled
		else
			if launchHook then
				launchHook()
				launchHook = nil
			end
		end
	end,
        Tooltip = 'Releases your shot at the set charge'
    })

    Percentage = AutoRelease:CreateSlider({
	Name = 'Percentage',
	Min = 0,
	Max = 100,
	Suffix = '%',
	Default = 100,
    })
    Delay = AutoRelease:CreateSlider({
	Name = 'Release delay',
	Min = 0,
	Max = 5,
	Default = 0.5,
	Decimal = 10,
	Suffix = util.Seconds,
    })
end)
