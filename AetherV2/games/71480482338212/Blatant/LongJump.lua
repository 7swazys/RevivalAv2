run(function()
	local LongJump
	local Value
	local Duration
	local Slope
	local VoidCheck
	local CameraDir
	local Steer
	local readyAt = 0
	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	local MAX_FALL = 30

	local function ground(point)
		return workspace:Raycast(point + Vector3.new(0, 3, 0), Vector3.new(0, -(MAX_FALL + 3), 0), rayCheck) ~= nil
	end

	local function plan(start, dir, flat, distance, void)
		local wall = workspace:Raycast(start, dir * (distance + 2), rayCheck)
		if wall then
			distance = math.max(wall.Distance - 2, 0)
		end
		if not void then
			return distance, wall ~= nil
		end
		local travelled = distance
		while travelled >= 4 do
			local point = start + dir * travelled
			if ground(point) and ground(point - flat * 2) then
				return travelled, wall ~= nil, travelled < distance - 0.5
			end
			travelled -= 2
		end
		return nil
	end

	local function heading()
		local look
		if CameraDir.Enabled then
			look = gameCamera.CFrame.LookVector
		else
			look = entitylib.character.Humanoid.MoveDirection
			if look.Magnitude < 0.05 then
				look = entitylib.character.RootPart.CFrame.LookVector
			end
		end
		look *= Vector3.new(1, 0, 1)
		if look.Magnitude < 0.01 then
			look = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
		end
		return look.Unit
	end

	LongJump = vape.Categories.Blatant:CreateModule({
		Name = 'LongJump',
		Function = function(callback)
			if callback then
				if tick() < readyAt then
					if not store.longJumpForce then
						notif('LongJump', string.format('Ready in %.1fs.', readyAt - tick()), 2)
					end
					store.longJumpForce = nil
					LongJump:Toggle()
					return
				end
				if not entitylib.isAlive then
					LongJump:Toggle()
					return
				end

				local forced = store.longJumpForce
				store.longJumpForce = nil
				local flat
				if forced then
					local look = forced.Dir * Vector3.new(1, 0, 1)
					flat = look.Magnitude > 0.01 and look.Unit or heading()
				else
					flat = heading()
				end
				local angle = math.rad(Slope.Value)
				local dir = flat * math.cos(angle) + Vector3.new(0, math.sin(angle), 0)
				local startPos = entitylib.character.RootPart.Position
				rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera, workspace:FindFirstChild('PlayersContainer')}

				local distance, walled, shortened = plan(startPos, dir, flat, Value.Value * Duration.Value, VoidCheck.Enabled or forced ~= nil)
				if not distance or distance < 1 then
					if forced then
						LongJump:Toggle()
						return
					end
					notif('LongJump', distance and 'A wall is in the way.' or 'Nothing to land on that way.', 3, 'warning')
					LongJump:Toggle()
					return
				end
				local reason = shortened and 'Stopped over the last ground' or walled and 'Stopped at a wall' or 'Ended'
				local travelled = 0
				store.dashOn = true

				LongJump:Clean(runService.PreSimulation:Connect(function(dt)
					if not entitylib.isAlive then
						LongJump:Toggle()
						return
					end
					local root = entitylib.character.RootPart
					if Steer.Enabled and not forced then
						local now = heading()
						if now:Dot(flat) < 0.9999 then
							flat = now
							dir = flat * math.cos(angle) + Vector3.new(0, math.sin(angle), 0)
						end
					end
					local length = math.min(Value.Value * dt, distance - travelled)
					if Steer.Enabled and not forced and VoidCheck.Enabled and not ground(root.Position + dir * (length + 2)) then
						reason = 'Stopped over the last ground'
						LongJump:Toggle()
						return
					end
					local step = dir * length
					if workspace:Raycast(root.Position, step + dir * 2, rayCheck) then
						reason = 'Hit a wall'
						LongJump:Toggle()
						return
					end
					travelled += length
					root.CFrame += step
					root.AssemblyLinearVelocity = Vector3.zero
					if travelled >= distance - 0.01 then
						LongJump:Toggle()
					end
				end))

				LongJump:Clean(function()
					store.dashOn = nil
					if entitylib.isAlive then
						local root = entitylib.character.RootPart
						root.AssemblyLinearVelocity = Vector3.zero
						local dist = ((root.Position - startPos) * Vector3.new(1, 0, 1)).Magnitude
						readyAt = tick() + math.clamp((dist / 50) ^ 2.5, 1, 3)
					end
					notif('LongJump', reason..'.', 2)
				end)
			end
		end,
		Tooltip = 'Dashes the way you face, then switches off'
	})
	Value = LongJump:CreateSlider({
		Name = 'Speed',
		Min = 20,
		Max = 300,
		Default = 300,
		Suffix = 'studs'
	})
	Duration = LongJump:CreateSlider({
		Name = 'Duration',
		Min = 0.1,
		Max = 2,
		Default = 0.2,
		Decimal = 100,
		Suffix = 's'
	})
	Slope = LongJump:CreateSlider({
		Name = 'Slope angle',
		Min = 0,
		Max = 10,
		Default = 5,
		Suffix = 'deg'
	})
	VoidCheck = LongJump:CreateToggle({
		Name = 'Void check',
		Tooltip = 'Only dashes as far as the last ground on the way'
	})
	CameraDir = LongJump:CreateToggle({
		Name = 'Camera Direction',
		Default = true,
		Tooltip = 'Dashes the way your camera faces instead of the way you walk'
	})
	Steer = LongJump:CreateToggle({
		Name = 'Change direction mid-air',
		Tooltip = 'Lets you turn while the dash is going'
	})
end)
