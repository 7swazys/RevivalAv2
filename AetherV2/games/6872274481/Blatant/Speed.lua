run(function()
	local Speed
	local Mode
	local Value
	local WallCheck
	local AutoJump
	local AlwaysJump
	local SpeedEffect
	local Modifier = {}
	local RayCheck: RaycastParams = RaycastParams.new()
	local RayCheckF1, RayCheckF2 = false, false
	RayCheck.RespectCanCollide = true
	local FilterFor
	local SavedImpulse

	local function hasSpeedEffect(): boolean
	    local Character = lplr.Character
	    local Expiry = Character and Character:GetAttribute("StatusEffect_speed")
	    return type(Expiry) == "number" and Expiry > workspace:GetServerTimeNow()
	end
	
	Speed = vape.Categories.Blatant:CreateModule({
	    Name = "Speed",
	    Function = function(Callback: boolean)
	        local Blatant: boolean = Callback and Mode.Value == "Blatant"
	        local Zephyr = vape.Kits and vape.Kits.Modules.ZephyrDisabler or vape.Modules.ZephyrDisabler
	        local ZephyrActive: boolean = Zephyr ~= nil and Zephyr.Enabled == true
	        frictionTable.Speed = Blatant or nil
	        updateVelocity()
	        pcall(store.windSpeedKey, (Blatant or ZephyrActive) and "constantSpeedMultiplier" or "moveSpeedMultiplier")
	        pcall(function()
	            local Controller = bedwars.StatefulEntityKnockbackController
	            if Blatant or ZephyrActive then
	                if SavedImpulse == nil and Controller.lastImpulseTime ~= math.huge then
	                    SavedImpulse = Controller.lastImpulseTime
	                end
	                Controller.lastImpulseTime = math.huge
	            elseif Controller.lastImpulseTime == math.huge then
	                Controller.lastImpulseTime = SavedImpulse or 0
	                SavedImpulse = nil
	            end
	        end)
	        if not Callback and entitylib.isAlive then
	            local Root = entitylib.character.RootPart
	            Root.AssemblyLinearVelocity = Vector3.new(0, Root.AssemblyLinearVelocity.Y, 0)
	        end

	        if Callback then
	            local EngineSpeed = store.engineSpeed(Speed)
	            if not Blatant then
	                Modifier.moveSpeedMultiplier = Value.Value / 20
	                local Handle = bedwars.SprintController:getMovementStatusModifier():addModifier(Modifier)
	                Speed:Clean(function()
	                    Handle:Destroy()
	                end)
	            end

	            Speed:Clean(runService.PreSimulation:Connect(function(Delta: number)
	                if Blatant then
	                    bedwars.StatefulEntityKnockbackController.lastImpulseTime = math.huge
	                end
	                if entitylib.isAlive and not (Fly and Fly.Enabled) and not (LongJump and LongJump.Enabled) and isnetworkowner(entitylib.character.RootPart) then
	                    local State: Enum.HumanoidStateType = entitylib.character.Humanoid:GetState()
	                    if State == Enum.HumanoidStateType.Climbing then
	                        return
	                    end

	                    local MoveDirection: Vector3 = AntiFallDirection or entitylib.character.Humanoid.MoveDirection
	                    if Blatant then
	                        local Root, CurrentSpeed = entitylib.character.RootPart, getSpeed()
	                        local Target: number = (SpeedEffect.Enabled and hasSpeedEffect()) and 34.5 or Value.Value
	                        local Destination: Vector3 = MoveDirection * math.max(Target - EngineSpeed(), 0) * Delta
	                        if WallCheck.Enabled and Destination.Magnitude > 0.001 then
	                            if FilterFor ~= lplr.Character then
	                                FilterFor = lplr.Character
	                                if RayCheckF1 ~= lplr.Character or RayCheckF2 ~= gameCamera then
	                                	RayCheckF1, RayCheckF2 = lplr.Character, gameCamera
	                                	RayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
	                                end
	                            end
	                            if RayCheck.CollisionGroup ~= Root.CollisionGroup then
	                                RayCheck.CollisionGroup = Root.CollisionGroup
	                            end
	                            local WallRay: RaycastResult? = workspace:Raycast(Root.Position, Destination, RayCheck)
	                            if WallRay then
	                                Destination = (WallRay.Position + WallRay.Normal) - Root.Position
	                            end
	                        end

	                        Root.CFrame += Destination
	                        Root.AssemblyLinearVelocity = (MoveDirection * CurrentSpeed) + Vector3.new(0, Root.AssemblyLinearVelocity.Y, 0)
	                    end
	                    if AutoJump.Enabled and (State == Enum.HumanoidStateType.Running or State == Enum.HumanoidStateType.Landed) and MoveDirection ~= Vector3.zero and (store.attacking or AlwaysJump.Enabled) then
	                        entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	                    end
	                end
	            end))
	        end
	    end,
	    ExtraText = function()
	        return Mode.Value
	    end,
	    Tooltip = "Increases your movement speed"
	})
	
	Mode = Speed:CreateDropdown({
	    Name = "Mode",
	    List = {"Blatant", "Legit"},
	    Function = function(Val: string)
	        if WallCheck then
	            WallCheck.Object.Visible = Val == "Blatant"
	        end
	        if SpeedEffect then
	            SpeedEffect.Object.Visible = Val == "Blatant"
	        end
	        if Speed.Enabled then
	            Speed:Toggle()
	            Speed:Toggle()
	        end
	    end,
	    Default = "Blatant",
	    Tooltip = 'Blatant - moves you forward\nLegit - raises your sprint speed'
	})
	Value = Speed:CreateSlider({
	    Name = "Speed",
	    Function = function(Val: number)
	        if Speed.Enabled and Mode.Value == "Legit" then
	            Modifier.moveSpeedMultiplier = Val / 20
	            bedwars.SprintController:getMovementStatusModifier():updateModifiers()
	        end
	    end,
	    Min = 1,
	    Max = 23,
	    Default = 23,
	    Suffix = function(Val: number)
	        return Val == 1 and "stud" or "studs"
	    end
	})
	SpeedEffect = Speed:CreateToggle({
	    Name = "Speed Effect",
	    Tooltip = 'Moves faster while a speed effect is active'
	})
	WallCheck = Speed:CreateToggle({
	    Name = "Wall Check",
	    Default = true
	})
	AutoJump = Speed:CreateGroup({
	    Name = "AutoJump"
	})
	AlwaysJump = AutoJump:CreateToggle({
	    Name = "Always Jump"
	})
end)