run(function()
    local BedProtector
    local PlaceRange
    local Layers
    local Blacklist
    local Mode
    local Smart
    local Switch
    local WoolOnly
    local LimitItem
    local Template
    local EmergencyKey
    local Radius
    local NoAnimation
    local layout, adjacent = {}, {}
    local patchTarget
    local placing = false
    local placeAnimation
    pcall(function()
        placeAnimation = bedwars.BlockController:getAnimationController():getAssetId(0)
    end)
    for _, v in Enum.NormalId:GetEnumItems() do
        table.insert(adjacent, Vector3.FromNormalId(v) * 3)
    end
    local previewParts = {}
    local templateSpecs = {
        ['Quick Wool'] = {Layers = 1, Wool = true},
        Layered = {Layers = 2, Wool = false},
        Defensive = {Layers = 3, Wool = false},
        ['Anti-Explosive'] = {Layers = 2, Wool = false}
    }

    local function clearPreview()
        for _, part in previewParts do part:Destroy() end
        table.clear(previewParts)
    end

    local function getBedNear()
        local localPosition = entitylib.isAlive and entitylib.character.RootPart.Position or Vector3.zero
        for _, v in collectionService:GetTagged('bed') do
            if (localPosition - v.Position).Magnitude < 14
                and v:GetAttribute('Team' .. (lplr:GetAttribute('Team') or -1) .. 'NoBreak') then
                return v
            end
        end
        return nil
    end

    local function getBlocks()
        local blocks = {}
        for _, item in store.inventory.inventory.items do
            local block = bedwars.ItemMeta[item.itemType].block
            if block and (not Template or Template.Value ~= 'Quick Wool' or item.itemType:find('wool'))
                and not table.find(Blacklist.ListEnabled, item.itemType:find('wool') and 'wool' or item.itemType) then
                table.insert(blocks, { item.itemType, block.health, item.tool })
            end
        end
        table.sort(blocks, function(a, b)
            return a[2] > b[2]
        end)
        return blocks
    end

    
    
    
    
    
    local function bedCells(bed)
        local cf, size
        if bed:IsA('BasePart') then
            cf, size = bed.CFrame, bed.Size
        else
            cf = bed:GetPivot()
            local ok, ext = pcall(function() return bed:GetExtentsSize() end)
            size = ok and ext or Vector3.new(3, 3, 6)
        end
        local center = cf.Position
        
        
        local axis = (size.X >= size.Z) and cf.RightVector or cf.LookVector
        axis = Vector3.new(axis.X, 0, axis.Z)
        axis = axis.Magnitude > 0 and axis.Unit or Vector3.new(1, 0, 0)
        local a = roundPos(center + axis * 1.5)
        local b = roundPos(center - axis * 1.5)
        if a == b then b = roundPos(center - axis * 3) end
        return a, b
    end

    


    


    local function getPatchBlock(preferred)
        if LimitItem.Enabled then
            local hand = store.hand
            if not hand or hand.toolType ~= 'block' or not hand.tool then return nil end
            local itemType = hand.tool.Name
            if WoolOnly.Enabled and not itemType:find('wool') then return nil end
            if table.find(Blacklist.ListEnabled, itemType:find('wool') and 'wool' or itemType) then return nil end
            return {itemType, 0, hand.tool}
        end

        local best
        for _, item in store.inventory.inventory.items do
            local meta = bedwars.ItemMeta[item.itemType]
            local block = meta and meta.block
            if not block then continue end
            if WoolOnly.Enabled and not item.itemType:find('wool') then continue end
            if table.find(Blacklist.ListEnabled, item.itemType:find('wool') and 'wool' or item.itemType) then continue end
            if item.itemType == preferred then
                return {item.itemType, block.health or 0, item.tool}
            end
            if not best or (block.health or 0) > best[2] then
                best = {item.itemType, block.health or 0, item.tool}
            end
        end
        return best
    end

    local function patchBedNear()
        local localPosition = entitylib.isAlive and entitylib.character.RootPart.Position or Vector3.zero
        for _, v in collectionService:GetTagged('bed') do
            if (localPosition - v.Position).Magnitude < (PlaceRange.Value + Radius.Value)
                and v:GetAttribute('Team' .. (lplr:GetAttribute('Team') or -1) .. 'NoBreak') then
                return v
            end
        end
        return nil
    end

    local function scanBed(bed)
        table.clear(layout)
        for _, v in store.blocks do
            if not v:HasTag('bed') and (v.Position - bed.Position).Magnitude <= Radius.Value then
                layout[v.Position] = v.Name
            end
        end

        local holes = {}
        for position, name in layout do
            for _, offset in adjacent do
                local cell = position + offset
                if layout[cell] or holes[cell] or getPlacedBlock(cell) then continue end
                local walls = 0
                for _, side in adjacent do
                    if layout[cell + side] then walls += 1 end
                end
                if walls >= 4 then holes[cell] = name end
            end
        end
        for position, name in holes do
            layout[position] = name
        end
    end

    local function startPatching()
        local old = bedwars.AnimationUtil.playAnimation
        local hook = function(self, player, assetId, config)
            if placing and NoAnimation.Enabled and assetId == placeAnimation then
                return
            end
            return old(self, player, assetId, config)
        end
        bedwars.AnimationUtil.playAnimation = hook
        BedProtector:Clean(function()
            if bedwars.AnimationUtil.playAnimation == hook then
                bedwars.AnimationUtil.playAnimation = old
            end
            placing = false
            patchTarget = nil
            table.clear(layout)
        end)
        BedProtector:Clean(collectionService:GetInstanceAddedSignal('block'):Connect(function(block)
            if patchTarget and not block:HasTag('bed') and (block.Position - patchTarget.Position).Magnitude <= Radius.Value then
                layout[block.Position] = block.Name
            end
        end))
        BedProtector:Clean(vapeEvents.BreakBlockEvent.Event:Connect(function(blockTable)
            local player = blockTable.player
            if player and (player == lplr or player:GetAttribute('Team') == lplr:GetAttribute('Team')) then
                layout[blockTable.blockRef.blockPosition * 3] = nil
            end
        end))
    end

    local function patchBed()
        local found = patchBedNear()
        if found ~= patchTarget then
            patchTarget = found
            if found then scanBed(found) else table.clear(layout) end
        end
        local bed = patchTarget
        if not (bed and entitylib.isAlive) then return false end

        local localPosition = entitylib.character.RootPart.Position
        local holes = {}
        for position, name in layout do
            if (localPosition - position).Magnitude <= PlaceRange.Value and not getPlacedBlock(position) then
                table.insert(holes, {position, name})
            end
        end
        table.sort(holes, function(a, b)
            return (a[1] - bed.Position).Magnitude < (b[1] - bed.Position).Magnitude
        end)

        for _, hole in holes do
            if not BedProtector.Enabled then break end
            local position, name = hole[1], hole[2]
            if getPlacedBlock(position) then continue end
            local block = getPatchBlock(name)
            if not block then break end
            if Switch.Enabled then
                local slot = getHotbar(block[3])
                if slot and hotbarSwitch(slot) then task.wait() end
            end
            placing = true
            bedwars.placeBlock(position, block[1])
            placing = false
            task.wait(1 / bedwars.SharedConstants.BLOCK_PLACE_CPS)
        end
        return true
    end

    BedProtector = vape.Categories.World:CreateModule({
        Name = 'BedProtector',
        Function = function(callback)
            if callback then
                local spec = templateSpecs[Template.Value]
                local estimated = spec and ((spec.Layers * spec.Layers * 16) + 6) or 0
                notif('BedProtector', Template.Value..' needs about '..estimated..' blocks', 5, 'info')
                BedProtector:Clean(inputService.InputBegan:Connect(function(input, processed)
                    if not processed and input.KeyCode.Name == EmergencyKey.Value and BedProtector.Enabled then
                        clearPreview()
                        BedProtector:Toggle()
                        notif('BedProtector', 'Emergency stop', 3, 'warning')
                    end
                end))
                local patching = Mode.Value == 'Bed patcher'
                if patching then startPatching() end
                repeat
                    local bed = not patching and getBedNear()
                    if patching then
                        patchBed()
                    elseif bed then
                        
                        
                        local cellA, cellB = bedCells(bed)
                        local protected = { [cellA] = true, [cellB] = true }

                        for i, block in getBlocks() do
                            local switch, old = Switch.Enabled, store.hand and store.hand.tool and getHotbar(store.hand.tool) or nil
                            local hotbar = switch and getHotbar(block[3]) or nil

                            for layer = 1, Layers.Value do
                                local newPositions = {}

                                
                                for pos in pairs(protected) do
                                    
                                    for dx = -3, 3, 3 do
                                        for dz = -3, 3, 3 do
                                            if dx ~= 0 or dz ~= 0 then
                                                local newPos = pos + Vector3.new(dx, 0, dz)
                                                if not protected[newPos] then
                                                    newPositions[newPos] = true
                                                end
                                            end
                                        end
                                    end
                                    
                                    local upPos = pos + Vector3.new(0, 3, 0)
                                    if not protected[upPos] then
                                        newPositions[upPos] = true
                                    end
                                end

                                
                                
                                
                                
                                local ordered = {}
                                for newPos in pairs(newPositions) do
                                    table.insert(ordered, newPos)
                                end
                                local rootPos = entitylib.character.RootPart.Position
                                table.sort(ordered, function(a, b)
                                    return (rootPos - a).Magnitude < (rootPos - b).Magnitude
                                end)

                                
                                local placedAny = false
                                for _, newPos in ordered do
                                    if not BedProtector.Enabled then break end
                                    if getPlacedBlock(newPos) then
                                        protected[newPos] = true   
                                        continue
                                    end
                                    if (entitylib.character.RootPart.Position - newPos).Magnitude > PlaceRange.Value then
                                        continue
                                    end
                                    if hotbar and hotbarSwitch(hotbar) then task.wait() end
                                    task.spawn(bedwars.placeBlock, newPos, block[1], false)
                                    placedAny = true
                                    protected[newPos] = true
                                    task.wait(0.05)
                                end

                                
                                
                                if not placedAny then break end
                                if not BedProtector.Enabled then break end
                            end

                            if switch and old and hotbarSwitch(old) then task.wait() end
                        end
                    else
                        if Mode.Value == 'On Key' then
                            notif('BedProtector', 'Unable to locate bed', 5)
                            BedProtector:Toggle()
                        end
                    end
                    
                    task.wait(patching and 0.2 or 0.5)
                    if Mode.Value == 'On Key' then
                        BedProtector:Toggle()
                        break
                    end
                until not BedProtector.Enabled
            end
            if not callback then clearPreview() end
        end,
        Tooltip = 'Automatically places strong blocks around the bed'
    })

    
    
    local function syncModeOptions()
        
        
        if not Mode then return end
        if Smart and Smart.Object then Smart.Object.Visible = Mode.Value == 'Toggle' end
        local patching = Mode.Value == 'Bed patcher'
        if WoolOnly and WoolOnly.Object then WoolOnly.Object.Visible = patching end
        if LimitItem and LimitItem.Object then LimitItem.Object.Visible = patching end
        if Radius and Radius.Object then Radius.Object.Visible = patching end
        if NoAnimation and NoAnimation.Object then NoAnimation.Object.Visible = patching end
        if Template and Template.Object then Template.Object.Visible = not patching end
        if Layers and Layers.Object then Layers.Object.Visible = not patching end
    end
    local restarting = false

    Mode = BedProtector:CreateDropdown({
        Name = 'Mode',
        List = {'Toggle', 'On Key', 'Bed patcher'},
        Default = 'Toggle',
        Tooltip = 'Toggle - builds and keeps it up\nOn Key - builds once\nBed patcher - repairs what breaks',
        Function = function()
            syncModeOptions()
            if BedProtector.Enabled and not restarting then
                restarting = true
                task.defer(function()
                    restarting = false
                    if BedProtector.Enabled then
                        BedProtector:Toggle()
                        BedProtector:Toggle()
                    end
                end)
            end
        end,
    })
    Template = BedProtector:CreateDropdown({
        Name = 'Template',
        List = {'Quick Wool', 'Layered', 'Defensive', 'Anti-Explosive'},
        Function = function(value)
            local spec = templateSpecs[value]
            if not spec or not Layers then return end
            Layers:SetValue(spec.Layers)
            if WoolOnly and WoolOnly.Enabled ~= spec.Wool then WoolOnly:Toggle() end
            clearPreview()
            local bed = getBedNear()
            if bed then
                local a, b = bedCells(bed)
                for _, centre in {a, b} do
                    for x = -spec.Layers, spec.Layers do
                        for z = -spec.Layers, spec.Layers do
                            if math.max(math.abs(x), math.abs(z)) ~= spec.Layers then continue end
                            local pos = centre + Vector3.new(x * 3, 0, z * 3)
                            if getPlacedBlock(pos) then continue end
                            local ghost = Instance.new('Part')
                            ghost.Name, ghost.Size, ghost.Position = 'BedProtectorPreview', Vector3.new(3, 3, 3), pos
                            ghost.Anchored, ghost.CanCollide, ghost.CanQuery = true, false, false
                            ghost.Material, ghost.Color, ghost.Transparency = Enum.Material.ForceField, Color3.fromRGB(90, 210, 140), 0.65
                            ghost.Parent = workspace
                            table.insert(previewParts, ghost)
                        end
                    end
                end
                task.delay(5, clearPreview)
            end
        end
    })
    EmergencyKey = BedProtector:CreateDropdown({Name = 'Emergency Stop', List = {'X', 'V', 'B', 'N', 'Delete'}, Default = 'X'})
    Blacklist = BedProtector:CreateItemPicker({
    	Name = 'Blacklist',
    	Multi = true,
    	Items = (function() local list = bedwars.itemPickerList(function(id, meta) return meta.block ~= nil and not id:find('wool') end, {Relevant = {'shop'}}) table.insert(list, 1, {Name = 'wool', Label = 'Any wool', Image = bedwars.ItemMeta.wool_white and bedwars.ItemMeta.wool_white.image}) return list end)(),
    	Default = {'siege_tnt', 'tnt'}
    })
    PlaceRange = BedProtector:CreateSlider({
        Name = 'Place Range',
        Min = 1, Max = 30, Default = 15,
    })
    Layers = BedProtector:CreateSlider({
        Name = 'Layers',
        Min = 1, Max = 5, Default = 1,
        Suffix = function(val) return val <= 1 and 'layer' or 'layers' end,
    })
    Switch = BedProtector:CreateToggle({Name = 'Auto Switch'})
    Smart = BedProtector:CreateToggle({Name = 'Smart', Default = true})
    WoolOnly = BedProtector:CreateToggle({
        Name = 'Wool only',
        Tooltip = 'Repairs with wool instead of your toughest block'
    })
    LimitItem = BedProtector:CreateToggle({
        Name = 'Limit to item',
        Tooltip = 'Only works while holding the item it uses'
    })
    Radius = BedProtector:CreateSlider({
        Name = 'Defense Radius',
        Min = 3,
        Max = 30,
        Default = 15,
        Suffix = function(val) return val == 1 and 'stud' or 'studs' end,
        Tooltip = 'How far from the bed counts as your defense'
    })
    NoAnimation = BedProtector:CreateToggle({
        Name = 'No Animation',
        Tooltip = 'Hides the arm swing while repairing'
    })
    
    
    syncModeOptions()
end)
