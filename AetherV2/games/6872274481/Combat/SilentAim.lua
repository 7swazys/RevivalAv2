run(function()
	local SilentAim
	local Targets
	local TargetPart
	local SortMethod
	local Prediction
	local FOV
	local Range
	local SAFOVCircle
	local RandomHeadPercent
	local RandomTorsoPercent
	local OtherProjectiles
	local MiloCheck
	local Blacklist
	local AutoCharge
	local skidChargePercent

	local rayCheck = RaycastParams.new()
	rayCheck.FilterType = Enum.RaycastFilterType.Include

	local Debug
	local hookState = getgenv().AetherSilentAimHook
	if type(hookState) ~= 'table' then
		hookState = {Classes = {}}
		getgenv().AetherSilentAimHook = hookState
	end
	local lockedRandomPart
	local _saVelHistory = {}
	local _saVelStamp = {}
	local fovCircle
	local fovColour
	local fovThickness
	local lastWarn = 0
	local diagReason = ''
	local diagTarget = nil
	local diagShot = ''
	local nextDiag = 0
	local fireRemote
	local fireRemoteResolved
	local fireRemoteObject
	local clientHooked

	local function locateLaunch(args)
		local projType, origin, velocity, velocityIndex = args[3], args[4], args[6], 6
		if type(projType) == 'string' and typeof(origin) == 'Vector3' and typeof(velocity) == 'Vector3' then
			return projType, origin, velocity, velocityIndex
		end
		local vectors = {}
		for index = 1, args.n do
			if typeof(args[index]) == 'Vector3' then table.insert(vectors, index) end
		end
		if #vectors < 3 then return end
		velocityIndex = vectors[3]
		origin, velocity = args[vectors[1]], args[velocityIndex]
		for index = vectors[1] - 1, 1, -1 do
			local value = args[index]
			if type(value) == 'string' and bedwars.ProjectileMeta[value] then
				projType = value
				break
			end
		end
		if type(projType) ~= 'string' then return end
		return projType, origin, velocity, velocityIndex
	end

	local function getMousePosition()
		if inputService.TouchEnabled then
			return gameCamera.ViewportSize / 2
		end
		return inputService:GetMouseLocation()
	end

	local function getClosestPart(char, mousePos)
		local magnitude, part = 9e9, nil
		for _, v in char:GetChildren() do
			if v:IsA('BasePart') then
				local position, vis = gameCamera:WorldToViewportPoint(v.Position)
				if vis then
					local mag = (mousePos - Vector2.new(position.X, position.Y)).Magnitude
					if mag < magnitude then
						magnitude = mag
						part = v
					end
				end
			end
		end
		return part
	end

	local function pickRandomPart(char)
		local roll = math.random(1, 100)
		local head = char:FindFirstChild('Head')
		local torso = char:FindFirstChild('HumanoidRootPart') or char.PrimaryPart
		if head and roll <= RandomHeadPercent.Value then
			return head
		elseif torso and roll <= (RandomHeadPercent.Value + RandomTorsoPercent.Value) then
			return torso
		end
		return torso or head
	end

	local function getTargetPart(plr, projectileType)
		local val = TargetPart.Value
		if val == 'Dynamic' then
			if isHeadshotDynamic(projectileType) then
				local head = plr.Character and plr.Character:FindFirstChild('Head')
				if head then return head end
			end
			return plr.RootPart
		elseif val == 'Head' then
			return (plr.Character and plr.Character:FindFirstChild('Head')) or plr.RootPart
		elseif val == 'Closest' then
			return (plr.Character and getClosestPart(plr.Character, getMousePosition())) or plr.RootPart
		elseif val == 'Randomize' then
			if lockedRandomPart and lockedRandomPart.Parent ~= plr.Character then
				lockedRandomPart = nil
			end
			if plr.Character and (not lockedRandomPart or not lockedRandomPart.Parent) then
				lockedRandomPart = pickRandomPart(plr.Character)
			end
			return lockedRandomPart or plr.RootPart
		end
		return plr.RootPart
	end

	local function isBlacklisted(projType)
		local key = (projType == 'glue_trap' or projType == 'glue_projectile') and 'gloop' or projType
		local list = Blacklist and (Blacklist.ListEnabled or Blacklist.Value) or {}
		return table.find(list, key) ~= nil
	end

	local function resolveFireRemote()
		if fireRemoteResolved then return fireRemote end
		fireRemoteResolved = true
		local name = getgenv().remotes and getgenv().remotes.FireProjectile
		if name then
			local ok, object = pcall(function()
				return bedwars.Client:Get(name)
			end)
			if ok and type(object) == 'table' then
				fireRemoteObject = object
				fireRemote = object.instance
			end
		end
		return fireRemote
	end

	local function isFireRemote(remote)
		if typeof(remote) == 'Instance' then
			if remote.Name == 'ProjectileFire' then return true end
			local resolved = resolveFireRemote()
			return resolved ~= nil and remote == resolved
		end
		if type(remote) == 'table' and typeof(remote.instance) == 'Instance' then
			local resolved = resolveFireRemote()
			return tostring(remote.name) == 'ProjectileFire' or (resolved ~= nil and remote.instance == resolved)
		end
		return false
	end

	local function chargeModel(tool, projType)
		local meta = bedwars.ProjectileMeta[projType]
		local itemMeta = tool and bedwars.ItemMeta and bedwars.ItemMeta[tool.Name]
		local source = itemMeta and (itemMeta.projectileSource or itemMeta.multiProjectileSource)
		local fullCharge = source and tonumber(source.maxStrengthChargeSec) or nil
		local minimum = source and tonumber(source.minStrengthScalar) or 0.25
		local maxSpeed = meta and tonumber(meta.launchVelocity) or nil
		return fullCharge, math.clamp(minimum, 0, 1), maxSpeed
	end

	local function isHoldingProjectile()
		local tool = store.hand and store.hand.tool
		local itemType = tool and tool.Name or ''
		local itemMeta = bedwars.ItemMeta and bedwars.ItemMeta[itemType]
		if not (itemMeta and itemMeta.projectileSource) then return false end

		local ammoTypes = itemMeta.projectileSource.ammoItemTypes
		if type(ammoTypes) == 'table' and table.find(ammoTypes, 'arrow') then return true end
		if itemType:find('headhunter', 1, true) then return true end
		if not (OtherProjectiles and OtherProjectiles.Enabled) then return false end

		return true
	end

	local circleLibrary = vape.Libraries and vape.Libraries.fovcircle

	local function runFOVCircle(state)
		if fovCircle then
			fovCircle:Destroy()
			fovCircle = nil
		end
		if not state or not (circleLibrary and circleLibrary.New) then return end

		fovCircle = circleLibrary.New({
			Name = 'SAFOVCircle',
			Parent = vape.gui,
			Visible = function()
				return SilentAim and SilentAim.Enabled and SAFOVCircle and SAFOVCircle.Enabled
			end,
			Radius = function()
				return FOV and FOV.Value or 0
			end,
			Colour = function()
				return Color3.fromHSV(fovColour.Hue, fovColour.Sat, fovColour.Value)
			end,
			Thickness = function()
				return fovThickness.Value
			end
		})
	end

	local function solveSilent(args)
		diagReason, diagTarget, diagShot = '', nil, ''
		local projType, origin, velocity, velocityIndex = locateLaunch(args)
		if not projType or typeof(origin) ~= 'Vector3' or typeof(velocity) ~= 'Vector3' then
			diagReason = 'the launch arguments did not line up'
			return
		end

		if (not OtherProjectiles.Enabled) and not projType:find('arrow', 1, true) then
			diagReason = projType..' is not an arrow and Other Projectiles is off'
			return
		end
		if isBlacklisted(projType) then
			diagReason = projType..' is blacklisted'
			return
		end

		local meta = bedwars.ProjectileMeta[projType]
		if not meta then
			diagReason = 'no projectile meta for '..tostring(projType)
			return
		end

		local projSpeed = velocity.Magnitude
		if projSpeed <= 0 then
			diagReason = 'the shot carries no speed'
			return
		end

		local sendSpeed, sendDraw = projSpeed, nil
		if AutoCharge and AutoCharge.Enabled and typeof(args[8]) == 'table' then
			local fullCharge, minimum, maxSpeed = chargeModel(args[1], projType)
			if fullCharge and maxSpeed and maxSpeed > 0 then
				local fraction = math.clamp((skidChargePercent and skidChargePercent.Value or 100) / 100, 0, 1)
				sendDraw = fullCharge * fraction
				sendSpeed = maxSpeed * (minimum + (1 - minimum) * fraction)
			end
		end
		local gravity = tonumber(meta.gravitationalAcceleration)
		if gravity == nil then gravity = 196.2 end
		if gravity < 1 then gravity = 0 end

		local map = workspace:FindFirstChild('Map')
		if map ~= rayCheck.FilterDescendantsInstances[1] then
			rayCheck.FilterDescendantsInstances = map and {map} or {}
		end

		if not (circleLibrary and circleLibrary.Center) then
			diagReason = 'the FOV circle library is unavailable'
			return
		end
		local plr = entitylib.EntityMouse({
			Part = 'RootPart',
			Range = FOV.Value,
			MaxDistance = Range.Value,
			Players = Targets.Players.Enabled,
			NPCs = (Targets.NPCs and Targets.NPCs.Enabled) or false,
			Priority = Targets.Priority and Targets.Priority.Value,
			Wallcheck = Targets.Walls.Enabled,
			Sort = sortmethods[SortMethod.Value or 'Cursor'],
			MouseOrigin = circleLibrary.Center(),
			Origin = origin,
			Check = function(ent)
				return not (MiloCheck and MiloCheck.Enabled and store.isDisguised(ent))
			end
		})
		if plr and not circleLibrary.ContainsEntity(plr, FOV.Value) then plr = nil end
		if not plr then
			diagReason = 'no target inside the FOV circle'
			return
		end

		local targetPart = getTargetPart(plr, projType)
		if not targetPart then
			diagReason = 'the target has no '..tostring(TargetPart.Value)..' part'
			return
		end
		diagTarget = (plr.Player and plr.Player.Name) or 'the entity'

		local playerGravity = workspace.Gravity
		local balloons = plr.Character and plr.Character:GetAttribute('InflatedBalloons')
		if balloons and balloons > 0 then
			playerGravity = workspace.Gravity * (1 - (balloons >= 4 and 1.2 or balloons >= 3 and 1 or 0.975))
		end
		if plr.Character and plr.Character.PrimaryPart and plr.Character.PrimaryPart:FindFirstChild('rbxassetid://8200754399') then
			playerGravity = 6
		end
		if plr.Player and plr.Player:GetAttribute('IsOwlTarget') then
			for _, owl in collectionService:GetTagged('Owl') do
				if owl:GetAttribute('Target') == plr.Player.UserId and owl:GetAttribute('Status') == 2 then
					playerGravity = 0
					break
				end
			end
		end

		local pearl = projType == 'telepearl'
		local rawVel = pearl and Vector3.zero or (plr.RootPart.AssemblyLinearVelocity or plr.RootPart.Velocity or Vector3.zero)
		local _velKey = tostring(plr)
		local _velNow = tick()
		if not _saVelHistory[_velKey] or (_velNow - (_saVelStamp[_velKey] or 0)) > 0.15 then
			_saVelHistory[_velKey] = rawVel
		else
			_saVelHistory[_velKey] = _saVelHistory[_velKey]:Lerp(rawVel, 0.35)
		end
		_saVelStamp[_velKey] = _velNow

		local calc, _, travelTime = prediction.SolveTrajectory(
			origin,
			sendSpeed * (Prediction and Prediction.Value or 1),
			gravity,
			targetPart.Position,
			rawVel,
			playerGravity,
			plr.HipHeight,
			plr.Jumping and 42.6 or nil,
			rayCheck,
			nil,
			plr.RootPart.Position,
			plr.RootPart,
			nil,
			true,
			TargetPart.Value ~= 'Dynamic' or isHeadshotDynamic(projType)
		)
		if not calc then
			diagReason = 'no ballistic solution to '..diagTarget
			return
		end

		local lifetime = tonumber(meta.predictionLifetimeSec) or tonumber(meta.lifetimeSec) or 3
		if travelTime and travelTime > lifetime then
			diagReason = string.format('the %.2fs flight is longer than the %.2fs lifetime', travelTime, lifetime)
			return
		end

		if targetinfo and targetinfo.Targets then
			targetinfo.Targets[plr] = tick() + 1
		end
		if travelTime then
			store.hitchance.SilentAim = {Value = getHitChance(plr, travelTime), Clock = tick()}
		end

		diagReason = 'redirected at '..tostring(diagTarget)
		diagShot = string.format('%.0f studs/s', sendSpeed)..(sendDraw and string.format(' with a %.2fs draw', sendDraw) or '')
		return CFrame.lookAt(origin, calc).LookVector * sendSpeed, velocityIndex, sendDraw
	end

	local function redirectShot(args)
		local ok, newVelocity, velocityIndex, drawSeconds = pcall(solveSilent, args)
		if ok and typeof(newVelocity) == 'Vector3' and velocityIndex then
			args[velocityIndex] = newVelocity

			if drawSeconds and typeof(args[8]) == 'table' then
				if args[8].drawDurationSec ~= nil and args[8].drawDurationSeconds == nil then
					args[8].drawDurationSec = drawSeconds
				else
					args[8].drawDurationSeconds = drawSeconds
				end
			end
			return true
		end
		if not ok then
			diagReason = tostring(newVelocity)
		end
		return false
	end

	local function reportShot(sent)
		if shared.VapeDeveloper and not sent and tick() > lastWarn then
			lastWarn = tick() + 5
			warn('[AetherV2] silentaim left a projectile alone: '..tostring(diagReason))
		end
		if not (Debug and Debug.Enabled) or tick() <= nextDiag then return end
		nextDiag = tick() + 1
		if sent then
			task.defer(notif, 'SilentAim', 'sent the shot at '..tostring(diagTarget)..(diagShot ~= '' and (' at '..diagShot) or ''), 4)
		else
			task.defer(notif, 'SilentAim', 'left the shot alone: '..tostring(diagReason), 4, 'warning')
		end
	end

	local function installClientHooks()
		if clientHooked then return true end
		resolveFireRemote()
		local object = fireRemoteObject
		local class = object and getmetatable(object)
		local index = type(class) == 'table' and (class.__index or class) or nil
		if type(index) ~= 'table' then return false end
		clientHooked = true
		if not hookState.Classes[index] then
			hookState.Classes[index] = true
			for _, method in {'CallServer', 'CallServerAsync', 'Fire', 'SendToServer', 'SendToServerAsync'} do
				local original = index[method]
				if type(original) == 'function' then
					index[method] = function(self, ...)
						local handler = hookState.OnClient
						if handler then return handler(original, self, ...) end
						return original(self, ...)
					end
				end
			end
		end
		local function onClient(original, self, ...)
			if not (SilentAim and SilentAim.Enabled) or not isFireRemote(self) then
				return original(self, ...)
			end
			local args = table.pack(...)
			if redirectShot(args) then
				reportShot(true)
				return original(self, table.unpack(args, 1, args.n))
			end
			reportShot(false)
			return original(self, ...)
		end
		hookState.OnClient = onClient
		vape:Clean(function()
			if hookState.OnClient == onClient then hookState.OnClient = nil end
		end)
		return true
	end

	SilentAim = vape.Categories.Combat:CreateModule({
		Name = 'SilentAim',
		ExtraText = function() return TargetPart.Value end,
		Tooltip = 'Silently aims your shots at enemies',
		Function = function(callback)
			if callback then
				local ProjectileAimbot = vape.Modules and vape.Modules.ProjectileAimbot
				if ProjectileAimbot and ProjectileAimbot.Enabled then
					ProjectileAimbot:Toggle(false)
				end

				if SAFOVCircle and SAFOVCircle.Enabled then
					runFOVCircle(true)
				end
				installClientHooks()

				if not hookState.Namecall then
					hookState.Namecall = hookmetamethod(game, '__namecall', newcclosure(function(...)
						local handler = hookState.OnNamecall
						if handler then return handler(...) end
						return hookState.Namecall(...)
					end))
				end
				if not hookState.OnNamecall then
					local namecall = hookState.Namecall
					local function onNamecall(...)
						if not SilentAim.Enabled then return namecall(...) end
						local remote = ...
						if not isFireRemote(remote) then
							if Debug and Debug.Enabled and typeof(remote) == 'Instance' and tick() > nextDiag then
								local method = tostring(getnamecallmethod())
								local name = remote.Name
								if (method == 'InvokeServer' or method == 'FireServer' or method == 'FireAllClients')
									and (name:find('rojectile') or name:find('Fire')) then
									nextDiag = tick() + 3
									task.defer(notif, 'SilentAim', 'saw '..name..' fired through '..method..', which is not the shot remote', 4, 'warning')
								end
							end
							return namecall(...)
						end

						local method = getnamecallmethod()
						local self = ...
						local args = table.pack(select(2, ...))
						local sent = redirectShot(args)
						reportShot(sent)

						local invoke = self[method] or self.InvokeServer
						return invoke(self, table.unpack(args, 1, args.n))
					end
					hookState.OnNamecall = onNamecall
					vape:Clean(function()
						if hookState.OnNamecall == onNamecall then hookState.OnNamecall = nil end
					end)
				end
			else
				lockedRandomPart = nil
				table.clear(_saVelHistory)
				table.clear(_saVelStamp)
				runFOVCircle(false)
			end
		end
	})

	Targets = SilentAim:CreateTargets({
		Players = true,
		NPCs = true,
		Walls = true
	})

	TargetPart = SilentAim:CreateDropdown({
		Name = 'Part',
		List = {'Dynamic', 'RootPart', 'Head', 'Closest', 'Randomize'},
		Default = 'RootPart',
		Tooltip = 'Where on the body shots aim',
		Function = function()
			lockedRandomPart = nil
		end
	})

	SortMethod = SilentAim:CreateDropdown({
		Name = 'Sort Method',
		List = getSortList({'Distance', 'Damage', 'Cursor'}),
		Default = 'Cursor',
		Tooltip = TARGET_MODE_TOOLTIP
	})

	Prediction = SilentAim:CreateSlider({
		Name = 'Prediction',
		Min = 0.1,
		Max = 2,
		Default = 1,
		Decimal = 10
	})

	FOV = SilentAim:CreateSlider({
		Name = 'FOV',
		Min = 1,
		Max = 1000,
		Default = 300
	})

	Range = SilentAim:CreateSlider({
		Name = 'Range',
		Min = 30,
		Max = 1000,
		Default = 1000,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end,
		Tooltip = 'How far away a target can be'
	})

	SAFOVCircle = SilentAim:CreateGroup({
		Name = 'FOV Circle',
		Function = function(call)
			if SilentAim.Enabled then
				runFOVCircle(call)
			end
		end
	})

	fovColour = SAFOVCircle:CreateColorSlider({
		Name = 'Circle colour',
		Darker = true
	})

	fovThickness = SAFOVCircle:CreateSlider({
		Name = 'Circle thickness',
		Min = 1,
		Max = 8,
		Default = 1,
		Darker = true,
		Tooltip = 'Width of the ring in pixels'
	})

	RandomHeadPercent = SilentAim:CreateSlider({
		Name = 'Head Chance',
		Min = 0,
		Max = 100,
		Default = 50,
		Darker = true,
		Visible = function()
			return TargetPart.Value == 'Randomize'
		end
	})

	RandomTorsoPercent = SilentAim:CreateSlider({
		Name = 'Torso Chance',
		Min = 0,
		Max = 100,
		Default = 50,
		Darker = true,
		Visible = function()
			return TargetPart.Value == 'Randomize'
		end,
		Function = function(val)
			if RandomHeadPercent and (RandomHeadPercent.Value + val) > 100 then
				notif('SilentAim', 'head or torso chance is more than 100% so root part will never be picked..', 3)
			end
		end
	})

	OtherProjectiles = SilentAim:CreateGroup({
		Name = 'Other Projectiles',
		Default = true,
	})

	Blacklist = OtherProjectiles:CreateTextList({
		Name = 'Blacklist',
		Darker = true,
		Default = {'telepearl', 'gloop'},
		Placeholder = 'projectile'
	})

	AutoCharge = SilentAim:CreateGroup({
		Name = 'AutoCharge',
		Default = true,
	})

	skidChargePercent = AutoCharge:CreateSlider({
		Name = 'Charge Percent',
		Min = 1,
		Max = 100,
		Default = 100
	})

	MiloCheck = SilentAim:CreateToggle({
		Name = 'Milo check',
		Default = true,
		Tooltip = 'Skips Milo players while they are disguised as a block'
	})
	Debug = SilentAim:CreateToggle({
		Name = 'Debug',
		Tooltip = 'Logs what it does'
	})
end)
