run(function()
	local Entity = entitylib
	local LocalPlayer = lplr
	local Camera = gameCamera
	local RunService = runService
	local UserInputService = inputService
	local FrictionTable = frictionTable
	local UpdateVelocity = updateVelocity
	local CalculateMoveVector = calculateMoveVector
	local Options = {TPTiming = tick()}
	local Mode
	local FloatMode
	local State
	local MoveMethod
	local Keys
	local VerticalValue
	local BounceLength
	local BounceDelay
	local FloatTPGround
	local FloatTPAir
	local CustomProperties
	local WallCheck
	local PlatformStanding
	local Platform, YLevel, OldYLevel
	local W, S, A, D, Up, Down = 0, 0, 0, 0, 0, 0
	local RayCheck: RaycastParams = RaycastParams.new()
	RayCheck.RespectCanCollide = true
	Options.rayCheck = RayCheck

	local Functions
	Functions = {
		Velocity = function()
			Entity.character.RootPart.AssemblyLinearVelocity = (Entity.character.RootPart.AssemblyLinearVelocity * Vector3.new(1, 0, 1)) + Vector3.new(0, 2.25 + ((Up + Down) * VerticalValue.Value), 0)
		end,
		Impulse = function(MethodOptions, MoveDirection: Vector3)
			local Root: BasePart = Entity.character.RootPart
			local Difference: Vector3 = (Vector3.new(0, 2.25 + ((Up + Down) * VerticalValue.Value), 0) - Root.AssemblyLinearVelocity) * Vector3.new(0, 1, 0)
			if Difference.Magnitude > 2 then
				Root:ApplyImpulse(Difference * Root.AssemblyMass)
			end
		end,
		CFrame = function(Delta: number)
			local Root: BasePart = Entity.character.RootPart
			if not YLevel then
				YLevel = Root.Position.Y
			end
			YLevel = YLevel + ((Up + Down) * VerticalValue.Value * Delta)
			if WallCheck.Enabled then
				RayCheck.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
				RayCheck.CollisionGroup = Root.CollisionGroup
				local Ray: RaycastResult? = workspace:Raycast(Root.Position, Vector3.new(0, YLevel - Root.Position.Y, 0), RayCheck)
				if Ray then
					YLevel = Ray.Position.Y + Entity.character.HipHeight
				end
			end
			Root.AssemblyLinearVelocity *= Vector3.new(1, 0, 1)
			Root.CFrame += Vector3.new(0, YLevel - Root.Position.Y, 0)
		end,
		Bounce = function()
			Functions.Velocity()
			Entity.character.RootPart.AssemblyLinearVelocity += Vector3.new(0, ((tick() % BounceDelay.Value) / BounceDelay.Value > 0.5 and 1 or -1) * BounceLength.Value, 0)
		end,
		Floor = function()
			Platform.CFrame = Down ~= 0 and CFrame.identity or Entity.character.RootPart.CFrame + Vector3.new(0, -(Entity.character.HipHeight + 0.5), 0)
		end,
		TP = function(Delta: number)
			Functions.CFrame(Delta)
			if tick() % (FloatTPAir.Value + FloatTPGround.Value) > FloatTPAir.Value then
				OldYLevel = OldYLevel or YLevel
				RayCheck.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
				RayCheck.CollisionGroup = Entity.character.RootPart.CollisionGroup
				local Ray: RaycastResult? = workspace:Raycast(Entity.character.RootPart.Position, Vector3.new(0, -1000, 0), RayCheck)
				if Ray then
					YLevel = Ray.Position.Y + Entity.character.HipHeight
				end
			else
				if OldYLevel then
					YLevel = OldYLevel
					OldYLevel = nil
				end
			end
		end,
		Jump = function(Delta: number)
			local Root: BasePart = Entity.character.RootPart
			if not YLevel then
				YLevel = Root.Position.Y
			end
			YLevel = YLevel + ((Up + Down) * VerticalValue.Value * Delta)
			if Root.Position.Y < YLevel then
				Entity.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			end
		end
	}

	Fly = vape.Categories.Blatant:CreateModule({
		Name = "Fly",
		Function = function(Callback: boolean)
			if Platform then
				Platform.Parent = Callback and Camera or nil
			end

			FrictionTable.Fly = Callback and CustomProperties.Enabled or nil
			UpdateVelocity()
			if Callback then
				Fly:Clean(RunService.PreSimulation:Connect(function(Delta: number)
					if Entity.isAlive then
						if PlatformStanding.Enabled then
							Entity.character.Humanoid.PlatformStand = true
							Entity.character.RootPart.RotVelocity = Vector3.zero
							Entity.character.RootPart.CFrame = CFrame.lookAlong(Entity.character.RootPart.CFrame.Position, Camera.CFrame.LookVector)
						end

						if State.Value ~= "None" then
							Entity.character.Humanoid:ChangeState(Enum.HumanoidStateType[State.Value])
						end

						SpeedMethods[Mode.Value](Options, TargetStrafeVector or MoveMethod.Value == "Direct" and CalculateMoveVector(Vector3.new(A + D, 0, W + S)) or Entity.character.Humanoid.MoveDirection, Delta)
						Functions[FloatMode.Value](Delta)
					else
						YLevel = nil
						OldYLevel = nil
					end
				end))

				W, S, A, D = UserInputService:IsKeyDown(Enum.KeyCode.W) and -1 or 0, UserInputService:IsKeyDown(Enum.KeyCode.S) and 1 or 0, UserInputService:IsKeyDown(Enum.KeyCode.A) and -1 or 0, UserInputService:IsKeyDown(Enum.KeyCode.D) and 1 or 0
				Up, Down = 0, 0
				for _, v: string in {"InputBegan", "InputEnded"} do
					Fly:Clean(UserInputService[v]:Connect(function(Input: InputObject)
						if not UserInputService:GetFocusedTextBox() then
							local Divided: {string} = Keys.Value:split("/")
							if Input.KeyCode == Enum.KeyCode.W then
								W = v == "InputBegan" and -1 or 0
							elseif Input.KeyCode == Enum.KeyCode.S then
								S = v == "InputBegan" and 1 or 0
							elseif Input.KeyCode == Enum.KeyCode.A then
								A = v == "InputBegan" and -1 or 0
							elseif Input.KeyCode == Enum.KeyCode.D then
								D = v == "InputBegan" and 1 or 0
							elseif Input.KeyCode == Enum.KeyCode[Divided[1]] then
								Up = v == "InputBegan" and 1 or 0
							elseif Input.KeyCode == Enum.KeyCode[Divided[2]] then
								Down = v == "InputBegan" and -1 or 0
							end
						end
					end))
				end

				if UserInputService.TouchEnabled then
					pcall(function()
						local JumpButton: ImageButton = LocalPlayer.PlayerGui.TouchGui.TouchControlFrame.JumpButton
						Fly:Clean(JumpButton:GetPropertyChangedSignal("ImageRectOffset"):Connect(function()
							Up = JumpButton.ImageRectOffset.X == 146 and 1 or 0
						end))
					end)
				end
			else
				YLevel, OldYLevel = nil, nil
				if Entity.isAlive then
					if PlatformStanding.Enabled then
						Entity.character.Humanoid.PlatformStand = false
					end

					if Options.WalkSpeed then
						Entity.character.Humanoid.WalkSpeed = Options.WalkSpeed
					end
				end

				Options.WalkSpeed = nil
			end
		end,
		ExtraText = function()
			return Mode.Value
		end,
		Tooltip = "Lets you fly"
	})

	Mode = Fly:CreateDropdown({
		Name = "Speed Mode",
		List = SpeedMethodList,
		Function = function(Val: string)
			WallCheck.Object.Visible = FloatMode.Value == "CFrame" or FloatMode.Value == "TP" or Val == "CFrame" or Val == "TP"
			Options.TPFrequency.Object.Visible = Val == "TP"
			Options.PulseLength.Object.Visible = Val == "Pulse"
			Options.PulseDelay.Object.Visible = Val == "Pulse"
			if Fly.Enabled then
				Fly:Toggle()
				Fly:Toggle()
			end
		end,
		Tooltip = "Velocity - smooth physics movement\nImpulse - like Velocity, using forces\nCFrame - moves your character directly\nTP - teleports in steps\nPulse - bursts of speed\nWalkSpeed - classic speed, detected in most games"
	})
	FloatMode = Fly:CreateDropdown({
		Name = "Float Mode",
		List = {"Velocity", "Impulse", "CFrame", "Bounce", "Floor", "Jump", "TP"},
		Function = function(Val: string)
			WallCheck.Object.Visible = Mode.Value == "CFrame" or Mode.Value == "TP" or Val == "CFrame" or Val == "TP"
			BounceLength.Object.Visible = Val == "Bounce"
			BounceDelay.Object.Visible = Val == "Bounce"
			VerticalValue.Object.Visible = Val ~= "Floor"
			FloatTPGround.Object.Visible = Val == "TP"
			FloatTPAir.Object.Visible = Val == "TP"

			if Platform then
				Platform:Destroy()
				Platform = nil
			end

			if Val == "Floor" then
				Platform = Instance.new("Part")
				Platform.CanQuery = false
				Platform.Anchored = true
				Platform.Size = Vector3.one
				Platform.Transparency = 1
				Platform.Parent = Fly.Enabled and Camera or nil
			end
		end,
		Tooltip = "Velocity - smooth physics movement\nImpulse - like Velocity, using forces\nCFrame - moves your character directly\nTP - teleports you down in steps\nFloor - puts a part under you\nJump - jumps when you drop below a height\nBounce - bounces you up and down"
	})
	local States: {string} = {"None"}
	for _, v: EnumItem in Enum.HumanoidStateType:GetEnumItems() do
		if v.Name ~= "Dead" and v.Name ~= "None" then
			table.insert(States, v.Name)
		end
	end
	State = Fly:CreateDropdown({
		Name = "Humanoid State",
		List = States
	})
	MoveMethod = Fly:CreateDropdown({
		Name = "Move Mode",
		List = {"MoveDirection", "Direct"},
		Tooltip = "MoveDirection - Uses the games input vector for movement\nDirect - Directly calculate our own input vector"
	})
	Keys = Fly:CreateDropdown({
		Name = "Keys",
		List = {"Space/LeftControl", "Space/LeftShift", "E/Q", "Space/Q", "ButtonA/ButtonL2"},
		Tooltip = "The key combination for going up & down"
	})
	Options.Value = Fly:CreateSlider({
		Name = "Speed",
		Min = 1,
		Max = 150,
		Default = 50,
		Suffix = function(Val: number)
			return Val == 1 and "stud" or "studs"
		end
	})
	VerticalValue = Fly:CreateSlider({
		Name = "Vertical Speed",
		Min = 1,
		Max = 150,
		Default = 50,
		Suffix = function(Val: number)
			return Val == 1 and "stud" or "studs"
		end
	})
	Options.TPFrequency = Fly:CreateSlider({
		Name = "TP Frequency",
		Min = 0,
		Max = 1,
		Decimal = 100,
		Darker = true,
		Visible = false,
		Suffix = function(Val: number)
			return Val == 1 and "second" or "seconds"
		end
	})
	Options.PulseLength = Fly:CreateSlider({
		Name = "Pulse Length",
		Min = 0,
		Max = 1,
		Decimal = 100,
		Darker = true,
		Visible = false,
		Suffix = function(Val: number)
			return Val == 1 and "second" or "seconds"
		end
	})
	Options.PulseDelay = Fly:CreateSlider({
		Name = "Pulse Delay",
		Min = 0,
		Max = 1,
		Decimal = 100,
		Darker = true,
		Visible = false,
		Suffix = function(Val: number)
			return Val == 1 and "second" or "seconds"
		end
	})
	BounceLength = Fly:CreateSlider({
		Name = "Bounce Length",
		Min = 0,
		Max = 30,
		Darker = true,
		Visible = false,
		Suffix = function(Val: number)
			return Val == 1 and "stud" or "studs"
		end
	})
	BounceDelay = Fly:CreateSlider({
		Name = "Bounce Delay",
		Min = 0,
		Max = 1,
		Decimal = 100,
		Darker = true,
		Visible = false,
		Suffix = function(Val: number)
			return Val == 1 and "second" or "seconds"
		end
	})
	FloatTPGround = Fly:CreateSlider({
		Name = "Ground",
		Min = 0,
		Max = 1,
		Decimal = 10,
		Default = 0.1,
		Darker = true,
		Visible = false,
		Suffix = function(Val: number)
			return Val == 1 and "second" or "seconds"
		end
	})
	FloatTPAir = Fly:CreateSlider({
		Name = "Air",
		Min = 0,
		Max = 5,
		Decimal = 10,
		Default = 2,
		Darker = true,
		Visible = false,
		Suffix = function(Val: number)
			return Val == 1 and "second" or "seconds"
		end
	})
	WallCheck = Fly:CreateToggle({
		Name = "Wall Check",
		Default = true,
		Darker = true,
		Visible = false
	})
	Options.WallCheck = WallCheck
	PlatformStanding = Fly:CreateToggle({
		Name = "PlatformStand",
		Function = function(Callback: boolean)
			if Fly.Enabled then
				Entity.character.Humanoid.PlatformStand = Callback
			end
		end,
		Tooltip = "Forces the character to look infront of the camera"
	})
	CustomProperties = Fly:CreateToggle({
		Name = "Custom Properties",
		Function = function()
			if Fly.Enabled then
				Fly:Toggle()
				Fly:Toggle()
			end
		end,
		Default = true
	})
end)
