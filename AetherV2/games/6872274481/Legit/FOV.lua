run(function()
    local FOV
    local Value
    local old, old2

    FOV = vape.Categories.Legit:CreateModule({
        Name = 'FOV',
        Function = function(callback)
            if callback then
                old = bedwars.FovController.setFOV
                old2 = bedwars.FovController.getFOV
                bedwars.FovController.setFOV = function(self)
                    return old(self, Value.Value)
                end
                bedwars.FovController.getFOV = function()
                    return Value.Value
                end
            else
                bedwars.FovController.setFOV = old
                bedwars.FovController.getFOV = old2
            end

            bedwars.FovController:setFOV(bedwars.Store:getState().Settings.fov)
        end,
        Tooltip = 'Changes your field of view'
    })
    Value = FOV:CreateSlider({
        Name = 'FOV',
        Min = 70,
        Max = 360,
        Function = function(val)
            if FOV.Enabled then
                bedwars.FovController:setFOV(val)
            end
        end
    })
    FOV:CreateButton({
        Name = 'Reset to default FOV',
        Tooltip = 'Sets your field of view back to your game setting',
        Function = function()
            local ok, stored = pcall(function()
                return bedwars.Store:getState().Settings.fov
            end)
            Value:SetValue(ok and tonumber(stored) or 70)
        end,
    })
end)
