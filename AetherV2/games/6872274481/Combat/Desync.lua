run(function()
	local Desync
	local Range
	local root, char, clone, hip
	local retryAt, filterAt, idleSince = 0, 0, 0
	local hitSeen, hitAt = 0, 0
	local spot, spotTarget, spotAt, noSpotSince = nil, nil, 0, nil
	local spacing = 0.3
	local flat = Vector3.new(1, 0, 1)
	local up = Vector3.new(0, 2.5, 0)
	local stand = 17.99
	local angles = {0, 30, -30, 60, -60, 90, -90}
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.RespectCanCollide = true
	local boxParams = OverlapParams.new()
	boxParams.FilterType = Enum.RaycastFilterType.Exclude
	boxParams.RespectCanCollide = true
	boxParams.MaxParts = 1

	local function refreshFilter()
		local list = {lplr.Character, gameCamera}
		local drops = workspace:FindFirstChild('ItemDrops')
		if drops then
			table.insert(list, drops)
		end
		if root then
			table.insert(list, root)
		end
		for _, ent in entitylib.List do
			if ent.Character then
				table.insert(list, ent.Character)
			end
		end
		rayParams.FilterDescendantsInstances = list
		boxParams.FilterDescendantsInstances = list
	end

	local function ground(x, z, top)
		local hit = workspace:Raycast(Vector3.new(x, top, z), Vector3.new(0, -80, 0), rayParams)
		return hit and hit.Normal.Y > 0.65 and hit.Position.Y or nil
	end

	local function forget()
		if root and store.rootpart == root then
			store.rootpart = nil
		end
		root, char, clone = nil, nil, nil
		spot, spotTarget, noSpotSince = nil, nil, nil
		store.desyncLimit = nil
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
		idleSince = os.clock()
		hitSeen, hitAt = bedwars.SwordController.lastAttack, 0
		spot, spotTarget, noSpotSince = nil, nil, nil
		refreshFilter()
		filterAt = os.clock()
	end

	local function place(position)
		root.CFrame = CFrame.new(position) * clone.CFrame.Rotation
		root.AssemblyLinearVelocity = up
	end

	local function blocked()
		local hitbox = store.antiHitMain
		return vape.MovementOwner or store.lowHpHide or (hitbox and hitbox.Enabled)
	end

	local function swordSpacing()
		local sword = store.tools.sword
		local meta = sword and sword.tool and bedwars.ItemMeta[sword.tool.Name]
		return meta and meta.sword and meta.sword.attackSpeed or 0.3
	end

	local function target(body)
		local killaura = vape.Modules.Killaura
		if not (killaura and killaura.Enabled and store.attacking) then return end
		local ent = store.KillauraTarget
		local part = ent and ent.RootPart
		if not (part and part.Parent and ent.Health > 0 and ent.Character and ent.Character.Parent) then return end
		local distance = (part.Position - body).Magnitude
		if distance > Range.Value then return end
		local normal = store.attackLimit or 17.6
		if distance <= (root and normal - 1.5 or normal) then return end
		return ent
	end

	local function rotate(dir, degrees)
		local r = math.rad(degrees)
		return Vector3.new(dir.X * math.cos(r) - dir.Z * math.sin(r), 0, dir.X * math.sin(r) + dir.Z * math.cos(r))
	end

	local function pathClear(from, to)
		local lift = Vector3.new(0, 1.5, 0)
		return not workspace:Raycast(from + lift, to - from, rayParams)
	end

	local function search(ent, body, from)
		local tp = ent.RootPart.Position
		if (body - tp).Magnitude <= stand then
			return body
		end
		local away = (body - tp) * flat
		local dir = away.Magnitude > 0.1 and away.Unit or Vector3.new(1, 0, 0)
		local top = math.max(tp.Y, body.Y) + 3
		for _, degrees in angles do
			local d = rotate(dir, degrees)
			local radius = stand
			local point
			for _ = 1, 2 do
				local at = tp + d * radius
				local g = ground(at.X, at.Z, top)
				if not g then
					point = nil
					break
				end
				point = Vector3.new(at.X, g + hip, at.Z)
				local dy = point.Y - tp.Y
				if math.abs(dy) > 8 then
					point = nil
					break
				end
				radius = math.sqrt(math.max(stand * stand - dy * dy, 4))
			end
			if point then
				local gap = (point - tp).Magnitude
				if gap <= stand + 0.01 and gap >= stand - 1.5 then
					local free = #workspace:GetPartBoundsInBox(CFrame.new(point.X, point.Y - hip + 2.7, point.Z), Vector3.new(2.2, 4.8, 2.2), boxParams) == 0
					if free and pathClear(from, point) then
						return point
					end
				end
			end
		end
	end

	local function step()
		if not root then return end
		if not entitylib.isAlive or char ~= lplr.Character or not root.Parent or not clone or not clone.Parent then
			if clone and clone.Parent then
				clone:Destroy()
			end
			forget()
			return
		end
		if blocked() or not isnetworkowner(root) then
			merge()
			retryAt = os.clock() + 1
			return
		end
		local now = os.clock()
		if now - filterAt > 1 then
			filterAt = now
			refreshFilter()
			spacing = swordSpacing()
		end
		local last = bedwars.SwordController.lastAttack
		if last ~= hitSeen then
			hitSeen, hitAt = last, now
		end
		local body = clone.Position
		local ent = target(body)
		if not ent then
			store.desyncLimit = nil
			place(body)
			if now - idleSince > 0.5 then
				merge()
			end
			return
		end
		idleSince = now
		if spotTarget ~= ent or now - spotAt > 0.1 then
			spotTarget, spotAt = ent, now
			spot = search(ent, body, root.Position)
			if spot then
				noSpotSince = nil
			else
				noSpotSince = noSpotSince or now
			end
		end
		store.desyncLimit = spot and stand + 2.5 or nil
		if not spot then
			place(body)
			if noSpotSince and now - noSpotSince > 1 then
				merge()
				retryAt = now + 0.5
			end
			return
		end
		local ping = math.min(lplr:GetNetworkPing(), 0.2)
		local after = math.clamp(ping * 0.5 + 0.06, 0.08, 0.16)
		local lead = 0.17 + ping * 0.5
		local since = now - hitAt
		local nextHit = store.killauraNextHit
		local untilHit = nextHit and nextHit - tick() or spacing - since
		if since < after or untilHit <= lead then
			place(spot)
		else
			place(body)
		end
	end

	Desync = vape.Categories.Combat:CreateModule({
		Name = 'Desync',
		Tags = {'Experimental'},
		Function = function(callback)
			if callback then
				store.desyncRange = Range.Value
				Desync:Clean(runService.PreSimulation:Connect(step))
				repeat
					if not root and entitylib.isAlive and store.matchState == 1 and not blocked() and not store.rootpart and os.clock() >= retryAt and lplr.Character and lplr.Character.Parent and entitylib.character.Humanoid.Health > 0 then
						local body = entitylib.character.RootPart.Position
						refreshFilter()
						if target(body) and ground(body.X, body.Z, body.Y + 2) then
							spacing = swordSpacing()
							split()
						end
					elseif root and blocked() then
						merge()
					end
					task.wait(0.1)
				until not Desync.Enabled
			else
				store.desyncRange = nil
				merge()
			end
		end,
		Tooltip = 'Moves your hitbox toward targets Killaura cannot reach yet so it can hit them from further away'
	})
	Range = Desync:CreateSlider({
		Name = 'Range',
		Min = 19,
		Max = 26,
		Default = 26,
		Decimal = 10,
		Suffix = 'studs',
		Tooltip = 'How far away a target can be',
		Function = function(value)
			if Desync.Enabled then
				store.desyncRange = value
			end
		end
	})
	store.hitboxView.Add(Desync)
end)
