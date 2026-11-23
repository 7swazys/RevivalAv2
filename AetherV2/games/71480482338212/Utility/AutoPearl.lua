run(function()
	local AutoPearl
	local Search
	local Cooldown
	local Pearl
	local ShowLanding
	local Warn
	local marker
	local warned = false
	local nextThrow = 0
	local rayCheck = RaycastParams.new()
	rayCheck.FilterType = Enum.RaycastFilterType.Exclude
	rayCheck.RespectCanCollide = true
	local DIRECTIONS = {Vector3.xAxis, Vector3.zAxis, -Vector3.xAxis, -Vector3.zAxis, Vector3.new(0.7, 0, 0.7), Vector3.new(-0.7, 0, 0.7), Vector3.new(0.7, 0, -0.7), Vector3.new(-0.7, 0, -0.7)}

	local function filter()
		local list = {workspace:FindFirstChild('PlayersContainer') or lplr.Character, gameCamera}
		for _, name in {'ProjectilesContainer', 'FakeBlocksContainer', 'DroppedItemsContainer'} do
			local folder = workspace:FindFirstChild(name)
			if folder then table.insert(list, folder) end
		end
		rayCheck.FilterDescendantsInstances = list
	end

	local function groundNear(origin)
		for step = 3, Search.Value, 3 do
			for _, direction in DIRECTIONS do
				local hit = workspace:Raycast(origin + direction * step + Vector3.new(0, 3, 0), Vector3.new(0, -80, 0), rayCheck)
				if hit and hit.Instance.Transparency < 1 then
					return hit.Position + Vector3.new(0, 0.5, 0)
				end
			end
		end
	end

	local function mark(spot)
		if not (ShowLanding.Enabled and spot) then
			if marker then marker.Box.Visible = false end
			return
		end
		if not marker then
			local part = Instance.new('Part')
			part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
			part.Transparency = 1
			part.Size = Vector3.new(3, 0.2, 3)
			part.Parent = gameCamera
			local box = Instance.new('BoxHandleAdornment')
			box.Size = part.Size
			box.AlwaysOnTop = true
			box.ZIndex = 1
			box.Transparency = 0.4
			box.Color3 = Color3.fromRGB(90, 220, 110)
			box.Adornee = part
			box.Parent = part
			marker = {Part = part, Box = box}
		end
		if marker.Part.Position ~= spot then marker.Part.Position = spot end
		if not marker.Box.Visible then marker.Box.Visible = true end
	end

	local function lost(reason)
		if Warn.Enabled and not warned then
			warned = true
			notif('AutoPearl', 'Cannot clutch: '..reason, 3, 'warning')
		end
	end

	AutoPearl = vape.Categories.Utility:CreateModule({
		Name = 'AutoPearl',
		Function = function(callback)
			if callback then
				local lastGround
				repeat
					local spot
					if entitylib.isAlive and not store.flyOn and store.throwTeleorb then
						local root = bodyRoot()
						if entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air then
							lastGround = root.Position
							warned = false
						elseif store.inVoid(root, 0.7) then
							if (store.inventory.Teleorb or 0) <= 0 then
								lost('no teleorb')
							elseif not Pearl.Blocked() then
								filter()
								spot = groundNear(root.Position + Vector3.new(0, 30, 0)) or (lastGround and groundNear(lastGround + Vector3.new(0, 5, 0)))
								if not spot then
									lost('no ground in range')
								elseif tick() >= nextThrow and store.throwTeleorb(spot, 'AutoPearl', Pearl.Options()) then
									nextThrow = tick() + Cooldown.Value
								end
							end
						end
					end
					mark(spot)
					task.wait(0.05)
				until not AutoPearl.Enabled
				mark(nil)
			elseif marker then
				marker.Part:Destroy()
				marker = nil
			end
		end,
		Tooltip = 'Throws a teleorb onto nearby ground when falling into the void'
	})
	Search = AutoPearl:CreateSlider({
		Name = 'Search range',
		Min = 6,
		Max = 90,
		Default = 45,
		Suffix = function(val) return val == 1 and 'stud' or 'studs' end,
		Tooltip = 'How far it looks for ground to land on'
	})
	Cooldown = AutoPearl:CreateSlider({
		Name = 'Cooldown',
		Min = 0.5,
		Max = 10,
		Default = 2,
		Decimal = 10,
		Suffix = 's'
	})
	Pearl = store.pearlOptions(AutoPearl)
	ShowLanding = AutoPearl:CreateToggle({
		Name = 'Show landing',
		Tooltip = 'Marks the ground it will throw to'
	})
	Warn = AutoPearl:CreateToggle({
		Name = 'Warn when lost',
		Tooltip = 'Tells you when a fall cannot be saved'
	})
end)
