run(function()
	local AutoLancer
	local Targets, Melee, Projectiles, LowHealth, Health, HealthRange, Notify
	local NAME = 'AutoLancer'
	local COOLDOWN = 6
	local FLAT = Vector3.new(1, 0, 1)
	local FACING = 0.5
	local LEAD = 0.6
	local incoming = {}

	local function reach(ent)
		local player = ent.Player
		local value = player and player:FindFirstChild('EquippedTool')
		local data = value and bedfight.SwordsData and bedfight.SwordsData[value.Value]
		if type(data) ~= 'table' then return nil end
		local size = typeof(data.HitboxSize) == 'Vector3' and data.HitboxSize.Z or 11
		return (data.Range or 5) + size / 2 + 3.25
	end

	local function meleeThreat(kit, root)
		for _, ent in kit.Targets(Targets, 20, 4) do
			local far = reach(ent)
			if far then
				local delta = root.Position - ent.RootPart.Position
				if delta.Magnitude <= far then
					local flat = delta * FLAT
					if flat.Magnitude < 2 or ent.RootPart.CFrame.LookVector:Dot(flat.Unit) >= FACING then
						return true
					end
				end
			end
		end
		return false
	end

	local function shotThreat(now)
		local hit = false
		for i = #incoming, 1, -1 do
			local shot = incoming[i]
			if now > shot.Arrive + 0.2 then
				table.remove(incoming, i)
			elseif shot.Arrive - now <= LEAD then
				hit = true
			end
		end
		return hit
	end

	AutoLancer = vape.Categories.Kits:CreateModule({
		Name = NAME,
		Category = 'Ability',
		Function = function(callback)
			table.clear(incoming)
			if not callback then return end
			local kit = store.kit
			if not kit then return end
			kit.Notify[NAME] = Notify
			local echo = kit.Remote('Shield')
			if echo then
				AutoLancer:Clean(echo.OnClientEvent:Connect(function(userId)
					if userId == lplr.UserId then kit.Confirm(NAME) end
				end))
			end
			local folder = replicatedStorage:FindFirstChild('Remotes')
			local shots = folder and folder:FindFirstChild('ReplicateProjectile')
			if shots then
				AutoLancer:Clean(shots.OnClientEvent:Connect(function(userId, _, name, origin, speed, unit)
					if not Projectiles.Enabled or userId == lplr.UserId or not entitylib.isAlive or kit.Value() ~= 'Lancer' then return end
					if typeof(origin) ~= 'Vector3' or typeof(unit) ~= 'Vector3' or type(speed) ~= 'number' then return end
					local data = bedfight.ProjectilesData and bedfight.ProjectilesData[name]
					if type(data) ~= 'table' then return end
					local shooter = playersService:GetPlayerByUserId(userId)
					if shooter and lplr.Team and shooter.Team == lplr.Team and lplr.Team.Name ~= 'Spectators' then return end
					local body = entitylib.character.RootPart.Position
					local velocity = unit * speed
					local across = velocity * FLAT
					if across.Magnitude < 1 then return end
					local t = ((body - origin) * FLAT):Dot(across) / across.Magnitude ^ 2
					if t <= 0 or t > math.min(data.LifeTime or 5, 4) then return end
					local gravity = typeof(data.Gravity) == 'Vector3' and data.Gravity or Vector3.zero
					local at = origin + velocity * t + gravity * (t * t / 2)
					local blast = data.BlastRadius or 0
					if (at - body).Magnitude > blast + 5 then return end
					if #incoming >= 16 then return end
					local late = math.min(lplr:GetNetworkPing(), 0.4)
					table.insert(incoming, {Arrive = tick() + t - late})
				end))
			end
			local nextAt = 0
			AutoLancer:Clean(runService.Heartbeat:Connect(function()
				local now = tick()
				if now < nextAt then return end
				nextAt = now + 0.05
				if kit.Value() ~= 'Lancer' or not kit.Ready(NAME, COOLDOWN) then return end
				local root = entitylib.character.RootPart
				local fire = Projectiles.Enabled and shotThreat(now)
				if not fire and Melee.Enabled then
					fire = meleeThreat(kit, root)
				end
				if not fire and LowHealth.Enabled and kit.Health() * 100 <= Health.Value then
					fire = kit.Targets(Targets, HealthRange.Value, 1)[1] ~= nil
				end
				if fire then
					kit.Fire(NAME, 'Shield', COOLDOWN, echo and 1 or nil)
				end
			end))
		end,
		Tooltip = 'Raises the Lancer shield when you are about to be hit'
	})
	Targets = AutoLancer:CreateTargets({Players = true, Walls = true})
	Melee = AutoLancer:CreateToggle({
		Name = 'Enemy in sword reach',
		Default = true,
		Tooltip = 'Shields when an enemy facing you can reach you with their sword'
	})
	Projectiles = AutoLancer:CreateToggle({
		Name = 'Incoming projectile',
		Default = true,
		Tooltip = 'Shields just before an enemy arrow or fireball reaches you'
	})
	LowHealth = AutoLancer:CreateGroup({
		Name = 'Low health',
		Default = true,
		Tooltip = 'Shields when your health is low and an enemy is close'
	})
	Health = LowHealth:CreateSlider({
		Name = 'Health',
		Min = 5,
		Max = 90,
		Default = 35,
		Suffix = '%',
		Tooltip = 'Health at or below which you shield'
	})
	HealthRange = LowHealth:CreateSlider({
		Name = 'Enemy range',
		Min = 4,
		Max = 30,
		Default = 15,
		Suffix = function(val) return val == 1 and 'stud' or 'studs' end,
		Tooltip = 'How close an enemy has to be'
	})
	Notify = AutoLancer:CreateToggle({
		Name = 'Notify',
		Tooltip = 'Shows a notification each time the ability is used'
	})
end)
