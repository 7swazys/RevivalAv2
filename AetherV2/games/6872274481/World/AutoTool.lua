run(function()
    local AutoTool
    local Mode
    local Delay = {}
    local SwitchBack
    local old, hook, event
    local looking, deadline, previous, switching = nil, 0, nil, false

    local function toolSlot(block)
        if not block or block:GetAttribute('NoBreak') or block:GetAttribute('Team'..(lplr:GetAttribute('Team') or 0)..'NoBreak') then return nil end
        local meta = bedwars.ItemMeta and bedwars.ItemMeta[block.Name]
        local blockMeta = meta and meta.block
        local tool = blockMeta and blockMeta.breakType and getBreakTool(blockMeta.breakType)
        if not tool then return nil end
        for i, v in store.inventory.hotbar do
            if v.item and v.item.itemType == tool.itemType then
                local slot = i - 1
                if store.inventory.hotbarSlot == slot then return nil end
                return slot
            end
        end
        return nil
    end

    local function lookTarget()
        local breaker = bedwars.BlockBreaker
        local selector = type(breaker) == 'table' and breaker.clientManager and breaker.clientManager:getBlockSelector()
        local info = selector and selector:getMouseInfo(1, {range = breaker.range})
        return info and info.target and info.target.blockInstance or nil
    end

    local function switchTo(slot)
        if switching then return end
        switching = true
        task.spawn(function()
            pcall(hotbarSwitch, slot)
            switching = false
        end)
    end

    local function switchHotbarItem(block)
        if not block then return false end
        if block:GetAttribute('NoBreak') then return false end
        if block:GetAttribute('Team'..(lplr:GetAttribute('Team') or 0)..'NoBreak') then return false end

        local meta = bedwars.ItemMeta and bedwars.ItemMeta[block.Name]
        local blockMeta = meta and meta.block
        if not blockMeta or not blockMeta.breakType then return false end

        local tool, slot = getBreakTool(blockMeta.breakType), nil
        if tool then
            for i, v in store.inventory.hotbar do
                if v.item and v.item.itemType == tool.itemType then slot = i - 1 break end
            end

            if slot == nil or (store.inventory and store.inventory.hotbarSlot == slot) then return false end

            if hotbarSwitch(slot) then
                if inputService:IsMouseButtonPressed(0) and event then
                    event:Fire()
                end
                return true
            end
        end
        return false
    end

    local function hookBreak()
        if hook then return end
        if type(bedwars.BlockBreaker) ~= 'table' or type(bedwars.BlockBreaker.hitBlock) ~= 'function' then return end
        old = bedwars.BlockBreaker.hitBlock
        hook = function(self, maid, raycastparams, ...)
            if not AutoTool.Enabled or Mode.Value ~= 'Break' then
                return old(self, maid, raycastparams, ...)
            end
            local ok, swapped = pcall(function()
                local selector = self.clientManager and self.clientManager:getBlockSelector()
                local block = selector and selector:getMouseInfo(1, {ray = raycastparams, range = self.range})
                return switchHotbarItem(block and block.target and block.target.blockInstance or nil)
            end)
            if ok and swapped then return end
            return old(self, maid, raycastparams, ...)
        end
        bedwars.BlockBreaker.hitBlock = hook
    end

    local function unhookBreak()
        if not hook then return end
        if bedwars.BlockBreaker.hitBlock == hook then
            bedwars.BlockBreaker.hitBlock = old
            hook, old = nil, nil
        end
    end

    AutoTool = vape.Categories.World:CreateModule({
        Name = 'AutoTool',
        Function = function(callback)
            if callback then
                event = Instance.new('BindableEvent')
                AutoTool:Clean(event)
                AutoTool:Clean(event.Event:Connect(function()
                    contextActionService:CallFunction('block-break', Enum.UserInputState.Begin, newproxy(true))
                end))
                hookBreak()
                looking, deadline, previous, switching = nil, 0, nil, false
                AutoTool:Clean(runService.Heartbeat:Connect(function()
                    if Mode.Value ~= 'Look' or not entitylib.isAlive then
                        looking, previous = nil, nil
                        return
                    end
                    local held = store.hand and store.hand.tool
                    local heldMeta = held and bedwars.ItemMeta[held.Name]
                    if not (heldMeta and heldMeta.breakBlock) then
                        looking, previous = nil, nil
                        return
                    end
                    local ok, block = pcall(lookTarget)
                    block = ok and block or nil
                    if not block then
                        looking = nil
                        if SwitchBack.Enabled and previous then
                            switchTo(previous)
                            previous = nil
                        end
                        return
                    end
                    if block ~= looking then
                        looking, deadline = block, tick() + Delay:GetRandomValue()
                        return
                    end
                    if tick() < deadline then return end
                    local slot = toolSlot(block)
                    if slot then
                        previous = previous or getHotbar(held)
                        switchTo(slot)
                    end
                end))
            else
                unhookBreak()
                event = nil
                looking, previous = nil, nil
            end
        end,
        Tooltip = 'Selects the right tool for what you are mining'
    })
    Mode = AutoTool:CreateDropdown({
        Name = 'Mode',
        List = {'Look', 'Break'},
        Default = 'Break',
        Tooltip = 'Look - swaps while you aim at a block\nBreak - swaps on the first hit'
    })
    Delay = AutoTool:CreateTwoSlider({
        Name = 'Delay',
        Min = 0,
        Max = 1,
        Decimal = 100,
        DefaultMin = 0.06,
        DefaultMax = 0.16,
        Darker = true,
        Suffix = 'seconds',
        Visible = function() return Mode.Value == 'Look' end,
        Tooltip = 'How long you look at a block before it swaps'
    })
    SwitchBack = AutoTool:CreateToggle({
        Name = 'Switch back',
        Darker = true,
        Visible = function() return Mode.Value == 'Look' end,
        Tooltip = 'Puts back the item you were holding once you look away'
    })
end)
