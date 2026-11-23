run(function()
	local Value
	local CameraDirection
	local LimitItems
	local start
	local jumpTick, jumpSpeed, direction = tick(), 0, nil
	local coast = 1.1
	local arcStart, arcEnd = 0, 0
	local projectileRemote = {InvokeServer = function() end}
	task.spawn(function()
		projectileRemote = bedwars.Client:Get(remotes.FireProjectile).instance
	end)

	local boosts = {
		cannon = {Multiplier = 5.25, Duration = 2.3},
		cat = {Multiplier = 4, Duration = 2.5},
		grappling_hook = {Multiplier = 2.5, Duration = 2.5},
		jade_hammer = {Multiplier = 1.4, Duration = 2.5},
		wood_dao = {Multiplier = 4.5, Duration = 2.4}
	}
	for _, v in {'stone_dao', 'iron_dao', 'diamond_dao', 'emerald_dao'} do
		boosts[v] = boosts.wood_dao
	end
	boosts.void_axe = boosts.jade_hammer

	local function scaled(name)
		local boost = boosts[name]
		if not boost then return nil end
		return boost.Multiplier * Value.Value, boost.Duration
	end

	local function flat(vector)
		local level = vector and Vector3.new(vector.X, 0, vector.Z) or Vector3.zero
		if level.Magnitude > 0.001 then return level.Unit end
		local look = entitylib.isAlive and entitylib.character.RootPart.CFrame.LookVector or Vector3.zAxis
		level = Vector3.new(look.X, 0, look.Z)
		return level.Magnitude > 0.001 and level.Unit or Vector3.zAxis
	end

	local function jumpAbility(item)
		return (item.itemType:find('jade_hammer', 1, true) and 'jade_hammer' or item.itemType)..'_jump'
	end

	local function ready(name, item)
		local options = {disableBlockedAbilityAlert = true}
		if name == 'cat' then
			return bedwars.AbilityController:canUseAbility('CAT_POUNCE', options)
		elseif name:find('_dao', 1, true) then
			return (lplr.Character and lplr.Character:GetAttribute('CanDashNext') or 0) < workspace:GetServerTimeNow() and bedwars.AbilityController:canUseAbility('dash', options)
		elseif boosts[name] == boosts.jade_hammer then
			return item ~= nil and bedwars.AbilityController:canUseAbility(jumpAbility(item), options)
		end
		return true
	end

	local function waitReady(name, item)
		while not ready(name, item) and LongJump.Enabled do
			task.wait()
		end
		return LongJump.Enabled and ready(name, item)
	end

	local function knockback(damageTable)
		if damageTable.entityInstance ~= lplr.Character or damageTable.fromEntity ~= lplr.Character or damageTable.knockbackMultiplier and damageTable.knockbackMultiplier.disabled then
			return nil
		end
		local from = damageTable.fromPosition and Vector3.new(damageTable.fromPosition.X, damageTable.fromPosition.Y, damageTable.fromPosition.Z) or damageTable.fromEntity and damageTable.fromEntity.PrimaryPart and damageTable.fromEntity.PrimaryPart.Position
		if not from or not entitylib.isAlive then return nil end
		local speed = bedwars.KnockbackUtil.calculateKnockbackVelocity(Vector3.one, 1, {
			vertical = 0,
			horizontal = (damageTable.knockbackMultiplier and damageTable.knockbackMultiplier.horizontal or 1)
		}).Magnitude * 1.1
		return speed, 2.5, entitylib.character.RootPart.Position - from
	end

	local function transit(dataTable)
		if dataTable.hookFunction == 'PLAYER_IN_TRANSIT' then
			return scaled('grappling_hook')
		end
		return nil
	end

	local function propel(look, speed, duration)
		jumpSpeed = speed
		jumpTick = tick() + duration
		direction = flat(look)
	end

	local launcher = {
		Active = function()
			return LongJump.Enabled
		end,
		Propel = propel,
		Anchor = function(position)
			start = position
		end,
		Clean = function(connection)
			LongJump:Clean(connection)
		end
	}

	local function playLaunchSound(item)
		local meta = bedwars.ItemMeta[item.itemType]
		local source = meta and meta.projectileSource
		local sounds = source and type(source.launchSound) == 'table' and #source.launchSound > 0 and source.launchSound or nil
		if sounds then
			bedwars.SoundManager:playSound(sounds[math.random(1, #sounds)])
		end
	end

	local function shoot(item, position, projectile, ammo, speed, look)
		if not position then return end
		position = position - look * 0.1
		local shootCFrame = CFrame.lookAlong(position, Vector3.new(0, -speed, 0)) * CFrame.new(Vector3.new(-bedwars.BowConstantsTable.RelX, -bedwars.BowConstantsTable.RelY, -bedwars.BowConstantsTable.RelZ))
		switchItem(item.tool, 0)
		task.wait(0.1)
		local result = projectileRemote:InvokeServer(item.tool, ammo, projectile, shootCFrame.Position, position, shootCFrame.LookVector * speed, bedwars.IdUtil.generateId(8), bedwars.getShotData(item.itemType), workspace:GetServerTimeNow() - 0.045)
		if type(result) == 'table' and result.accepted then
			playLaunchSound(item)
		end
	end

	local function feetCell(position)
		local feet = position - Vector3.new(0, (entitylib.character.HipHeight + (entitylib.character.RootPart.Size.Y / 2)) - 3, 0)
		return Vector3.new(math.round(feet.X / 3) * 3, math.round(feet.Y / 3) * 3, math.round(feet.Z / 3) * 3)
	end

	local methods = {
		cannon = function(_, position, look, launch)
			if not position then return end
			local rounded = feetCell(position)
			bedwars.placeBlock(rounded, 'cannon', false)

			task.defer(function()
				local block, blockPosition = getPlacedBlock(rounded)
				if not (block and block.Name == 'cannon' and entitylib.isAlive and (entitylib.character.RootPart.Position - block.Position).Magnitude < 20) then return end
				local tool = getBreakTool(bedwars.ItemMeta[block.Name].block.breakType)
				if tool then
					switchItem(tool.tool)
				end

				bedwars.Client:Get(remotes.CannonAim):SendToServer({
					cannonBlockPos = blockPosition,
					lookVector = look
				})

				local breakDelay = 0.1
				if bedwars.BlockController:calculateBlockDamage(lplr, {blockPosition = blockPosition}) < block:GetAttribute('Health') then
					breakDelay = 0.4
					bedwars.breakBlock(block, true, true)
				end

				task.delay(breakDelay, function()
					for _ = 1, 3 do
						if bedwars.Client:Get(remotes.CannonLaunch):CallServer({cannonBlockPos = blockPosition}) then
							bedwars.breakBlock(block, true, true)
							launch.Propel(look, scaled('cannon'))
							break
						end
						task.wait(0.1)
					end
				end)
			end)
		end,
		cat = function(_, _, look, launch)
			launch.Clean(vapeEvents.CatPounce.Event:Connect(function()
				launch.Propel(look, scaled('cat'))
				if entitylib.isAlive then
					entitylib.character.RootPart.AssemblyLinearVelocity = Vector3.zero
				end
			end))

			local controller = bedwars.CatController
			if controller and type(controller.leap) == 'function' then
				local original = controller.leap
				local hook
				hook = function(...)
					vapeEvents.CatPounce:Fire()
					return original(...)
				end
				controller.leap = hook
				launch.Clean(function()
					if controller.leap == hook then
						controller.leap = original
					end
				end)
			end

			if waitReady('cat') then
				bedwars.AbilityController:useAbility('CAT_POUNCE')
			end
		end,
		fireball = function(item, position, look)
			shoot(item, position, 'fireball', 'fireball', 60, look)
		end,
		grappling_hook = function(item, position, look)
			shoot(item, position, 'grappling_hook_projectile', nil, 140, look)
		end,
		jade_hammer = function(item, position, look, launch)
			if not (item and position) then return end
			if waitReady('jade_hammer', item) then
				switchItem(item.tool, 0)
				lplr.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
				launch.Anchor(position + Vector3.new(0, 3.1, 0))
				task.wait(0.1)
				bedwars.AbilityController:useAbility(jumpAbility(item))
				launch.Propel(look, scaled('jade_hammer'))
			end
		end,
		tnt = function(item, position, look, launch)
			if not (item and position) then return end
			local rounded = feetCell(position)
			launch.Anchor(Vector3.new(rounded.X, position.Y, rounded.Z) + (look * (item.itemType == 'pirate_gunpowder_barrel' and 2.6 or 0.2)))
			bedwars.placeBlock(rounded, item.itemType, false)
		end,
		wood_dao = function(item, position, look, launch)
			if not item then return end
			if waitReady('wood_dao') then
				bedwars.SwordController.lastAttack = workspace:GetServerTimeNow()
				switchItem(item.tool, 0.1)
				replicatedStorage['events-@easy-games/game-core:shared/game-core-networking@getEvents.Events'].useAbility:FireServer('dash', {
					direction = look,
					origin = position,
					weapon = item.itemType
				})
				launch.Propel(look, scaled('wood_dao'))
			end
		end
	}
	for _, v in {'stone_dao', 'iron_dao', 'diamond_dao', 'emerald_dao'} do
		methods[v] = methods.wood_dao
	end
	methods.void_axe = methods.jade_hammer
	methods.siege_tnt = methods.tnt
	methods.pirate_gunpowder_barrel = methods.tnt

	local function heldMethod()
		local tool = store.hand and store.hand.tool
		if not tool then return nil end
		local name = tool.Name
		if isJadeHammerName(name) then
			return methods.jade_hammer, getItem(name) or {itemType = name, tool = tool}
		end
		local method = methods[name]
		return method, method and (getItem(name) or {itemType = name, tool = tool})
	end

	local function lookVector()
		return (CameraDirection.Enabled and gameCamera or entitylib.character.RootPart).CFrame.LookVector
	end

	LongJump = vape.Categories.Blatant:CreateModule({
		Name = 'LongJump',
		Function = function(callback)
			if callback and vape.MovementOwner then
				notif('LongJump', 'Unavailable until '..tostring(vape.MovementOwner)..' has landed', 3, 'warning')
				task.spawn(function()
					if LongJump.Enabled then LongJump:Toggle() end
				end)
				return
			end
			if callback and LimitItems.Enabled and not heldMethod() then
				notif('LongJump', 'Hold a long jump item to use it (Limit to items is on)', 4)
				task.spawn(function()
					if LongJump.Enabled then LongJump:Toggle() end
				end)
				return
			end
			frictionTable.LongJump = callback or nil
			updateVelocity()
			if callback then
				if not LimitItems.Enabled then
					LongJump:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
						local speed, duration, away = knockback(damageTable)
						if speed and speed >= jumpSpeed then
							propel(away, speed, duration)
						end
					end))
					LongJump:Clean(vapeEvents.GrapplingHookFunctions.Event:Connect(function(dataTable)
						local speed, duration = transit(dataTable)
						if speed and entitylib.isAlive then
							propel(entitylib.character.RootPart.CFrame.LookVector, speed, duration)
						end
					end))
				end

				start = entitylib.isAlive and entitylib.character.RootPart.Position or nil
				LongJump:Clean(runService.PreSimulation:Connect(function(dt)
					local root = entitylib.isAlive and entitylib.character.RootPart or nil
					if vape.MovementOwner then
						return
					elseif root and isnetworkowner(root) then
						if jumpTick > tick() and direction then
							local boost = (jumpTick - tick()) > coast and jumpSpeed or 0
							local rise = 15
							if not start and entitylib.character.Humanoid.FloorMaterial == Enum.Material.Air then
								if arcEnd ~= jumpTick then
									arcStart, arcEnd = tick(), jumpTick
								end
								local total = math.max(arcEnd - arcStart, 0.1)
								rise = (16 / total) * (1 - 2 * math.clamp((tick() - arcStart) / total, 0, 1)) + dt * workspace.Gravity
							end
							root.AssemblyLinearVelocity = direction * (getSpeed() + boost) + Vector3.new(0, rise, 0)
							start = nil
						else
							if start then
								root.CFrame = CFrame.lookAlong(start, root.CFrame.LookVector)
							end
							root.AssemblyLinearVelocity = Vector3.zero
							jumpSpeed = 0
						end
					else
						start = nil
					end
				end))

				if not entitylib.isAlive then return end
				local method, item = heldMethod()
				if method then
					task.spawn(method, item, start, lookVector(), launcher)
					return
				end
				if LimitItems.Enabled then return end

				for name, fallback in methods do
					local found = getItem(name, nil, true)
					if found or store.equippedKit == name then
						task.spawn(fallback, found, start, lookVector(), launcher)
						break
					end
				end
			else
				jumpTick = tick()
				direction = nil
				jumpSpeed = 0
			end
		end,
		ExtraText = function()
			return 'Heatseeker'
		end,
		Tooltip = 'Lets you jump farther'
	})
	LongJump.Launch = {
		Methods = methods,
		Coast = coast,
		Ready = ready,
		Scaled = scaled,
		Knockback = knockback,
		Transit = transit
	}

	Value = LongJump:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 37,
		Default = 37,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})
	CameraDirection = LongJump:CreateToggle({
		Name = 'Camera Direction'
	})
	LimitItems = LongJump:CreateToggle({
		Name = 'Limit to items',
		Tooltip = 'Only works while holding the item it uses'
	})
end)
