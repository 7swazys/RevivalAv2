run(function()
	local AntiFall
	local Mode
	local Material
	local Color
	local FlyRelease
	local PopAboveLand
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true

	local CELL = 3
	local WATER = 'Realistic Water'
	local water

	local function clearWater()
		if not water then return end
		local terrain = workspace.Terrain
		pcall(terrain.FillBlock, terrain, water.CFrame, water.Size, Enum.Material.Air)
		for prop, value in water.Saved do
			pcall(function() terrain[prop] = value end)
		end
		water = nil
	end

	local function tintWater()
		if not water then return end
		pcall(function()
			workspace.Terrain.WaterColor = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
			workspace.Terrain.WaterTransparency = 1 - Color.Opacity
		end)
	end

	local function applyLook()
		if not AntiFallPart or not AntiFallPart.Parent or not AntiFall.Enabled then
			clearWater()
			return
		end
		if Material.Value == WATER then
			AntiFallPart.Transparency = 1
			if not water then
				local terrain = workspace.Terrain
				local top = AntiFallPart.Position.Y - 3.5
				local centre = entitylib.isAlive and entitylib.character.RootPart.Position or Vector3.zero
				water = {
					CFrame = CFrame.new(centre.X, top - 4, centre.Z),
					Size = Vector3.new(1600, 8, 1600),
					Saved = {WaterColor = terrain.WaterColor, WaterTransparency = terrain.WaterTransparency}
				}
				pcall(terrain.FillBlock, terrain, water.CFrame, water.Size, Enum.Material.Water)
			end
			tintWater()
		else
			clearWater()
			AntiFallPart.Material = Enum.Material[Material.Value]
			AntiFallPart.Transparency = 1 - Color.Opacity
		end
	end

	local function balloonCount()
		return (lplr.Character and lplr.Character:GetAttribute('InflatedBalloons')) or 0
	end

	local function inflate()
		if balloonCount() < 3 and getItem('balloon') then
			for _ = 1, 3 - balloonCount() do
				pcall(function() bedwars.BalloonController:inflateBalloon() end)
			end
		end
	end

	local function getLowGround()
		local mag = math.huge
		for _, pos in bedwars.BlockController:getStore():getAllBlockPositions() do
			pos = pos * 3
			if pos.Y < mag and not getPlacedBlock(pos + Vector3.new(0, 3, 0)) then
				mag = pos.Y
			end
		end
		return mag
	end

	local lowestValue, lowestAt = math.huge, 0
	local function lowestGround()
		if tick() - lowestAt > 5 then
			lowestValue = getLowGround()
			lowestAt = tick()
		end
		return lowestValue
	end

	local columnKey, columnValue, columnAt = nil, nil, 0

	local function beingCarried()
		local flyModule = Fly or vape.Modules.Fly
		local longJumpModule = LongJump or vape.Modules.LongJump
		if flyModule and flyModule.Enabled then return true end
		if longJumpModule and longJumpModule.Enabled then return true end
		return false
	end

	local function landBelow(root, lookahead)
		local pos = root.Position
		local horiz = root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
		local drift = horiz * math.clamp(lookahead or 0, 0, 2)
		local from = Vector3.new(pos.X + drift.X, pos.Y, pos.Z + drift.Z)

		rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera, AntiFallPart}
		rayCheck.CollisionGroup = root.CollisionGroup
		local ray = workspace:Raycast(from, Vector3.new(0, -600, 0), rayCheck)
		if ray then return ray.Position.Y end

		local lowest = lowestGround()
		if lowest == math.huge then return nil end
		local cell = bedwars.BlockController:getBlockPosition(from)
		local key = cell.X .. ',' .. cell.Z
		if columnKey == key and (tick() - columnAt) < 0.15 then
			return columnValue
		end
		local floor = math.max(math.floor(lowest / CELL), cell.Y - 400)
		local found = nil
		for y = cell.Y, floor, -1 do
			if getPlacedBlock(Vector3.new(cell.X, y, cell.Z) * CELL) then
				found = y * CELL
				break
			end
		end
		columnKey, columnValue, columnAt = key, found, tick()
		return found
	end

	local flyOwned, landSince = false, 0

	local function flyModule()
		return Fly or vape.Modules.Fly
	end

	local function stopFly(force)
		local module = flyModule()
		if not module then
			flyOwned = false
			return
		end
		if flyOwned and (force or module.Enabled) then
			flyOwned = false
			if module.Enabled then
				task.spawn(function()
					module:Toggle()
				end)
			end
		end
	end

	local function updateFlyMode()
		if Mode.Value ~= 'Fly' then
			stopFly(true)
			return
		end
		if not entitylib.isAlive then
			stopFly(true)
			return
		end
		local root = entitylib.character.RootPart
		local module = flyModule()
		if not root or not module then return end

		local grounded = entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air
		local land = grounded and root.Position.Y or landBelow(root, 0.25)

		if not land then
			landSince = 0
			if not module.Enabled then
				flyOwned = true
				root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
				task.spawn(function()
					module:Toggle()
				end)
			elseif not flyOwned then
				return
			end
			return
		end

		if flyOwned then
			if landSince == 0 then
				landSince = tick()
			end
			local safeDrop = (FlyRelease and FlyRelease.Value or 12)
			if (tick() - landSince) >= 0.2 and (root.Position.Y - land) <= safeDrop then
				stopFly(false)
			end
		else
			landSince = 0
		end
	end

	AntiFall = vape.Categories.Blatant:CreateModule({
		Name = 'AntiVoid',
		ExtraText = function() return Mode.Value end,
		Function = function(callback)
			if callback then
				repeat task.wait() until store.matchState ~= 0 or (not AntiFall.Enabled)
				if not AntiFall.Enabled then return end

				flyOwned, landSince = false, 0
				AntiFall:Clean(function()
					stopFly(true)
				end)

				AntiFall:Clean(runService.Heartbeat:Connect(updateFlyMode))

				AntiFall:Clean(task.spawn(function()
					repeat
						if Mode.Value == 'Balloon' and PopAboveLand.Enabled and entitylib.isAlive and balloonCount() > 0 then
							local root = entitylib.character.RootPart
							if workspace:Raycast(root.Position, Vector3.new(0, -3000, 0), store.airRay) then
								for _ = 1, 3 do
									if balloonCount() <= 0 then break end
									pcall(function() bedwars.BalloonController:deflateBalloon() end)
									task.wait(0.05)
								end
							end
						end
						task.wait(0.1)
					until not AntiFall.Enabled
				end))

				local pos, debounce = getLowGround(), tick()
				if pos ~= math.huge then
					AntiFallPart = Instance.new('Part')
					AntiFallPart.Size = Vector3.new(10000, 1, 10000)
					AntiFallPart.Transparency = 1 - Color.Opacity
					AntiFallPart.Color = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
					AntiFallPart.Position = Vector3.new(0, pos - 2, 0)
					AntiFallPart.CanCollide = Mode.Value == 'Collide'
					AntiFallPart.Anchored = true
					AntiFallPart.CanQuery = false
					AntiFallPart.Parent = workspace
					AntiFall:Clean(AntiFallPart)
					applyLook()
					AntiFall:Clean(AntiFallPart.Touched:Connect(function(touched)
						if touched.Parent == lplr.Character and entitylib.isAlive and debounce < tick() then
							debounce = tick() + 0.1
							if Mode.Value == 'Normal' then
								local top = getNearGround()
								if top then
									local lastTeleport = lplr:GetAttribute('LastTeleported')
									local connection
									connection = runService.PreSimulation:Connect(function()
										if beingCarried() then
											connection:Disconnect()
											AntiFallDirection = nil
											return
										end

										if entitylib.isAlive and lplr:GetAttribute('LastTeleported') == lastTeleport then
											local delta = ((top - entitylib.character.RootPart.Position) * Vector3.new(1, 0, 1))
											local root = entitylib.character.RootPart
											AntiFallDirection = delta.Unit == delta.Unit and delta.Unit or Vector3.zero
											root.Velocity *= Vector3.new(1, 0, 1)
											rayCheck.FilterDescendantsInstances = {gameCamera, lplr.Character}
											rayCheck.CollisionGroup = root.CollisionGroup

											local ray = workspace:Raycast(root.Position, AntiFallDirection, rayCheck)
											if ray then
												for _ = 1, 10 do
													local dpos = roundPos(ray.Position + ray.Normal * 1.5) + Vector3.new(0, 3, 0)
													if not getPlacedBlock(dpos) then
														top = dpos
														break
													end
												end
											end

											root.CFrame += Vector3.new(0, top.Y - root.Position.Y, 0)
											if not frictionTable.Speed then
												root.AssemblyLinearVelocity = (AntiFallDirection * getSpeed()) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
											end

											if delta.Magnitude < 1 then
												connection:Disconnect()
												AntiFallDirection = nil
											end
										else
											connection:Disconnect()
											AntiFallDirection = nil
										end
									end)
									AntiFall:Clean(connection)
								end
							elseif Mode.Value == 'Balloon' then
								inflate()
							elseif Mode.Value == 'Velocity' then
								entitylib.character.RootPart.Velocity = Vector3.new(entitylib.character.RootPart.Velocity.X, 100, entitylib.character.RootPart.Velocity.Z)
							end
						end
					end))
				end
			else
				AntiFallDirection = nil
				clearWater()
				stopFly(true)
			end
		end,
		Tooltip = 'Prevents you from falling into the void'
	})
	Mode = AntiFall:CreateDropdown({
		Name = 'Move Mode',
		List = {'Normal', 'Collide', 'Velocity', 'Fly', 'Balloon'},
		Function = function(val)
			if AntiFallPart then
				AntiFallPart.CanCollide = val == 'Collide'
			end
			if val ~= 'Fly' then
				stopFly(true)
			end
			pcall(function()
				FlyRelease.Object.Visible = val == 'Fly'
				PopAboveLand.Object.Visible = val == 'Balloon'
			end)
		end,
		Tooltip = 'How it saves you'
	})
	FlyRelease = AntiFall:CreateSlider({
		Name = 'Release height',
		Min = 3,
		Max = 60,
		Default = 12,
		Suffix = ' studs',
		Darker = true,
		Visible = false,
		Tooltip = 'How close to land Fly mode stops'
	})
	PopAboveLand = AntiFall:CreateToggle({
		Name = 'Pop when above land',
		Darker = true,
		Visible = false,
		Tooltip = 'Pops the balloons as soon as there is ground underneath you again'
	})
	local materials = {'ForceField', WATER}
	for _, v in Enum.Material:GetEnumItems() do
		if v.Name ~= 'ForceField' then
			table.insert(materials, v.Name)
		end
	end
	Material = AntiFall:CreateDropdown({
		Name = 'Material',
		List = materials,
		Function = function()
			applyLook()
		end
	})
	Color = AntiFall:CreateColorSlider({
		Name = 'Colour',
		DefaultOpacity = 0.5,
		Function = function(h, s, v, o)
			if AntiFallPart then
				AntiFallPart.Color = Color3.fromHSV(h, s, v)
				if water then
					tintWater()
				else
					AntiFallPart.Transparency = 1 - o
				end
			end
		end
	})
end)
