run(function()
	local Spider
	local SpiderShift = false
    local Mode
    local Animation
    local Value
    local rayCheck = RaycastParams.new()
    rayCheck.RespectCanCollide = true
    local Active, Truss, Loaded
    local dirty, lastCharacter, lastTruss = true

    local climbAnimation = Instance.new('Animation')
    climbAnimation.AnimationId = 'rbxassetid://11344417710'

    Spider = vape.Categories.Blatant:CreateModule({
	Name = 'Spider',
	ExtraText = function() return Mode.Value end,
	Function = function(callback)
		if callback then
			if Truss then
				Truss.Parent = gameCamera
			end

			dirty = true
			Spider:Clean(entitylib.Events.EntityAdded:Connect(function() dirty = true end))
			Spider:Clean(entitylib.Events.EntityRemoved:Connect(function() dirty = true end))
			Spider:Clean(runService.PreSimulation:Connect(function(dt)
				if entitylib.isAlive then
					local root = entitylib.character.RootPart
					if dirty or lastCharacter ~= lplr.Character or lastTruss ~= Truss then
						dirty, lastCharacter, lastTruss = false, lplr.Character, Truss
						local chars = { gameCamera, lplr.Character, Truss }
						for _, v in entitylib.List do
							table.insert(chars, v.Character)
						end
						rayCheck.FilterDescendantsInstances = chars
					end
					SpiderShift = inputService:IsKeyDown(Enum.KeyCode.LeftShift)
					rayCheck.CollisionGroup = root.CollisionGroup

                        local dir, stop = entitylib.character.Humanoid.MoveDirection, false
                        if dir.Magnitude <= 0 then
                            dir, stop = root.CFrame.LookVector, true
                        end
                        local vec = dir * 2.5
                        local ray = workspace:Raycast(
                            root.Position - Vector3.new(0, entitylib.character.HipHeight - 0.5, 0),
                            vec,
                            rayCheck
                        )
                        if Active then
                            if not Loaded and Animation.Enabled then
                                Loaded = entitylib.character.Humanoid:LoadAnimation(climbAnimation)
                                Loaded:Play()
                            end
                            if Loaded then
                                Loaded:AdjustSpeed((not stop) and 2 or 0)
                            end
                            
                            
                            
                            
                            
                            if not ray and not stop then
                                root.Velocity = Vector3.new(root.Velocity.X, 0, root.Velocity.Z)
                            end
                        end

                        Active = ray
                        if Active and ray.Normal.Y == 0 and not stop then
                            if not (vape.Modules.NoClip and vape.Modules.NoClip.Enabled) or not SpiderShift then
                                if Animation.Enabled then
                                    entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Climbing)
                                end

                                root.Velocity *= Vector3.new(1, 0, 1)
                                if Mode.Value == 'CFrame' then
                                    root.CFrame += Vector3.new(0, Value.Value * dt, 0)
                                elseif Mode.Value == 'Impulse' then
                                    root:ApplyImpulse(Vector3.new(0, Value.Value, 0) * root.AssemblyMass)
                                else
                                    root.Velocity += Vector3.new(0, Value.Value, 0)
                                end
                            end
                        elseif not Active then
                            if Loaded then
                                Loaded:Stop()
                            end
                            Loaded = nil
                        end
                    else
                        if Loaded then
                            Loaded:Stop()
                        end
                        Loaded = nil
				end
			end))
		else
			if Truss then
				Truss.Parent = nil
			end
                if Loaded then
                    Loaded:Stop()
                end
                Loaded = nil
			SpiderShift = false
		end
	end,
	Tooltip = 'Lets you climb walls. Hold Shift to pass through with NoClip',
    })
    Mode = Spider:CreateDropdown({
	Name = 'Mode',
	List = {'Velocity', 'Impulse', 'CFrame'},
	Function = function(val)
		Value.Object.Visible = val ~= 'Part'
            if Truss then
			Truss:Destroy()
			Truss = nil
		end
		if val == 'Part' then
			Truss = Instance.new('TrussPart')
			Truss.Size = Vector3.new(2, 2, 2)
			Truss.Transparency = 1
			Truss.Anchored = true
			Truss.Parent = Spider.Enabled and gameCamera or nil
		end
	end,
	Tooltip = 'How you are moved up',
    })
    Value = Spider:CreateSlider({
	Name = 'Speed',
	Min = 0,
	Max = 100,
	Default = 30,
	Darker = true,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end,
    })
    Animation = Spider:CreateToggle({
        Name = 'Use bedwars climbing',
        Tooltip = 'Plays the kit climbing animation'
    })
end)
