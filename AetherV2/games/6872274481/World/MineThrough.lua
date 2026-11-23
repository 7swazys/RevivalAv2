run(function()
    local MineThrough
    local Place
    local Targets
    local Self

    local SCAN_DISTANCE = 64
    local SCAN_DISTANCE_SQ = SCAN_DISTANCE * SCAN_DISTANCE
    local QUERY_IGNORE = 'gamecore_GameQueryIgnore'

    local depth = 0
    local originalGetMouseInfo
    local selectorHook
    local originalHitBlock
    local breakHook

    local function invisible(entity)
        local root = entity.RootPart
        return root ~= nil and (root.Transparency >= 0.95 or root.LocalTransparencyModifier >= 0.95)
    end

    local function watched(entity)
        if Targets.Invisible.Enabled and invisible(entity) then return false end
        if entity.Player then
            return Targets.Players.Enabled
        end
        return Targets.NPCs.Enabled
    end

    local partCache = setmetatable({}, {__mode = 'k'})

    local function collectParts(character)
        local list = {}
        for _, part in character:GetDescendants() do
            if part:IsA('BasePart') then
                table.insert(list, part)
            end
        end
        return list
    end

    local function partsOf(character)
        local entry = partCache[character]
        if entry then
            if entry.Dirty then
                entry.Parts = collectParts(character)
                entry.Dirty = false
            end
            return entry.Parts
        end

        entry = {Parts = collectParts(character), Dirty = false}
        partCache[character] = entry
        character.DescendantAdded:Connect(function()
            entry.Dirty = true
        end)
        character.DescendantRemoved:Connect(function()
            entry.Dirty = true
        end)
        return entry.Parts
    end

    local hitboxes = {}
    local saved = {}
    local origin
    local total

    local function scan(character, root)
        if not character or not root then return end
        local offset = root.Position - origin
        if offset:Dot(offset) > SCAN_DISTANCE_SQ then return end
        for _, part in partsOf(character) do
            local ignored = part:GetAttribute(QUERY_IGNORE)
            if part.CanQuery and ignored ~= true then
                total += 1
                hitboxes[total] = part
                if ignored ~= nil then
                    saved[part] = ignored
                end
            end
        end
    end

    local function collect()
        origin = gameCamera.CFrame.Position
        total = 0

        for _, entity in entitylib.List do
            if watched(entity) then
                scan(entity.Character, entity.RootPart)
            end
        end
        if Self.Enabled and entitylib.isAlive then
            scan(entitylib.character.Character, entitylib.character.RootPart)
        end

        for index = total + 1, #hitboxes do
            hitboxes[index] = nil
        end

        return total
    end

    local charRay = RaycastParams.new()
    charRay.FilterType = Enum.RaycastFilterType.Include
    local charList, charListAt = {}, 0

    local function refreshCharacters()
        local now = os.clock()
        if now - charListAt < 0.25 then return end
        charListAt = now
        table.clear(charList)
        for _, entity in entitylib.List do
            if entity.Character and watched(entity) then
                table.insert(charList, entity.Character)
            end
        end
        if Self.Enabled and entitylib.isAlive and entitylib.character.Character then
            table.insert(charList, entitylib.character.Character)
        end
        charRay.FilterDescendantsInstances = charList
    end

    local function entityInTheWay()
        refreshCharacters()
        if #charList == 0 then return false end
        local camera = workspace.CurrentCamera
        if not camera then return true end
        local mouse = inputService:GetMouseLocation()
        local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
        return workspace:Raycast(ray.Origin, ray.Direction * SCAN_DISTANCE, charRay) ~= nil
    end

    local function ignoreHitboxes(callback, ...)
        if depth > 0 then return callback(...) end
        if not entityInTheWay() then return callback(...) end

        local count = collect()
        if count == 0 then
            return callback(...)
        end

        depth = 1

        for index = 1, count do
            local part = hitboxes[index]
            part.CanQuery = false
            part:SetAttribute(QUERY_IGNORE, true)
        end

        local args = table.pack(...)
        local results = table.pack(xpcall(function()
            return callback(table.unpack(args, 1, args.n))
        end, function(err) return err end))

        for index = 1, count do
            local part = hitboxes[index]
            if part.Parent then
                part.CanQuery = true
                part:SetAttribute(QUERY_IGNORE, saved[part])
            end
        end
        if next(saved) ~= nil then
            table.clear(saved)
        end
        depth = 0

        if not results[1] then error(results[2], 0) end
        return table.unpack(results, 2, results.n)
    end

    local function hookSelector()
        if selectorHook then return end
        local selector = bedwars.BlockSelector
        if type(selector) ~= 'table' or type(selector.getMouseInfo) ~= 'function' then return end

        originalGetMouseInfo = selector.getMouseInfo
        selectorHook = function(self, mode, ...)
            if depth > 0 or not MineThrough.Enabled or (mode == 0 and not Place.Enabled) then
                return originalGetMouseInfo(self, mode, ...)
            end
            return ignoreHitboxes(originalGetMouseInfo, self, mode, ...)
        end
        selector.getMouseInfo = selectorHook
    end

    local function unhookSelector()
        if not selectorHook then return end
        if bedwars.BlockSelector.getMouseInfo == selectorHook then
            bedwars.BlockSelector.getMouseInfo = originalGetMouseInfo
            selectorHook, originalGetMouseInfo = nil, nil
        end
    end

    local function hookBreak()
        if breakHook then return end
        local breaker = bedwars.BlockBreaker
        if type(breaker) ~= 'table' or type(breaker.hitBlock) ~= 'function' then return end

        originalHitBlock = breaker.hitBlock
        breakHook = function(self, ...)
            if depth > 0 or not MineThrough.Enabled then
                return originalHitBlock(self, ...)
            end
            return ignoreHitboxes(originalHitBlock, self, ...)
        end
        breaker.hitBlock = breakHook
    end

    local function unhookBreak()
        if not breakHook then return end
        if bedwars.BlockBreaker.hitBlock == breakHook then
            bedwars.BlockBreaker.hitBlock = originalHitBlock
            breakHook, originalHitBlock = nil, nil
        end
    end

    MineThrough = vape.Categories.World:CreateModule({
        Name = 'MineThrough',
        Tooltip = 'Mines the block behind an entity under your cursor',
        Function = function(enabled)
            if enabled then
                hookSelector()
                hookBreak()
                bedwars.MineThrough = Place.Enabled and ignoreHitboxes or nil
            else
                bedwars.MineThrough = nil
                unhookSelector()
                unhookBreak()
            end
        end,
        ExtraText = function()
            return Place.Enabled and 'Mine + place' or 'Mine'
        end
    })
    Targets = MineThrough:CreateTargets({
        Players = true,
        NPCs = true,
        Tooltip = 'Who it mines through',
    })
    Place = MineThrough:CreateToggle({
        Name = 'Place',
        Default = true,
        Tooltip = 'Lets you place blocks through entities',
        Function = function(value)
            if MineThrough.Enabled then
                bedwars.MineThrough = value and ignoreHitboxes or nil
            end
        end
    })
    Self = MineThrough:CreateToggle({
        Name = 'Self',
        Default = true,
        Tooltip = 'Also ignores your own hitbox'
    })
end)
