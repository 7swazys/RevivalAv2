run(function()
    local Value
    local VerticalValue
    local WallCheck
    local PopBalloons
    local TP
    local ShowUI
    local AirOnly
    local rayCheck = RaycastParams.new()
    local rayCheckF1, rayCheckF2, rayCheckF3 = false, false, false
    rayCheck.RespectCanCollide = true
    local up, down, old = 0, 0
    local deflateHook
    local bar, fill

    local function removeBar()
        if bar then
            bar:Destroy()
            bar, fill = nil, nil
        end
    end

    local function createBar()
        removeBar()
        bar = Instance.new('Frame')
        bar.AnchorPoint = Vector2.new(0.5, 0)
        bar.BackgroundColor3 = Color3.new()
        bar.BackgroundTransparency = 0.5
        bar.BorderSizePixel = 0
        bar.Position = UDim2.new(0.5, 0, 0.5, 150)
        bar.Size = UDim2.fromOffset(160, 6)
        bar.Visible = false
        bar.Parent = vape.gui
        local corner = Instance.new('UICorner')
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = bar
        fill = Instance.new('Frame')
        fill.BorderSizePixel = 0
        fill.Size = UDim2.fromScale(0, 1)
        fill.Parent = bar
        corner:Clone().Parent = fill
    end

    local function updateBar(airTime, airborne, counting)
        if not bar or not fill then return end
        bar.Visible = Fly.Enabled and counting and entitylib.isAlive and (airborne or not AirOnly.Enabled) or false
        fill.BackgroundColor3 = Color3.fromHSV(vape.GUIColor.Hue, vape.GUIColor.Sat, vape.GUIColor.Value)
        fill.Size = UDim2.fromScale(math.clamp(airTime / 2, 0, 1), 1)
    end

    Fly = vape.Categories.Blatant:CreateModule({
        Name = 'Fly',
        Function = function(callback)
            frictionTable.Fly = callback or nil
            updateVelocity()
            if callback then
                up, down = 0, 0
                if not deflateHook then
                    old = bedwars.BalloonController.deflateBalloon
                    deflateHook = function(...)
                        if Fly.Enabled then return end
                        return old(...)
                    end
                    bedwars.BalloonController.deflateBalloon = deflateHook
                end
                local tpTick, tpToggle, oldy = tick(), true
                local engineSpeed = store.engineSpeed(Fly)

                if lplr.Character and (lplr.Character:GetAttribute('InflatedBalloons') or 0) == 0 and getItem('balloon') then
                    bedwars.BalloonController:inflateBalloon()
                end
                Fly:Clean(vapeEvents.AttributeChanged.Event:Connect(function(changed)
                    if changed == 'InflatedBalloons' and (lplr.Character:GetAttribute('InflatedBalloons') or 0) == 0 and getItem('balloon') then
                        bedwars.BalloonController:inflateBalloon()
                    end
                end))
                Fly:Clean(runService.PreSimulation:Connect(function(dt)
                    if entitylib.isAlive and isnetworkowner(entitylib.character.RootPart) then
                        local flyAllowed = ((lplr.Character:GetAttribute('InflatedBalloons') or 0) > 0) or store.matchState == 2
                        local mass = (-0.02 + (flyAllowed and 6 or 0) * (tick() % 0.4 < 0.2 and -1 or 1)) + ((up + down) * VerticalValue.Value)
                        local root, moveDirection = entitylib.character.RootPart, entitylib.character.Humanoid.MoveDirection
                        local currentSpeed = getSpeed()
                        local destination = moveDirection * math.max(Value.Value - engineSpeed(), 0) * dt
                        if rayCheckF1 ~= lplr.Character or rayCheckF2 ~= gameCamera or rayCheckF3 ~= AntiFallPart then
                            rayCheckF1, rayCheckF2, rayCheckF3 = lplr.Character, gameCamera, AntiFallPart
                            rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera, AntiFallPart}
                        end
                        rayCheck.CollisionGroup = root.CollisionGroup

                        if WallCheck.Enabled then
                            local ray = workspace:Raycast(root.Position, destination, rayCheck)
                            if ray then
                                destination = ((ray.Position + ray.Normal) - root.Position)
                            end
                        end

                        local counting = not flyAllowed and TP.Enabled and not vape.FloatExempt
                        local airborne = entitylib.character.Humanoid.FloorMaterial == Enum.Material.Air
                        local airTime = counting and tpToggle and airborne and (tick() - (entitylib.character.AirTime or tick())) or 0
                        Fly.PullIn = counting and (2 - airTime) or nil
                        updateBar(airTime, airborne, counting)

                        if not flyAllowed then
                            if tpToggle then
                                local airleft = (tick() - entitylib.character.AirTime)
                                if airleft > 2 then
                                    if not oldy then
                                        local ray = workspace:Raycast(root.Position, Vector3.new(0, -1000, 0), rayCheck)
                                        if ray and TP.Enabled and not vape.FloatExempt then
                                            tpToggle = false
                                            oldy = root.Position.Y
                                            tpTick = tick() + 0.11
                                            root.CFrame = CFrame.lookAlong(Vector3.new(root.Position.X, ray.Position.Y + entitylib.character.HipHeight, root.Position.Z), root.CFrame.LookVector)
                                        end
                                    end
                                end
                            else
                                if oldy then
                                    if tpTick < tick() then
                                        local newpos = Vector3.new(root.Position.X, oldy, root.Position.Z)
                                        root.CFrame = CFrame.lookAlong(newpos, root.CFrame.LookVector)
                                        tpToggle = true
                                        oldy = nil
                                    else
                                        mass = 0
                                    end
                                end
                            end
                        end

                        root.CFrame += destination
                        root.AssemblyLinearVelocity = (moveDirection * currentSpeed) + Vector3.new(0, mass, 0)
                    end
                end))
                Fly:Clean(inputService.InputBegan:Connect(function(input)
                    if not inputService:GetFocusedTextBox() then
                        if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
                            up = 1
                        elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL2 then
                            down = -1
                        end
                    end
                end))
                Fly:Clean(inputService.InputEnded:Connect(function(input)
                    if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
                        up = 0
                    elseif input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.ButtonL2 then
                        down = 0
                    end
                end))
                if inputService.TouchEnabled then
                    pcall(function()
                        local jumpButton = lplr.PlayerGui.TouchGui.TouchControlFrame.JumpButton
                        Fly:Clean(jumpButton:GetPropertyChangedSignal('ImageRectOffset'):Connect(function()
                            up = jumpButton.ImageRectOffset.X == 146 and 1 or 0
                        end))
                    end)
                end
            else
                Fly.PullIn = nil
                updateBar(0, false, false)
                if deflateHook and bedwars.BalloonController.deflateBalloon == deflateHook then
                    bedwars.BalloonController.deflateBalloon = old
                    deflateHook = nil
                end
                if PopBalloons.Enabled and entitylib.isAlive and (lplr.Character:GetAttribute('InflatedBalloons') or 0) > 0 then
                    for _ = 1, 3 do
                        bedwars.BalloonController:deflateBalloon()
                    end
                end
            end
        end,
        ExtraText = function()
            return 'Heatseeker'
        end,
        Tooltip = 'Lets you fly'
    })
    Value = Fly:CreateSlider({
        Name = 'Speed',
        Min = 1,
        Max = 23,
        Default = 23,
        Suffix = function(val)
            return val == 1 and 'stud/s' or 'studs/s'
        end,
        Tooltip = 'How fast you fly'
    })
    VerticalValue = Fly:CreateSlider({
        Name = 'Vertical Speed',
        Min = 1,
        Max = 150,
        Default = 50,
        Suffix = function(val)
            return val == 1 and 'stud' or 'studs'
        end
    })
    WallCheck = Fly:CreateToggle({
        Name = 'Wall Check',
        Default = true
    })
    PopBalloons = Fly:CreateToggle({
        Name = 'Pop Balloons',
        Default = true
    })
    TP = Fly:CreateToggle({
        Name = 'TP Down',
        Default = true
    })
    ShowUI = Fly:CreateGroup({
        Name = 'Show UI',
        Function = function(callback)
            if callback then
                local other = vape.Modules.TPDown
                other = other and other.Options['Show UI']
                if other and other.Enabled then other:Toggle() end
                createBar()
            else
                removeBar()
            end
        end,
        Tooltip = 'Shows a bar that fills up until you are pulled down'
    })
    AirOnly = ShowUI:CreateToggle({
        Name = 'Air Only',
        Tooltip = 'Only shows the bar while you are in the air'
    })
    vape:Clean(removeBar)
    Fly:CreateButton({
        Name = 'Reset to default speeds',
        Tooltip = 'Sets speed back to the game\'s default',
        Function = function()
            Value:SetValue(20)
        end,
    })
end)
