run(function()
    local ChatPosition
    local Vertical
    local Horizontal
    local moved

    local function targetOffset()
        return Vector2.new(Horizontal and Horizontal.Value or 0, Vertical and Vertical.Value or 200)
    end

    local function applyLegacy()
        local off = targetOffset()
        pcall(function()
            starterGui:SetCore('ChatWindowPosition', UDim2.fromOffset(off.X, off.Y))
        end)
    end

    
    
    local function findChatFrame()
        local roots = {coreGui}
        local pg = lplr:FindFirstChild('PlayerGui')
        if pg then table.insert(roots, pg) end
        for _, root in roots do
            for _, gui in root:GetChildren() do
                if gui:IsA('ScreenGui') and gui.Name:lower():find('chat') then
                    for _, child in gui:GetChildren() do
                        if child:IsA('GuiObject') and child:FindFirstChildWhichIsA('ScrollingFrame', true) then
                            return child
                        end
                    end
                end
            end
        end
    end

    local function apply()
        applyLegacy()
        local frame = findChatFrame()
        if frame then
            moved = frame
            pcall(function()
                frame.Position = UDim2.fromOffset(targetOffset().X, targetOffset().Y)
            end)
        end
    end

    local function restore()
        pcall(function()
            starterGui:SetCore('ChatWindowPosition', UDim2.new())
        end)
        if moved and moved.Parent then
            pcall(function() moved.Position = UDim2.new() end)
        end
        moved = nil
    end

    ChatPosition = vape.Categories.Legit:CreateModule({
        Name = 'ChatPosition',
        Function = function(callback)
            if callback then
                ChatPosition:Clean(task.spawn(function()
                    while ChatPosition.Enabled do
                        apply()
                        task.wait(1)
                    end
                end))
            else
                restore()
            end
        end,
        Tooltip = 'Moves the chat window'
    })
    Vertical = ChatPosition:CreateSlider({
        Name = 'Vertical',
        Min = 0,
        Max = 700,
        Default = 200,
        Suffix = ' px',
        Tooltip = 'How far from the top the chat window sits',
        Function = function()
            if ChatPosition.Enabled then apply() end
        end
    })
    Horizontal = ChatPosition:CreateSlider({
        Name = 'Horizontal',
        Min = 0,
        Max = 700,
        Default = 0,
        Suffix = ' px',
        Tooltip = 'How far from the left the chat window sits',
        Function = function()
            if ChatPosition.Enabled then apply() end
        end
    })
end)
