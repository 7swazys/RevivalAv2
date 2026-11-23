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
	local CONQUEROR_FLAG_RADIUS = (bedwars.ConquerorBalance and bedwars.ConquerorBalance.CONQUEROR_FLAG_RADIUS) or 30

		local v12 = nil
		local v13 = nil
		local v14 = nil
		local tbl3 = {}
		local v15 = nil
		local v16 = nil
		local tbl4 = {}
		local n = 0
		local flag = false
		local tbl5 = { Fire = "damage_banner", Defense = "defense_banner", Heal = "heal_banner" }
		local v17

		local function fn5()
			if flag or tick() < n or not entity.isAlive then
				return
			end
			local v18 = tbl5[v17.Value]
			local v19 = getItem(tbl5[v17.Value])
			local flag2

			if v19 then
				flag2 = (v19.amount or 1) > 0
			else
				flag2 = v19
			end

			v19 = flag2 and v19 or nil
			if not v19 then
				return
			end
			local position = entity.character.RootPart.Position

			for _, v20 in v8:GetTagged("flag-kit") do
				if v20:IsA("BasePart") and v20.Name == v18 and (v20.Position - position).Magnitude <= CONQUEROR_FLAG_RADIUS / 2 then
					return
				end
			end

			local character = entity.character
			local v20 = roundPos(character.RootPart.Position - Vector3.new(0, character.HipHeight + 1.5, 0))
			local n2 = nil

			for _, v21 in {
				Vector3.new(3, 3, 0),
				Vector3.new(-3, 3, 0),
				Vector3.new(0, 3, 3),
				Vector3.new(0, 3, -3),
				Vector3.new(0, 3, 0),
			}, nil, nil do
				n2 = v20 + v21
				if not (not getPlacedBlock(n2) and getPlacedBlock(n2 - Vector3.new(0, 3, 0))) then
					n2 = nil
					continue
				end
				break
			end

			if not n2 then
				return
			end
			flag = true
			local value = v15.Value
			n = tick() + value
			local tool = v16.Enabled and store.hand.tool and getHotbar(store.hand.tool) or nil

			if not v16.Enabled or hotbarSwitch(getHotbar(v19.tool)) then
				if v16.Enabled then
					task.wait(tbl4.Value)
				end

				bedwars.placeBlock(n2, v18)

				if tool then
					task.wait(tbl4.Value)
					hotbarSwitch(tool)
				end
			end

			flag = false
		end

		v12 = vape.Categories.Kits:CreateModule({
			Name = "AutoConqueror",
			Function = function(arg)
				if arg then
					n = 0
					flag = false

					v12:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(arg2)
						if v14.Value ~= "On attack" or arg2.damageType ~= 0 or store.equippedKit ~= "vesta" then
							return
						end
						local character = localPlayer.Character

						if arg2.fromEntity and arg2.fromEntity.Name == localPlayer.Name or character and arg2.entityInstance == character then
							task.spawn(fn5)
						end
					end))

					while true do
						local flag2 = v14.Value == "On near" and entity.isAlive and store.equippedKit == "vesta"

						if flag2 then
							flag2 = entity.EntityPosition({
								Range = tbl3.Value,
								Part = "RootPart",
								Players = v13.Players.Enabled,
								NPCs = v13.NPCs.Enabled,
								Priority = v13.Priority.Value,
								Wallcheck = v13.Walls.Enabled or nil,
							})
						end

						if flag2 then
							fn5()
						end

						task.wait(0.1)
						if v12.Enabled then
							continue
						end
						break
					end
				else
					flag = false
				end
			end,
			Tooltip = 'Drops a banner beside you when a fight starts',
		})

		v13 = v12:CreateTargets({ Players = true, NPCs = false })

		v17 = v12:CreateDropdown({
			Name = "Banner",
			List = { "Fire", "Defense", "Heal" },
			Tooltip = 'Which banner to put down',
		})

		v14 = v12:CreateDropdown({
			Name = "Place on",
			List = { "On attack", "On near" },
			Function = function(arg)
				if tbl3.Object then
					tbl3.Object.Visible = arg == "On near"
				end
			end,
			Tooltip = 'On attack - when you trade hits\nOn near - when someone comes close',
		})

		tbl3 = v12:CreateSlider({
			Name = "Range",
			Min = 5,
			Max = 100,
			Default = 30,
			Darker = true,
			Visible = false,
			Suffix = function(arg)
				return arg <= 1 and "stud" or "studs"
			end,
			Tooltip = "How close an enemy has to be for On near",
		})

		v15 = v12:CreateSlider({
			Name = "Cooldown",
			Min = 1,
			Max = 60,
			Default = 30,
			Suffix = "seconds",
			Tooltip = 'Time before it puts another one down',
		})

		v16 = v12:CreateGroup({
			Name = "Legit switch",
			Function = function(visible)
				if tbl4.Object then
				end
			end,
			Tooltip = 'Visibly switches items on your hotbar',
		})

		tbl4 = v16:CreateSlider({
			Name = "Switch delay",
			Min = 0,
			Max = 1,
			Decimal = 100,
			Default = 0.08,
			Darker = true,
			Suffix = "seconds",
		})
	end)
