run(function()
	local Main = vape.Libraries.mergedModule(kits, {
		Name = 'TerraAimbot',
		Category = 'Aim',
		Tooltip = 'Steers terra blocks at targets, kicks blocks and stomps'
	})

run(function()
    local TerraAimbot
    local Range
    local Mode
    local Sort

    local old

    TerraAimbot = Main:Part({
		Label = 'Aimbot',
        Name = 'TerraAimbot',
        Category = 'Aim',
        Function = function(callback)
            if callback then
                old = bedwars.BlockKickerKitController.getKickBlockProjectileOriginPosition
                local hook
                hook = function(...)
                    if not TerraAimbot.Enabled then return old(...) end
                    local origin, dir = select(2, ...)
                    local plr = entitylib['Entity'.. Mode.Value]({
                        Part = 'RootPart',
                        Range = Range.Value,
                        Origin = origin,
                        Players = true,
                        Wallcheck = true,
                        Sort = sortmethods[Sort.Value]
                    })

                    if plr then
                        local calc = prediction.SolveTrajectory(origin, 100, 20, plr.RootPart.Position, plr.RootPart.Velocity, workspace.Gravity, plr.HipHeight, plr.Jumping and 42.6 or nil, nil, plr.Humanoid.FloorMaterial == Enum.Material.Air or math.abs(plr.RootPart.AssemblyLinearVelocity.Y) > 0.01, plr.RootPart.Position, plr.RootPart, nil, true)

                        if calc then
                            for i, v in debug.getstack(2) do
                                if v == dir then
                                    debug.setstack(2, i, CFrame.lookAt(origin, calc).LookVector)
                                end
                            end
                        end
                    end

                    return old(...)
                end
                bedwars.BlockKickerKitController.getKickBlockProjectileOriginPosition = hook
                TerraAimbot:Clean(function()
                    if bedwars.BlockKickerKitController.getKickBlockProjectileOriginPosition == hook then
                        bedwars.BlockKickerKitController.getKickBlockProjectileOriginPosition = old
                    end
                end)
            end
        end,
        Tooltip = 'Silently steers terra blocks at targets'
    })

    Mode = TerraAimbot:CreateDropdown({
        Name = 'Mode',
        List = {'Position', 'Mouse'},
        Default = 'Mouse'
    })
    local methods = {'Distance', 'Damage'}
    for _, v in sortlist do
        if not table.find(methods, v) then
            table.insert(methods, v)
        end
    end
    Sort = TerraAimbot:CreateDropdown({
        Name = 'Target mode',
        List = methods,
        Tooltip = TARGET_MODE_TOOLTIP
    })
    Range = TerraAimbot:CreateSlider({
        Name = 'Range',
        Min = 1,
        Max = 1000,
        Default = 1000,
        Suffix = function(val)
            return val <= 1 and 'studs' or 'stud'
        end
    })
end)

run(function()
	local util = vape.Libraries.bedwarsutil
	local AutoBlockKicker
	local Kick
	local KickRange
	local KickDelay
	local Stomp
	local StompTargets
	local StompRange
	local StompDelay
	local nextKick, nextStomp = 0, 0

	local function show(option, visible)
		if option and option.Object then option.Object.Visible = visible end
	end

	AutoBlockKicker = Main:Part({
		Label = 'Auto kick and stomp',
		Name = 'AutoBlockKicker',
		Function = function(callback)
			if callback then
				nextKick, nextStomp = 0, 0
				repeat
					if entitylib.isAlive and util.IsKit('block_kicker') then
						if Kick.Enabled and tick() >= nextKick and util.Ability.Ready('BLOCK_KICK') then
							local target = entitylib.EntityPosition({
								Origin = entitylib.character.RootPart.Position,
								Range = KickRange.Value,
								Part = 'RootPart',
								Players = true,
								Wallcheck = true
							})
							if target then
								nextKick = tick() + KickDelay.Value
								util.Ability.Use('BLOCK_KICK')
							end
						end
						if Stomp.Enabled and tick() >= nextStomp and util.Ability.Ready('BLOCK_STOMP') then
							local found = #entitylib.AllPosition({
								Origin = entitylib.character.RootPart.Position,
								Range = StompRange.Value,
								Part = 'RootPart',
								Players = true
							})
							if found >= StompTargets.Value then
								nextStomp = tick() + StompDelay.Value
								util.Ability.Use('BLOCK_STOMP')
							end
						end
					end
					task.wait(0.1)
				until not AutoBlockKicker.Enabled
			end
		end,
		Tooltip = 'Kicks blocks at enemies and stomps when surrounded'
	})
	Kick = AutoBlockKicker:CreateToggle({
		Name = 'Auto kick',
		Default = true,
		Function = function(callback)
			show(KickRange, callback)
			show(KickDelay, callback)
		end
	})
	KickRange = AutoBlockKicker:CreateSlider({
		Name = 'Kick range',
		Min = 1,
		Max = 60,
		Default = 25,
		Darker = true,
		Suffix = util.Studs
	})
	KickDelay = AutoBlockKicker:CreateSlider({
		Name = 'Kick delay',
		Min = 0.1,
		Max = 5,
		Default = 0.5,
		Decimal = 10,
		Darker = true,
		Suffix = util.Seconds
	})
	Stomp = AutoBlockKicker:CreateToggle({
		Name = 'Auto stomp',
		Default = true,
		Function = function(callback)
			show(StompTargets, callback)
			show(StompRange, callback)
			show(StompDelay, callback)
		end
	})
	StompTargets = AutoBlockKicker:CreateSlider({
		Name = 'Stomp targets',
		Min = 1,
		Max = 8,
		Default = 2,
		Darker = true
	})
	StompRange = AutoBlockKicker:CreateSlider({
		Name = 'Stomp range',
		Min = 1,
		Max = 60,
		Default = 20,
		Darker = true,
		Suffix = util.Studs
	})
	StompDelay = AutoBlockKicker:CreateSlider({
		Name = 'Stomp delay',
		Min = 0.1,
		Max = 5,
		Default = 0.5,
		Decimal = 10,
		Darker = true,
		Suffix = util.Seconds
	})
end)

end)
