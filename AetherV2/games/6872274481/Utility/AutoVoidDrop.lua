run(function()
    local AutoVoidDrop
    local OwlCheck
    local PearlCheck
    local AutoReset
    local resetQueued = false
    local VOID_ITEMS = {'iron', 'diamond', 'emerald', 'gold'}

    local pearlRay = RaycastParams.new()
    pearlRay.RespectCanCollide = true
    pearlRay.FilterType = Enum.RaycastFilterType.Exclude

    
    
    
    
    local function pearlLandsOnGround(pearl, lowestpoint)
        local position = pearl.Position
        local velocity = pearl.AssemblyLinearVelocity
        
        
        if velocity.Magnitude < 1 then return true end

        local meta = bedwars.ProjectileMeta.telepearl
        local gravity = (meta and meta.gravitationalAcceleration) or workspace.Gravity
        pearlRay.FilterDescendantsInstances = {lplr.Character, gameCamera, pearl}

        local step = 0.05
        for _ = 1, 120 do
            local nextPosition = position + (velocity * step)
            local result = workspace:Raycast(position, nextPosition - position, pearlRay)
            if result then
                return result.Position.Y > lowestpoint
            end
            if nextPosition.Y < lowestpoint then return false end
            position = nextPosition
            velocity -= Vector3.new(0, gravity * step, 0)
        end
        
        return false
    end

    local function holdsVoidItems()
        for _, name in VOID_ITEMS do
            if getItem(name) then return true end
        end
        return false
    end

    local function resetCharacter()
        local sent = pcall(function()
            bedwars.Client:Get(remotes.ResetCharacter):CallServer()
        end)
        if sent then return true end
        return pcall(function()
            entitylib.character.Character:BreakJoints()
        end)
    end

    local function pearlWillSave(lowestpoint)
        for _, projectile in store.selfProjectiles do
            if projectile.Parent and projectile.Name == 'telepearl' and pearlLandsOnGround(projectile, lowestpoint) then
                return true
            end
        end
        return false
    end

    AutoVoidDrop = vape.Categories.Utility:CreateModule({
        Name = 'AutoVoidDrop',
        Function = function(callback)
            if callback then
                repeat task.wait() until store.matchState ~= 0 or (not AutoVoidDrop.Enabled)
                if not AutoVoidDrop.Enabled then return end

                local lowestpoint = math.huge
                local blocks, index, started = store.blocks, 1, os.clock()
                while index <= #blocks do
                    local v = blocks[index]
                    index += 1
                    if v then
                        local point = (v.Position.Y - (v.Size.Y / 2)) - 50
                        if point < lowestpoint then
                            lowestpoint = point
                        end
                    end
                    if os.clock() - started > 0.002 then
                        task.wait()
                        started = os.clock()
                    end
                end

                repeat
                    if entitylib.isAlive then
                        local root = entitylib.character.RootPart
                        if root.Position.Y < lowestpoint and (lplr.Character:GetAttribute('InflatedBalloons') or 0) <= 0 and not getItem('balloon') then
                            local saved = OwlCheck.Enabled and root:FindFirstChild('OwlLiftForce')
                                or (PearlCheck.Enabled and pearlWillSave(lowestpoint))
                            if not saved then
                                local dropped = false
                                for _, name in VOID_ITEMS do
                                    local item = getItem(name)
                                    if item then
                                        item = bedwars.Client:Get(remotes.DropItem):CallServer({
                                            item = item.tool,
                                            amount = item.amount
                                        })

                                        if item then
                                            item:SetAttribute('ClientDropTime', tick() + 100)
                                            dropped = true
                                        end
                                    end
                                end
                                if dropped and AutoReset.Enabled and not resetQueued then
                                    resetQueued = true
                                    task.spawn(function()
                                        local deadline = os.clock() + 2
                                        repeat task.wait(0.05) until not holdsVoidItems() or os.clock() >= deadline
                                        task.wait(0.1)
                                        if AutoReset.Enabled and AutoVoidDrop.Enabled then
                                            resetCharacter()
                                        end
                                    end)
                                end
                            end
                        else
                            resetQueued = false
                        end
                    end

                    task.wait(0.1)
                until not AutoVoidDrop.Enabled
            end
        end,
        Tooltip = 'Drops your resources when falling into the void'
    })
    local Checks
    Checks = AutoVoidDrop:CreateMultiDropdown({
    	Name = 'Checks',
    	List = {'Owl', 'Telepearl'},
    	Default = {'Owl', 'Telepearl'},
    	Tooltip = 'Keeps your items while one of these can still save you'
    })
    OwlCheck = setmetatable({}, {__index = function(_, key) if key == 'Enabled' then return Checks:Has('Owl') end end})
    PearlCheck = setmetatable({}, {__index = function(_, key) if key == 'Enabled' then return Checks:Has('Telepearl') end end})
    AutoReset = AutoVoidDrop:CreateToggle({
        Name = 'Auto reset',
        Default = false,
        Function = function()
            resetQueued = false
        end,
        Tooltip = 'Respawns you once everything selected has been dropped'
    })
end)
