run(function()
    local PickupRange
    local Range
    local Network
    local Lower
    local Delay

    PickupRange = vape.Categories.Utility:CreateModule({
        Name = 'PickupRange',
        Function = function(callback)
            if callback then
                local items = collection('ItemDrop', PickupRange)
                local picked = setmetatable({}, {__mode = 'k'})
                repeat
                    if entitylib.isAlive then
                        local localPosition = entitylib.character.RootPart.Position
                        for _, v in items do
                            if tick() - (v:GetAttribute('ClientDropTime') or 0) < Delay.Value or (picked[v] or 0) > tick() then continue end
                            if isnetworkowner(v) and Network.Enabled and entitylib.character.Humanoid.Health > 0 then
                                v.CFrame = CFrame.new(localPosition - Vector3.new(0, 3, 0))
                            end

                            if (localPosition - v.Position).Magnitude <= Range.Value then
                                if Lower.Enabled and (localPosition.Y - v.Position.Y) < (entitylib.character.HipHeight - 1) then continue end
                                picked[v] = tick() + 1
                                task.spawn(function()
                                    bedwars.Client:Get(remotes.PickupItem):CallServerAsync({
                                        itemDrop = v
                                    }):andThen(function(suc)
                                        picked[v] = nil
                                        if suc and bedwars.SoundList then
                                            bedwars.SoundManager:playSound(bedwars.SoundList.PICKUP_ITEM_DROP)
                                            local sound = bedwars.ItemMeta[v.Name].pickUpOverlaySound
                                            if sound then
                                                bedwars.SoundManager:playSound(sound, {
                                                    position = v.Position,
                                                    volumeMultiplier = 0.9
                                                })
                                            end
                                        end
                                    end)
                                end)
                            end
                        end
                    end
                    task.wait(0.05)
                until not PickupRange.Enabled
            end
        end,
        Tooltip = 'Picks up items from further away'
    })
    Range = PickupRange:CreateSlider({
        Name = 'Range',
        Min = 1,
        Max = 10,
        Default = 10,
        Suffix = function(val)
            return val == 1 and 'stud' or 'studs'
        end
    })
    Network = PickupRange:CreateToggle({
        Name = 'Network TP',
        Default = true
    })
    Lower = PickupRange:CreateToggle({Name = 'Feet Check'})
    Delay = PickupRange:CreateSlider({
        Name = 'Pickup delay',
        Min = 0,
        Max = 2,
        Default = 2,
        Decimal = 10,
        Suffix = 's',
        Tooltip = 'How long a drop must be on the ground before it is picked up'
    })
end)
