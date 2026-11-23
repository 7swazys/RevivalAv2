run(function()
	local NoFallDamage
	local Trigger
	local Lethal
	local Notify
	local Clutch
	local FREE = 18
	local filterFor
	local rayCheck = RaycastParams.new()
	rayCheck.FilterType = Enum.RaycastFilterType.Exclude
	rayCheck.RespectCanCollide = true

	NoFallDamage = vape.Categories.Blatant:CreateModule({
		Name = 'NoFallDamage',
		Function = function(callback)
			if not callback then return end
			local peak, tried, told = nil, 0, false
			NoFallDamage:Clean(runService.Heartbeat:Connect(function()
				if not entitylib.isAlive or store.flyOn or store.dashOn or store.split then
					peak = nil
					return
				end
				local hum, root = entitylib.character.Humanoid, entitylib.character.RootPart
				local y = root.Position.Y
				if hum.FloorMaterial ~= Enum.Material.Air then
					peak = y
					return
				end
				peak = math.max(peak or y, y)
				local fallen = peak - y
				if fallen < Trigger.Value or root.AssemblyLinearVelocity.Y > -10 or tick() - tried < 0.15 then return end
				local players = workspace:FindFirstChild('PlayersContainer') or lplr.Character
				if filterFor ~= players then
					filterFor = players
					rayCheck.FilterDescendantsInstances = {players, gameCamera}
				end
				local hit = workspace:Raycast(root.Position, Vector3.new(0, -400, 0), rayCheck)
				if not hit then return end
				local height = entitylib.character.HipHeight + root.Size.Y / 2
				local drop = peak - (hit.Position.Y + height)
				if drop <= FREE then return end
				if Lethal.Enabled and (drop - 20) * 2 < entitylib.character.Humanoid.Health then return end
				if root.Position.Y - height - hit.Position.Y < 1.5 then return end
				tried = tick()
				local placed, why = false, 'none'
				if Clutch:Has('Blocks') then
					placed, why = store.catchBlock('NoFallDamage')
				end
				if not placed and Clutch:Has('Teleorb') and (store.inventory.Teleorb or 0) > 0 and store.throwTeleorb and not store.orbsInAir() then
					placed = store.throwTeleorb(hit.Position + Vector3.new(0, 0.5, 0), 'NoFallDamage')
				end
				if not placed and Clutch:Has('Balloon') and (store.inventory.Balloon or 0) > 0 then
					local amount = lplr:FindFirstChild('BalloonsAmount')
					if not amount or amount.Value < 3 then
						equipServer('Balloon', 'NoFallDamage')
						fireRemote('DeployBalloon', 'Balloon')
						placed = true
					end
				end
				if placed then
					told = false
				elseif why == 'none' and not told and Notify.Enabled then
					told = true
					notif('NoFallDamage', 'You have nothing to clutch with.', 3, 'warning')
				end
				task.delay(0.3, function()
					if tick() - tried >= 0.3 then
						syncTool('NoFallDamage')
					end
				end)
			end))
		end,
		Tooltip = 'Prevents fall damage by placing a block under you'
	})
	Trigger = NoFallDamage:CreateSlider({
		Name = 'Catch after',
		Min = 4,
		Max = 16,
		Default = 12,
		Suffix = 'studs',
		Tooltip = 'How far you fall before a block is placed under you'
	})
	Lethal = NoFallDamage:CreateToggle({
		Name = 'Only lethal falls',
		Tooltip = 'Only catches a fall that would kill you'
	})
	Notify = NoFallDamage:CreateToggle({
		Name = 'Notify',
		Default = true
	})
	Clutch = NoFallDamage:CreateMultiDropdown({
		Name = 'Clutch with',
		List = {'Blocks', 'Teleorb', 'Balloon'},
		Default = {'Blocks'},
		Tooltip = 'What it uses to save you from a fall, tried in this order'
	})
end)
