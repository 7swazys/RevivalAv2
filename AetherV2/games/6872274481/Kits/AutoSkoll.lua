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
	local VOID_HUNTER_MARK_DURATION = (bedwars.VoidHunterBalance and bedwars.VoidHunterBalance.MARK_DURATION) or 6

		local v12 = nil
		local v13 = nil
		local v14 = nil
		local v15 = nil
		local v16 = nil
		local tbl3 = {}
		local tbl4 = {}
		local tbl5 = {}
		local onAbilityUsed = nil

		local function fn5()
			return entity.EntityPosition({
				Range = v15.Value,
				Part = "RootPart",
				Players = v13.Players.Enabled,
				NPCs = v13.NPCs.Enabled,
				Priority = v13.Priority.Value,
				Wallcheck = v13.Walls.Enabled or nil,
				Sort = sortmethods[v14.Value],
			})
		end

		local function fn6()
			if not v16.Enabled then
				return false
			end
			local n = nil
			local v17 = nil

			for k, v18 in tbl5, nil, nil do
				if k.Parent and tick() < v18 then
					local humanoid = k:FindFirstChildWhichIsA("Humanoid")

					if humanoid and humanoid.MaxHealth > 0 then
						n = (humanoid.Health + getShieldAttribute(k)) / humanoid.MaxHealth * 100
						v17 = v18
						break
					else
						n = nil
						v17 = nil
					end
				else
					n = nil
					v17 = nil
				end
			end

			if tbl3.Value == "Instantly" then
				return true
			end

			if not n then
				return false
			end

			if tbl3.Value == "Low health" then
				return n <= tbl4.Value
			end
			return tick() >= v17 - 1
		end

		local v17

		v12 = vape.Categories.Kits:CreateModule({
			Name = "AutoSkoll",
			Function = function(arg)
				if arg then
					table.clear(tbl5)
					local voidHunterController = bedwars.VoidHunterKitController

					if voidHunterController then
						onAbilityUsed = voidHunterController.onAbilityUsed

						voidHunterController.onAbilityUsed = function(arg2, arg3, arg4, ...)
							if v17.Enabled and arg4 and arg4.ability == "void_hunter_mark" and arg3 == localPlayer.Character and arg3.PrimaryPart then
								local v18 = fn5()

								if v18 then
									local position = arg3.PrimaryPart.Position
									local n = v18.RootPart.Position - position
									if n.Magnitude > 0 then
										pcall(function()
											bedwars.Handler:Get("VoidHunter_MarkAbilityRequest"):Fire("SendToServer", { originPosition = position, direction = n.Unit })
										end)
										return
									end
								end
							end

							local v18 = onAbilityUsed
							if not v18 then return end
							local v19 = table.pack(...)
							v19.n = 4 + v19.n - 1
							table.move(v19, 1, v19.n, 4, v19)
							v19[1] = arg2
							v19[2] = arg3
							v19[3] = arg4
							return v18(table.unpack(v19, 1, v19.n))
						end
					end

					local markedRemote = bedwars.Handler:Get("VoidHunter_TargetMarked").Remote
					if markedRemote then
						v12:Clean(markedRemote:Connect(function(arg2)
							if arg2.userPlayer == localPlayer and arg2.targetEntityInstance then
								local markDuration = VOID_HUNTER_MARK_DURATION
								tbl5[arg2.targetEntityInstance] = tick() + markDuration
							end
						end))
					end

					local removedRemote = bedwars.Handler:Get("VoidHunter_TargetMarkRemoved").Remote
					if removedRemote then
						v12:Clean(removedRemote:Connect(function(arg2)
							if arg2.userPlayer == localPlayer and arg2.targetEntityInstance then
								tbl5[arg2.targetEntityInstance] = nil
							end
						end))
					end

					while true do
						if entity.isAlive and store.equippedKit == "void_hunter" then
							if fn6() and bedwars.AbilityController:canUseAbility("void_hunter_detonate", { disableBlockedAbilityAlert = true }) then
								bedwars.AbilityController:useAbility("void_hunter_detonate")
								table.clear(tbl5)
							elseif fn5() and bedwars.AbilityController:canUseAbility("void_hunter_mark", { disableBlockedAbilityAlert = true }) then
								bedwars.AbilityController:useAbility("void_hunter_mark")
							end
						end

						task.wait(0.1)
						if v12.Enabled then
							continue
						end
						break
					end
				else
					table.clear(tbl5)

					if onAbilityUsed then
						local voidHunterController = bedwars.VoidHunterKitController
						if voidHunterController then voidHunterController.onAbilityUsed = onAbilityUsed end
						onAbilityUsed = nil
					end
				end
			end,
			Tooltip = 'Sends Fenrir at nearby enemies and sets the mark off',
		})

		v13 = v12:CreateTargets({ Players = true, NPCs = false })
		local tbl6 = { "Distance", "Lowest Health" }

		for _, v18 in sortlist, nil, nil do
			if not table.find(tbl6, v18) then
				table.insert(tbl6, v18)
			end
		end

		v14 = v12:CreateDropdown({ Name = "Target mode", List = tbl6 })

		v15 = v12:CreateSlider({
			Name = "Range",
			Min = 1,
			Max = 100,
			Default = 50,
			Suffix = function(arg)
				return arg <= 1 and "stud" or "studs"
			end,
			Tooltip = 'How far away a target can be',
		})

		v17 = v12:CreateToggle({
			Name = "Aim wolf",
			Default = true,
			Tooltip = 'Throws Fenrir at your target instead of where you look',
		})

		v16 = v12:CreateGroup({
			Name = "Auto detonate",
			Function = function(visible)
				if tbl3 and tbl3.Object then
					if tbl3 and tbl4 then tbl4.Object.Visible = visible and tbl3.Value == "Low health" end
				end
			end,
			Default = true,
			Tooltip = 'Sets the mark off',
		})

		tbl3 = v16:CreateDropdown({
			Name = "Detonate at",
			List = { "Low health", "Instantly", "Before it expires" },
			Darker = true,
			Function = function(arg)
				if tbl4.Object then
					tbl4.Object.Visible = v16.Enabled and arg == "Low health"
				end
			end,
			Tooltip = 'When to set the mark off',
		})

		tbl4 = v12:CreateSlider({
			Name = "Health",
			Min = 1,
			Max = 100,
			Default = 30,
			Darker = true,
			Visible = false,
			Suffix = "%",
			Tooltip = 'Sets the mark off when they drop under this health',
		})
	end)
