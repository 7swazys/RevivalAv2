run(function()

    local util = vape.Libraries.bedwarsutil
    local PlayerAttach
    local Range
    local Targets

    local rayCheck = RaycastParams.new()
    rayCheck.FilterType = Enum.RaycastFilterType.Exclude

    PlayerAttach = vape.Categories.Blatant:CreateModule({
        Name = 'PlayerAttach',
        Tooltip = 'Sticks you to the nearest target',
        Function = function(call)
            if call then
                local plr, nextScan = nil, 0
                local function sortHealth(a, b)
                    return a.Entity.Health < b.Entity.Health
                end
                repeat
                    if entitylib.isAlive then
                        if tick() >= nextScan then
                            nextScan = tick() + 0.1
                            plr = entitylib.AllPosition({
                                Range = Range.Value,
                                Wallcheck = Targets.Walls.Enabled or nil,
                                Part = 'RootPart',
                                Players = Targets.Players.Enabled,
                                Priority = Targets.Priority and Targets.Priority.Value,
                                NPCs = Targets.NPCs.Enabled,
                                Limit = 1,
                                Sort = sortHealth
                            })[1]
                        end
                        local root = entitylib.character.RootPart
                        if plr and plr.RootPart and plr.RootPart.Parent and root and isnetworkowner(root) then
                            rayCheck.FilterDescendantsInstances = {plr.RootPart.Parent, lplr.Character}

                            root.AssemblyLinearVelocity = Vector3.new(0, root.Size.Y / 2 + entitylib.character.Humanoid.HipHeight + 0.25 * 3, 0)
                            root.CFrame = plr.RootPart.CFrame + (not workspace:Raycast(plr.RootPart.Position, plr.RootPart.CFrame.LookVector, rayCheck) and (plr.RootPart.CFrame.LookVector * 1.4) or Vector3.zero)
                        end
                    else
                        plr = nil
                    end
                    task.wait()
                until not PlayerAttach.Enabled
            end
        end
    })

    Targets = PlayerAttach:CreateTargets({
        Players = true,
        NPCs = true
    })

    Range = PlayerAttach:CreateSlider({
        Name = 'Range',
        Min = 1,
        Max = 35,
        Default = 23,
        Suffix = util.Studs
    })
end)
