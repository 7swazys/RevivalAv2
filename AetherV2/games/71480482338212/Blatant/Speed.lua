run(function()
	local Speed
	local Mode
	local Value
	local AutoJump
	local AlwaysJump
	local WallCheck
	local rayCheck = RaycastParams.new()
	local filterFor
	rayCheck.RespectCanCollide = true

	Speed = vape.Categories.Blatant:CreateModule({
		Name = 'Speed',
		Function = function(callback)
			if callback then
				Speed:Clean(runService.PreSimulation:Connect(function(dt)
					if not entitylib.isAlive or store.flyOn or store.dashOn then return end
					local hum, root = entitylib.character.Humanoid, entitylib.character.RootPart
					local dir = hum.MoveDirection
					if dir.Magnitude < 0.05 or hum:GetState() == Enum.HumanoidStateType.Climbing then return end

					if Mode.Value == 'CFrame' then
						local extra = dir * math.max(Value.Value - hum.WalkSpeed, 0) * dt
						if filterFor ~= lplr.Character then
							filterFor = lplr.Character
							rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
						end
						if not WallCheck.Enabled or not workspace:Raycast(root.Position, extra + dir * 1.5, rayCheck) then
							root.CFrame += extra
						end
					else
						root.AssemblyLinearVelocity = Vector3.new(dir.X * Value.Value, root.AssemblyLinearVelocity.Y, dir.Z * Value.Value)
					end

					if AutoJump.Enabled and hum.FloorMaterial ~= Enum.Material.Air and (AlwaysJump.Enabled or tick() - (store.melee or 0) < 0.5) then
						hum:ChangeState(Enum.HumanoidStateType.Jumping)
					end
				end))
			end
		end,
		ExtraText = function()
			return Mode.Value
		end,
		Tooltip = 'Increases your movement speed'
	})
	Mode = Speed:CreateDropdown({
		Name = 'Mode',
		List = {'Velocity', 'CFrame'},
		Tooltip = 'How your speed is raised'
	})
	Value = Speed:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 30,
		Default = 24,
		Suffix = 'studs',
		Tooltip = 'How fast you move'
	})
	WallCheck = Speed:CreateToggle({
		Name = 'Wall Check',
		Default = true,
		Visible = function() return Mode.Value == 'CFrame' end,
		Tooltip = 'Stops the extra speed from pushing you into walls'
	})
	AutoJump = Speed:CreateGroup({Name = 'AutoJump'})
	AlwaysJump = AutoJump:CreateToggle({
		Name = 'Always Jump',
		Default = true,
		Tooltip = 'Jumps all the time instead of only while you fight'
	})
end)
