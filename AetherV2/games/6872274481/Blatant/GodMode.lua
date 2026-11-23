run(function()
	local GodMode
	local Clear
	local Height
	local Strike
	local EnemyReach
	local HitEnemies
	local Range
	local Nearby
	local root, char, clone, hip
	local phase, since, returning
	local retryAt = 0
	local filterAt = 0
	local hitSeen, hitAt = 0, 0
	local threats = {}
	local flat = Vector3.new(1, 0, 1)
	local up = Vector3.new(0, 2.5, 0)
	local HOLD, MAXHOLD, REST, LEASH = 1.7, 2.2, 0.13, 30
	local LEAD, AFTER, MAXDROP = 0.16, 0.08, 12
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.RespectCanCollide = true

	local function refreshFilter()
		local list = {lplr.Character, gameCamera}
		if root then
			table.insert(list, root)
		end
		for _, ent in entitylib.List do
			if ent.Character then
				table.insert(list, ent.Character)
			end
		end
		rayParams.FilterDescendantsInstances = list
	end

	local function ground(x, z, top)
		local hit = workspace:Raycast(Vector3.new(x, top, z), Vector3.new(0, -300, 0), rayParams)
		return hit and hit.Normal.Y > 0.65 and hit.Position.Y or nil
	end

	local function forget()
		if root and store.rootpart == root then
			store.rootpart = nil
		end
		root, char, clone, returning = nil, nil, nil, nil
	end

	local function merge()
		if root and root.Parent and char and char.Parent and char == lplr.Character then
			local velocity = clone and clone.AssemblyLinearVelocity or Vector3.zero
			char.Parent = replicatedStorage
			root.Parent = char
			if clone then
				root.CFrame = clone.CFrame
				clone:Destroy()
			end
			char.PrimaryPart = root
			char.Parent = workspace
			root.CanCollide = true
			local humanoid = char:FindFirstChildOfClass('Humanoid')
			if humanoid and hip then
				humanoid.HipHeight = hip
			end
			root.AssemblyLinearVelocity = velocity
		elseif clone then
			clone:Destroy()
		end
		forget()
	end

	local function split()
		char = lplr.Character
		root = entitylib.character.HumanoidRootPart
		hip = entitylib.character.Humanoid.HipHeight
		char.Parent = replicatedStorage
		clone = root:Clone()
		clone.Parent = char
		root.Transparency = 1
		root.Parent = workspace
		clone.AssemblyLinearVelocity = root.AssemblyLinearVelocity
		store.rootpart = root
		char.PrimaryPart = clone
		char.Parent = workspace
		if bedwars.QueryUtil then
			bedwars.QueryUtil:setQueryIgnored(clone, true)
			bedwars.QueryUtil:setQueryIgnored(root, true)
		end
		phase, since, returning = 'up', os.clock(), nil
		refreshFilter()
		filterAt = os.clock()
	end

	local function scan(origin, range, skip)
		table.clear(threats)
		local lead = math.min(lplr:GetNetworkPing(), 0.3) + 0.1
		for _, ent in entitylib.List do
			local part = ent ~= skip and ent.Targetable and ent.Health > 0 and ent.RootPart
			if part then
				local pos = part.Position
				if (pos - origin).Magnitude <= range then
					local v = part.AssemblyLinearVelocity
					table.insert(threats, pos)
					table.insert(threats, pos + Vector3.new(v.X, math.max(v.Y, 0), v.Z) * lead)
				end
			end
		end
	end

	local function nearest(point)
		local best = math.huge
		for _, t in threats do
			local d = (t - point).Magnitude
			if d < best then
				best = d
			end
		end
		return best
	end

	local function place(position)
		root.CFrame = CFrame.new(position) * clone.CFrame.Rotation
		root.AssemblyLinearVelocity = up
	end

	local function combatTarget()
		if not HitEnemies.Enabled then return end
		local killaura = vape.Modules.Killaura
		local target = killaura and killaura.Enabled and store.attacking and store.KillauraTarget
		if target and target.RootPart and target.Health > 0 and target.Character and target.Character.Parent then
			return target
		end
	end

	local function swordSpacing()
		local sword = store.tools.sword
		local meta = sword and sword.tool and bedwars.ItemMeta[sword.tool.Name]
		return meta and meta.sword and meta.sword.attackSpeed or 0.3
	end

	local function walkStep(at, goal, speed)
		local flatAt = Vector3.new(at.X, 0, at.Z)
		local d = Vector3.new(goal.X, 0, goal.Z) - flatAt
		if d.Magnitude > 0.05 then
			local move = d.Unit * math.min(speed, d.Magnitude)
			return at.X + move.X, at.Z + move.Z
		end
		return at.X, at.Z
	end

	local function hover(nx, nz, floor, clearRange)
		local y = floor + Height.Value
		for _, t in threats do
			local dxz = ((t - Vector3.new(nx, 0, nz)) * flat).Magnitude
			if dxz < clearRange then
				y = math.max(y, t.Y + math.sqrt(clearRange * clearRange - dxz * dxz))
			end
		end
		y = math.min(y, floor + MAXDROP)
		local roof = workspace:Raycast(Vector3.new(nx, floor, nz), Vector3.new(0, y - floor + 3, 0), rayParams)
		if roof then
			y = math.max(math.min(y, roof.Position.Y - 3), floor)
		end
		return y
	end

	local function step(dt)
		if not root then return end
		if not entitylib.isAlive or char ~= lplr.Character or not root.Parent or not clone or not clone.Parent then
			if clone and clone.Parent then
				clone:Destroy()
			end
			forget()
			return
		end
		if vape.MovementOwner or store.lowHpHide or not isnetworkowner(root) then
			merge()
			retryAt = os.clock() + 1
			return
		end
		local now = os.clock()
		if now - filterAt > 1 then
			filterAt = now
			refreshFilter()
		end
		local h = entitylib.character.HipHeight
		local body = clone.Position
		local at = root.Position
		local speed = getSpeed() * math.max(dt, 1 / 240)

		if returning then
			local d = (body - at) * flat
			if d.Magnitude <= 3 or now - returning > 2.5 then
				merge()
				return
			end
			local nxt = at + d.Unit * math.min(speed, d.Magnitude)
			local g = ground(nxt.X, nxt.Z, math.max(at.Y, body.Y) + 3)
			if not g then
				merge()
				return
			end
			place(Vector3.new(nxt.X, g + h, nxt.Z))
			return
		end

		local clearRange = Clear.Value
		local reach = EnemyReach.Value
		local strike = math.max(Strike.Value, reach + 0.5)
		local target = combatTarget()
		local due = phase == 'up' and now - since >= HOLD

		local goal
		if target then
			local tp = target.RootPart.Position
			local fromTarget = (at - tp) * flat
			if fromTarget.Magnitude < 0.1 then
				fromTarget = (body - tp) * flat
			end
			local dir = fromTarget.Magnitude > 0.1 and fromTarget.Unit or Vector3.new(1, 0, 0)
			goal = tp + dir * ((reach + strike) / 2)
		else
			goal = body
			local away = Vector3.zero
			scan(body, Range.Value + 30)
			for _, t in threats do
				local d = (at - t) * flat
				local m = d.Magnitude
				if m < clearRange + 8 then
					away += (m > 0.1 and d.Unit or Vector3.new(1, 0, 0)) * (clearRange + 8 - m)
				end
			end
			local flatAt = Vector3.new(at.X, 0, at.Z)
			local flatBody = Vector3.new(body.X, 0, body.Z)
			if away.Magnitude > 0.1 then
				goal = flatAt + away.Unit * 50
			elseif (flatAt - flatBody).Magnitude > LEASH then
				goal = flatBody + (flatAt - flatBody).Unit * LEASH
			end
		end

		local nx, nz = walkStep(at, goal, speed)
		local g = ground(nx, nz, math.max(at.Y, body.Y) + 2)
		if not g then
			nx, nz = at.X, at.Z
			g = ground(nx, nz, math.max(at.Y, body.Y) + 2)
			if not g then
				merge()
				retryAt = now + 1
				return
			end
		end
		local floor = g + h
		local spot = Vector3.new(nx, floor, nz)

		if target then
			scan(body, Range.Value + 30, target)
		end

		if phase == 'down' then
			place(spot)
			if now - since >= REST then
				phase, since = 'up', now
			end
			return
		end

		if due then
			local safe = nearest(spot) >= (target and reach + 0.5 or clearRange)
			if safe and target then
				safe = (target.RootPart.Position - spot).Magnitude >= reach + 0.5
			end
			if safe or now - since >= MAXHOLD then
				phase, since = 'down', now
				place(spot)
				return
			end
		end

		if target then
			local last = bedwars.SwordController.lastAttack
			if last ~= hitSeen then
				hitSeen, hitAt = last, now
			end
			local tp = target.RootPart.Position
			local dxz = ((spot - tp) * flat).Magnitude
			local window = now - hitAt < AFTER or now - hitAt >= swordSpacing() - LEAD
			if window and dxz <= strike - 0.3 then
				local want = strike - 0.5
				local y = math.clamp(tp.Y + math.sqrt(math.max(want * want - dxz * dxz, 0)), floor, floor + MAXDROP)
				local point = Vector3.new(nx, y, nz)
				if (point - tp).Magnitude <= strike and nearest(point) >= reach + 0.5 then
					local roof = workspace:Raycast(spot, Vector3.new(0, y - floor + 3, 0), rayParams)
					if not roof or roof.Position.Y - 3 >= y then
						place(point)
						return
					end
				end
			end
			table.insert(threats, tp)
		end

		place(Vector3.new(nx, hover(nx, nz, floor, clearRange), nz))
	end

	local Host
	GodMode, Host = store.antiHitMode('GodMode', {
		Function = function(callback)
			if callback then
				hitSeen, hitAt = bedwars.SwordController.lastAttack, 0
				GodMode:Clean(runService.PreSimulation:Connect(step))
				repeat
					if not root and entitylib.isAlive and store.matchState == 1 and not vape.MovementOwner and not store.lowHpHide and not store.rootpart and os.clock() >= retryAt and lplr.Character and lplr.Character.Parent and entitylib.character.Humanoid.Health > 0 then
						local body = entitylib.character.RootPart.Position
						local want = not Nearby.Enabled
						if not want then
							scan(body, Range.Value)
							want = #threats > 0
						end
						if want then
							refreshFilter()
							if ground(body.X, body.Z, body.Y + 2) then
								split()
							end
						end
					elseif root and not returning and Nearby.Enabled then
						scan(clone and clone.Position or root.Position, Range.Value + 10)
						if #threats == 0 then
							returning = os.clock()
						end
					end
					task.wait(0.1)
				until not GodMode.Enabled
			else
				merge()
			end
		end,
		Tooltip = 'GodMode'
	})
	local function shown()
		return Host.Mode.Value == 'GodMode'
	end
	HitEnemies = GodMode:CreateToggle({
		Name = 'Hit enemies',
		Default = true,
		Visible = shown,
		Tooltip = 'Lets Killaura hit by moving your hitbox into your reach just before each hit'
	})
	Strike = GodMode:CreateSlider({
		Name = 'Strike distance',
		Min = 15,
		Max = 18,
		Default = 17,
		Decimal = 10,
		Suffix = 'studs',
		Visible = shown,
		Tooltip = 'How far from the target your hitbox goes to hit, keep it inside your Killaura attack range'
	})
	EnemyReach = GodMode:CreateSlider({
		Name = 'Enemy reach',
		Min = 13,
		Max = 18,
		Default = 15.5,
		Decimal = 10,
		Suffix = 'studs',
		Visible = shown,
		Tooltip = 'Your hitbox never comes closer than this to an enemy'
	})
	Clear = GodMode:CreateSlider({
		Name = 'Safe distance',
		Min = 20,
		Max = 40,
		Default = 24,
		Suffix = 'studs',
		Visible = shown,
		Tooltip = 'How far your hitbox stays from every enemy between hits'
	})
	Height = GodMode:CreateSlider({
		Name = 'Hitbox height',
		Min = 2,
		Max = 12,
		Default = 10,
		Suffix = 'studs',
		Visible = shown,
		Tooltip = 'How high your hitbox waits above the ground'
	})
	Nearby = GodMode:CreateToggle({
		Name = 'Only when enemy nearby',
		Default = true,
		Visible = shown,
		Tooltip = 'Only hides your hitbox while an enemy is close'
	})
	Range = GodMode:CreateSlider({
		Name = 'Activation range',
		Min = 20,
		Max = 80,
		Default = 40,
		Suffix = 'studs',
		Visible = shown,
		Tooltip = 'How close an enemy has to be before it starts'
	})
end)
