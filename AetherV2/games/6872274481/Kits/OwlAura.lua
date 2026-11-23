run(function()
	local Main = vape.Libraries.mergedModule(kits, {
		Name = 'OwlAura',
		Category = 'Aim',
		Tooltip = 'Shoots at nearby enemies and helps a teammate with your owl'
	})

run(function()
    local OwlAura
    local Targets
    local Mode
    local Range
    local ShowFOV
    local FOV
    local fovColour
    local fovThickness
    local fovCircle
    local circleLibrary = vape.Libraries and vape.Libraries.fovcircle

    local function insideFOV(ent)
        return circleLibrary ~= nil and circleLibrary.ContainsEntity ~= nil and circleLibrary.ContainsEntity(ent, FOV.Value)
    end

    local function findTarget(origin)
        local settings = {
            Origin = origin,
            Range = Range.Value,
            Part = 'RootPart',
            Players = Targets.Players.Enabled,
            Priority = Targets.Priority and Targets.Priority.Value,
            NPCs = Targets.NPCs.Enabled,
            Wallcheck = Targets.Walls.Enabled,
            Sort = sortmethods[Mode.Value],
        }
        if not ShowFOV.Enabled then
            return entitylib.EntityPosition(settings)
        end
        for _, ent in entitylib.AllPosition(settings) do
            if ent.RootPart and insideFOV(ent) then return ent end
        end
    end

    local function runFOVCircle(state)
        if fovCircle then fovCircle:Destroy(); fovCircle = nil end
        if not state or not (circleLibrary and circleLibrary.New) then return end
        fovCircle = circleLibrary.New({
            Name = 'OwlAuraFOVCircle',
            Parent = vape.gui,
            Visible = function()
                return OwlAura and OwlAura.Enabled and ShowFOV.Enabled
            end,
            Radius = function()
                return FOV.Value
            end,
            Colour = function()
                return Color3.fromHSV(fovColour.Hue, fovColour.Sat, fovColour.Value)
            end,
            Thickness = function()
                return fovThickness.Value
            end
        })
    end

    local function getProjectileMeta()
        local meta = table.clone(bedwars.ProjectileMeta.owl_projectile)
        return meta
    end

    OwlAura = Main:Part({
		Label = 'Owl aura',
        Name = 'OwlAura',
        Category = 'Aim',
        Function = function(callback)
            runFOVCircle(callback and ShowFOV.Enabled)
            if callback then
                local owls = collection('Owl', OwlAura, function(self, obj)
                    task.delay(1, function()
                        if obj and obj.Parent and obj:GetAttribute('Owner') == lplr.UserId then
                            table.insert(self, obj)
                        end
                    end)
                end)
                repeat
                    if store.equippedKit ~= 'owl' then
                        task.wait(3)
                        continue
                    end

                    if entitylib.isAlive then
                        local owl = owls[1]
                        if owl then
                            local origin = owl.Part.Position
                            local plr = findTarget(origin)

                            if plr then
                                local meta = getProjectileMeta()
                                local calc = prediction.SolveTrajectory(origin, meta.launchVelocity, meta.gravitationalAcceleration, plr.RootPart.Position, plr.RootPart.Velocity, workspace.Gravity, plr.HipHeight, plr.Jumping and 42.6 or nil, nil, plr.Humanoid.FloorMaterial == Enum.Material.Air or math.abs(plr.RootPart.AssemblyLinearVelocity.Y) > 0.01, plr.RootPart.Position, plr.RootPart, nil, true)
                                if calc then
                                    local dir = CFrame.lookAt(origin, calc).LookVector * meta.launchVelocity
                                    bedwars.Client:Get('OwlAiming'):SendToServer({
                                        owl = owl.Part,
                                        starting = true,
                                    })
                                    bedwars.Client:Get('OwlFireProjectile'):SendToServer({
                                        ProjectileRefId = vape.Libraries.string:GenerateString(8),
                                        direction = dir,
                                        fromPosition = origin,
                                        initialVelocity = dir,
                                    })
                                    task.wait(lplr:GetNetworkPing())
                                end
                            end
                        end
                    end
                    task.wait(0.1)
                until not OwlAura.Enabled
            else
                bedwars.Client:Get('OwlAiming'):SendToServer({
                    starting = false,
                })
            end
        end,
        Tooltip = 'Shoots owl projectiles at nearby enemies'
    })

    Targets = OwlAura:CreateTargets({
        Players = true,
        Wallcheck = true,
    })
    local methods = {'Distance', 'Damage'}
    for _, v in sortlist do
        if not table.find(methods, v) then
            table.insert(methods, v)
        end
    end
    Mode = OwlAura:CreateDropdown({
        Name = 'Target mode',
        List = methods,
        Default = 'Distance',
        Tooltip = TARGET_MODE_TOOLTIP
    })
    Range = OwlAura:CreateSlider({
        Name = 'Range',
        Min = 1,
        Max = 50,
        Suffix = function(val)
            return val <= 0 and 'stud' or 'studs'
        end,
        Default = 50,
    })
    ShowFOV = OwlAura:CreateGroup({
        Name = 'FOV Circle',
        Tooltip = 'Shows the range around your cursor',
        Function = function(callback)
            if FOV and FOV.Object then FOV.Object.Visible = callback end
            if OwlAura.Enabled then runFOVCircle(callback) end
        end
    })
    FOV = OwlAura:CreateSlider({
        Name = 'FOV',
        Min = 1,
        Max = 1000,
        Default = 300,
        Darker = true,
        Visible = false
    })
    fovColour = ShowFOV:CreateColorSlider({
        Name = 'Circle colour',
        Darker = true
    })
    fovThickness = ShowFOV:CreateSlider({
        Name = 'Circle thickness',
        Min = 1,
        Max = 8,
        Default = 1,
        Darker = true
    })
end)

run(function()
	local Camera = gameCamera
	local Entity = entitylib
	local LocalPlayer = lplr
	local Players = playersService
	local ReplicatedStorage = replicatedStorage
	local RunService = runService
	local Store = store
	local UserInputService = inputService
	local AutoWhisper
	local Heal
	local Threshold
	local Fly
	local Owl
	local Target
	local FOVCheck
	local FOV
	local RangeCircle
	local CircleColor
	local CircleTransparency
	local CircleThickness
	local CircleFilled
	local CircleObject

	local Teammates: {string} = {"None"}
	local Old
	local MapBottom: number = math.huge
	local FallDepth: number = 12
	local FootingCharacter, FootingY = nil, -math.huge

	local Success, OwlBalance = pcall(function()
		return require(ReplicatedStorage.TS.balance["owl-balance-file"]).OwlBalance
	end)
	local AttachRange: number = Success and OwlBalance.OWL_ATTACH_MAX_RANGE or 60

	local function GetMouseOrigin()
		return UserInputService.TouchEnabled and Camera.ViewportSize / 2 or UserInputService:GetMouseLocation()
	end

	local function GetOwlTarget(): Player?
		local Picked: Player? = Players:FindFirstChild(Target.Value)
		if not FOVCheck.Enabled then
			return Picked
		end

		if not Entity.isAlive then
			return nil
		end

		local Origin: Vector2 = GetMouseOrigin()
		local Best, BestDistance = nil, FOV.Value
		for _, v: Player in (Picked and {Picked} or Players:GetPlayers()) do
			local Character: Model? = v.Character
			local Root: BasePart? = Character and Character:FindFirstChild("HumanoidRootPart")
			if v == LocalPlayer or not Root or v:GetAttribute("Team") ~= LocalPlayer:GetAttribute("Team") or v:GetAttribute("IsOwlTarget") then
				continue
			end

			if (Root.Position - Entity.character.RootPart.Position).Magnitude > AttachRange then
				continue
			end

			local Position, Visible = Camera:WorldToViewportPoint(Root.Position)
			local Distance: number = (Vector2.new(Position.X, Position.Y) - Origin).Magnitude
			if Visible and Distance <= BestDistance then
				Best, BestDistance = v, Distance
			end
		end

		return Best
	end

	local function RefreshOptions()
		local ShowFOV: boolean = Owl.Enabled and FOVCheck.Enabled
		local ShowCircle: boolean = ShowFOV and RangeCircle.Enabled

		Target.Object.Visible = Owl.Enabled
		FOVCheck.Object.Visible = Owl.Enabled
		FOV.Object.Visible = ShowFOV
		RangeCircle.Object.Visible = ShowFOV
		CircleColor.Object.Visible = ShowCircle
		CircleTransparency.Object.Visible = ShowCircle
		CircleThickness.Object.Visible = ShowCircle
		CircleFilled.Object.Visible = ShowCircle

		if CircleObject then
			CircleObject.Visible = AutoWhisper.Enabled and ShowFOV
		end
	end

	local function GetAttachedCharacter(): Model?
		local Attached: Instance? = bedwars.OwlAbilityController.target
		if Attached and Attached:IsA("Player") then
			return Attached.Character
		end
		return Attached :: Model?
	end

	local function GetMapBottom(): number
		if MapBottom == math.huge then
			for _, v: BasePart in Store.blocks do
				MapBottom = math.min(MapBottom, v.Position.Y - (v.Size.Y / 2))
			end
		end
		return MapBottom == math.huge and -math.huge or MapBottom
	end

	local function CanUse(Ability: string): boolean
		return bedwars.AbilityController:getEnabledAbility(Ability) ~= nil and bedwars.AbilityController:canUseAbility(Ability, {disableBlockedAbilityAlert = true})
	end

	local function AddConnection(TargetPlayer: Player, Connected: boolean?)
		if not Connected then
			vape:Clean(TargetPlayer:GetAttributeChangedSignal("Team"):Connect(function()
				AddConnection(TargetPlayer, true)
			end))
		end

		if TargetPlayer ~= LocalPlayer and TargetPlayer:GetAttribute("Team") == LocalPlayer:GetAttribute("Team") and not table.find(Teammates, TargetPlayer.Name) then
			table.insert(Teammates, TargetPlayer.Name)
			Target:Change(Teammates)
		end
	end

	AutoWhisper = Main:Part({
		Label = 'Teammate owl',
		Name = "AutoWhisper",
		Function = function(Callback: boolean)
			if CircleObject then
				CircleObject.Visible = Callback and Owl.Enabled and FOVCheck.Enabled
			end

			if Callback then
				AutoWhisper:Clean(RunService.RenderStepped:Connect(function()
					if CircleObject then
						CircleObject.Position = GetMouseOrigin()
					end
				end))

				Old = bedwars.OwlKitController.onAbilityUsed
				bedwars.OwlKitController.onAbilityUsed = function(self, Character, Data, ...)
					if Owl.Enabled and Data and Data.ability == "SUMMON_OWL" and Character == LocalPlayer.Character then
						local TargetPlayer: Player? = GetOwlTarget()
						if TargetPlayer and TargetPlayer ~= LocalPlayer then
							bedwars.Handler:Get("SummonOwl"):Fire("CallServer", TargetPlayer)
							return
						end
					end
					return Old(self, Character, Data, ...)
				end

				repeat
					task.wait()
				until Store.matchState ~= 0 or not AutoWhisper.Enabled
				if not AutoWhisper.Enabled then
					return
				end

				repeat
					if Owl.Enabled and not bedwars.OwlAbilityController.target and GetOwlTarget() and bedwars.AbilityController:canUseAbility("SUMMON_OWL", {disableBlockedAbilityAlert = true}) then
						bedwars.AbilityController:useAbility("SUMMON_OWL")
					end

					local Character: Model? = GetAttachedCharacter()
					if Character then
						local Root: BasePart? = Character.PrimaryPart
						if Root then
							if FootingCharacter ~= Character then
								FootingCharacter, FootingY = Character, GetMapBottom() + FallDepth
							end
							if math.abs(Root.AssemblyLinearVelocity.Y) < 2 then
								FootingY = Root.Position.Y
							end

							if Fly.Enabled and Root.Position.Y < FootingY - FallDepth and CanUse("OWL_LIFT") then
								bedwars.AbilityController:useAbility("OWL_LIFT")
							end
						end

						local Health: number? = Character:GetAttribute("Health")
						local MaxHealth: number? = Character:GetAttribute("MaxHealth")
						if Heal.Enabled and (Threshold.Value >= 100 or Health and MaxHealth and MaxHealth > 0 and Health / MaxHealth <= Threshold.Value / 100) and CanUse("OWL_HEAL") then
							bedwars.AbilityController:useAbility("OWL_HEAL")
						end
					end
					task.wait(0.1)
				until not AutoWhisper.Enabled
			elseif Old then
				bedwars.OwlKitController.onAbilityUsed = Old
				Old = nil
			end
		end,
		Tooltip = 'Uses Whisper\'s abilities for you'
	})

	Heal = AutoWhisper:CreateGroup({
		Name = "Heal",
		Default = true
	})
	Threshold = Heal:CreateSlider({
		Name = "Heal health",
		Min = 1,
		Max = 100,
		Default = 99,
		Darker = true,
		Suffix = "%"
	})
	Fly = AutoWhisper:CreateToggle({
		Name = "Fly",
		Default = true,
		Tooltip = 'Lifts your owl\'s player when they fall over the void'
	})
	Owl = AutoWhisper:CreateToggle({
		Name = "Auto owl",
		Function = RefreshOptions,
		Tooltip = 'Sends the owl to the chosen teammate when ready'
	})
	Target = AutoWhisper:CreateDropdown({
		Name = "Teammate",
		List = Teammates,
		Darker = true,
		Visible = false,
		Tooltip = 'Who the owl is summoned onto'
	})
	FOVCheck = AutoWhisper:CreateToggle({
		Name = "FOV check",
		Function = RefreshOptions,
		Darker = true,
		Visible = false,
		Tooltip = 'Only sends the owl to a teammate near your cursor'
	})
	FOV = AutoWhisper:CreateSlider({
		Name = "Teammate FOV",
		Min = 1,
		Max = 1000,
		Function = function(Val: number)
			if CircleObject then
				CircleObject.Radius = Val
			end
		end,
		Darker = true,
		Default = 150,
		Visible = false
	})
	RangeCircle = AutoWhisper:CreateToggle({
		Name = "Range Circle",
		Function = function(Callback: boolean)
			if Callback then
				CircleObject = Drawing.new("Circle")
				CircleObject.Filled = CircleFilled.Enabled
				CircleObject.Color = Color3.fromHSV(CircleColor.Hue, CircleColor.Sat, CircleColor.Value)
				CircleObject.Position = GetMouseOrigin()
				CircleObject.Radius = FOV.Value
				CircleObject.NumSides = 100
				CircleObject.Thickness = CircleThickness.Value
				CircleObject.Transparency = 1 - CircleTransparency.Value
			else
				pcall(function()
					CircleObject.Visible = false
					CircleObject:Remove()
				end)
				CircleObject = nil
			end
			RefreshOptions()
		end,
		Darker = true,
		Visible = false
	})
	CircleColor = AutoWhisper:CreateColorSlider({
		Name = "Circle Color",
		Function = function(Hue: number, Sat: number, Val: number)
			if CircleObject then
				CircleObject.Color = Color3.fromHSV(Hue, Sat, Val)
			end
		end,
		Darker = true,
		Visible = false
	})
	CircleTransparency = AutoWhisper:CreateSlider({
		Name = "Transparency",
		Min = 0,
		Max = 1,
		Decimal = 10,
		Function = function(Val: number)
			if CircleObject then
				CircleObject.Transparency = 1 - Val
			end
		end,
		Darker = true,
		Default = 0.5,
		Visible = false
	})
	CircleThickness = AutoWhisper:CreateSlider({
		Name = "Thickness",
		Min = 1,
		Max = 10,
		Decimal = 10,
		Function = function(Val: number)
			if CircleObject then
				CircleObject.Thickness = Val
			end
		end,
		Darker = true,
		Default = 1,
		Visible = false,
		Tooltip = 'How wide the circle\'s outline is'
	})
	CircleFilled = AutoWhisper:CreateToggle({
		Name = "Circle Filled",
		Function = function(Callback: boolean)
			if CircleObject then
				CircleObject.Filled = Callback
			end
		end,
		Darker = true,
		Visible = false
	})

	for _, v: Player in Players:GetPlayers() do
		AddConnection(v)
	end
	vape:Clean(Players.PlayerAdded:Connect(AddConnection))
end)

end)
