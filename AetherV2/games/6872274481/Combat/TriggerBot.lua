run(function()
	local TriggerBot
	local Targets
	local Range
	local Angle
	local CPS
	local Limit
	local Region
	local Continue
	local Duration
	local Mouse
	local AFKCheck
	local GUI
	local BoxColor
	local BoxTween
	local BoxSpeed
	
	local box
	local lastTarget, lastSwing, killUntil = nil, 0, 0
	local rayParams = RaycastParams.new()
	
	local function getTarget(localPosition, attackRange, angle)
		if angle > 0 then
			local origin, facing = gameCamera.CFrame.Position, gameCamera.CFrame.LookVector
			local limit = math.cos(math.rad(math.min(angle, 360)) / 2)
			for _, v in entitylib.AllPosition({
				Part = 'RootPart',
				Range = attackRange,
				Origin = localPosition,
				Players = Targets.Players.Enabled,
				NPCs = Targets.NPCs.Enabled,
				Priority = Targets.Priority.Value,
				Wallcheck = Targets.Walls.Enabled or nil,
				Sort = sortmethods.Distance
			}) do
				local delta = v.RootPart.Position - origin
				if delta.Magnitude < 0.001 or facing:Dot(delta.Unit) >= limit then
					return v
				end
			end
	
			return nil
		end
	
		local unit = lplr:GetMouse().UnitRay
		rayParams.FilterDescendantsInstances = {lplr.Character}
		local ray = bedwars.QueryUtil:raycast(unit.Origin, unit.Direction * 200, rayParams)
		if not ray then return nil end
	
		for _, v in entitylib.List do
			if v.Targetable and ray.Instance:IsDescendantOf(v.Character) and (localPosition - v.RootPart.Position).Magnitude <= attackRange then
				if Targets.Players.Enabled and v.Player or Targets.NPCs.Enabled and not v.Player then
					if not Targets.Walls.Enabled or not entitylib.Wallcheck(localPosition, v.RootPart.Position, true, v) then
						return v
					end
				end
			end
		end
	
		return nil
	end
	
	TriggerBot = vape.Categories.Combat:CreateModule({
		Name = 'TriggerBot',
		ExtraText = function() return CPS.ValueMin..'-'..CPS.ValueMax end,
		Function = function(callback)
			if callback then
				lastTarget, lastSwing, killUntil = nil, 0, 0
	
				repeat
					local ent, doAttack
					if entitylib.isAlive and (not GUI.Enabled or not bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN)) and (not Mouse.Enabled or inputService:IsMouseButtonPressed(0)) and (not AFKCheck.Enabled or not isAfk()) then
						if (not Limit.Enabled or store.hand.toolType == 'sword') and bedwars.DaoController.chargingMaid == nil then
							local attackRange = math.clamp(Range.Value, 0, getReach(store.hand.tool) * 2)
							ent = getTarget(entitylib.character.RootPart.Position, attackRange, Angle.Value)
							doAttack = ent ~= nil
	
							if lastTarget and lastTarget.Health <= 0 then
								if tick() - lastSwing <= 1 then
									killUntil = tick() + Duration.Value
								end
								lastTarget = nil
							end
	
							if not doAttack and Region.Enabled then
								doAttack = (bedwars.SwordController.getTargetInRegion and bedwars.SwordController:getTargetInRegion(attackRange, 0) ~= nil) or false
							end
	
							if not doAttack and Continue.Enabled and tick() < killUntil then
								doAttack = true
							end
	
							if ent then
								lastTarget = ent
								targetinfo.Targets[ent] = tick() + 1
							end
	
							if doAttack and canSwing() then
								if ent then
									lastSwing = tick()
								end
								bedwars.SwordController:swingSwordAtMouse()
							end
						end
					end
	
					if box then
						box.Adornee = ent and ent.RootPart or nil
						tweenService:Create(box, TweenInfo.new(BoxSpeed.Value, Enum.EasingStyle[BoxTween.Value]), {
							Size = ent and Vector3.new(4, 6, 4) or Vector3.zero
						}):Play()
						if ent then
							box.Color3 = Color3.fromHSV(BoxColor.Hue, BoxColor.Sat, BoxColor.Value)
							box.Transparency = 1 - BoxColor.Opacity
						end
					end
	
					task.wait(doAttack and 1 / CPS:GetRandomValue() or 0.016)
				until not TriggerBot.Enabled
			end
		end,
		Tooltip = 'Attacks or fires when your cursor is on an enemy'
	})
	
	Targets = TriggerBot:CreateTargets({
		Players = true,
		NPCs = true,
		Walls = true
	})
	Range = TriggerBot:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 18,
		Default = 18,
		Decimal = 10,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end,
		Tooltip = 'How far away a target can be'
	})
	Angle = TriggerBot:CreateSlider({
		Name = 'Angle',
		Min = 0,
		Max = 360,
		Default = 0,
		Suffix = 'degrees',
		Tooltip = 'How wide an area around your view it attacks'
	})
	TriggerBot:CreateButton({
		Name = 'Reset to default reach',
		Tooltip = 'Sets the range back to the game\'s default',
		Function = function()
			Range:SetValue(14.4)
			Angle:SetValue(0)
		end,
	})
	CPS = TriggerBot:CreateTwoSlider({
		Name = 'CPS',
		Min = 1,
		Max = 9,
		DefaultMin = 7,
		DefaultMax = 7
	})
	Limit = TriggerBot:CreateToggle({
		Name = 'Limit to items',
		Default = true,
		Tooltip = 'Only works while holding the item it uses'
	})
	Region = TriggerBot:CreateToggle({
		Name = 'Region check',
		Default = true,
		Tooltip = 'Also swings when anything is inside your sword region'
	})
	Continue = TriggerBot:CreateGroup({
		Name = 'Continue after kill',
		Tooltip = 'Keeps swinging briefly after a kill'
	})
	Duration = Continue:CreateSlider({
		Name = 'Continue time',
		Min = 0.05,
		Max = 2,
		Default = 0.4,
		Decimal = 100,
		Darker = true,
		Suffix = 'seconds'
	})
	Mouse = TriggerBot:CreateToggle({Name = 'Require mouse down'})
	AFKCheck = TriggerBot:CreateToggle({
		Name = 'AFK check',
		Tooltip = 'Stops attacking while you are away from your keyboard and mouse'
	})
	GUI = TriggerBot:CreateToggle({Name = 'GUI check'})
	local ShowTargetGroup = TriggerBot:CreateGroup({
		Name = 'Show target',
		Function = function(callback)
			if callback then
				box = Instance.new('BoxHandleAdornment')
				box.Adornee = nil
				box.AlwaysOnTop = true
				box.Size = Vector3.zero
				box.CFrame = CFrame.new(0, -0.5, 0)
				box.ZIndex = 0
				box.Parent = vape.gui
			elseif box then
				box:Destroy()
				box = nil
			end
		end
	})
	local animlist = {'Bounce'}
	for _, v in Enum.EasingStyle:GetEnumItems() do
		if not table.find(animlist, v.Name) then
			table.insert(animlist, v.Name)
		end
	end
	BoxTween = ShowTargetGroup:CreateDropdown({
		Name = 'Box Animation',
		List = animlist,
		Darker = true
	})
	BoxSpeed = ShowTargetGroup:CreateSlider({
		Name = 'Animation Speed',
		Min = 0,
		Max = 10,
		Default = 0.9,
		Decimal = 30,
		Darker = true
	})
	BoxColor = ShowTargetGroup:CreateColorSlider({
		Name = 'Target Color',
		Darker = true,
		DefaultHue = 0.6,
		DefaultOpacity = 0.5
	})
end)
