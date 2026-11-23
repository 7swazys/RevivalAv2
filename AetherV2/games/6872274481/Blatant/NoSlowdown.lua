run(function()
    local NoSlowdown
    local old, hook, hooked

    NoSlowdown = vape.Categories.Blatant:CreateModule({
        Name = 'NoSlowdown',
        Function = function(callback)
            local modifier = bedwars.SprintController:getMovementStatusModifier()
            if callback then
                if not (hook and hooked == modifier) then
                    old = modifier.addModifier
                    hooked = modifier
                    hook = function(self, tab)
                        if NoSlowdown.Enabled and type(tab) == 'table' and tab.moveSpeedMultiplier then
                            tab.moveSpeedMultiplier = math.max(tab.moveSpeedMultiplier, 1)
                        end
                        return old(self, tab)
                    end
                    modifier.addModifier = hook
                end

                local slowing = {}
                for i in modifier.modifiers do
                    if (i.moveSpeedMultiplier or 1) < 1 then
                        table.insert(slowing, i)
                    end
                end
                for _, i in slowing do
                    modifier:removeModifier(i)
                end
            elseif hook then
                if hooked.addModifier == hook then
                    hooked.addModifier = old
                    old, hook, hooked = nil, nil, nil
                end
            end
        end,
        Tooltip = 'Stops items and weapons slowing you down'
    })
end)
