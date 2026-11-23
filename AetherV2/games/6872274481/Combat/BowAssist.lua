run(function()
	local BowAssist
	local Targets
	local Sort
	local AimPart
	local FOV
	local AimSpeed
	local Smoothness
	local Distance
	local Shake
	local Clear
	local Blacklist
	local Debug
	
	local drawStart, oldStart, oldStop = 0
	local rng = Random.new()
	local nextDiag = 0
	local diagReason

	local function isDrawing()
		if drawStart > 0 and tick() - drawStart < 30 then return true end
		local ok, held = pcall(function()
			return inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
		end)
		if ok and held then return true end
		ok, held = pcall(function()
			return inputService:IsGamepadButtonDown(Enum.KeyCode.ButtonR2)
		end)
		return ok and held == true
	end

	local function report(sent, detail)
		if not (Debug and Debug.Enabled) or tick() <= nextDiag then return end
		nextDiag = tick() + 2
		if sent then
			task.defer(notif, 'BowAssist', 'eased the aim onto '..tostring(detail), 4)
		else
			task.defer(notif, 'BowAssist', 'left the draw alone: '..tostring(detail), 4, 'warning')
		end
	end
	
	local arcCheck = RaycastParams.new()
	arcCheck.FilterType = Enum.RaycastFilterType.Exclude
	
	BowAssist = vape.Categories.Combat:CreateModule({
		Name = 'BowAssist',
		Function = function(callback)
			if callback then
				local controller = bedwars.DefaultProjectileSourceController
				if not controller then
					notif('BowAssist', 'The projectile source controller is unavailable.', 5, 'warning')
					return
				end
				oldStart = controller.onStartCharging
				if type(oldStart) == 'function' then
					controller.onStartCharging = function(self, ...)
						drawStart = tick()
						return oldStart(self, ...)
					end
				end
	
				oldStop = controller.onStopCharging
				if type(oldStop) == 'function' then
					controller.onStopCharging = function(self, ...)
						drawStart = 0
						return oldStop(self, ...)
					end
				end				BowAssist:Clean(runService.PostSimulation:Connect(function(dt)
					if not entitylib.isAlive or not isDrawing() then return end

					local meta = store.hand.tool and bedwars.ItemMeta[store.hand.tool.Name]
					local source = meta and meta.projectileSource
					if not source or not source.projectileType then return end
	
					local ammo = store.hand.tool.Name
					if source.ammoItemTypes and #source.ammoItemTypes > 0 then
						ammo = nil
						for _, v in store.inventory.inventory.items do
							if table.find(source.ammoItemTypes, v.itemType) then
								ammo = v.itemType
								break
							end
						end
					end
					if not ammo then return end					local projType = source.projectileType(ammo)
					if table.find(Blacklist.ListEnabled or {}, ((projType == 'glue_trap' or projType == 'glue_projectile') and 'gloop' or projType)) then
						report(false, projType..' is blacklisted')
						return
					end

					local projmeta = bedwars.ProjectileMeta[projType]
					if not projmeta or type(projmeta.launchVelocity) ~= 'number' then
						report(false, 'no projectile meta for '..tostring(projType))
						return
					end

					local scalar = tonumber(source.minStrengthScalar) or 1
					local chargeWindow = tonumber(source.maxStrengthChargeSec) or tonumber(source.multiShotChargeTime)
					local ratio = chargeWindow and drawStart > 0 and math.clamp((tick() - drawStart) / chargeWindow, 0, 1) or 1
					local projSpeed = projmeta.launchVelocity * (scalar + (1 - scalar) * ratio)

	
					local localPosition = entitylib.character.RootPart.Position
					local ent = entitylib.EntityMouse({
						Range = FOV.Value,
						Part = 'RootPart',
						Wallcheck = Targets.Walls.Enabled,
						Players = Targets.Players.Enabled,
						NPCs = Targets.NPCs.Enabled,
						Priority = Targets.Priority.Value,
						Origin = localPosition,
						Sort = sortmethods[Sort.Value]
					})					if not ent or (localPosition - ent.RootPart.Position).Magnitude > Distance.Value then
						report(false, 'no target inside the FOV within '..tostring(Distance.Value)..' studs')
						return
					end

					local targetPosition = ent[AimPart.Value].Position
					local shootPosition
					pcall(function()
						local value = bedwars.ProjectileController:getLaunchPosition(gameCamera.CFrame)
						if typeof(value) == 'Vector3' then
							shootPosition = value
						elseif typeof(value) == 'CFrame' then
							shootPosition = value.Position
						end
					end)
					if not shootPosition then
						local bow = bedwars.BowConstantsTable
						shootPosition = bow and (CFrame.new(localPosition, targetPosition) * CFrame.new(Vector3.new(-bow.RelX, -bow.RelY, -bow.RelZ))).Position
							or (localPosition + (targetPosition - localPosition).Unit * 1.5)
					end
					local gravity = projmeta.gravitationalAcceleration or 196.2
					local calc, _, travelTime = prediction.SolveTrajectory(shootPosition, projSpeed, gravity, targetPosition, ent.RootPart.AssemblyLinearVelocity, workspace.Gravity, ent.HipHeight, ent.Jumping and 42.6 or nil, nil, ent.Humanoid.FloorMaterial == Enum.Material.Air or math.abs(ent.RootPart.AssemblyLinearVelocity.Y) > 0.01, ent.RootPart.Position, ent.RootPart, nil, true)
					if not calc then
						report(false, 'no ballistic solution to '..tostring(ent.Player and ent.Player.Name or 'the target'))
						return
					end

	
					if Clear.Enabled and travelTime then
						local ignorelist = {gameCamera, lplr.Character}
						for _, v in entitylib.List do
							if v.Character then
								table.insert(ignorelist, v.Character)
							end
						end
						arcCheck.FilterDescendantsInstances = ignorelist
						if not prediction.IsTrajectoryClear(shootPosition, calc - shootPosition, gravity, travelTime, arcCheck) then
							report(false, 'a block is in the way of the arc')
							return
						end
					end
	
					report(true, (ent.Player and ent.Player.Name) or 'the target')
					targetinfo.Targets[ent] = tick() + 1
					local jitter = Vector3.new((rng:NextNumber() - 0.5) * Shake.Value * dt, (rng:NextNumber() - 0.5) * Shake.Value * dt, (rng:NextNumber() - 0.5) * Shake.Value * dt)
					local speed = math.clamp((AimSpeed.Value / Smoothness.Value) * dt, 0, 1)
					if entitylib.character.Head.LocalTransparencyModifier ~= 1 and mousemoverel then
						local viewport = gameCamera:WorldToViewportPoint(calc + jitter)
						if viewport.Z > 0 then
							local pos = (Vector2.new(viewport.X, viewport.Y) - inputService:GetMouseLocation()) * speed
							mousemoverel(pos.X, pos.Y)
						end
					else
						gameCamera.CFrame = gameCamera.CFrame:Lerp(CFrame.lookAt(gameCamera.CFrame.Position, calc + jitter), speed)
					end
				end))
			else
				drawStart = 0
				local controller = bedwars.DefaultProjectileSourceController
				if controller then
					if oldStart then controller.onStartCharging = oldStart end
					if oldStop then controller.onStopCharging = oldStop end
				end
			end
		end,
		Tooltip = 'Eases your aim onto where the arrow will drop while drawing a bow'
	})
	
	Targets = BowAssist:CreateTargets({
		Players = true,
		Walls = true
	})
	local methods = {'Distance', 'Damage'}
	for _, v in sortlist do
		if not table.find(methods, v) then
			table.insert(methods, v)
		end
	end
	Sort = BowAssist:CreateDropdown({
		Name = 'Target mode',
		List = methods,
		Default = 'Distance',
		Tooltip = TARGET_MODE_TOOLTIP
	})
	AimPart = BowAssist:CreateDropdown({
		Name = 'Part',
		List = {'RootPart', 'Head'}
	})
	FOV = BowAssist:CreateSlider({
		Name = 'FOV',
		Min = 1,
		Max = 1000,
		Default = 220,
		Tooltip = 'How far from your cursor a target can be'
	})
	Distance = BowAssist:CreateSlider({
		Name = 'Distance',
		Min = 1,
		Max = 300,
		Default = 200,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	AimSpeed = BowAssist:CreateSlider({
		Name = 'Aim speed',
		Min = 1,
		Max = 20,
		Default = 5
	})
	Smoothness = BowAssist:CreateSlider({
		Name = 'Smoothness',
		Min = 1,
		Max = 20,
		Default = 2,
		Decimal = 10,
		Tooltip = 'Softens the aim, 1 leaves it unchanged'
	})
	Shake = BowAssist:CreateSlider({
		Name = 'Shake',
		Min = 0,
		Max = 100,
		Default = 0,
		Tooltip = 'Adds random jitter to look more human'
	})
	Clear = BowAssist:CreateToggle({
		Name = 'Clear shot only',
		Default = true,
		Tooltip = 'Stops assisting when a block is in the way'
	})
	Blacklist = BowAssist:CreateTextList({
		Name = 'Blacklist',
		Default = {'gloop', 'telepearl'},
		Darker = true,
		Placeholder = 'projectile',
		Tooltip = 'Projectile types the assist leaves alone'
	})
	Debug = BowAssist:CreateToggle({
		Name = 'Debug',
		Tooltip = 'Logs what it does'
	})
end)
