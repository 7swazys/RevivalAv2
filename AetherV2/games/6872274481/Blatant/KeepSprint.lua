run(function()
    local KeepSprint

    local function findConstant(func)
        local ok, constants = pcall(debug.getconstants, func)
        if ok and type(constants) == 'table' then
            for index, value in constants do
                if value == 'blockSprint' or value == 'blockSprinting' then
                    return index
                end
            end
            return nil
        end
        local read, value = pcall(debug.getconstant, func, 5)
        if read and (value == 'blockSprint' or value == 'blockSprinting') then
            return 5
        end
        return nil
    end

    KeepSprint = vape.Categories.Blatant:CreateModule({
        Name = 'KeepSprint',
        Function = function(callback)
            local controller = bedwars.SprintController
            local index = controller and findConstant(controller.startSprinting)
            if not index then
                if callback then
                    notif('KeepSprint', 'The game\'s sprint code has changed and KeepSprint could not find what it patches.', 6, 'warning')
                    KeepSprint:Toggle()
                end
                return
            end
            debug.setconstant(controller.startSprinting, index, callback and 'blockSprinting' or 'blockSprint')
            controller:stopSprinting()
        end,
        Tooltip = 'Lets you sprint with a speed potion'
    })
end)
