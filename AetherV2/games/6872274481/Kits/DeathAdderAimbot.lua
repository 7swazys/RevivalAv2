run(function()
	local Main = vape.Libraries.mergedModule(kits, {
		Name = 'DeathAdderAimbot',
		Category = 'Aim',
		Tooltip = 'Aims Death Adder spells and fires at the closest enemy'
	})

run(function()
	local DeathAdderAimbot, Mode, BedRange, Targets, Sort, TargetPart, FOV
	local originalDirection, hookedDirection

	local function aimPosition(origin)
		if Mode.Value == 'Bed' then
			local closest, distance
			for _, bed in collectionService:GetTagged('bed') do
				if not bed:GetAttribute(`Team{lplr:GetAttribute('Team') or -1}NoBreak`) then
					local magnitude = (origin - bed.Position).Magnitude
					if magnitude <= BedRange.Value and (not distance or magnitude < distance) then closest, distance = bed, magnitude end
				end
			end
			return closest and closest.Position
		end
		local ent = entitylib.EntityMouse({Range = FOV.Value, Part = 'RootPart', Wallcheck = Targets.Walls.Enabled,
			Players = Targets.Players.Enabled,
			Priority = Targets.Priority and Targets.Priority.Value, NPCs = Targets.NPCs.Enabled, Origin = origin, Sort = sortmethods[Sort.Value]})
		if not ent then return end
		targetinfo.Targets[ent] = tick() + 1
		local tier = bedwars.SorcererBalance.getSorcererTierData(bedwars.SorcererBalance.getSorcererTier(lplr))
		local position = ent[TargetPart.Value].Position
		return position + ent.RootPart.AssemblyLinearVelocity * ((position - origin).Magnitude / ((tier and tier.projectileVelocity) or 70))
	end

	DeathAdderAimbot = Main:Part({
		Label = 'Aimbot',Name = 'DeathAdderAimbot', Category = 'Aim', Function = function(enabled)
		local controller = bedwars.SorcererController
		if enabled then
			if not controller or type(controller.getProjectileDirection) ~= 'function' then
				notif('DeathAdderAimbot', 'Death Adder controller is unavailable.', 5, 'warning'); DeathAdderAimbot:Toggle(); return
			end
			originalDirection = controller.getProjectileDirection
			hookedDirection = function(self, ...)
				if entitylib.isAlive then
					local origin = entitylib.character.RootPart.Position
					local aim = aimPosition(origin)
					if aim and aim ~= origin then return (aim - origin).Unit end
				end
				return originalDirection(self, ...)
			end
			controller.getProjectileDirection = hookedDirection
			DeathAdderAimbot:Clean(function()
				if controller.getProjectileDirection == hookedDirection then controller.getProjectileDirection = originalDirection end
				originalDirection, hookedDirection = nil, nil
			end)
		end
	end, Tooltip = 'Leads Death Adder spells onto players or enemy beds'})
	Targets = DeathAdderAimbot:CreateTargets({Players = true, Walls = true})
	Mode = DeathAdderAimbot:CreateDropdown({Name = 'Mode', List = {'Player', 'Bed'}, Function = function(value)
		if BedRange then BedRange.Object.Visible = value == 'Bed'; FOV.Object.Visible = value == 'Player'; TargetPart.Object.Visible = value == 'Player'; Sort.Object.Visible = value == 'Player' end
	end})
	BedRange = DeathAdderAimbot:CreateSlider({Name = 'Bed range', Min = 1, Max = 60, Default = 60, Suffix = ' studs', Visible = false})
	local methods = {'Distance', 'Damage'}
	for _, name in sortlist do if not table.find(methods, name) then table.insert(methods, name) end end
	Sort = DeathAdderAimbot:CreateDropdown({Name = 'Target mode', List = methods, Default = 'Distance'})
	TargetPart = DeathAdderAimbot:CreateDropdown({Name = 'Part', List = {'RootPart', 'Head'}})
	FOV = DeathAdderAimbot:CreateSlider({Name = 'FOV', Min = 1, Max = 1000, Default = 1000})
end)

run(function()
	local util = vape.Libraries.bedwarsutil
	local AutoSorcerer
	local Range
	local Delay
	local nextUse = 0

	AutoSorcerer = Main:Part({
		Label = 'Auto fire',
		Name = 'AutoSorcerer',
		Function = function(callback)
			if callback then
				nextUse = 0
				repeat
					if entitylib.isAlive and util.IsKit('sorcerer') and tick() >= nextUse and util.Ability.Ready('SORCERER_PROJECTILE_FIRE') then
						local target = entitylib.EntityPosition({
							Origin = entitylib.character.RootPart.Position,
							Range = Range.Value,
							Part = 'RootPart',
							Players = true,
							Wallcheck = true
						})
						if target then
							nextUse = tick() + Delay.Value
							util.Ability.Use('SORCERER_PROJECTILE_FIRE')
						end
					end
					task.wait(0.1)
				until not AutoSorcerer.Enabled
			end
		end,
		Tooltip = 'Fires the sorcerer projectile at the closest enemy'
	})
	Range = AutoSorcerer:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 100,
		Default = 40,
		Suffix = util.Studs
	})
	Delay = AutoSorcerer:CreateSlider({
		Name = 'Delay',
		Min = 0.1,
		Max = 5,
		Default = 0.4,
		Decimal = 10,
		Suffix = util.Seconds
	})
end)

end)
