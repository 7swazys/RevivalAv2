run(function()
	local Main = vape.Libraries.mergedModule(kits, {
		Name = 'WhimAura',
		Category = 'Aim',
		Tooltip = 'Casts spells at nearby enemies and reads nearby tomes'
	})

run(function()
	local AutoWhim
	local Targets
	local Range
	local FireRate
	local SwitchDelay
	local nextFire = 0

	local function getSpellSource()
		local util = bedwars.MageKitUtil
		local element = bedwars.BalanceFile.MAGE_ELEMENT_CYCLE[(lplr:GetAttribute('MageElementIndex') or 0) + 1]
		if not element or table.find(util.getUnlockedMageElements(lplr), element) == nil then
			element = 'BASE'
		end

		local meta = util.MageElementMeta[element]
		return meta and meta.projectileSource or nil
	end

	local function castSpell()
		local item = getItem('mage_spellbook')
		local source = item and getSpellSource() or nil
		local target = source and getFacingEntity({
			Part = 'RootPart',
			Range = Range.Value,
			Players = Targets.Players.Enabled,
			Priority = Targets.Priority and Targets.Priority.Value,
			NPCs = Targets.NPCs.Enabled,
			Wallcheck = Targets.Walls.Enabled,
			Limit = 10
		}) or nil
		if not target then return end

		local hotbar = store.hand.tool and getHotbar(store.hand.tool) or nil
		if hotbarSwitch(getHotbar(item.tool)) then
			task.wait(store.ping.total or 0)
			if fireProjectile(item, 'mage_spellbook', source.projectileType('mage_spellbook'), target) then
				nextFire = tick() + source.fireDelaySec + FireRate:GetRandomValue()
				task.wait(SwitchDelay.Value)
			end
			hotbarSwitch(hotbar)
		end
	end

	AutoWhim = Main:Part({
		Label = 'Auto cast',
		Name = 'AutoWhim',
		Function = function(callback)
			if callback then
				nextFire = 0

				repeat
					if entitylib.isAlive and store.equippedKit == 'mage' and store.hand.toolType == 'sword' and (tick() - bedwars.SwordController.lastSwing) < 0.2 and tick() >= nextFire then
						castSpell()
					end
					task.wait(0.1)
				until not AutoWhim.Enabled
			end
		end,
		Tooltip = 'Casts the magic book at your melee target'
	})
	Targets = AutoWhim:CreateTargets({
		Players = true,
		NPCs = false
	})
	Range = AutoWhim:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 22,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	FireRate = AutoWhim:CreateTwoSlider({
		Name = 'Fire Rate',
		Min = 0,
		Max = 1,
		DefaultMin = 0.05,
		DefaultMax = 0.12,
		Decimal = 100
	})
	SwitchDelay = AutoWhim:CreateSlider({
		Name = 'Switch Delay',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Suffix = 'seconds',
		Default = 0.02
	})
end)

run(function()
	local v2 = httpService
	local v3 = playersService
	local v4 = replicatedStorage
	local v5 = runService
	local v6 = inputService
	local v7 = tweenService
	local v8 = collectionService
	local v9 = guiService
	local v10 = game:GetService('TeleportService')
	local obj = debug
	local currentCamera = gameCamera
	local localPlayer = lplr
	local entity = entitylib
	local getfontbounds = getfontsize
	local getvapeasset = getcustomasset
	local LEARN_TOME_DURATION = (bedwars.BalanceFile and bedwars.BalanceFile.LEARN_TOME_DURATION) or 2

		local v12 = nil
		local v13 = nil
		local v14 = nil
		local v15 = nil
		local tbl3 = {}

		local function fn5(arg)
			local attribute = arg:GetAttribute("TomeSecret")
			local flag = not attribute

			if not flag then
				flag = (tbl3[attribute] or 0) > tick()
			end

			if flag then
				return
			end
			tbl3[attribute] = tick() + 3
			local CallServer
			local ok = pcall(function()
				CallServer = bedwars.Handler:Get("LearnElementTome"):Fire("CallServer", { secret = attribute })
			end)
			if not ok or typeof(CallServer) ~= "table" or not CallServer.element then
				return
			end
			local element = CallServer.element

			pcall(function()
				bedwars.MageController:destroyTomeGuidingBeam()
				bedwars.MageController:playLearnTomeEffect(localPlayer, arg, element)
			end)

			task.delay(LEARN_TOME_DURATION or 2, function()
				pcall(function()
					bedwars.MageController:fadeOutTome(arg)

					if localPlayer.Character then
						bedwars.MageKitUtil.changeMageKitAppearance(localPlayer, localPlayer.Character, element)
					end
				end)
			end)

			if v15.Enabled then
				notif("AutoWhimElement", ("Learned the %* element"):format(CallServer.element), 5, "info")
			end
		end

		v12 = Main:Part({
		Label = 'Read tomes',
			Name = "AutoWhimElement",
			Function = function(arg)
				if arg then
					table.clear(tbl3)

					while true do
						if entity.isAlive and store.equippedKit == "mage" then
							local position = entity.character.RootPart.Position

							for _, v16 in v8:GetTagged("ElementTome") do
								local primaryPart = v16.Parent and (not v16:IsA("Model") and v16 or v16.PrimaryPart or v16:FindFirstChildWhichIsA("BasePart", true))

								if primaryPart and (primaryPart.Position - position).Magnitude <= v13.Value then
									fn5(v16)
								end
							end
						end

						task.wait(v14.Value)
						if v12.Enabled then
							continue
						end
						break
					end
				else
					table.clear(tbl3)
				end
			end,
			Tooltip = 'Reads nearby Tomes of the Elements to unlock spells',
		})

		v13 = v12:CreateSlider({
			Name = "Tome range",
			Min = 1,
			Max = 500,
			Default = 10,
			Suffix = function(arg)
				return arg <= 1 and "stud" or "studs"
			end,
			Tooltip = 'How close a tome must be to read it',
		})

		v14 = v12:CreateSlider({
			Name = "Tome delay",
			Min = 0.1,
			Max = 5,
			Decimal = 10,
			Default = 0.5,
			Suffix = "seconds",
			Tooltip = "How often it looks for a tome",
		})

		v15 = v12:CreateToggle({ Name = "Notify", Default = true, Tooltip = "Tells you which element you picked up" })
	end)

end)
