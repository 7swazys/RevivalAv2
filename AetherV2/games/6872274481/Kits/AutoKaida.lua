run(function()

	local util = vape.Libraries.bedwarsutil
	local AutoKaida
	local Targets
	local Sort
	local SwingRange
	local AttackRange
	local Spell
	local SpellMode
	local SpellCharge
	local SpellRange
	local Swing
	local Limit
	local Mouse
	local GUI

	local casting = 0

	local function getClaw()
		if Limit.Enabled then
			return store.hand.tool and bedwars.IsItemClaw(store.hand.tool.Name) and store.hand or nil
		end

		for _, item in store.inventory.inventory.items do
			if bedwars.IsItemClaw(item.itemType) then
				return item
			end
		end
		return nil
	end

	local function getSpellTarget()
		local localPosition = entitylib.character.RootPart.Position
		if SpellMode.Value == 'Camera' then
			local point = bedwars.AbilityIndicatorUtil:calculateBlockTargetPoint(gameCamera.CFrame.Position, gameCamera.CFrame.LookVector, 300, nil, {allowArenaBarrierTarget = false})
			return point and (point - localPosition).Magnitude <= SpellRange.Value and point or nil
		end

		local ent = entitylib.EntityPosition({
			Range = SpellRange.Value,
			Part = 'RootPart',
			Players = Targets.Players.Enabled,
			Priority = Targets.Priority and Targets.Priority.Value,
			NPCs = Targets.NPCs.Enabled,
			Sort = sortmethods[Sort.Value]
		})
		if not ent then return nil end

		local point = bedwars.AbilityIndicatorUtil:calculateBlockTargetPoint(ent.RootPart.Position + Vector3.new(0, 3, 0), Vector3.new(0, -1, 0), 30, nil, {allowArenaBarrierTarget = false})
		return point and (point - localPosition).Magnitude <= SpellRange.Value and point or ent.RootPart.Position
	end

	local function castSpell()
		local target = getSpellTarget()
		if not target or not bedwars.AbilityController:canUseAbility('summoner_start_charging', {disableBlockedAbilityAlert = true}) then return end

		casting = tick() + 6
		bedwars.AbilityController:useAbility('summoner_start_charging', nil, {targetPosition = target})

		local level = bedwars.SummonerUtil.summoner_getPlayerSpellLevel(lplr) or 1
		local charge = math.max(bedwars.SummonerUtil.summoner_getTotalCastTimeRequired(level) * (SpellCharge.Value / 100), bedwars.SummonerKitBalance.SPELL_MINIMUM_CAST_TIME)
		local deadline = tick() + charge

		repeat task.wait() until tick() >= deadline or not AutoKaida.Enabled or not entitylib.isAlive or not bedwars.SummonerKitController:isPlayerCastingSpell(lplr)

		if AutoKaida.Enabled and entitylib.isAlive and bedwars.SummonerKitController:isPlayerCastingSpell(lplr) then
			bedwars.AbilityController:useAbility('summoner_finish_charging')
		end
		casting = 0
	end

	AutoKaida = kits:CreateModule({
		Name = 'AutoKaida',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and store.equippedKit == 'summoner' then
						if Spell.Enabled and tick() > casting and not bedwars.SummonerKitController:isPlayerCastingSpell(lplr) then
							task.spawn(castSpell)
						end

						local claw = (not Mouse.Enabled or inputService:IsMouseButtonPressed(0)) and (not GUI.Enabled or not bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN)) and getClaw()
						local ent = claw and (workspace:GetServerTimeNow() - bedwars.SummonerClawHandController.lastAttackTime) > bedwars.SummonerKitBalance.CLAW_COOLDOWN and (Swing.Enabled or not bedwars.SummonerKitController:isPlayerCastingSpell(lplr)) and entitylib.EntityPosition({
							Range = SwingRange.Value,
							Wallcheck = Targets.Walls.Enabled or nil,
							Part = 'RootPart',
							Players = Targets.Players.Enabled,
							Priority = Targets.Priority and Targets.Priority.Value,
							NPCs = Targets.NPCs.Enabled,
							Sort = sortmethods[Sort.Value]
						})

						if ent then
							local selfpos = entitylib.character.RootPart.Position
							local delta = ent.RootPart.Position - selfpos
							local dir = CFrame.lookAt(selfpos, ent.RootPart.Position).LookVector
							targetinfo.Targets[ent] = tick() + 1
							switchItem(claw.tool, 0)
							if delta.Magnitude <= AttackRange.Value then
								bedwars.Handler:Get('SummonerClawAttackRequest'):Fire(nil, {
									position = selfpos + dir * math.max(delta.Magnitude - 16.399, 0),
									direction = dir,
									clientTime = workspace:GetServerTimeNow()
								})
							end
							bedwars.SummonerClawHandController.lastAttackTime = workspace:GetServerTimeNow()
							bedwars.SummonerClawController:clawAttack(lplr, selfpos, dir, claw.tool.Name)
						end
					end

					task.wait(0.1)
				until not AutoKaida.Enabled
			else
				casting = 0
			end
		end,
		Tooltip = 'Attacks with Kaida\'s claw and casts her summon circle'
	})
	Targets = AutoKaida:CreateTargets({Players = true})
	local methods = {'Distance', 'Damage'}
	for _, i in sortlist do
		if not table.find(methods, i) then
			table.insert(methods, i)
		end
	end
	Sort = AutoKaida:CreateDropdown({
		Name = 'Target mode',
		List = methods,
		Tooltip = TARGET_MODE_TOOLTIP
	})
	SwingRange = AutoKaida:CreateSlider({
		Name = 'Swing Range',
		Min = 1,
		Max = 32,
		Default = 32,
		Suffix = util.Studs
	})
	AttackRange = AutoKaida:CreateSlider({
		Name = 'Attack Range',
		Min = 1,
		Max = 32,
		Default = 32,
		Suffix = util.Studs
	})
	Spell = AutoKaida:CreateGroup({
		Name = 'Auto summon',
		Function = function(callback)
			if SpellMode then
			end
		end,
		Tooltip = 'Casts the summon circle automatically'
	})
	SpellMode = Spell:CreateDropdown({
		Name = 'Summon at',
		List = {'Target', 'Camera'},
		Darker = true,
		Tooltip = 'Target - on the closest enemy\nCamera - where you look'
	})
	SpellCharge = Spell:CreateSlider({
		Name = 'Charge',
		Min = 1,
		Max = 100,
		Default = 100,
		Darker = true,
		Suffix = '%',
		Tooltip = 'How far to charge before firing'
	})
	SpellRange = Spell:CreateSlider({
		Name = 'Summon Range',
		Min = 1,
		Max = 39,
		Default = 39,
		Darker = true,
		Suffix = util.Studs,
		Tooltip = 'How far away it can summon'
	})
	Swing = AutoKaida:CreateToggle({
		Name = 'Swing during ability',
		Default = true,
		Tooltip = 'Keeps attacking while the ability charges'
	})
	Limit = AutoKaida:CreateToggle({
		Name = 'Limit to items',
		Tooltip = 'Only works while holding the item it uses'
	})
	Mouse = AutoKaida:CreateToggle({Name = 'Require mouse down'})
	GUI = AutoKaida:CreateToggle({Name = 'GUI check'})
end)
