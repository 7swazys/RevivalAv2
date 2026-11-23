run(function()
    local HitFix

    local function findConstant(func)
        local ok, constants = pcall(debug.getconstants, func)
        if ok and type(constants) == 'table' then
            for index, value in constants do
                if value == 'Raycast' or value == 'raycast' then
                    return index
                end
            end
            return nil
        end
        local read, value = pcall(debug.getconstant, func, 23)
        return read and (value == 'Raycast' or value == 'raycast') and 23 or nil
    end

    local function findUpvalue(func)
        local function holds(index)
            local read, value = pcall(debug.getupvalue, func, index)
            if not read then return nil end
            return value == workspace or (bedwars.QueryUtil ~= nil and value == bedwars.QueryUtil)
        end
        if holds(4) then return 4 end
        for index = 1, 24 do
            local found = holds(index)
            if found == nil then break end
            if found then return index end
        end
        return nil
    end

    HitFix = vape.Categories.Legit:CreateModule({
        Name = 'HitFix',
        Function = function(callback)
            local swing = bedwars.SwordController and bedwars.SwordController.swingSwordAtMouse
            local constant = type(swing) == 'function' and findConstant(swing)
            local upvalue = constant and findUpvalue(swing)
            if not constant or not upvalue or (callback and not bedwars.QueryUtil) then
                if callback then
                    notif('HitFix', 'The game\'s sword code has changed and HitFix could not find what it patches.', 6, 'warning')
                    HitFix:Toggle()
                end
                return
            end
            debug.setconstant(swing, constant, callback and 'raycast' or 'Raycast')
            debug.setupvalue(swing, upvalue, callback and bedwars.QueryUtil or workspace)
        end,
        Tooltip = 'Fixes sword hit detection'
    })
end)
