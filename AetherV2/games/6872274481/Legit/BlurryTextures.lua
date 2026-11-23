run(function()
	local BlurryTextures
	local Intensity
	local BlurHotbar
	local BlurTextures
	local BlurAll
	local DepthBlur
	local Padding
	local LowGraphics
	local MinQuality

	local BLUR_PATH = 'aetherv2/assets/new/blur.png'
	local BLUR_FALLBACK = 'rbxassetid://14898786664'
	local SLICE_CENTER = Rect.new(52, 31, 261, 502)
	local OVERLAY_NAME = 'AetherBlur'
	local MARKER = 'AetherBlurryTextures'
	local OVERLAY_LIMIT = 160
	local SWAP_LIMIT = 512
	local PER_FRAME = 12
	local SWEEP_FRAMES = 180
	local MIN_ICON = 24
	local MIN_PANEL = 40
	local SLICE_FROM = 96
	local LOOK_INTERVAL = 6

	local overlays = setmetatable({}, {__mode = 'k'})
	local swaps = setmetatable({}, {__mode = 'k'})
	local attempts = setmetatable({}, {__mode = 'k'})
	local queued = {}
	local pending = {}
	local scopeRoots = {}
	local overlayCount = 0
	local swapCount = 0
	local frames = 0
	local lookFrame = 0
	local lookDistance
	local depthEffect
	local blurAsset

	local function blurImage()
		if not blurAsset then
			local ok, result = pcall(getcustomasset, BLUR_PATH)
			blurAsset = (ok and type(result) == 'string' and result ~= '') and result or BLUR_FALLBACK
		end
		return blurAsset
	end

	local function strength()
		return math.clamp((Intensity and Intensity.Value or 30) / 100, 0.1, 0.9)
	end

	local function overlayTransparency()
		return math.clamp(1 - strength(), 0.05, 0.9)
	end

	local function padding()
		return math.clamp(Padding and Padding.Value or 6, 0, 32)
	end

	local qualitySettings
	local blocked = false

	local function qualityLevel()
		if not qualitySettings then
			local ok, settings = pcall(function()
				return game:GetService('UserSettings'):GetService('UserGameSettings')
			end)
			qualitySettings = ok and settings or false
		end
		if not qualitySettings then return 0 end
		local ok, level = pcall(function()
			return qualitySettings.SavedQualityLevel.Value
		end)
		return (ok and tonumber(level)) or 0
	end

	local function recomputeBlocked()
		if not (LowGraphics and LowGraphics.Enabled) then
			blocked = false
			return blocked
		end
		local level = qualityLevel()
		blocked = level > 0 and level < (MinQuality and MinQuality.Value or 3)
		return blocked
	end

	local function active()
		return BlurryTextures.Enabled == true and not blocked
	end

	local function cornerOf(object)
		for _, child in object:GetChildren() do
			if child:IsA('UICorner') then
				return child.CornerRadius
			end
		end
		return nil
	end

	local function walk(root, visit)
		local stack = {root}
		while #stack > 0 do
			local object = table.remove(stack)
			if not visit(object) then return false end
			for _, child in object:GetChildren() do
				table.insert(stack, child)
			end
		end
		return true
	end

	local hotbarCache
	local function hotbarPanel()
		local cached = hotbarCache
		if cached and cached.Parent then return cached end
		hotbarCache = nil
		local playerGui = lplr.PlayerGui
		local gui = playerGui and playerGui:FindFirstChild('hotbar')
		if not gui then return end
		local panel = gui:FindFirstChild('1')
		if not (panel and panel:IsA('GuiObject')) then
			panel = gui:FindFirstChildWhichIsA('GuiObject')
		end
		if not (panel and panel:IsA('GuiObject')) then return end
		hotbarCache = panel
		return panel
	end

	local function minSizeFor(kind)
		return kind == 'panel' and MIN_PANEL or MIN_ICON
	end

	local function targetKind(object)
		if BlurHotbar and BlurHotbar.Enabled and hotbarCache and object:IsDescendantOf(hotbarCache) then
			return nil
		end
		if object:IsA('ImageLabel') or object:IsA('ImageButton') then
			if object.Image ~= '' and object.ImageTransparency < 1 then return 'icon' end
			return nil
		end
		if BlurAll and BlurAll.Enabled then
			if object:IsA('CanvasGroup') or object:IsA('ViewportFrame') then return 'panel' end
			if object:IsA('Frame') or object:IsA('ScrollingFrame') or object:IsA('TextLabel') or object:IsA('TextButton') then
				if object.BackgroundTransparency < 0.75 then return 'panel' end
			end
		end
		return nil
	end

	local function isCovered(object)
		local parent = object.Parent
		while parent do
			if overlays[parent] then return true end
			parent = parent.Parent
		end
		return false
	end

	local function buildOverlay(object, pad, forced)
		if overlays[object] then return overlays[object] end
		if not object or not object:IsA('GuiObject') or not object.Parent then return end
		if object:GetAttribute(MARKER) then return end
		local kind = forced and 'panel' or targetKind(object)
		if not kind then return end
		if not forced and not active() then return end
		if not forced and isCovered(object) then return end
		if overlayCount >= OVERLAY_LIMIT then return end

		local size = object.AbsoluteSize
		if size.X < 1 and size.Y < 1 then
			local tries = attempts[object] or 0
			if tries < 3 then
				attempts[object] = tries + 1
				return false
			end
			return
		end
		if math.max(size.X, size.Y) < minSizeFor(kind) then return end

		pad = tonumber(pad) or padding()
		if object.ClipsDescendants then
			pad = 0
		end

		local overlay = Instance.new('ImageLabel')
		overlay.Name = OVERLAY_NAME
		overlay:SetAttribute(MARKER, true)
		overlay.BackgroundTransparency = 1
		overlay.BorderSizePixel = 0
		overlay.Image = blurImage()
		overlay.ImageTransparency = overlayTransparency()
		overlay.Position = UDim2.fromOffset(-pad, -pad)
		overlay.Size = UDim2.new(1, pad * 2, 1, pad * 2)
		if math.max(size.X, size.Y) >= SLICE_FROM then
			overlay.ScaleType = Enum.ScaleType.Slice
			overlay.SliceCenter = SLICE_CENTER
		else
			overlay.ScaleType = Enum.ScaleType.Stretch
		end
		local radius = cornerOf(object)
		if radius then
			local corner = Instance.new('UICorner')
			corner.CornerRadius = UDim.new(math.min(radius.Scale, 0.5), radius.Offset + pad)
			corner.Parent = overlay
		end
		overlay.ZIndex = math.clamp(object.ZIndex + 1, 1, 100)
		local seen = 0
		for _, descendant in object:GetDescendants() do
			seen += 1
			if seen > 400 then break end
			if descendant:IsA('GuiObject') and descendant.ZIndex >= overlay.ZIndex then
				overlay.ZIndex = math.clamp(descendant.ZIndex + 1, 1, 100)
			end
		end
		overlay.Parent = object

		overlays[object] = overlay
		overlayCount += 1
		return overlay
	end

	local function destroyOverlay(object)
		local overlay = overlays[object]
		if not overlay then return end
		overlays[object] = nil
		attempts[object] = nil
		overlayCount = math.max(overlayCount - 1, 0)
		if overlay.Parent then
			overlay:Destroy()
		end
	end

	local function resetOverlays()
		for object in overlays do
			destroyOverlay(object)
		end
		overlayCount = 0
		table.clear(pending)
		table.clear(queued)
		table.clear(attempts)
	end

	local function styleOverlays()
		local transparency = overlayTransparency()
		for _, overlay in overlays do
			if overlay.Parent then
				overlay.ImageTransparency = transparency
			end
		end
	end

	local function padOverlays()
		local wanted = padding()
		for object, overlay in overlays do
			if overlay.Parent then
				local pad = object.ClipsDescendants and 0 or wanted
				overlay.Position = UDim2.fromOffset(-pad, -pad)
				overlay.Size = UDim2.new(1, pad * 2, 1, pad * 2)
				local corner = overlay:FindFirstChildWhichIsA('UICorner')
				local radius = cornerOf(object)
				if corner and radius then
					corner.CornerRadius = UDim.new(math.min(radius.Scale, 0.5), radius.Offset + pad)
				end
			end
		end
	end

	local function schedule(object, pad, forced)
		if overlays[object] or queued[object] then return end
		queued[object] = true
		table.insert(pending, {Object = object, Pad = pad, Forced = forced})
	end

	local function flush()
		local budget = PER_FRAME
		while budget > 0 do
			local entry = table.remove(pending, 1)
			if not entry then break end
			local object = entry.Object
			queued[object] = nil
			if buildOverlay(object, entry.Pad, entry.Forced) == false then
				schedule(object, entry.Pad, entry.Forced)
			end
			budget -= 1
		end
	end

	local function sweep()
		for object, overlay in overlays do
			if object.Parent == nil or overlay.Parent == nil then
				overlays[object] = nil
				attempts[object] = nil
				overlayCount -= 1
			end
		end
		for object in swaps do
			if object.Parent == nil then
				swaps[object] = nil
				swapCount -= 1
			end
		end
		overlayCount = math.max(overlayCount, 0)
		swapCount = math.max(swapCount, 0)
	end

	local function scan()
		local playerGui = lplr.PlayerGui
		if not (playerGui and active() and BlurTextures.Enabled) then return end
		walk(playerGui, function(object)
			if not object:GetAttribute(MARKER) and object:IsA('GuiObject') and targetKind(object) then
				schedule(object)
			end
			return true
		end)
	end

	local function stampHotbar()
		if not (active() and BlurHotbar.Enabled) then return end
		local panel = hotbarPanel()
		if not panel then return end
		if buildOverlay(panel, padding(), true) == false then
			schedule(panel, padding(), true)
		end
	end


	local function textureProperty(object)
		if object:IsA('Decal') or object:IsA('Texture') then return 'Texture' end
		if object:IsA('SurfaceAppearance') then return 'ColorMap' end
		if object:IsA('MeshPart') then return 'TextureID' end
		return nil
	end

	local function isCharacter(object)
		local model = object:FindFirstAncestorOfClass('Model')
		return model ~= nil and model:FindFirstChildOfClass('Humanoid') ~= nil
	end

	local function refreshScope()
		table.clear(scopeRoots)
		table.insert(scopeRoots, getWorldFolder() or workspace)
		local viewmodel = gameCamera:FindFirstChild('Viewmodel')
		if viewmodel then
			table.insert(scopeRoots, viewmodel)
		end
	end

	local function inScope(object)
		for _, root in scopeRoots do
			if object:IsDescendantOf(root) then return true end
		end
		return false
	end

	local function swapTexture(object, property)
		if swaps[object] or swapCount >= SWAP_LIMIT then return end
		local ok, original = pcall(function()
			return object[property]
		end)
		if not ok or type(original) ~= 'string' or original == '' then return end
		local image = blurImage()
		if original == image then return end
		if not pcall(function()
			object[property] = image
		end) then
			return
		end
		swaps[object] = {Property = property, Original = original}
		swapCount += 1
	end

	local function restoreSwaps()
		for object, entry in swaps do
			swaps[object] = nil
			pcall(function()
				if object[entry.Property] == blurImage() then
					object[entry.Property] = entry.Original
				end
			end)
		end
		swapCount = 0
	end

	local function syncTextures()
		refreshScope()
		if swapCount >= SWAP_LIMIT then return end
		for _, root in scopeRoots do
			if swapCount >= SWAP_LIMIT then break end
			walk(root, function(object)
				local property = textureProperty(object)
				if property then swapTexture(object, property) end
				return swapCount < SWAP_LIMIT
			end)
		end
	end

	local function onWorld(object)
		if not (active() and BlurAll.Enabled) or swapCount >= SWAP_LIMIT then return end
		local property = textureProperty(object)
		if not property or not inScope(object) or isCharacter(object) then return end
		swapTexture(object, property)
	end

	local function ensureDepth()
		if depthEffect and depthEffect.Parent then return depthEffect end
		depthEffect = Instance.new('DepthOfFieldEffect')
		depthEffect.Name = 'AetherBlurryTextures'
		depthEffect.Enabled = true
		depthEffect.Parent = lightingService
		return depthEffect
	end

	local function removeDepth()
		if depthEffect then
			depthEffect:Destroy()
			depthEffect = nil
		end
	end

	local function lookedAtDistance()
		local ignore = {gameCamera}
		if lplr.Character then table.insert(ignore, lplr.Character) end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = ignore
		local camera = gameCamera.CFrame
		local ok, result = pcall(workspace.Raycast, workspace, camera.Position, camera.LookVector * 512, params)
		return ok and result and result.Distance or nil
	end

	local function updateLookedAt()
		if frames - lookFrame >= LOOK_INTERVAL then
			lookFrame = frames
			lookDistance = lookedAtDistance() or lookDistance
		end
		local effect = depthEffect
		if not (effect and effect.Parent) or not lookDistance then return end
		local value = strength()
		effect.FocusDistance = lookDistance * 1.6
		effect.InFocusRadius = 6
		effect.NearIntensity = value
		effect.FarIntensity = value * 0.5
	end

	local function updateDepth()
		local mode = DepthBlur and DepthBlur.Value or 'Off'
		if mode == 'Off' or not active() then
			removeDepth()
			return
		end
		local effect = ensureDepth()
		local value = strength()
		effect.Height = math.max(gameCamera.ViewportSize.Y, 1)
		effect.Enabled = true
		effect.FarIntensity = value
		if mode == 'Distant' then
			effect.FocusDistance = math.max(6, 24 * (1 - value))
			effect.InFocusRadius = math.max(48 * (1 - value), 8)
			effect.NearIntensity = 0
		elseif mode == 'Everything' then
			effect.FocusDistance = 0
			effect.InFocusRadius = 0
			effect.NearIntensity = value
		elseif mode == 'Looked at' then
			updateLookedAt()
		end
	end


	local function refresh()
		if not BlurryTextures.Enabled then return end
		resetOverlays()
		if blocked then
			restoreSwaps()
			removeDepth()
			return
		end
		stampHotbar()
		if BlurTextures.Enabled then scan() end
		if BlurAll.Enabled then
			syncTextures()
		else
			restoreSwaps()
		end
		styleOverlays()
		updateDepth()
	end

	local function drive()
		frames += 1
		if #pending > 0 then flush() end
		if frames % SWEEP_FRAMES == 0 then
			sweep()
			local was = blocked
			if recomputeBlocked() ~= was then
				refresh()
			end
		end
		if depthEffect and depthEffect.Parent then
			if not depthEffect.Enabled then depthEffect.Enabled = true end
			if DepthBlur and DepthBlur.Value == 'Looked at' then updateLookedAt() end
		end
	end

	local function apply()
		local playerGui = lplr.PlayerGui
		if not playerGui then return end
		frames = 0
		lookDistance = nil
		hotbarCache = nil
		refreshScope()
		BlurryTextures:Clean(runService.Heartbeat:Connect(drive))
		BlurryTextures:Clean(lplr.PlayerGui.DescendantAdded:Connect(function(object)
			if object:GetAttribute(MARKER) then return end
			if object:IsA('LayerCollector') then
				hotbarCache = nil
				stampHotbar()
				walk(object, function(descendant)
					if not descendant:GetAttribute(MARKER) and descendant:IsA('GuiObject') and targetKind(descendant) then
						schedule(descendant)
					end
					return true
				end)
				return
			end
			if not object:IsA('GuiObject') then return end
			local panel = BlurHotbar.Enabled and hotbarPanel()
			if panel and (object == panel or object:IsDescendantOf(panel)) then
				stampHotbar()
			end
			if BlurTextures.Enabled and targetKind(object) then schedule(object) end
		end))
		BlurryTextures:Clean(workspace.DescendantAdded:Connect(onWorld))
		BlurryTextures:Clean(gameCamera:GetPropertyChangedSignal('ViewportSize'):Connect(updateDepth))
		BlurryTextures:Clean(playersService.LocalPlayer.CharacterAdded:Connect(function()
			task.delay(0.5, function()
				if not BlurryTextures.Enabled then return end
				refreshScope()
				stampHotbar()
				scan()
			end)
		end))
		recomputeBlocked()
		refresh()
		if blocked then
			notif('BlurryTextures', 'Blur skipped: graphics level '..qualityLevel()..' is below '..(MinQuality.Value)..'.', 8, 'warning')
		end
	end

	local function revert()
		table.clear(pending)
		table.clear(queued)
		table.clear(scopeRoots)
		resetOverlays()
		restoreSwaps()
		removeDepth()
	end

	BlurryTextures = vape.Categories.Legit:CreateModule({
		Name = 'BlurryTextures',
		Function = function(callback)
			if callback then
				apply()
			else
				revert()
			end
		end,
		Tooltip = 'Blurs the hotbar, item icons and world textures',
		Category = 'Hud'
	})

	Intensity = BlurryTextures:CreateSlider({
		Name = 'Intensity',
		Min = 10,
		Max = 90,
		Default = 30,
		Function = function()
			if not BlurryTextures.Enabled then return end
			styleOverlays()
			updateDepth()
		end,
		Tooltip = 'How strong the blur is'
	})

	local BlurHotbarState
	local BlurTexturesState
	local BlurAllState
	local BlurHotbarChanged = function()
			if not BlurryTextures.Enabled then return end
			refresh()
		end
	local BlurTexturesChanged = function()
			if not BlurryTextures.Enabled then return end
			refresh()
		end
	local BlurAllChanged = function()
			if not BlurryTextures.Enabled then return end
			refresh()
		end
	local BlurTargets
	BlurTargets = BlurryTextures:CreateMultiDropdown({
		Name = 'Blur',
		List = {'Hotbar', 'Textures', 'Everything'},
		Default = {'Hotbar', 'Textures'},
		Function = function()
			local on = BlurTargets:Has('Hotbar')
			if BlurHotbarState ~= on then
				BlurHotbarState = on
				BlurHotbarChanged(on)
			end
			local on = BlurTargets:Has('Textures')
			if BlurTexturesState ~= on then
				BlurTexturesState = on
				BlurTexturesChanged(on)
			end
			local on = BlurTargets:Has('Everything')
			if BlurAllState ~= on then
				BlurAllState = on
				BlurAllChanged(on)
			end
		end,
		Tooltip = 'What gets blurred; Everything also blurs the textures the other two miss'
	})
	BlurHotbarState = BlurTargets:Has('Hotbar')
	BlurTexturesState = BlurTargets:Has('Textures')
	BlurAllState = BlurTargets:Has('Everything')
	BlurHotbar = setmetatable({}, {__index = function(_, key) if key == 'Enabled' then return BlurTargets:Has('Hotbar') end end})
	BlurTextures = setmetatable({}, {__index = function(_, key) if key == 'Enabled' then return BlurTargets:Has('Textures') end end})
	BlurAll = setmetatable({}, {__index = function(_, key) if key == 'Enabled' then return BlurTargets:Has('Everything') end end})



	DepthBlur = BlurryTextures:CreateDropdown({
		Name = 'Depth blur',
		List = {'Off', 'Distant', 'Everything', 'Looked at'},
		Default = 'Off',
		Function = function()
			if not BlurryTextures.Enabled then return end
			updateDepth()
		end,
		Tooltip = 'Adds depth of field to the map'
	})

	Padding = BlurryTextures:CreateSlider({
		Name = 'Padding',
		Min = 0,
		Max = 20,
		Default = 6,
		Function = function()
			if not BlurryTextures.Enabled then return end
			padOverlays()
		end,
		Tooltip = 'Extends the overlay past the target'
	})

	LowGraphics = BlurryTextures:CreateToggle({
		Name = 'Disable on low graphics',
		Default = true,
		Function = function()
			if not BlurryTextures.Enabled then return end
			recomputeBlocked()
			refresh()
		end,
		Tooltip = 'Skips the blur on low graphics'
	})

	MinQuality = BlurryTextures:CreateSlider({
		Name = 'Min graphics level',
		Min = 1,
		Max = 10,
		Default = 3,
		Function = function()
			if not BlurryTextures.Enabled then return end
			recomputeBlocked()
			refresh()
		end,
		Tooltip = 'Lowest graphics level that still gets the blur'
	})

	local api = {}
	function api:AddBlur(object, pad)
		return buildOverlay(object, pad, true)
	end
	function api:RemoveBlur(object)
		destroyOverlay(object)
	end
	shared.AetherBlurryTextures = api

	vape:Remove('BlurryTextures')
end)
