run(function()
	local ProjectileAimbot
	local Blacklist
	local TargetPart
	local Targets
	local Sort
	local FOV
	local Range
	local Horizontal
	local Vertical
	local AutoCharge
	local Aim = {}
	local OtherProjectiles
	local MiloCheck
	local rayCheck = RaycastParams.new()
	rayCheck.FilterType = Enum.RaycastFilterType.Include
	rayCheck.FilterDescendantsInstances = {workspace:FindFirstChild('Map')}
	local fovCircle
	local fovColour
	local fovThickness
	local ShowFOV
	local circleLibrary = vape.Libraries and vape.Libraries.fovcircle
	local launchHook
	local sticky = {}
	local held
	local SWITCH, IDLE, HOLD = 0.4, 0.75, 0.3

	local function stickTo(candidates)
		local now = tick()
		if now - (sticky.Clock or 0) > IDLE then
			sticky.Entity, sticky.Rival = nil, nil
		end
		sticky.Clock = now
		local top = candidates[1]
		local current = sticky.Entity
		if current and not table.find(candidates, current) then
			current = nil
		end
		if not current then
			sticky.Entity, sticky.Rival = top, nil
			return top
		end
		if top ~= current then
			if sticky.Rival ~= top then
				sticky.Rival, sticky.Since = top, now
			end
			if now - sticky.Since >= SWITCH then
				sticky.Entity, sticky.Rival = top, nil
				return top
			end
		else
			sticky.Rival = nil
		end
		return current
	end

	local function projectileChargeTime()
		local held = store.hand and store.hand.tool
		local itemMeta = held and bedwars.ItemMeta and bedwars.ItemMeta[held.Name]
		local source = itemMeta and (itemMeta.projectileSource or itemMeta.multiProjectileSource)
		if not source then return nil end
		return tonumber(source.maxStrengthChargeSec)
	end

	local function resolveProjectileAimbotPart(ent, requested, projectileType)
		local character = ent and ent.Character
		local root = ent and (ent.RootPart or ent.HumanoidRootPart) or character and character.PrimaryPart
		if not character then return root end
		local function first(...)
			for index = 1, select('#', ...) do
				local partName = select(index, ...)
				local part = partName and character:FindFirstChild(partName)
				if part and part:IsA('BasePart') then return part end
			end
			return root
		end
		if requested == 'Dynamic' then
			requested = isHeadshotDynamic(projectileType) and 'Head' or 'RootPart'
		end
		if requested == 'Head' then return first('Head') end
		if requested == 'Torso' then return first('UpperTorso', 'Torso', 'LowerTorso') end
		if requested == 'Left arm' then return first('LeftHand', 'LeftLowerArm', 'LeftUpperArm', 'Left Arm') end
		if requested == 'Right arm' then return first('RightHand', 'RightLowerArm', 'RightUpperArm', 'Right Arm') end
		if requested == 'Left leg' then return first('LeftFoot', 'LeftLowerLeg', 'LeftUpperLeg', 'Left Leg') end
		if requested == 'Right leg' then return first('RightFoot', 'RightLowerLeg', 'RightUpperLeg', 'Right Leg') end
		if requested == 'Random' then
			local available = {first('Head'), first('UpperTorso', 'Torso'), first('LeftHand', 'Left Arm'), first('RightHand', 'Right Arm'), first('LeftFoot', 'Left Leg'), first('RightFoot', 'Right Leg')}
			local filtered = {}
			for _, part in available do if part and part ~= root then table.insert(filtered, part) end end
			return #filtered > 0 and filtered[math.random(1, #filtered)] or root
		end
		return root
	end

	local function targetGravityOf(ent)
		local gravity = workspace.Gravity
		local character = ent.Character
		local balloons = character and character:GetAttribute('InflatedBalloons')
		if type(balloons) == 'number' and balloons > 0 then
			gravity = workspace.Gravity * (1 - (balloons >= 4 and 1.2 or balloons >= 3 and 1 or 0.975))
		end
		if ent.RootPart and ent.RootPart:FindFirstChild('rbxassetid://8200754399') then gravity = 6 end
		if ent.Player and ent.Player:GetAttribute('IsOwlTarget') then
			for _, owl in collectionService:GetTagged('Owl') do
				if owl:GetAttribute('Target') == ent.Player.UserId and owl:GetAttribute('Status') == 2 then
					gravity = 0
					break
				end
			end
		end
		return gravity
	end

	local function solveAimbotLaunch(origin, projmeta, projectileType, launch)
		local drawSpeed = type(launch) == 'table' and typeof(launch.initialVelocity) == 'Vector3' and launch.initialVelocity.Magnitude or nil
		local metaOk, meta = pcall(projmeta.getProjectileMeta, projmeta)
		meta = metaOk and meta or bedwars.ProjectileMeta[projectileType]
		if type(meta) ~= 'table' then return end
		local gravityMultiplier = tonumber(projmeta.gravityMultiplier) or 1
		if gravityMultiplier == 0 then gravityMultiplier = 1 end
		local gravity = (tonumber(meta.gravitationalAcceleration) or 196.2) * gravityMultiplier
		local fullSpeed = tonumber(meta.launchVelocity) or drawSpeed
		if not fullSpeed or fullSpeed <= 0 then return end
		local shootSpeed = drawSpeed and drawSpeed > 0 and drawSpeed or fullSpeed
		local solveSpeed = Aim.Enabled == false and fullSpeed or shootSpeed

		local function valuesFor(ent)
			local aimPart = resolveProjectileAimbotPart(ent, TargetPart.Value, projectileType)
			if not aimPart or not aimPart.Parent then return end
			local partAim = TargetPart.Value ~= 'Dynamic' or isHeadshotDynamic(projectileType)
			local targetPosition = aimPart.Position
			local targetVelocity = projectileType == 'telepearl' and Vector3.zero or aimPart.AssemblyLinearVelocity
			local playerGravity = targetGravityOf(ent)
			local root = ent.RootPart
			if not root then return end
			local airborne = (ent.Humanoid and ent.Humanoid.FloorMaterial == Enum.Material.Air)
				or math.abs(root.AssemblyLinearVelocity.Y) > 0.01

			local function solve(position)
				local ok, aimPoint, _, travelTime = pcall(
					prediction.SolveTrajectory,
					origin, solveSpeed, gravity, position, targetVelocity, playerGravity,
					ent.HipHeight, ent.Jumping and 42.6 or nil, store.airRay, airborne,
					root.Position, root, nil, true, partAim
				)
				if ok and aimPoint and travelTime then return aimPoint, travelTime end
			end

			local aimPoint, travelTime = solve(targetPosition)
			if not aimPoint then return end

			if Horizontal.Value ~= 1 or Vertical.Value ~= 1 then
				local rise = (targetVelocity.Y * travelTime) - (playerGravity * travelTime * travelTime * 0.5)
				local lead = Vector3.new(
					targetVelocity.X * travelTime * (Horizontal.Value - 1),
					rise * (Vertical.Value - 1),
					targetVelocity.Z * travelTime * (Horizontal.Value - 1)
				)
				local adjusted, adjustedTime = solve(targetPosition + lead)
				if adjusted then aimPoint, travelTime = adjusted, adjustedTime or travelTime end
			end

			local direction = CFrame.new(origin, aimPoint).LookVector
			return {Velocity = direction * shootSpeed, Time = travelTime, Player = ent}
		end

		local inCircle = circleLibrary and circleLibrary.ContainsEntity
		if not inCircle then return nil end
		local center = circleLibrary.Center()
		local candidates = {}
		for _, ent in entitylib.AllPosition({
			Part = 'RootPart',
			Range = Range.Value,
			Players = Targets.Players.Enabled,
			NPCs = Targets.NPCs.Enabled,
			Priority = Targets.Priority and Targets.Priority.Value,
			Wallcheck = Targets.Walls.Enabled,
			Origin = origin,
			Sort = sortmethods[Sort.Value]
		}) do
			if inCircle(ent, FOV.Value, center) and not (MiloCheck and MiloCheck.Enabled and store.isDisguised(ent)) then
				table.insert(candidates, ent)
				if #candidates >= 10 then break end
			end
		end

		local now = tick()
		local keep = stickTo(candidates)
		if keep then
			local ok, values = pcall(valuesFor, keep)
			if ok and values then
				held = {Values = values, Clock = now}
				return values
			end
			if held and held.Values.Player == keep and now - held.Clock < HOLD then
				return held.Values
			end
		end
		for _, ent in candidates do
			if ent ~= keep then
				local ok, values = pcall(valuesFor, ent)
				if ok and values then
					sticky.Entity, sticky.Rival = ent, nil
					held = {Values = values, Clock = now}
					return values
				end
			end
		end
		local last = held and held.Values.Player
		if last and now - held.Clock < HOLD and last.RootPart and last.RootPart.Parent then
			return held.Values
		end
		return nil
	end

	ProjectileAimbot = vape.Categories.Blatant:CreateModule({
		Name = 'ProjectileAimbot',
		ExtraText = function() return Sort.Value end,
		Function = function(callback)
			if callback then
				if not (bedwars.ProjectileLaunchHook and bedwars.ProjectileController) then
					notif('ProjectileAimbot', 'The projectile controller is unavailable.', 5, 'warning')
					task.defer(function()
						if ProjectileAimbot.Enabled then ProjectileAimbot:Toggle() end
					end)
					return
				end
				if vape.Modules.SilentAim and vape.Modules.SilentAim.Enabled then vape.Modules.SilentAim:Toggle() end
				launchHook = bedwars.ProjectileLaunchHook:Add('ProjectileAimbot', 12, function(nextLaunch, self, launchData, ...)
					local projmeta = launchData
					if AutoCharge.Enabled and type(projmeta) == 'table' and bedwars.ProjectileMeta[projmeta.projectile] then
						local fullCharge = projectileChargeTime()
						if fullCharge then
							projmeta.drawDurationSeconds = math.max(tonumber(projmeta.drawDurationSeconds) or 0, fullCharge)
							projmeta.velocityMultiplier = math.max(tonumber(projmeta.velocityMultiplier) or 0, 1)
						end
					end

					local worldmeta, launchOrigin, shootPosition = ...
					local launch = nextLaunch(self, launchData, ...)
					if not projmeta then return launch end
					local gamePosition = type(launch) == 'table' and typeof(launch.positionFrom) == 'Vector3' and launch.positionFrom or nil
					local base = gamePosition
						or (typeof(shootPosition) == 'Vector3' and shootPosition)
						or (typeof(launchOrigin) == 'Vector3' and launchOrigin)
						or (entitylib.isAlive and entitylib.character.RootPart.Position)
					if not base then return launch end
					local projectileType = tostring(projmeta.projectile or '')
					if projectileType == '' or ((not OtherProjectiles.Enabled) and not projectileType:find('arrow')) then return launch end
					local blacklistName = (projectileType == 'glue_trap' or projectileType == 'glue_projectile') and 'gloop' or projectileType
					if table.find(Blacklist.ListEnabled or {}, blacklistName) then return launch end

					local ok, solved = pcall(solveAimbotLaunch, base, projmeta, projectileType, launch)
					if not ok then
						if shared.VapeDeveloper then
							warn('[catvape] projectile aimbot solve failed: ' .. tostring(solved))
						end
						return launch
					end
					if type(solved) ~= 'table' then return launch end

					local projMeta = bedwars.ProjectileMeta[projectileType] or {}
					local answer = {}
					if type(launch) == 'table' then
						for key, value in pairs(launch) do
							answer[key] = value
						end
					end
					answer.initialVelocity = solved.Velocity
					if not gamePosition then
						answer.positionFrom = base
					end
					answer.deltaT = answer.deltaT or tonumber(projmeta.lifetimeSec) or tonumber(projMeta.lifetimeSec) or 7
					answer.gravitationalAcceleration = answer.gravitationalAcceleration or tonumber(projMeta.gravitationalAcceleration) or 196.2
					answer.drawDurationSeconds = answer.drawDurationSeconds or tonumber(projmeta.drawDurationSeconds) or 1
					store.hitchance.ProjectileAimbot = {
						Value = getHitChance(solved.Player, solved.Time),
						Clock = tick()
					}
					targetinfo.Targets[solved.Player] = tick() + 1
					return answer
				end)
				if ShowFOV.Enabled and circleLibrary and circleLibrary.New then
					fovCircle = circleLibrary.New({
						Name = 'PAFOVCircle',
						Parent = vape.gui,
						Visible = function()
							return ProjectileAimbot and ProjectileAimbot.Enabled and ShowFOV.Enabled
						end,
						Radius = function()
							return FOV.Value
						end,
						Colour = function()
							return Color3.fromHSV(fovColour.Hue, fovColour.Sat, fovColour.Value)
						end,
						Thickness = function()
							return fovThickness.Value
						end
					})
				end
				ProjectileAimbot:Clean(function()
					table.clear(sticky)
					held = nil
					if launchHook then launchHook(); launchHook = nil end
					if fovCircle then fovCircle:Destroy(); fovCircle = nil end
				end)
			elseif launchHook then
				launchHook()
				launchHook = nil
				if fovCircle then fovCircle:Destroy(); fovCircle = nil end
			end
		end,
		Tooltip = 'Silently aims your shots at enemies'
	})
	Targets = ProjectileAimbot:CreateTargets({
		Players = true,
		Walls = true
	})
	local methods = {'Distance', 'Damage'}
	for _, i in sortlist do
		if not table.find(methods, i) then
			table.insert(methods, i)
		end
	end
	Sort = ProjectileAimbot:CreateDropdown({
		Name = 'Target mode',
		List = methods,
		Default = 'Distance',
		Tooltip = TARGET_MODE_TOOLTIP
	})
	TargetPart = ProjectileAimbot:CreateDropdown({
		Name = 'Part',
		List = {'RootPart', 'Head', 'Torso', 'Left arm', 'Right arm', 'Left leg', 'Right leg', 'Random', 'Dynamic'},
		Tooltip = 'Where on the body shots aim'
	})
	FOV = ProjectileAimbot:CreateSlider({
		Name = 'FOV',
		Min = 1,
		Max = 1000,
		Default = 1000,
		Suffix = ' px',
		Tooltip = 'How far from your cursor a target can be'
	})
	Range = ProjectileAimbot:CreateSlider({
		Name = 'Range',
		Min = 30,
		Max = 1000,
		Default = 1000,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end,
		Tooltip = 'How far away a target can be'
	})
	ShowFOV = ProjectileAimbot:CreateGroup({
		Name = 'FOV Circle',
		Tooltip = 'Shows the range around your cursor',
		Function = function(callback)
			if not ProjectileAimbot.Enabled then return end
			if fovCircle then fovCircle:Destroy(); fovCircle = nil end
			if callback and circleLibrary and circleLibrary.New then
				fovCircle = circleLibrary.New({
					Name = 'PAFOVCircle',
					Parent = vape.gui,
					Visible = function()
						return ProjectileAimbot and ProjectileAimbot.Enabled and ShowFOV.Enabled
					end,
					Radius = function()
						return FOV.Value
					end,
					Colour = function()
						return Color3.fromHSV(fovColour.Hue, fovColour.Sat, fovColour.Value)
					end,
					Thickness = function()
						return fovThickness.Value
					end
				})
			end
		end
	})
	fovColour = ShowFOV:CreateColorSlider({
		Name = 'Circle colour',
		Darker = true
	})
	fovThickness = ShowFOV:CreateSlider({
		Name = 'Circle thickness',
		Min = 1,
		Max = 8,
		Default = 1,
		Darker = true,
		Tooltip = 'Width of the ring in pixels'
	})
	Horizontal = ProjectileAimbot:CreateSlider({
		Name = 'Horizontal prediction',
		Min = 0,
		Max = 2,
		Default = 1,
		Decimal = 100,
		Tooltip = 'How far ahead of a moving target to aim'
	})
	Vertical = ProjectileAimbot:CreateSlider({
		Name = 'Vertical prediction',
		Min = 0,
		Max = 2,
		Default = 1,
		Decimal = 100,
		Tooltip = 'How far ahead to aim at a target rising or falling'
	})
	AutoCharge = ProjectileAimbot:CreateGroup({
		Name = 'Auto Charge',
		Function = function(callback)
			if Aim and Aim.Object then
			end
		end,
		Default = true,
		Tooltip = 'Fires bows at full charge however long you draw'
	})
	Aim = AutoCharge:CreateToggle({
		Name = 'Aim change',
		Default = true,
		Darker = true,
		Tooltip = 'Matches your shot\'s path to its charge'
	})
	OtherProjectiles = ProjectileAimbot:CreateToggle({
		Name = 'Other Projectiles',
		Default = true
	})
	Blacklist = ProjectileAimbot:CreateTextList({
		Name = 'Blacklist',
		Default = {'telepearl'}
	})
	MiloCheck = ProjectileAimbot:CreateToggle({
		Name = 'Milo check',
		Default = true,
		Tooltip = 'Skips Milo players while they are disguised as a block'
	})
end)
