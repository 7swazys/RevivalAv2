run(function()
    local Runtime = assert(AetherMatchRuntime, 'Aether BedWars runtime is unavailable')
    local Ports = AetherPortContext
    local safe = aetherPortSafe
    local notify = aetherPortNotify
    local rootOfLocal = aetherPortRoot
    local matchRunning = aetherPortMatchRunning
    local equippedKit = aetherPortEquippedKit
    local horizontalUnit = aetherPortHorizontalUnit
    local register = aetherPortRegister
    local abilityController = aetherPortAbilityController
    local canUseAbility = aetherPortCanUseAbility
    local addMovementOwner = aetherPortAddMovementOwner
    addMovementOwner('YaminiTP')

    local YaminiTP, created
    local Options = {}
    local generation = 0
    local busy = false
    local lastMethod = 'Pounce teleport'

    local MAX_HOP = 50
    local MAX_RANGE = 125
    local HOP_INTERVAL = 0.15
    local ARRIVAL_TOLERANCE = 6
    local PULLED_BACK = 22
    local MAX_HOPS = 60

    local rayCheck = RaycastParams.new()
    rayCheck.FilterType = Enum.RaycastFilterType.Exclude
    rayCheck.RespectCanCollide = true

    local function lookUnit(root)
        return horizontalUnit(root.CFrame.LookVector) or Vector3.zAxis
    end

    local function positionNow()
        local root = rootOfLocal()
        return root and root.Position
    end

    local function canWrite()
        local movement = Runtime.Movement
        if not movement then return true end
        return movement:CanWrite('YaminiTP')
    end

    local function writeTo(point)
        local root, _, humanoid = rootOfLocal()
        if not root then return false, 'character missing' end
        if not canWrite() then return false, 'movement is owned by another module' end
        root.AssemblyLinearVelocity = Vector3.zero
        root.CFrame = CFrame.lookAt(point, point + lookUnit(root))
        if humanoid then
            safe('yaminitp.state', function() humanoid:ChangeState(Enum.HumanoidStateType.Freefall) end)
        end
        return true
    end

    local function destinationUnderCursor()
        local camera = gameCamera
        if not camera then return nil, 'no camera' end
        local mouse = inputService.TouchEnabled and (camera.ViewportSize / 2) or inputService:GetMouseLocation()
        rayCheck.FilterDescendantsInstances = {lplr.Character, camera}
        local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
        local result = workspace:Raycast(ray.Origin, ray.Direction * MAX_RANGE, rayCheck)
        if not result then return nil, 'nothing under the cursor' end
        local _, _, humanoid = rootOfLocal()
        local lift = (humanoid and humanoid.HipHeight or 2) + 2.5
        local point = result.Position
        if Options.GroundSnap.Enabled then
            local ground = workspace:Raycast(point + Vector3.new(0, 16, 0), Vector3.new(0, -48, 0), store.blockRaycast)
            if ground then point = ground.Position end
        end
        return point + Vector3.new(0, lift, 0)
    end

    local function castPounce()
        local controller = abilityController()
        if controller and type(controller.useAbility) == 'function' and canUseAbility('CAT_POUNCE') then
            local ok, result = pcall(controller.useAbility, controller, 'CAT_POUNCE')
            if ok and result ~= false then return true, 'pounce' end
        end
        local events = replicatedStorage['events-@easy-games/game-core:shared/game-core-networking@getEvents.Events']
        local remote = events and events:FindFirstChild('useAbility')
        if not remote then return false, 'the pounce ability is not in this game' end
        local ok = pcall(function()
            remote:FireServer('CAT_POUNCE', {direction = Vector3.new(9e9, 9e9, 9e9)})
        end)
        if not ok then return false, 'the pounce could not be cast' end
        return true, 'pounce (direct cast)'
    end

    local function runSingle(destination)
        if not canWrite() then return false end
        local wrote = writeTo(destination)
        if not wrote then return false end
        task.wait(HOP_INTERVAL)
        local after = positionNow()
        if not after then return false end
        if (after - destination).Magnitude <= ARRIVAL_TOLERANCE then return true end
        return false
    end

    local function runHops(destination)
        local start = positionNow()
        local distance = start and (destination - start).Magnitude or 0
        local budget = math.min(math.max(math.ceil(distance / MAX_HOP) + 2, 2), MAX_HOPS)
        local hops = 0

        while hops < budget do
            hops += 1
            local root = rootOfLocal()
            if not root then return false end
            if not canWrite() then return false end
            local delta = destination - root.Position
            local target = delta.Magnitude <= MAX_HOP and destination or (root.Position + delta.Unit * MAX_HOP)
            if not writeTo(target) then return false end
            task.wait(HOP_INTERVAL)

            local after = positionNow()
            if not after then return false end
            if (after - destination).Magnitude <= ARRIVAL_TOLERANCE then return true end
            if (after - target).Magnitude > PULLED_BACK then return false end
        end
        return false
    end

    local function execute(token)
        local cancelled = function() return token ~= generation or not YaminiTP.Enabled end
        local root = rootOfLocal()
        if not root then return end
        if not matchRunning() then return end

        local kit = equippedKit()
        kit = type(kit) == 'string' and kit:lower() or nil
        if kit ~= 'cat' then return end

        local destination = destinationUnderCursor()
        if not destination then return end

        local multi = Options.Multi.Enabled
        local attempted = (destination - root.Position).Magnitude
        local cap = multi and MAX_RANGE or MAX_HOP

        if attempted > cap then
            return notify(string.format('YaminiTP: that point is %.0f studs away - the limit is %d studs.', attempted, cap), 5, 'alert')
        end
        if attempted <= ARRIVAL_TOLERANCE then return end

        local movement = Runtime.Movement
        local lease = movement and movement:Acquire('YaminiTP', movement.Priorities.Ability, 6, nil, true)

        local cast, castName = castPounce()
        if not cast then
            if lease then lease:Release() end
            return
        end
        if castName then lastMethod = castName end

        local arrived = false
        if not cancelled() then
            arrived = multi and runHops(destination) or runSingle(destination)
        end

        if arrived then
            task.wait(0.4)
            local after = positionNow()
            if not after or (after - destination).Magnitude > ARRIVAL_TOLERANCE + 4 then
                arrived = false
            end
        end

        if arrived then
            Ports.Diagnostics.YaminiTP = {At = tick(), Method = lastMethod, Result = 'arrived'}
            print(string.format('[YaminiTP] arrived with %s', lastMethod))
        else
            lastMethod = 'blocked'
            Ports.Diagnostics.YaminiTP = {At = tick(), Result = 'blocked'}
            print('[YaminiTP] blocked')
        end
        if lease then lease:Release() end
    end

    YaminiTP, created = register('Kits', 'YaminiTP', {
        Category = 'Ability',
        Tooltip = 'Teleports you to your cursor as Yamini',
        Function = function(callback)
            generation += 1
            local token = generation
            if not callback or busy then return end
            task.spawn(function()
                busy = true
                local ok, err = xpcall(function()
                    if not YaminiTP.Enabled or token ~= generation then return end
                    execute(token)
                end, debug and debug.traceback or tostring)
                if not ok then
                    print('[YaminiTP] error ' .. tostring(err))
                    Ports.Diagnostics.YaminiTP = {At = tick(), Error = tostring(err)}
                end
                busy = false
                if token == generation and YaminiTP.Enabled then
                    task.spawn(function()
                        if token == generation and YaminiTP.Enabled then YaminiTP:Toggle() end
                    end)
                end
            end)
        end,
        ExtraText = function()
            return lastMethod
        end
    })

    if created then
        Options.Multi = YaminiTP:CreateToggle({
            Name = 'Multi Teleport',
            Default = false,
            Tooltip = 'Teleports in hops to reach further'
        })
        Options.GroundSnap = YaminiTP:CreateToggle({
            Name = 'Land on ground',
            Default = true,
            Tooltip = 'Lands you on the floor under your cursor'
        })
    end
end)
