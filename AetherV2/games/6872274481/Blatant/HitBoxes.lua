run(function()
    local Mode
    local Expand
    local objects, set = {}, nil
    local oldSwing, newSwing

    local function setQuery(on)
        for _, part in objects do
            part.CanQuery = on
        end
    end

    local function createHitbox(ent)
        if ent.Targetable and ent.Player then
            local hitbox = Instance.new('Part')
            hitbox.Size = Vector3.new(3, 6, 3) + Vector3.one * (Expand.Value / 5)
            hitbox.Position = ent.RootPart.Position
            hitbox.CanCollide = false
            hitbox.CanTouch = false
            hitbox.CanQuery = false
            hitbox.Massless = true
            hitbox.Transparency = 1
            hitbox.Parent = ent.Character
            local weld = Instance.new('Motor6D')
            weld.Part0 = hitbox
            weld.Part1 = ent.RootPart
            weld.Parent = hitbox
            objects[ent] = hitbox
        end
    end

    HitBoxes = vape.Categories.Blatant:CreateModule({
        Name = 'HitBoxes',
        ExtraText = function() return Mode.Value end,
        Function = function(callback)
            if callback then
                if Mode.Value == 'Sword' then
                    debug.setconstant(bedwars.SwordController.swingSwordInRegion, 6, (Expand.Value / 3))
                    set = true
                else
                    local controller = bedwars.SwordController
                    if controller and type(controller.swingSwordInRegion) == 'function' then
                        oldSwing = controller.swingSwordInRegion
                        newSwing = function(...)
                            setQuery(true)
                            local res = table.pack(pcall(oldSwing, ...))
                            setQuery(false)
                            if not res[1] then error(res[2], 0) end
                            return table.unpack(res, 2, res.n)
                        end
                        controller.swingSwordInRegion = newSwing
                    end
                    HitBoxes:Clean(entitylib.Events.EntityAdded:Connect(createHitbox))
                    HitBoxes:Clean(entitylib.Events.EntityRemoving:Connect(function(ent)
                        if objects[ent] then
                            objects[ent]:Destroy()
                            objects[ent] = nil
                        end
                    end))
                    for _, ent in entitylib.List do
                        createHitbox(ent)
                    end
                end
            else
                if set then
                    debug.setconstant(bedwars.SwordController.swingSwordInRegion, 6, 3.8)
                    set = nil
                end
                if newSwing then
                    local controller = bedwars.SwordController
                    if controller and rawget(controller, 'swingSwordInRegion') == newSwing then
                        controller.swingSwordInRegion = oldSwing
                    end
                    oldSwing, newSwing = nil, nil
                end
                for _, part in objects do
                    part:Destroy()
                end
                table.clear(objects)
            end
        end,
        Tooltip = 'Expands attack hitbox'
    })
    Mode = HitBoxes:CreateDropdown({
        Name = 'Mode',
        List = {'Sword', 'Player'},
        Function = function()
            if HitBoxes.Enabled then
                HitBoxes:Toggle()
                HitBoxes:Toggle()
            end
        end,
        Tooltip = 'Sword - raises your attack range\nPlayer - enlarges player hitboxes'
    })
    Expand = HitBoxes:CreateSlider({
        Name = 'Expand amount',
        Min = 0,
        Max = 14.4,
        Default = 14.4,
        Decimal = 10,
        Function = function(val)
            if HitBoxes.Enabled then
                if Mode.Value == 'Sword' then
                    debug.setconstant(bedwars.SwordController.swingSwordInRegion, 6, (val / 3))
                else
                    for _, part in objects do
                        part.Size = Vector3.new(3, 6, 3) + Vector3.one * (val / 5)
                    end
                end
            end
        end,
        Suffix = function(val)
            return val == 1 and 'stud' or 'studs'
        end
    })
    HitBoxes:CreateButton({
        Name = 'Reset to default hitbox',
        Tooltip = 'Sets the hitbox back to the game\'s default',
        Function = function()
            Expand:SetValue(0)
        end,
    })
end)
