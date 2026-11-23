run(function()
	local util = vape.Libraries.bedwarsutil
	local RavenAura
	local Transform
	local TransformRange
	local Send
	local SendRange
	local Delay
	local nextAction = 0

	local function show(option, visible)
		if option and option.Object then option.Object.Visible = visible end
	end

	local function teleportRaven()
		local plr = entitylib.EntityMouse({
			Range = 1000,
			Players = true,
			Part = 'RootPart'
		})
		if not (getItem('raven') and plr) then return end
		bedwars.Handler:Get('SpawnRaven'):Fire('CallServerAsync'):andThen(function(projectile)
			if not (projectile and projectile.PrimaryPart) then return end
			local bodyforce = Instance.new('BodyForce')
			bodyforce.Force = Vector3.new(0, projectile.PrimaryPart.AssemblyMass * workspace.Gravity, 0)
			bodyforce.Parent = projectile.PrimaryPart
			task.spawn(function()
				for _ = 1, 20 do
					if plr.RootPart and projectile.Parent then
						projectile:SetPrimaryPartCFrame(CFrame.lookAlong(plr.RootPart.Position, gameCamera.CFrame.LookVector))
					end
					task.wait(0.05)
				end
			end)
			task.wait(0.3)
			bedwars.RavenController:detonateRaven()
		end)
	end

	RavenAura = kits:CreateModule({
		Name = 'RavenAura',
		Category = 'Ability',
		Function = function(callback)
			if callback then
				nextAction = 0
				repeat
					if entitylib.isAlive and util.IsKit('raven') and tick() >= nextAction then
						local range = math.max(Transform.Enabled and TransformRange.Value or 0, Send.Enabled and SendRange.Value or 0)
						local target = range > 0 and entitylib.EntityPosition({
							Origin = entitylib.character.RootPart.Position,
							Range = range,
							Part = 'RootPart',
							Players = true,
							Wallcheck = true
						}) or nil

						if target and Transform.Enabled and util.Ability.Ready('raven_transform') then
							nextAction = tick() + Delay.Value
							util.Ability.Use('raven_transform')
						elseif target and Send.Enabled and util.Ability.Ready('raven_send_request') then
							nextAction = tick() + Delay.Value
							util.Ability.Use('raven_send_request')
						end
					end
					task.wait(0.1)
				until not RavenAura.Enabled
			end
		end,
		Tooltip = 'Transforms into the raven or sends it at nearby enemies'
	})
	Transform = RavenAura:CreateToggle({
		Name = 'Auto transform',
		Default = false,
		Function = function(callback)
			show(TransformRange, callback)
		end
	})
	TransformRange = RavenAura:CreateSlider({
		Name = 'Transform range',
		Visible = false,
		Min = 1,
		Max = 80,
		Default = 30,
		Darker = true,
		Suffix = util.Studs
	})
	Send = RavenAura:CreateToggle({
		Name = 'Auto send',
		Default = true,
		Function = function(callback)
			show(SendRange, callback)
		end
	})
	SendRange = RavenAura:CreateSlider({
		Name = 'Send range',
		Min = 1,
		Max = 100,
		Default = 50,
		Darker = true,
		Suffix = util.Studs
	})
	Delay = RavenAura:CreateSlider({
		Name = 'Delay',
		Min = 0.1,
		Max = 5,
		Default = 0.5,
		Decimal = 10,
		Suffix = util.Seconds
	})
	RavenAura:CreateButton({
		Name = 'Teleport raven',
		Function = teleportRaven,
		Tooltip = 'Flies a raven onto the player nearest your cursor'
	})
end)
