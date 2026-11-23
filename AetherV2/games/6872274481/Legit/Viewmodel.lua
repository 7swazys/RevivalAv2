run(function()
	local Main = vape.Libraries.mergedModule(vape.Categories.Legit, {
		Name = 'Viewmodel',
		Tooltip = 'Changes how the item you hold looks and moves'
	})

run(function()
    local Viewmodel
    local Depth
    local Horizontal
    local Vertical
    local NoBob
    local Rots = {}
    local old, oldc1
    local walkIds, walkTypes

    local function loadWalk()
        if walkIds then return end
        walkIds, walkTypes = {}, {}
        for name, value in bedwars.AnimationType or {} do
            if type(name) == 'string' and name:find('^FP_') and (name:find('WALK') or name:find('SPRINT') or name:find('RUN')) then
                walkTypes[value] = true
                local ok, id = pcall(bedwars.GameAnimationUtil.getAssetId, bedwars.GameAnimationUtil, value)
                if ok and id then
                    walkIds[tostring(id)] = true
                end
            end
        end
    end

    local function isWalk(track)
        local anim = track.Animation
        return anim ~= nil and walkIds ~= nil and walkIds[anim.AnimationId] == true
    end

    local function stopBob(viewmodel)
        local animator = viewmodel and viewmodel:FindFirstChildWhichIsA('Animator', true)
        if not animator then return end
        for _, track in animator:GetPlayingAnimationTracks() do
            if isWalk(track) then
                track:Stop(0)
            end
        end
        Viewmodel:Clean(animator.AnimationPlayed:Connect(function(track)
            if NoBob.Enabled and isWalk(track) then
                track:Stop(0)
            end
        end))
    end

    Viewmodel = Main:Part({
		Label = 'Position and bobbing',
        Name = 'Viewmodel',
        Function = function(callback)
            local viewmodel = gameCamera:FindFirstChild('Viewmodel')
            if callback then
                old = bedwars.ViewmodelController.playAnimation
                oldc1 = viewmodel and viewmodel.RightHand.RightWrist.C1 or CFrame.identity
                loadWalk()
                bedwars.ViewmodelController.playAnimation = function(self, animtype, ...)
                    if NoBob.Enabled and walkTypes[animtype] then return end
                    return old(self, animtype, ...)
                end
                if NoBob.Enabled then
                    stopBob(viewmodel)
                end
                Viewmodel:Clean(gameCamera.ChildAdded:Connect(function(child)
                    if child.Name == 'Viewmodel' and NoBob.Enabled then
                        task.defer(stopBob, child)
                    end
                end))

                bedwars.InventoryViewmodelController:handleStore(bedwars.Store:getState())
                if viewmodel then
                    gameCamera.Viewmodel.RightHand.RightWrist.C1 = oldc1 * CFrame.Angles(math.rad(Rots[1].Value), math.rad(Rots[2].Value), math.rad(Rots[3].Value))
                end
                lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_DEPTH_OFFSET', -Depth.Value)
                lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_HORIZONTAL_OFFSET', Horizontal.Value)
                lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_VERTICAL_OFFSET', Vertical.Value)
            else
                if old then
                    bedwars.ViewmodelController.playAnimation = old
                end
                if viewmodel then
                    viewmodel.RightHand.RightWrist.C1 = oldc1
                end

                bedwars.InventoryViewmodelController:handleStore(bedwars.Store:getState())
                lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_DEPTH_OFFSET', 0)
                lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_HORIZONTAL_OFFSET', 0)
                lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_VERTICAL_OFFSET', 0)
                old = nil
            end
        end,
        Tooltip = 'Changes how the item you hold looks and moves'
    })
    Depth = Viewmodel:CreateSlider({
        Name = 'Depth',
        Min = 0,
        Max = 2,
        Default = 0.8,
        Decimal = 10,
        Function = function(val)
            if Viewmodel.Enabled then
                lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_DEPTH_OFFSET', -val)
            end
        end
    })
    Horizontal = Viewmodel:CreateSlider({
        Name = 'Horizontal',
        Min = 0,
        Max = 2,
        Default = 0.8,
        Decimal = 10,
        Function = function(val)
            if Viewmodel.Enabled then
                lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_HORIZONTAL_OFFSET', val)
            end
        end
    })
    Vertical = Viewmodel:CreateSlider({
        Name = 'Vertical',
        Min = -0.2,
        Max = 2,
        Default = -0.2,
        Decimal = 10,
        Function = function(val)
            if Viewmodel.Enabled then
                lplr.PlayerScripts.TS.controllers.global.viewmodel['viewmodel-controller']:SetAttribute('ConstantManager_VERTICAL_OFFSET', val)
            end
        end
    })
    for _, name in {'Rotation X', 'Rotation Y', 'Rotation Z'} do
        table.insert(Rots, Viewmodel:CreateSlider({
            Name = name,
            Min = 0,
            Max = 360,
            Function = function(val)
                if Viewmodel.Enabled then
                    gameCamera.Viewmodel.RightHand.RightWrist.C1 = oldc1 * CFrame.Angles(math.rad(Rots[1].Value), math.rad(Rots[2].Value), math.rad(Rots[3].Value))
                end
            end
        }))
    end
    NoBob = Viewmodel:CreateToggle({
        Name = 'No Bobbing',
        Default = true,
        Function = function(callback)
            if callback and Viewmodel.Enabled then
                stopBob(gameCamera:FindFirstChild('Viewmodel'))
            end
        end
    })
end)

run(function()
    local ViewmodelVisuals
    local StrokeColor
    local Color

    local Instances = {}

    ViewmodelVisuals = Main:Part({
		Label = 'Item highlight',
		Default = false,
        Name = 'ViewmodelVisuals',
        Function = function(call)
            if call then
                local viewmodel = gameCamera:WaitForChild('Viewmodel', 9e9)
                if not ViewmodelVisuals.Enabled then
                    return
                end

                for i,v in viewmodel:GetChildren() do
                    if v:IsA('Accessory') then
                        local highlight = v.Handle:FindFirstChildOfClass('Highlight') or Instance.new('Highlight', v.Handle)
                        highlight.FillColor = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
                        highlight.FillTransparency = Color.Opacity
                        highlight.OutlineTransparency = StrokeColor.Opacity
                        highlight.OutlineColor = Color3.fromHSV(StrokeColor.Hue, StrokeColor.Sat, StrokeColor.Value)

                        ViewmodelVisuals:Clean(highlight)
                        table.insert(Instances, highlight)

                        break
                    end
                end

                ViewmodelVisuals:Clean(viewmodel.ChildAdded:Connect(function(visual)
                    if visual:IsA('Accessory') then
                        local highlight = visual.Handle:FindFirstChildOfClass('Highlight') or Instance.new('Highlight', visual.Handle)
                        highlight.FillColor = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
                        highlight.FillTransparency = Color.Opacity
                        highlight.OutlineTransparency = StrokeColor.Opacity
                        highlight.OutlineColor = Color3.fromHSV(StrokeColor.Hue, StrokeColor.Sat, StrokeColor.Value)

                        ViewmodelVisuals:Clean(highlight)
                        table.insert(Instances, highlight)
                    end
                end))

                ViewmodelVisuals:Clean(gameCamera.ChildAdded:Connect(function(visual)
                    if visual.Name == 'Viewmodel' then
                        ViewmodelVisuals:Toggle()
                        ViewmodelVisuals:Toggle()
                    end
                end))
            else
                table.clear(Instances)
            end
        end
    })

    Color = ViewmodelVisuals:CreateColorSlider({
        Name = 'Colour',
        Default = Color3.new(1, 1, 1),
        Function = function(hue, sat, val, opacity)
            for _, v in Instances do
                v.FillColor = Color3.fromHSV(hue, sat, val)
                v.FillTransparency = opacity
            end
        end
    })
    StrokeColor = ViewmodelVisuals:CreateColorSlider({
        Name = 'Stroke Colour',
        Default = Color3.new(),
        Function = function(hue, sat, val, opacity)
            for _, v in Instances do
                v.OutlineColor = Color3.fromHSV(hue, sat, val)
                v.OutlineTransparency = opacity
            end
        end
    })
end)


run(function()
    local replica, replicaName, watched

    local function clickGui()
        local scaled = vape.gui and vape.gui:FindFirstChild('ScaledGui')
        return scaled and scaled:FindFirstChild('ClickGui')
    end

    local function heldItem(viewmodel)
        for _, v in viewmodel:GetChildren() do
            if v:IsA('Accessory') and v ~= replica then
                return v
            end
        end
    end

    local function clearReplica()
        if replica then
            replica:Destroy()
            replica = nil
        end
    end

    local function makeReplica(viewmodel)
        local name = store.tools.sword and store.tools.sword.itemType or 'wood_sword'
        if replica and replica.Parent == viewmodel and replicaName == name then return end
        clearReplica()
        local items = replicatedStorage:FindFirstChild('Items')
        local template = items and (items:FindFirstChild(name) or items:FindFirstChild('wood_sword'))
        local hand = viewmodel:FindFirstChild('RightHand')
        local handGrip = hand and hand:FindFirstChild('RightGripAttachment')
        local handle = template and template:FindFirstChild('Handle')
        if not (handGrip and handle and handle:FindFirstChild('RightGripAttachment')) then return end
        local copy = template:Clone()
        copy.Name = 'AetherViewmodelPreview'
        for _, v in copy:GetDescendants() do
            if v:IsA('BasePart') then
                v.Transparency = 1 - (1 - v.Transparency) * 0.45
                v.CanCollide = false
                v.CanTouch = false
                v.CanQuery = false
                v.Massless = true
                v.CastShadow = false
            elseif v:IsA('Decal') or v:IsA('Texture') then
                v.Transparency = 1 - (1 - v.Transparency) * 0.45
            end
        end
        local weld = Instance.new('Weld')
        weld.Part0 = hand
        weld.Part1 = copy.Handle
        weld.C0 = handGrip.CFrame
        weld.C1 = copy.Handle.RightGripAttachment.CFrame
        weld.Parent = copy.Handle
        copy.Parent = viewmodel
        replica, replicaName = copy, name
    end

    local function refresh()
        local pane = Main.SettingsPane
        local gui = clickGui()
        local viewmodel = gameCamera:FindFirstChild('Viewmodel')
        if pane and pane.Visible and gui and gui.Visible and viewmodel and not heldItem(viewmodel) then
            makeReplica(viewmodel)
        else
            clearReplica()
        end
    end

    local function watch(viewmodel)
        if watched then
            watched:Disconnect()
            watched = nil
        end
        if viewmodel then
            watched = viewmodel.ChildAdded:Connect(function(child)
                if child ~= replica and child:IsA('Accessory') then
                    refresh()
                end
            end)
        end
        refresh()
    end

    if Main.SettingsPane then
        vape:Clean(Main.SettingsPane:GetPropertyChangedSignal('Visible'):Connect(refresh))
    end
    if clickGui() then
        vape:Clean(clickGui():GetPropertyChangedSignal('Visible'):Connect(refresh))
    end
    vape:Clean(gameCamera.ChildAdded:Connect(function(child)
        if child.Name == 'Viewmodel' then
            watch(child)
        end
    end))
    vape:Clean(gameCamera.ChildRemoved:Connect(function(child)
        if child.Name == 'Viewmodel' then
            refresh()
        end
    end))
    vape:Clean(function()
        if watched then
            watched:Disconnect()
        end
        clearReplica()
    end)
    watch(gameCamera:FindFirstChild('Viewmodel'))
end)

end)
