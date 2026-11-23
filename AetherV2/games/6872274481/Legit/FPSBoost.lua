run(function()
	local Main = vape.Libraries.mergedModule(vape.Categories.Legit, {
		Name = 'FPSBoost',
		Tooltip = 'Raises your framerate by reducing visual effects'
	})

run(function()
    local FPSBoost
    local Profile
    local Systems
	local changed = setmetatable({}, {__mode = 'k'})
	local killEffects, visualizers = {}, {}
	local profiles = {
		Quality = {},
		Balanced = {'Particles', 'Bloom', 'Weather'},
		Performance = {'Particles', 'Bloom', 'Weather', 'Shadows', 'Kill effects', 'Projectile effects', 'Lights', 'Atmosphere'},
		Potato = {'Particles', 'Bloom', 'Weather', 'Shadows', 'Kill effects', 'Projectile effects', 'Textures', 'Materials', 'Lighting', 'Lights', 'Atmosphere'},
		
		Minimal = {'Particles'}, Competitive = {'Particles', 'Bloom', 'Weather', 'Shadows', 'Kill effects', 'Projectile effects'}, Max = {'Particles', 'Bloom', 'Weather', 'Shadows', 'Kill effects', 'Projectile effects', 'Textures', 'Materials', 'Lighting'}
    }

    local active = {}
    local potato = false
    local function selected(name)
        return active[name] == true
    end
    local function refreshSelection()
        table.clear(active)
        for _, name in Systems.ListEnabled do active[name] = true end
        potato = Profile.Value == 'Potato' or Profile.Value == 'Max'
    end

    local function wanted(object)
        if object:IsA('ParticleEmitter') or object:IsA('Trail') or object:IsA('Beam') then
            return active.Particles or active.Weather
        end
        if object:IsA('PostEffect') then return active.Bloom end
        if object:IsA('Light') then return active.Lights end
        if object:IsA('Atmosphere') then return active.Atmosphere end
        if potato then
            return object:IsA('BasePart') or object:IsA('Texture') or object:IsA('Decal') or object:IsA('SurfaceAppearance')
                or object:IsA('Explosion') or object:IsA('Smoke') or object:IsA('Fire') or object:IsA('Sparkles')
        end
        return false
    end

    local function setProperty(object, property, value)
        if not object or changed[object] and changed[object][property] then return end
        local ok, original = pcall(function() return object[property] end)
        if not ok or original == value then return end
        changed[object] = changed[object] or {}
        changed[object][property] = {Original = original, Applied = value}
        pcall(function() object[property] = value end)
    end

    local function isBedName(name)
        name = name:lower()
        return name == 'bed' or name == 'beds' or (name:sub(1, 3) == 'bed' and name:sub(1, 7) ~= 'bedrock')
    end

    local function isBedPart(object)
        local current = object
        for _ = 1, 6 do
            if not current then break end
            if isBedName(current.Name) then return true end
            if typeof(current) == 'Instance' and collectionService:HasTag(current, 'bed') then return true end
            current = current.Parent
        end
        return false
    end

    local function applyObject(object)
        if object:IsDescendantOf(coreGui) or (lplr.PlayerGui and object:IsDescendantOf(lplr.PlayerGui)) then return end
        if selected('Particles') and (object:IsA('ParticleEmitter') or object:IsA('Trail') or object:IsA('Beam')) then
            setProperty(object, 'Enabled', false)
        elseif selected('Bloom') and object:IsA('PostEffect') then
            setProperty(object, 'Enabled', false)
        end
        if selected('Lights') and object:IsA('Light') then setProperty(object, 'Enabled', false) end
        if selected('Atmosphere') and object:IsA('Atmosphere') then
            setProperty(object, 'Density', 0)
            setProperty(object, 'Haze', 0)
            setProperty(object, 'Glare', 0)
        end
        if selected('Weather') and (object:GetAttribute('WeatherEffect') or object.Name:lower():find('weather')) then
            if object:IsA('ParticleEmitter') or object:IsA('Trail') or object:IsA('Beam') then setProperty(object, 'Enabled', false) end
        end
		if potato then
            if isBedPart(object) then return end
            if object:IsA('BasePart') then
                setProperty(object, 'CastShadow', false)
                setProperty(object, 'Reflectance', 0)
                setProperty(object, 'Material', Enum.Material.SmoothPlastic)
                if object:IsA('MeshPart') then
                    setProperty(object, 'TextureID', '')
                    setProperty(object, 'RenderFidelity', Enum.RenderFidelity.Performance)
                end
            elseif object:IsA('Texture') or object:IsA('Decal') then
                setProperty(object, 'Transparency', 1)
            elseif object:IsA('SurfaceAppearance') then
                setProperty(object, 'ColorMap', '')
                setProperty(object, 'MetalnessMap', '')
                setProperty(object, 'NormalMap', '')
                setProperty(object, 'RoughnessMap', '')
            elseif object:IsA('Explosion') then
                setProperty(object, 'Visible', false)
            elseif object:IsA('Smoke') or object:IsA('Fire') or object:IsA('Sparkles') then
                setProperty(object, 'Enabled', false)
            end
        end
    end

    local queue, queued, head, tail = {}, {}, 1, 0
    local FRAME_BUDGET = 0.0008
    local function queueObject(object)
        if queued[object] or not wanted(object) then return end
        queued[object] = true
        tail += 1
        queue[tail] = object
    end

    local function drain()
        local deadline = os.clock() + FRAME_BUDGET
        while head <= tail do
            local object = queue[head]
            queue[head] = nil
            head += 1
            queued[object] = nil
            if object and object.Parent then
                pcall(applyObject, object)
            end
            if os.clock() >= deadline then break end
        end
        if head > tail then
            table.clear(queue)
            head, tail = 1, 0
        end
    end

    local function restore()
        for object, properties in changed do
            for property, state in properties do
                pcall(function()
                    if object.Parent and object[property] == state.Applied then object[property] = state.Original end
                end)
            end
        end
        for name, effect in killEffects do
            if bedwars.KillEffectController.killEffects[name] then bedwars.KillEffectController.killEffects[name] = effect end
        end
        for name, fn in visualizers do
            if bedwars.VisualizerUtils[name] then bedwars.VisualizerUtils[name] = fn end
        end
        table.clear(changed); table.clear(killEffects); table.clear(visualizers)
    end

    local function apply()
        if selected('Shadows') then setProperty(game:GetService('Lighting'), 'GlobalShadows', false) end
		if Profile.Value == 'Potato' or Profile.Value == 'Max' then
            local lighting = game:GetService('Lighting')
            local terrain = workspace:FindFirstChildOfClass('Terrain')
            setProperty(lighting, 'Brightness', 1)
            setProperty(lighting, 'EnvironmentDiffuseScale', 0)
            setProperty(lighting, 'EnvironmentSpecularScale', 0)
            if terrain then
                setProperty(terrain, 'Decoration', false)
                setProperty(terrain, 'WaterReflectance', 0)
                setProperty(terrain, 'WaterTransparency', 1)
                setProperty(terrain, 'WaterWaveSize', 0)
                setProperty(terrain, 'WaterWaveSpeed', 0)
            end
        end
        local lighting = game:GetService('Lighting')
        for _, root in {workspace, lighting} do
            for _, object in root:GetDescendants() do queueObject(object) end
        end
        if selected('Kill effects') then
            for name, effect in bedwars.KillEffectController.killEffects do
                if not name:find('Custom') then
                    killEffects[name] = effect
                    bedwars.KillEffectController.killEffects[name] = {new = function() return {onKill = function() end, isPlayDefaultKillEffect = function() return true end} end}
                end
            end
        end
        if selected('Projectile effects') then
            for name, fn in bedwars.VisualizerUtils do visualizers[name] = fn; bedwars.VisualizerUtils[name] = function() end end
        end
    end

    FPSBoost = Main:Part({
		Label = 'Reduce effects',
        Name = 'FPSBoost',
        Function = function(callback)
            restore()
            table.clear(queue)
            table.clear(queued)
            head, tail = 1, 0
            if not callback then return end
            refreshSelection()
            apply()

            local lighting = game:GetService('Lighting')
            FPSBoost:Clean(workspace.DescendantAdded:Connect(queueObject))
            FPSBoost:Clean(lighting.DescendantAdded:Connect(queueObject))
            FPSBoost:Clean(runService.Heartbeat:Connect(function()
                if head <= tail then drain() end
            end))
        end,
        Tooltip = 'Raises your framerate by reducing visual effects'
    })
	Profile = FPSBoost:CreateDropdown({
		Name = 'Profile', List = {'Quality', 'Balanced', 'Performance', 'Potato'}, Default = 'Balanced',
		Function = function(value)
			local canonical = ({Minimal = 'Performance', Competitive = 'Performance', Max = 'Potato'})[value] or value
			shared.AetherPerformancePreset = canonical
			if not Systems then return end
			Systems.ListEnabled = table.clone(profiles[canonical] or profiles.Balanced)
			Systems:ChangeValue()
            if FPSBoost.Enabled then FPSBoost:Toggle(); FPSBoost:Toggle() end
        end
    })
	
	
	local loadProfile = Profile.Load
	function Profile:Load(tab)
		if tab and type(tab.Value) == 'string' then
			local legacy = ({Minimal = 'Quality', Competitive = 'Performance', Max = 'Potato'})[tab.Value]
			if legacy then
				local migrated = table.clone(tab)
				migrated.Value = legacy
				return loadProfile(self, migrated)
			end
		end
		return loadProfile(self, tab)
	end
    Systems = FPSBoost:CreateTextList({
        Name = 'Visual systems', Default = profiles.Balanced,
        Function = function() if FPSBoost.Enabled then FPSBoost:Toggle(); FPSBoost:Toggle() end end
    })
end)

run(function()
	local PotatoMode
	local originalProperties = {}
	local blockMonitorConnections = {}
	local processedBlocks = {}

	local blockColors = {
		["clay_white"] = Color3.fromRGB(255, 255, 255),
		["wool_white"] = Color3.fromRGB(255, 255, 255),
		["wool_red"] = Color3.fromRGB(255, 50, 50),
		["wool_green"] = Color3.fromRGB(50, 255, 50),
		["grass"] = Color3.fromRGB(50, 255, 50),
		["moss_block"] = Color3.fromRGB(50, 255, 50),
		["wool_blue"] = Color3.fromRGB(50, 100, 255),
		["wool_yellow"] = Color3.fromRGB(255, 255, 50),
		["wool_orange"] = Color3.fromRGB(255, 150, 50),
		["clay_orange"] = Color3.fromRGB(255, 150, 50),
		["wool_purple"] = Color3.fromRGB(180, 50, 255),
		["clay_light_brown"] = Color3.fromRGB(200, 170, 120),
		["wool_pink"] = Color3.fromRGB(255, 100, 200),
		["wool_black"] = Color3.fromRGB(50, 50, 50),
		["wool_cyan"] = Color3.fromRGB(50, 255, 255),
		["wool_magenta"] = Color3.fromRGB(255, 50, 150),
		["wool_lime"] = Color3.fromRGB(150, 255, 50),
		["wool_brown"] = Color3.fromRGB(150, 75, 0),
		["wood_plank_spruce"] = Color3.fromRGB(222, 184, 135),
		["wool_light_blue"] = Color3.fromRGB(100, 200, 255),
		["wool_gray"] = Color3.fromRGB(150, 150, 150),
		["clay"] = Color3.fromRGB(220, 180, 140),
		["wood"] = Color3.fromRGB(180, 140, 100),
		["stone"] = Color3.fromRGB(150, 150, 150),
		["andesite"] = Color3.fromRGB(150, 150, 150),
		["cobblestone"] = Color3.fromRGB(150, 150, 150),
		["obsidian"] = Color3.fromRGB(50, 30, 80),
		["bedrock"] = Color3.fromRGB(80, 80, 80),
		["tnt"] = Color3.fromRGB(255, 50, 50),
		["sandstone"] = Color3.fromRGB(220, 200, 150),
		["sand"] = Color3.fromRGB(220, 200, 150),
		["wool"] = Color3.fromRGB(200, 200, 200),
		["concrete"] = Color3.fromRGB(180, 180, 180),
	}

	local cachedColors = {}

	local function getBlockColor(blockName)
		if cachedColors[blockName] then
			return cachedColors[blockName]
		end

		if blockColors[blockName] then
			cachedColors[blockName] = blockColors[blockName]
			return blockColors[blockName]
		end

		local lowerName = blockName:lower()

		if blockColors[lowerName] then
			cachedColors[blockName] = blockColors[lowerName]
			return blockColors[lowerName]
		end

		if lowerName:find("wool", 1, true) then
			for key, color in pairs(blockColors) do
				if key:find("wool", 1, true) and lowerName:find(key, 1, true) then
					cachedColors[blockName] = color
					return color
				end
			end
			cachedColors[blockName] = blockColors["wool"]
			return blockColors["wool"]
		end

		for name, color in pairs(blockColors) do
			if lowerName:find(name, 1, true) then
				cachedColors[blockName] = color
				return color
			end
		end

		local defaultColor = Color3.fromRGB(150, 150, 150)
		cachedColors[blockName] = defaultColor
		return defaultColor
	end

	local function cleanupDeadReferences()
		for block, _ in pairs(originalProperties) do
			if not block or not block.Parent then
				originalProperties[block] = nil
				processedBlocks[block] = nil
			end
		end
	end

	local function simplifyBlock(block)
		if not block or not block.Parent or processedBlocks[block] then return end

		if not originalProperties[block] then
			originalProperties[block] = {
				Material = block.Material,
				Color = block.Color,
				TextureID = block:IsA("MeshPart") and block.TextureID or nil,
				Textures = {}
			}

			for _, child in block:GetChildren() do
				if child:IsA("Texture") or child:IsA("Decal") then
					table.insert(originalProperties[block].Textures, {
						Class = child.ClassName,
						Texture = child.Texture,
						StudsPerTileU = child.StudsPerTileU,
						StudsPerTileV = child.StudsPerTileV,
						Face = child.Face,
						Transparency = child.Transparency,
						Color3 = child:IsA("Decal") and child.Color3 or nil
					})
				end
			end
		end

		block.Material = Enum.Material.SmoothPlastic
		block.Color = getBlockColor(block.Name)

		for _, child in block:GetChildren() do
			if child:IsA("Texture") or child:IsA("Decal") then
				child:Destroy()
			end
		end

		if block:IsA("MeshPart") and block.TextureID ~= "" then
			block.TextureID = ""
		end

		processedBlocks[block] = true
	end

	local function restoreBlock(block)
		if not block or not block.Parent then
			originalProperties[block] = nil
			processedBlocks[block] = nil
			return
		end

		local props = originalProperties[block]
		if not props then return end

		block.Material = props.Material or Enum.Material.Plastic
		block.Color = props.Color or Color3.fromRGB(255, 255, 255)

		if props.TextureID and block:IsA("MeshPart") then
			block.TextureID = props.TextureID
		end

		for _, textureProps in props.Textures do
			local newTexture
			if textureProps.Class == "Texture" then
				newTexture = Instance.new("Texture")
				newTexture.StudsPerTileU = textureProps.StudsPerTileU or 1
				newTexture.StudsPerTileV = textureProps.StudsPerTileV or 1
			else
				newTexture = Instance.new("Decal")
				newTexture.Color3 = textureProps.Color3 or Color3.fromRGB(255, 255, 255)
			end

			newTexture.Texture = textureProps.Texture or ""
			newTexture.Face = textureProps.Face or Enum.NormalId.Front
			newTexture.Transparency = textureProps.Transparency or 0
			newTexture.Parent = block
		end

		originalProperties[block] = nil
		processedBlocks[block] = nil
	end

	local function isBedPart(obj)
		local current = obj
		for _ = 1, 6 do
			if not current then break end
			local lower = tostring(current.Name):lower()
			if lower == 'bed' or lower == 'beds' or (lower:sub(1, 3) == 'bed' and lower:sub(1, 7) ~= 'bedrock') then return true end
			if typeof(current) == 'Instance' and collectionService:HasTag(current, 'bed') then return true end
			current = current.Parent
		end
		return false
	end

	local function isTargetBlock(obj)
		if not obj:IsA("BasePart") then return false end
		if isBedPart(obj) then return false end

		local name = obj.Name

		if blockColors[name] then return true end

		local lowerName = name:lower()
		return lowerName:find("wool", 1, true) or
		       lowerName:find("clay", 1, true) or
		       lowerName:find("wood", 1, true) or
		       lowerName:find("stone", 1, true) or
		       lowerName:find("glass", 1, true) or
		       lowerName:find("plank", 1, true) or
		       lowerName:find("obsidian", 1, true) or
		       lowerName:find("sand", 1, true) or
		       lowerName:find("end", 1, true) or
		       lowerName:find("tnt", 1, true) or
		       lowerName:find("barrier", 1, true) or
		       lowerName:find("magic", 1, true) or
		       lowerName:find("concrete", 1, true) or
		       lowerName:find("_block", 1, true) or
		       obj:IsA("Seat")
	end

	local function processExistingBlocks(simplify)
		local descendants = workspace:GetDescendants()

		task.spawn(function()
			for i, obj in descendants do
				if isTargetBlock(obj) then
					if simplify then
						simplifyBlock(obj)
					else
						restoreBlock(obj)
					end
				end
			end

			if not simplify then
				cleanupDeadReferences()
			end
		end)
	end

	local function setupBlockMonitor(simplify)
		for _, conn in blockMonitorConnections do
			conn:Disconnect()
		end
		table.clear(blockMonitorConnections)

		if not simplify then return end

		local mainConn = workspace.DescendantAdded:Connect(function(descendant)
			if isTargetBlock(descendant) then
				task.defer(function()
					if descendant and descendant.Parent then
						simplifyBlock(descendant)
					end
				end)
			end
		end)

		table.insert(blockMonitorConnections, mainConn)

		local lastCleanup = 0
		local cleanupConn = runService.Heartbeat:Connect(function()
			local now = tick()
			if now - lastCleanup >= 5 then
				lastCleanup = now
				cleanupDeadReferences()
			end
		end)

		table.insert(blockMonitorConnections, cleanupConn)
	end

	PotatoMode = Main:Part({
		Label = 'Potato mode',
		Default = false,
		Name = 'PotatoMode',
		Function = function(callback)
			if callback then
				processExistingBlocks(true)
				setupBlockMonitor(true)
			else
				processExistingBlocks(false)
				for _, conn in blockMonitorConnections do
					conn:Disconnect()
				end
				table.clear(blockMonitorConnections)
				table.clear(cachedColors)
				cleanupDeadReferences()
			end
		end,
	})
end)

run(function()
	local Store = store
	local NoTextures
	local Materials = {}
	local Decals = {}
	local Meshes = {}
	local Reference = {}

	local function Remember(Object: Instance, Property: string)
		local Properties = Reference[Object]
		if not Properties then
			Properties = {}
			Reference[Object] = Properties
		end

		if Properties[Property] == nil then
			Properties[Property] = Object[Property]
		end
	end

	local function StripObject(Object: Instance)
		if Decals.Enabled and Object:IsA("Decal") then
			local Parent: Instance? = Object.Parent
			if Parent and Parent:IsA("BasePart") and Parent.Transparency > 0.5 then
				return
			end

			Remember(Object, "Transparency")
			Object.Transparency = 1
			return
		end

		if Decals.Enabled and Object:IsA("SurfaceAppearance") then
			Remember(Object, "Parent")
			Object.Parent = nil
			return
		end

		if Meshes.Enabled and Object:IsA("SpecialMesh") then
			Remember(Object, "TextureId")
			Object.TextureId = ""
			return
		end

		if Object:IsA("BasePart") then
			if Meshes.Enabled and Object:IsA("MeshPart") then
				Remember(Object, "TextureID")
				Object.TextureID = ""
			end

			if Materials.Enabled then
				Remember(Object, "Material")
				Object.Material = Enum.Material.SmoothPlastic
			end
		end
	end

	local function Scan()
		local Descendants: {Instance} = Store.map:GetDescendants()
		for i: number, v: Instance in Descendants do
			if not NoTextures.Enabled then return end
			StripObject(v)

			if i % 500 == 0 then
				task.wait()
			end
		end
	end

	local function Refresh()
		if not NoTextures.Enabled then return end
		for Object: Instance, Properties: {[string]: any} in Reference do
			pcall(function()
				for Property: string, Value: any in Properties do
					Object[Property] = Value
				end
			end)
		end
		table.clear(Reference)
		Scan()
	end

	NoTextures = Main:Part({
		Label = 'No textures',
		Default = false,
		Name = "NoTextures",
		Function = function(Callback: boolean)
			if Callback then
				repeat task.wait() until Store.map or not NoTextures.Enabled
				if not NoTextures.Enabled then return end

				NoTextures:Clean(Store.map.DescendantAdded:Connect(function(Object: Instance)
					task.defer(StripObject, Object)
				end))
				Scan()
			else
				for Object: Instance, Properties: {[string]: any} in Reference do
					pcall(function()
						for Property: string, Value: any in Properties do
							Object[Property] = Value
						end
					end)
				end
				table.clear(Reference)
			end
		end,
		Tooltip = "Removes textures and materials from the map"
	})

	local TextureKinds
	TextureKinds = NoTextures:CreateMultiDropdown({
		Name = 'Remove',
		List = {'Materials', 'Decals', 'Meshes'},
		Default = {'Materials', 'Decals', 'Meshes'},
		Tooltip = 'What gets its texture removed'
	})
	Materials = setmetatable({}, {__index = function(_, key) if key == 'Enabled' then return TextureKinds:Has('Materials') end end})
	Decals = setmetatable({}, {__index = function(_, key) if key == 'Enabled' then return TextureKinds:Has('Decals') end end})
	Meshes = setmetatable({}, {__index = function(_, key) if key == 'Enabled' then return TextureKinds:Has('Meshes') end end})
end)

run(function()
	local RemoveNeon = {Enabled = false}
	local neonConnection
	local safetyLoop
	local originalMaterials = {}
	local processedParts = {}
	local lastCleanup = 0

	local function cleanupDeadReferences()
		local count = 0
		for obj, _ in pairs(originalMaterials) do
			if not obj or not obj.Parent then
				originalMaterials[obj] = nil
				processedParts[obj] = nil
			end
			count = count + 1
			if count % 100 == 0 then
				task.wait()
			end
		end
	end

	local function removeNeonFromPart(obj)
		if obj:IsA("BasePart") then
			if obj.Material == Enum.Material.Neon then
				if not originalMaterials[obj] then
					originalMaterials[obj] = {
						Material = obj.Material,
						Reflectance = obj.Reflectance
					}
				end
				pcall(function()
					obj.Material = Enum.Material.Plastic
					obj.Reflectance = 0
				end)
			end
		end
	end

	local function restoreNeon()
		for obj, data in pairs(originalMaterials) do
			if obj and obj.Parent then
				pcall(function()
					obj.Material = data.Material
					obj.Reflectance = data.Reflectance
				end)
			end
		end
		table.clear(originalMaterials)
		table.clear(processedParts)
	end

	local function batchProcessParts(parts, batchSize)
		local count = 0
		for i, part in ipairs(parts) do
			if part and part.Parent then
				removeNeonFromPart(part)
				count = count + 1
			end
			if i % batchSize == 0 then
				task.wait()
			end
		end
		return count
	end

	RemoveNeon = Main:Part({
		Label = 'Remove neon',
		Default = false,
		Name = 'RemoveNeon',
		Function = function(callback)
			if callback then
				task.spawn(function()
					local allParts = {}
					for _, v in pairs(workspace:GetDescendants()) do
						if v:IsA("BasePart") then
							table.insert(allParts, v)
						end
					end

					batchProcessParts(allParts, 200)
				end)

				neonConnection = workspace.DescendantAdded:Connect(function(obj)
					if RemoveNeon.Enabled then
						removeNeonFromPart(obj)
					end
				end)

				safetyLoop = task.spawn(function()
					while RemoveNeon.Enabled do
						task.wait(30)
						if RemoveNeon.Enabled then
							cleanupDeadReferences()
						end
					end
				end)
			else
				if neonConnection then
					neonConnection:Disconnect()
					neonConnection = nil
				end
				if safetyLoop then
					task.cancel(safetyLoop)
					safetyLoop = nil
				end
				restoreNeon()
			end
		end,
	})
end)

run(function()
	local ShadowRemover
	local originalShadows = setmetatable({}, {__mode = 'k'})
	local generation = 0

	local function removeShadow(obj)
		if obj:IsA("BasePart") and originalShadows[obj] == nil then
			originalShadows[obj] = obj.CastShadow
			if obj.CastShadow then
				obj.CastShadow = false
			end
		end
	end

	ShadowRemover = Main:Part({
		Label = 'No shadows',
		Default = false,
		Name = 'ShadowRemover',
		Function = function(callback)
			generation += 1
			if callback then
				local current = generation
				ShadowRemover:Clean(workspace.DescendantAdded:Connect(removeShadow))

				local started = os.clock()
				for _, obj in workspace:GetDescendants() do
					if current ~= generation then return end
					removeShadow(obj)
					if os.clock() - started > 0.002 then
						task.wait()
						started = os.clock()
					end
				end
			else
				for obj, shadow in originalShadows do
					if shadow and obj.Parent then
						pcall(function()
							obj.CastShadow = true
						end)
					end
				end
				table.clear(originalShadows)
			end
		end,
		Tooltip = 'Removes shadows, which can raise your framerate'
	})
end)

end)
