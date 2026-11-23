run(function()
    local ArmorSwitch
    local Mode
    local Targets
    local Range

    local function waitForInventory()
        local answered = false
        local connection = vapeEvents.InventoryChanged.Event:Once(function()
            answered = true
        end)
        local deadline = tick() + 0.5
        repeat
            task.wait()
        until answered or tick() > deadline
        connection:Disconnect()
    end

    ArmorSwitch = vape.Categories.Inventory:CreateModule({
        Name = 'ArmorSwitch',
        Function = function(callback)
            if callback then
                if Mode.Value == 'Toggle' then
                    repeat
                        local state = entitylib.EntityPosition({
                            Part = 'RootPart',
                            Range = Range.Value,
                            Players = Targets.Players.Enabled,
                            Priority = Targets.Priority and Targets.Priority.Value,
                            NPCs = Targets.NPCs.Enabled,
                            Wallcheck = Targets.Walls.Enabled
                        }) and true or false

                        for i = 0, 2 do
                            local armor = store.inventory.inventory.armor[i + 1]
                            if (armor ~= 'empty') ~= state and ArmorSwitch.Enabled then
                                local item = armor == 'empty' and state and getBestArmor(i) or nil
                                if armor ~= 'empty' or item then
                                    bedwars.Store:dispatch({
                                        type = 'InventorySetArmorItem',
                                        item = item,
                                        armorSlot = i
                                    })
                                    waitForInventory()
                                end
                            end
                        end
                        task.wait(0.1)
                    until not ArmorSwitch.Enabled
                else
                    ArmorSwitch:Toggle()
                    for i = 0, 2 do
                        local armor = store.inventory.inventory.armor[i + 1]
                        local item = armor == 'empty' and getBestArmor(i) or nil
                        if armor ~= 'empty' or item then
                            bedwars.Store:dispatch({
                                type = 'InventorySetArmorItem',
                                item = item,
                                armorSlot = i
                            })
                            waitForInventory()
                        end
                    end
                end
            end
        end,
        Tooltip = 'Takes your armour on and off to bait enemies'
    })
    Targets = ArmorSwitch:CreateTargets({
        Players = true,
        NPCs = true
    })
    Mode = ArmorSwitch:CreateDropdown({
        Name = 'Mode',
        List = {'Toggle', 'On Key'},
        Tooltip = 'Toggle - wears armour only with someone near\nOn Key - swaps once and switches off'
    })
    Range = ArmorSwitch:CreateSlider({
        Name = 'Range',
        Min = 1,
        Max = 30,
        Default = 30,
        Suffix = function(val)
            return val == 1 and 'stud' or 'studs'
        end
    })
end)
