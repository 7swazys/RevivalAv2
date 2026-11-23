run(function()
	local AimAssist
	local AimMode
	local Mode
	local Targets
	local Sort
	local AimPart
	local AimSpeed
	local Smoothness
	local Shake
	local Distance
	local AngleSlider
	local StrafeIncrease
	local BlockBreak
	local KillauraTarget
	local ClickAim
	local Mouse
	local Limit
	local Projectiles
	local ProjectileRange
	local aimOverride
	
local rng = Random.new()
	local cache = setmetatable({}, {__mode = 'k'})
	
	local function getProjectile()
		if not Projectiles.Enabled then return nil end
		local tool = store.hand.tool
		local meta = tool and bedwars.ItemMeta[tool.Name]
		local source = meta and not meta.sword and meta.projectileSource
		if not source or not source.projectileType then return nil end
		local controller = bedwars.DefaultProjectileSourceController
		local handler = controller and controller.projectileHandler
		local handlerItem = handler and handler.projectileSourceController and handler.projectileSourceController:getHandItem()
		if handler and (not handlerItem or handlerItem.tool ~= tool) then handler = nil end
		local projectileType = handler and handler.projectile
		if not projectileType then
			local ammo = tool.Name
			if source.ammoItemTypes and #source.ammoItemTypes > 0 then
				ammo = nil
				for _, v in store.inventory.inventory.items do
					if table.find(source.ammoItemTypes, v.itemType) then
						ammo = v.itemType
						break
					end
				end
			end
			projectileType = ammo and source.projectileType(ammo)
		end
		local projectileMeta = projectileType and bedwars.ProjectileMeta[projectileType]
		if not projectileMeta or not projectileMeta.combat or type(projectileMeta.launchVelocity) ~= 'number' then return nil end
		return projectileMeta, handler
	end

	local function cameraAim(launchPosition, aimPosition, handler)
		local constants = bedwars.BowConstantsTable or {}
		local cameraPosition = gameCamera.CFrame.Position
		local direction = (aimPosition - launchPosition).Unit
		local offset = launchPosition - cameraPosition
		local reach = offset.Magnitude * (constants.CameraMultiplier or 10)
		local look = direction
		if reach > 0.01 then
			local along = offset:Dot(direction)
			local travel = math.sqrt(math.max(along * along - offset:Dot(offset) + reach * reach, 0)) - along
			look = (offset + direction * travel).Unit
		end
		local lift = constants.YTargetOffset or 0.05
		local scale = look.Y * lift + math.sqrt(math.max(look.Y * look.Y * lift * lift - lift * lift + 1, 0))
		local desired = look * scale - Vector3.new(0, lift, 0)
		local mouse = lplr:GetMouse()
		local mousePosition = Vector2.new(mouse.X, mouse.Y)
		if handler then
			mousePosition = handler.lockedAimPoint or (handler.inputInfo and handler.inputInfo.initialPosition) or mousePosition
			if handler.startAtCenterOfCamera then mousePosition = gameCamera.ViewportSize / 2 end
		elseif inputService.TouchEnabled then
			mousePosition = gameCamera.ViewportSize / 2 - Vector2.new(0, guiService:GetGuiInset().Y / 2)
		end
		local ray = gameCamera:ScreenPointToRay(mousePosition.X, mousePosition.Y).Direction
		local localRay = gameCamera.CFrame:VectorToObjectSpace(ray)
		local vertical = math.sqrt(localRay.Y * localRay.Y + localRay.Z * localRay.Z)
		local pitch = math.asin(math.clamp(desired.Y / math.max(vertical, 0.001), -1, 1)) - math.atan2(localRay.Y, -localRay.Z)
		local forward = localRay.Y * math.sin(pitch) + localRay.Z * math.cos(pitch)
		local yaw = math.atan2(-desired.X, -desired.Z) - math.atan2(-localRay.X, -forward)
		local desiredCamera = CFrame.new(cameraPosition) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
		return cameraPosition + desiredCamera.LookVector * (aimPosition - cameraPosition).Magnitude
	end

	local function projectileAim(ent, projectileMeta, handler)
		local launchPosition = (bedwars.ProjectileController:getLaunchPosition(store.hand.tool) or entitylib.character.RootPart.Position) + (handler and handler.fromPositionOffset or Vector3.new(0, 2, 0))
		local values = handler and bedwars.ProjectileController:calculateImportantLaunchValues(handler, false, store.hand.tool)
		local speed = values and values.initialVelocity.Magnitude or projectileMeta.launchVelocity
		local gravity = values and values.gravitationalAcceleration or projectileMeta.gravitationalAcceleration or 196.2
		launchPosition = values and values.positionFrom or launchPosition
		local velocity = ent.RootPart.AssemblyLinearVelocity
		local aimPosition, _, travelTime = prediction.SolveTrajectory(launchPosition, speed, gravity, ent.RootPart.Position, velocity, workspace.Gravity, ent.HipHeight, ent.Jumping and 42.6 or nil, nil, ent.Humanoid.FloorMaterial == Enum.Material.Air or math.abs(velocity.Y) > 0.01, ent.RootPart.Position, ent.RootPart, nil, true)
		if not aimPosition or not travelTime or travelTime > (projectileMeta.lifetimeSec or 3) then return nil end
		return cameraAim(launchPosition, aimPosition, handler)
	end

	local function getAim(ent)
		if aimOverride then return aimOverride end
		if AimPart.Value == 'Closest' then
			if not cache[ent.Character] then
				cache[ent.Character] = ent.Character:GetChildren()
			end
			local localPosition, magnitude, part = inputService.TouchEnabled and gameCamera.ViewportSize / 2 or inputService:GetMouseLocation(), 9e9, nil
			for _, v in cache[ent.Character] do
				if v and v.Parent and v:IsA('BasePart') then
					local position, vis = gameCamera:WorldToViewportPoint(v.Position)
					if vis then
						local mag = (localPosition - Vector2.new(position.X, position.Y)).Magnitude
						if mag < magnitude then
							magnitude = mag
							part = v
						end
					end
				end
			end
			if part then
				return part.Position
			end
		end
		return ent.RootPart.Position
	end
	
	local started, lasttarget, nextsearch = 0, nil, 0
	local aimfuncs = {
		Simple = function(localcframe, ent, fps)
			local speed = (AimSpeed.Value + (StrafeIncrease.Enabled and (inputService:IsKeyDown(Enum.KeyCode.A) or inputService:IsKeyDown(Enum.KeyCode.D)) and 10 or 0)) / Smoothness.Value
			return localcframe:Lerp(CFrame.lookAt(localcframe.p, getAim(ent) + Vector3.new((rng:NextNumber() - 0.5) * Shake.Value * fps, (rng:NextNumber() - 0.5) * Shake.Value * fps, (rng:NextNumber() - 0.5) * Shake.Value * fps)), speed * fps), speed
		end,
		Adaptive = function(localcframe, ent, fps)
			local t = math.min(tick() - started, 1)
			local prog = t < 0.5 and 4 * t * t * t or 1 - math.pow(-2 * t + 2, 3) / 2
			local speed = ((AimSpeed.Value * 0.1 * prog) + (1 - prog) + (StrafeIncrease.Enabled and (inputService:IsKeyDown(Enum.KeyCode.A) or inputService:IsKeyDown(Enum.KeyCode.D)) and 10 or 5)) / Smoothness.Value
			return localcframe:Lerp(CFrame.lookAt(localcframe.p, getAim(ent) + Vector3.new((rng:NextNumber() - 0.5) * Shake.Value * fps, (rng:NextNumber() - 0.5) * Shake.Value * fps, (rng:NextNumber() - 0.5) * Shake.Value * fps)), speed * fps), speed
		end
	}
	
	AimAssist = vape.Categories.Combat:CreateModule({
		Name = 'AimAssist',
		ExtraText = function() return Mode.Value end,
		Function = function(callback)
			if callback then
				local rotate = 0
				AimAssist:Clean(runService.PostSimulation:Connect(function(dt)
					if entitylib.isAlive then
						local autoRotate = tick() > rotate
						if entitylib.character.Humanoid.AutoRotate ~= autoRotate then
							entitylib.character.Humanoid.AutoRotate = autoRotate
						end

						local projectileMeta, handler
						local okProjectile, a, b = pcall(getProjectile)
						if okProjectile then projectileMeta, handler = a, b end
						local charging = projectileMeta ~= nil and bedwars.ProjectileController.isTargeting == true
						local range = projectileMeta and ProjectileRange.Value or Distance.Value
						aimOverride = nil

						local blocked = Mouse.Enabled and not charging and not inputService:IsMouseButtonPressed(0) and (tick() - bedwars.SwordController.lastSwing) > 0.15
						blocked = blocked or (ClickAim.Enabled and not charging and (tick() - bedwars.SwordController.lastSwing) > 0.3)
						blocked = blocked or (BlockBreak.Enabled and (tick() - store.lastHit) < 0.3)
						blocked = blocked or (Limit.Enabled and store.hand.toolType ~= 'sword' and not projectileMeta)

						local ent
						if not blocked then
							if entitylib.isAlive and lasttarget and lasttarget.Character and lasttarget.Character.Parent and lasttarget.RootPart and lasttarget.RootPart.Parent and lasttarget.Targetable and entitylib.isVulnerable(lasttarget) and (entitylib.character.RootPart.Position - lasttarget.RootPart.Position).Magnitude <= range and not (Targets.Walls.Enabled and entitylib.Wallcheck(entitylib.character.RootPart.Position, lasttarget.RootPart.Position, Targets.Walls.Enabled, lasttarget)) and tick() < nextsearch then
								ent = lasttarget
							else
								local target = store.KillauraTarget
								ent = KillauraTarget.Enabled and entitylib.isAlive and target and target.Character and target.Character.Parent and target.RootPart and target.RootPart.Parent and target.Targetable and entitylib.isVulnerable(target) and (entitylib.character.RootPart.Position - target.RootPart.Position).Magnitude <= range and not (Targets.Walls.Enabled and entitylib.Wallcheck(entitylib.character.RootPart.Position, target.RootPart.Position, Targets.Walls.Enabled, target)) and target or entitylib.EntityPosition({
									Range = range,
									Part = 'RootPart',
									Wallcheck = Targets.Walls.Enabled,
									Players = Targets.Players.Enabled,
									NPCs = Targets.NPCs.Enabled,
									Priority = Targets.Priority.Value,
									Sort = sortmethods[Sort.Value]
								})
								if ent ~= lasttarget then
									started = tick()
								end
								lasttarget = ent
								nextsearch = tick() + 1
							end
						end
	
						if ent then
							local root = entitylib.character.RootPart
							local delta = (ent.RootPart.Position - root.Position)
							local localfacing = root.CFrame.LookVector * Vector3.new(1, 0, 1)
							local horizontal = delta * Vector3.new(1, 0, 1)
							local angle = localfacing.Magnitude > 0 and horizontal.Magnitude > 0 and math.acos(math.clamp(localfacing.Unit:Dot(horizontal.Unit), -1, 1)) or 0
							if angle >= (math.rad(AngleSlider.Value) / 2) then
								return
							end
							if projectileMeta then
								local okAim, point = pcall(projectileAim, ent, projectileMeta, handler)
								if not (okAim and point) then return end
								aimOverride = point
							end
							targetinfo.Targets[ent] = tick() + 1

							local firstPerson = entitylib.character.Head.LocalTransparencyModifier == 1
							local perspective = AimMode.Value
							if perspective == 'Mouse' then
								local cframe, speed = aimfuncs[Mode.Value](gameCamera.CFrame, ent, dt)
								local viewport = gameCamera:WorldToViewportPoint(cframe.Position)
								local pos = (Vector2.new(viewport.X, viewport.Y) - inputService:GetMouseLocation()) * (speed / 15)
								mousemoverel(pos.X, pos.Y)
							elseif perspective == 'First person' or (perspective == 'Dynamic' and firstPerson) then
								if not firstPerson then return end
								local cframe = aimfuncs[Mode.Value](gameCamera.CFrame, ent, dt)
								gameCamera.CFrame = cframe
							elseif perspective == 'Third person' or (perspective == 'Dynamic' and not firstPerson) then
								if firstPerson then return end
								if projectileMeta then
									gameCamera.CFrame = aimfuncs[Mode.Value](gameCamera.CFrame, ent, dt)
									return
								end
								local cframe = aimfuncs[Mode.Value](root.CFrame, ent, dt)
								local direction = cframe.LookVector * Vector3.new(1, 0, 1)
								if direction.Magnitude > 0 then
									entitylib.character.Humanoid.AutoRotate = false
									root.CFrame = CFrame.lookAlong(root.Position, direction)
									rotate = tick() + 0.1
								end
							end
						end
					else
						lasttarget = nil
					end
				end))
			else
				lasttarget = nil
				if entitylib.isAlive then
					entitylib.character.Humanoid.AutoRotate = true
				end
			end
		end,
		Tooltip = 'Smoothly aims at the closest target while holding a sword'
	})
	Targets = AimAssist:CreateTargets({
		Players = true,
		Walls = true
	})
	
	AimMode = AimAssist:CreateDropdown({
		Name = 'Aim perspective',
		Tooltip = 'How your aim is moved: camera, character, mouse or picked by your view',
		List = {'First person', 'Third person', 'Dynamic'},
		Default = 'First person'
	})
	Mode = AimAssist:CreateDropdown({
		Name = 'Mode',
		List = {'Simple', 'Adaptive'},
		Tooltip = 'Simple - smooth aiming\nAdaptive - tracks targets more closely',
		Default = 'Simple'
	})
	local methods = {'Angle', 'Damage', 'Distance'}
	for _, v in sortlist do
		if not table.find(methods, v) then
			table.insert(methods, v)
		end
	end
	ClickAim = AimAssist:CreateToggle({
		Name = 'Click aim',
		Default = true
	})
	Mouse = AimAssist:CreateToggle({Name = 'Require mouse down'})
	StrafeIncrease = AimAssist:CreateToggle({Name = 'Strafe increase'})
	BlockBreak = AimAssist:CreateToggle({Name = 'Check block break'})
	KillauraTarget = AimAssist:CreateToggle({Name = 'Use killaura target'})
	AimSpeed = AimAssist:CreateSlider({
		Name = 'Aim speed',
		Min = 1,
		Max = 20,
		Default = 6
	})
	Smoothness = AimAssist:CreateSlider({
		Name = 'Smoothness',
		Min = 1,
		Max = 20,
		Default = 1,
		Decimal = 10,
		Tooltip = 'Softens the aim, 1 leaves it unchanged'
	})
	Distance = AimAssist:CreateSlider({
		Name = 'Distance',
		Min = 1,
		Max = 30,
		Default = 30,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	Shake = AimAssist:CreateSlider({
		Name = 'Shake',
		Min = 0,
		Max = 100,
		Default = 0,
		Tooltip = 'Adds random jitter to look more human'
	})
	AngleSlider = AimAssist:CreateSlider({
		Name = 'Max angle',
		Min = 1,
		Max = 360,
		Default = 70
	})
	Projectiles = AimAssist:CreateGroup({
		Name = 'Projectiles',
		Tooltip = 'While you hold a bow or another damaging projectile, aims where the shot will meet a moving target'
	})
	ProjectileRange = Projectiles:CreateSlider({
		Name = 'Projectile Range',
		Min = 1,
		Max = 400,
		Default = 200,
		Suffix = function(val) return val == 1 and 'stud' or 'studs' end,
		Tooltip = 'How far away a target can be while you hold a projectile'
	})
	Limit = AimAssist:CreateToggle({
		Name = 'Limit to items',
		Tooltip = 'Only works while holding the item it uses'
	})
	Sort = AimAssist:CreateDropdown({
		Name = 'Target mode',
		List = methods,
		Default = 'Angle',
		Tooltip = TARGET_MODE_TOOLTIP
	})
	AimPart = AimAssist:CreateDropdown({
		Name = 'Target area',
		List = {'Center', 'Closest'},
		Default = 'Center'
	})
end)
