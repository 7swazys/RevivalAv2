run(function()
	local TPDown
	local Delay
	local Touchdown
	local Return
	local ShowUI
	local AirOnly
	
	local RayParams: RaycastParams = RaycastParams.new()
	local RayParamsF1, RayParamsF2, RayParamsF3 = false, false, false
	RayParams.RespectCanCollide = true
	
	local Bar: Frame? = nil
	local Fill: Frame? = nil
	
	local function RemoveBar()
	    if Bar then
	        Bar:Destroy()
	        Bar, Fill = nil, nil
	    end
	end
	
	local function CreateBar()
	    RemoveBar()
	
	    Bar = Instance.new("Frame")
	    Bar.AnchorPoint = Vector2.new(0.5, 0)
	    Bar.BackgroundColor3 = Color3.new()
	    Bar.BackgroundTransparency = 0.5
	    Bar.BorderSizePixel = 0
	    Bar.Position = UDim2.new(0.5, 0, 0.5, 150)
	    Bar.Size = UDim2.fromOffset(160, 6)
	    Bar.Visible = false
	    Bar.Parent = vape.gui
	    local Corner: UICorner = Instance.new("UICorner")
	    Corner.CornerRadius = UDim.new(1, 0)
	    Corner.Parent = Bar
	
	    Fill = Instance.new("Frame")
	    Fill.BorderSizePixel = 0
	    Fill.Size = UDim2.fromScale(0, 1)
	    Fill.Parent = Bar
	    Corner:Clone().Parent = Fill
	end
	
	local function HandledElsewhere(): (boolean, any)
	    for _, Name: string in {"Fly", "InfiniteJump"} do
	        local Module = vape.Modules[Name]
	        local Option = Module and Module.Options["TP Down"]
	        if Module and Module.Enabled and Option and Option.Enabled then
	            return true, Module
	        end
	    end
	    return false, nil
	end
	
	local function UpdateBar(AirTime: number, Airborne: boolean, Span: number?)
	    if not Bar or not Fill then
	        return
	    end
	
	    Bar.Visible = TPDown.Enabled and entitylib.isAlive and (Airborne or not AirOnly.Enabled)
	    Fill.BackgroundColor3 = Color3.fromHSV(vape.GUIColor.Hue, vape.GUIColor.Sat, vape.GUIColor.Value)
	    Fill.Size = UDim2.fromScale(math.clamp(AirTime / (Span or Delay.Value), 0, 1), 1)
	end
	
	TPDown = vape.Categories.Blatant:CreateModule({
	    Name = "TPDown",
	    Function = function(Callback: boolean)
	        TPDown.PullIn = nil
	        if Callback then
	            local OldY: number? = nil
	            local ReturnTick: number = 0
	            local NextPull: number = 0
	
	            TPDown:Clean(runService.PreSimulation:Connect(function()
	                local Handled: boolean, Handler = HandledElsewhere()
	                if not entitylib.isAlive or vape.MovementOwner or Handled then
	                    OldY = nil
	                    TPDown.PullIn = nil
	                    if Handled and entitylib.isAlive and not vape.MovementOwner then
	                        local InAir: boolean = entitylib.character.Humanoid.FloorMaterial == Enum.Material.Air
	                        local Left: number? = Handler.PullIn
	                        if Handler.Name ~= "Fly" then
	                            Left = InAir and (2 - (tick() - (entitylib.character.AirTime or tick()))) or 2
	                        end
	                        UpdateBar(Left and (2 - Left) or 0, InAir, 2)
	                    else
	                        UpdateBar(0, false)
	                    end
	                    return
	                end
	
	                local Root: BasePart = entitylib.character.RootPart
	                local Airborne: boolean = entitylib.character.Humanoid.FloorMaterial == Enum.Material.Air
	                local AirTime: number = Airborne and (tick() - (entitylib.character.AirTime or tick())) or 0
	
	                if ReturnTick > tick() then
	                    Root.AssemblyLinearVelocity = Vector3.new(Root.AssemblyLinearVelocity.X, 0, Root.AssemblyLinearVelocity.Z)
	                    UpdateBar(0, Airborne)
	                    return
	                end
	
	                if OldY then
	                    Root.CFrame = CFrame.lookAlong(Vector3.new(Root.Position.X, OldY, Root.Position.Z), Root.CFrame.LookVector)
	                    entitylib.character.AirTime = tick()
	                    OldY = nil
	                    UpdateBar(0, true)
	                    return
	                end
	
	                if vape.FloatExempt then
	                    TPDown.PullIn = nil
	                    UpdateBar(0, Airborne)
	                    return
	                end

	                TPDown.PullIn = Airborne and (Delay.Value - AirTime) or nil
	                UpdateBar(AirTime, Airborne)
	
	                if Airborne and AirTime > Delay.Value and NextPull < tick() and isnetworkowner(Root) then
	                    if RayParamsF1 ~= lplr.Character or RayParamsF2 ~= gameCamera or RayParamsF3 ~= AntiFallPart then
	                    	RayParamsF1, RayParamsF2, RayParamsF3 = lplr.Character, gameCamera, AntiFallPart
	                    	RayParams.FilterDescendantsInstances = {lplr.Character, gameCamera, AntiFallPart}
	                    end
	                    RayParams.CollisionGroup = Root.CollisionGroup
	                    local Ground: RaycastResult? = workspace:Raycast(Root.Position, Vector3.new(0, -1000, 0), RayParams)
	                    if Ground then
	                        OldY = Return.Enabled and Root.Position.Y or nil
	                        ReturnTick = tick() + Touchdown.Value
	                        NextPull = ReturnTick + 0.2
	                        Root.CFrame = CFrame.lookAlong(Vector3.new(Root.Position.X, Ground.Position.Y + entitylib.character.HipHeight, Root.Position.Z), Root.CFrame.LookVector)
	                        Root.AssemblyLinearVelocity = Vector3.new(Root.AssemblyLinearVelocity.X, 0, Root.AssemblyLinearVelocity.Z)
	                    end
	                end
	            end))
	        else
	            UpdateBar(0, false)
	        end
	    end,
	    Tooltip = 'Touches the ground when you have been in the air too long'
	})
	
	Delay = TPDown:CreateSlider({
	    Name = "Air Time",
	    Min = 0.5,
	    Max = 3,
	    Default = 1.7,
	    Decimal = 10,
	    Suffix = function(Val: number)
	        return Val == 1 and "second" or "seconds"
	    end,
	    Tooltip = "How long you can stay in the air before it pulls you down"
	})
	Touchdown = TPDown:CreateSlider({
	    Name = "Touchdown",
	    Min = 0.05,
	    Max = 0.5,
	    Default = 0.11,
	    Decimal = 100,
	    Suffix = function(Val: number)
	        return Val == 1 and "second" or "seconds"
	    end,
	    Tooltip = "How long you stay on the ground before going back up"
	})
	Return = TPDown:CreateToggle({
	    Name = "Return",
	    Default = true,
	    Tooltip = 'Teleports you back up after being pulled down'
	})
	ShowUI = TPDown:CreateGroup({
	    Name = "Show UI",
	    Function = function(Callback: boolean)
	
	        if Callback then
	            local Other = vape.Modules.Fly
	            Other = Other and Other.Options["Show UI"]
	            if Other and Other.Enabled then
	                Other:Toggle()
	            end
	            CreateBar()
	        else
	            RemoveBar()
	        end
	    end,
	    Tooltip = 'Shows a bar that fills up until you are pulled down'
	})
	AirOnly = ShowUI:CreateToggle({
	    Name = "Air Only",
	    Darker = true,
	    Tooltip = "Only shows the bar while you are in the air"
	})
	vape:Clean(RemoveBar)
end)
