run(function()
    local Sprint
    local old
    local hook

    local SPRINT_WALK_SPEED = 20

    local function isSprinting(controller)
        return type(controller.isSprinting) == 'function' and controller:isSprinting()
    end

    local function assertSprint()
        local controller = bedwars.SprintController
        if not controller or type(controller.startSprinting) ~= 'function' then return end
        local character = entitylib.isAlive and entitylib.character
        local humanoid = character and character.Humanoid
        if not humanoid or humanoid.Health <= 0 then return end
        if isSprinting(controller) and humanoid.WalkSpeed >= SPRINT_WALK_SPEED then return end
        controller:stopSprinting()
        controller:startSprinting()
    end

    Sprint = vape.Categories.Combat:CreateModule({
        Name = 'Sprint',
        Function = function(callback)
            if callback then
                if inputService.TouchEnabled then
                    pcall(function()
                        lplr.PlayerGui.MobileUI['4'].Visible = false
                    end)
                end
                old = bedwars.SprintController.stopSprinting
                hook = function(...)
                    local call = old(...)
                    bedwars.SprintController:startSprinting()
                    return call
                end
                bedwars.SprintController.stopSprinting = hook
                Sprint:Clean(entitylib.Events.LocalAdded:Connect(function()
                    for _, pause in {0.1, 0.25, 0.5, 0.75, 1, 1.5, 2} do
                        task.delay(pause, function()
                            if Sprint.Enabled then
                                assertSprint()
                            end
                        end)
                    end
                end))
                bedwars.SprintController:stopSprinting()
                assertSprint()
            else
                if inputService.TouchEnabled then
                    pcall(function()
                        lplr.PlayerGui.MobileUI['4'].Visible = true
                    end)
                end
                if bedwars.SprintController.stopSprinting == hook then
                    bedwars.SprintController.stopSprinting = old
                end
                hook, old = nil, nil
                bedwars.SprintController:stopSprinting()
            end
        end,
        Tooltip = 'Keeps you sprinting while you move'
    })
end)
