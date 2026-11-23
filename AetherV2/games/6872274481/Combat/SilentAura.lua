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
	local function handlerRateLimit(handler)
		if type(handler.GetRateLimit) == 'function' then
			local ok, value = pcall(handler.GetRateLimit, handler)
			if ok and tonumber(value) then return tonumber(value) end
		end
		return 60 / 0.289
	end
	local furyBalance
	local function furyMultiplier()
		if furyBalance then return furyBalance.FURY_POTION_ATTACK_SPEED_MULTIPLIER or 1 end
		local balance = bedwars.BlackMarketeerBalance
		if balance then
			furyBalance = balance
			return balance.FURY_POTION_ATTACK_SPEED_MULTIPLIER or 1
		end
		return 0.5
	end

		local v11 = nil
		local v12 = nil
		local v13 = nil
		local v14 = nil
		local v15 = nil
		local v16 = nil
		local v17 = nil
		local v18 = nil
		local v19 = nil
		local v20 = nil
		local v21 = nil
		local v22 = nil
		local v23 = nil
		local v24 = nil
		local v25 = nil
		local v26 = nil
		local v27 = nil
		local v28 = nil
		local v29 = Random.new()
		local obj2 = setmetatable({}, { __mode = "k" })
		local n = 0
		local n2 = 0
		local n3 = 0
		local v30 = nil
		local playSwordEffect = nil
		local n4 = 0.2
		local n5 = 0.296
		local n6 = 0.296
		local tbl3 = { [0.21] = 0.229, [0.25] = 0.249, [0.35] = 0.345, [0.4] = 0.341, [0.6] = 0.63 }
		local n7 = 0.03
		local n8 = 1 - furyMultiplier() - 1

		task.spawn(function()
					n4 = 60 / handlerRateLimit(bedwars.Handler:Get("SwordHit"))
		end)

		local boxHandleAdornment = Instance.new("BoxHandleAdornment")
		boxHandleAdornment.Adornee = nil
		boxHandleAdornment.AlwaysOnTop = true
		boxHandleAdornment.Size = Vector3.new(3, 5, 3)
		boxHandleAdornment.CFrame = CFrame.new(0, -0.5, 0)
		boxHandleAdornment.ZIndex = 0
		boxHandleAdornment.Parent = vape.gui

		v11 = vape.Categories.Combat:CreateModule({
			Name = "SilentAura",
			Function = function(arg)
				if arg then
					local playSwordEffect2 = bedwars.SwordController.playSwordEffect
					v30 = playSwordEffect2

					playSwordEffect = function(arg2, arg3, arg4, arg5)
						if not v11.Enabled then
							return playSwordEffect2(arg2, arg3, arg4, arg5)
						end
						local n9 = v24.Enabled and 0.11 or math.max(v23.Value, 0.11)
						if (tick() - n2 < 0.4 or tick() - n3 < 0.4) and tick() - n < n9 then
							return
						end
						n = tick()
						return playSwordEffect2(arg2, arg3, arg4, arg5)
					end

					bedwars.SwordController.playSwordEffect = playSwordEffect
					local swingSync = bedwars.SyncEvents and bedwars.SyncEvents.SwordSwing
					if swingSync then
						local swingConnection = swingSync:setPriority(150):connect(function(event)
							if tick() - n2 < 0.4 and event.config and event.config.respectAttackSpeedOverride then
								event.config.respectAttackSpeedOverride = nil
							end
						end)
						v11:Clean(function() swingConnection:Destroy() end)
					end
					local v31 = nil
					local n9 = 0
					local now = tick()
					local now2 = tick()

					v11:Clean(v5.PostSimulation:Connect(function(deltaTime)
						if entity.isAlive and v31 and v31.RootPart and v31.RootPart.Parent and tick() - n9 < 0.5 then
							targetinfo.Targets[v31] = tick() + 0.5
							if entity.character.Humanoid.AutoRotate == v22.Enabled then entity.character.Humanoid.AutoRotate = not v22.Enabled end
							local n10 = 1 / v13.Value * 0.5
							local n11 = math.min((tick() - now) / n10, 1)
							local n12 = v13.Value * (n11 < 0.5 and 4 * n11 * n11 * n11 or 1 - math.pow(-2 * n11 + 2, 3) / 2)
							local position = v31.RootPart.Position

							if v17.Value == "Closest" then
								if not obj2[v31.Character] then
									obj2[v31.Character] = v31.Character:GetChildren()
								end

								local mouseLocation = v6:GetMouseLocation()
								local n13 = 9e9

								for _, v32 in obj2[v31.Character], nil, nil do
									if v32 and v32.Parent and v32:IsA("BasePart") then
										local v33, v34 = currentCamera:WorldToViewportPoint(v32.Position)

										if v34 then
											local magnitude = (mouseLocation - Vector2.new(v33.X, v33.Y)).Magnitude

											if magnitude < n13 then
												position = v32.Position
												n13 = magnitude
											end
										end
									end
								end
							end

							local v32 = currentCamera.CFrame:Lerp(CFrame.lookAt(currentCamera.CFrame.p, position + Vector3.new((v29:NextNumber() - 0.5) * 15 * deltaTime, (v29:NextNumber() - 0.5) * 15 * deltaTime, (v29:NextNumber() - 0.5) * 15 * deltaTime)), n12 * deltaTime)

							if v22.Enabled then
								local rootPart = entity.character.RootPart
								local vector = Vector3.new(v31.RootPart.Position.X - rootPart.Position.X, 0, v31.RootPart.Position.Z - rootPart.Position.Z)

								if vector.Magnitude > 0 then
									rootPart.CFrame = rootPart.CFrame:Lerp(CFrame.lookAlong(rootPart.Position, vector), math.clamp((n12 + 2) * deltaTime, 0, 1))
								end
							else
								currentCamera.CFrame = v32
							end
						elseif entity.isAlive and not entity.character.Humanoid.AutoRotate then
							entity.character.Humanoid.AutoRotate = true
						end
					end))

					local n10 = 0
					local n11 = 0
					local now3 = nil

					local function fn5()
						while true do
							task.wait()
							local flag = not entity.isAlive

							if not flag then
								flag = v19.Enabled and not v6:IsMouseButtonPressed(0)

								if flag then
									flag = bedwars.SwordController.lastSwing == now3

									if not flag then
										local lastSwing = bedwars.SwordController.lastSwing
										flag = tick() - lastSwing > 0.3
									end
								end
							end

							if not flag then
								flag = v18.Enabled

								if flag then
									local lastSwing = bedwars.SwordController.lastSwing
									flag = tick() - lastSwing > 0.3
								end
							end

							if not flag then
								flag = (localPlayer.Character:GetAttribute("StunnedUntilTime") or 0) - workspace:GetServerTimeNow() > 0
							end

							flag = flag or bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN)
							local hand = nil
							local v32 = nil

							if not flag then
								hand = v21.Enabled and store.hand or store.tools.sword

								if not hand or not hand.tool then
									hand = nil
									v32 = nil
								elseif v21.Enabled and (store.hand.toolType ~= "sword" or (bedwars.DaoController and bedwars.DaoController.chargingMaid)) then
									hand = nil
									v32 = nil
								else
									v32 = bedwars.ItemMeta[hand.tool.Name]
								end
							end

							if hand then
								local position = entity.character.RootPart.Position

								local v33 = entity.EntityPosition({
									Origin = position,
									Range = bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE + v14.Value,
									Wallcheck = v12.Walls.Enabled or nil,
									Part = "RootPart",
									Players = v12.Players.Enabled,
									NPCs = v12.NPCs.Enabled,
									Priority = v12.Priority.Value,
									Sort = sortmethods[v16.Value or "Distance"],
								})

								local flag2 = tick() - now2 < 0.1 and v28 or v27
								boxHandleAdornment.Adornee = v26.Enabled and v33 and v33.RootPart or nil
								boxHandleAdornment.Transparency = 1 - flag2.Opacity
								boxHandleAdornment.Color3 = Color3.fromHSV(flag2.Hue, flag2.Sat, flag2.Value)

								if v33 then
									local keyboardEnabled, n12, n13, n14, n15, flag3, lastSwing, n16, attackSpeed, flag4, now4, attackSpeed2, attribute, flag5, n17, n18, n19, n20, n21, n22, n23, flag6, flag7, lookVector, n24, flag8

									if not store.hand or store.hand.tool ~= hand.tool then
										local v34 = getHotbar(hand.tool)

										if v34 then
											hotbarSwitch(v34)

											if store.hand.tool == hand.tool then
												keyboardEnabled = v6.KeyboardEnabled and currentCamera or entity.character.RootPart
												n12 = keyboardEnabled.CFrame.LookVector * Vector3.new(1, 0, 1)
												n13 = v33.RootPart.Position - position
												n14 = (v33.RootPart.Position - position) * Vector3.new(1, 0, 1)
												n15 = n14.Magnitude > 0 and n12.Magnitude > 0 and (n12 / n12.Magnitude):Dot(n14 / n14.Magnitude) or 0

												if not (n15 < math.cos(math.rad(v15.Value) / 2)) then
													flag3 = not v18.Enabled and not (v24.Enabled and n13.Magnitude <= bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE)

													if flag3 then
														lastSwing = bedwars.SwordController.lastSwing
														n16 = tick() - lastSwing
														attackSpeed = v24.Enabled and math.max(bedwars.swordSpeed(hand.tool.Name, v32 and v32.sword and v32.sword.attackSpeed or 0.3), 0.11) or math.max(v23.Value, 0.11)
														flag3 = n16 >= attackSpeed
													end

													if flag3 then
														now3 = tick()
														n3 = now3
														bedwars.swingEffect(v32)
														bedwars.SwordController.lastSwing = now3
													end

													flag4 = v31 ~= v33 or n15 < -0.5

													if flag4 then
														now = tick()
													end

													now4 = tick()
													v31 = v33
													n9 = now4

													if not (bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE < n13.Magnitude) then
														now2 = tick()
														attackSpeed2 = v32 and v32.sword and v32.sword.attackSpeed or 0.3
														attribute = bedwars.swordSpeed(hand.tool.Name, attackSpeed2) / attackSpeed2
														flag5 = attackSpeed2 == 0.3
														n17 = flag5 and n5 or tbl3[attackSpeed2] or attackSpeed2 + n7
														n18 = n17 * attribute
														n19 = attackSpeed2 * attribute - 0.015211999922513961
														flag5 = flag5 and n6 * attribute or n18
														n20 = math.max(n4, n18, bedwars.SwordController.lastAttack + n19 - workspace:GetServerTimeNow())

														if v20.Enabled then
															n21 = math.max(getReach(hand.tool), 0.001)
															n22 = math.clamp(n20 * math.min((entity.character.RootPart.Position - v33.RootPart.Position).Magnitude, n21) / n21, flag5, n20)
														else
															n22 = n20
														end

														n23 = n10 + n22
														flag6 = tick() >= n23 and tick() - n11 >= flag5

														if flag6 then
															flag7 = v33.Humanoid and v33.Humanoid.FloorMaterial == Enum.Material.Air or math.abs(v33.RootPart.AssemblyLinearVelocity.Y) > 0.01
															lookVector = CFrame.lookAt(position, v33.RootPart.Position).LookVector
															n24 = position + lookVector * math.max(n13.Magnitude - getReach(hand.tool) - 0.001, 0)
															bedwars.SwordController.lastAttack = workspace:GetServerTimeNow()
															if v24.Enabled and not v18.Enabled then
																now3 = tick()
																n3 = now3
																bedwars.swingEffect(v32)
																bedwars.SwordController.lastSwing = now3
															end
															n2 = tick()
															n10 = math.max(n10 + n22, tick())
															n11 = tick()
															flag8 = not flag7 or v29:NextNumber(0, 100) <= v25:GetRandomValue()

															if flag8 then
																bedwars.Handler:Get("SwordHit"):Fire("SendToServer", {
																	weapon = hand.tool,
																	chargedAttack = { chargeRatio = 0 },
																	entityInstance = v33.Character,
																	validate = {
																		raycast = {
																			cameraPosition = { value = currentCamera.CFrame.Position },
																			cursorDirection = { value = lookVector },
																		},
																		targetPosition = { value = v33.Character:GetPivot().Position },
																		selfPosition = { value = n24 },
																	},
																})
															end
														end
													end
												end
											end
										end
									elseif store.hand.tool == hand.tool then
										keyboardEnabled = v6.KeyboardEnabled and currentCamera or entity.character.RootPart
										n12 = keyboardEnabled.CFrame.LookVector * Vector3.new(1, 0, 1)
										n13 = v33.RootPart.Position - position
										n14 = (v33.RootPart.Position - position) * Vector3.new(1, 0, 1)
										n15 = n14.Magnitude > 0 and n12.Magnitude > 0 and (n12 / n12.Magnitude):Dot(n14 / n14.Magnitude) or 0

										if not (n15 < math.cos(math.rad(v15.Value) / 2)) then
											flag3 = not v18.Enabled and not (v24.Enabled and n13.Magnitude <= bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE)

											if flag3 then
												lastSwing = bedwars.SwordController.lastSwing
												n16 = tick() - lastSwing
												attackSpeed = v24.Enabled and math.max(bedwars.swordSpeed(hand.tool.Name, v32 and v32.sword and v32.sword.attackSpeed or 0.3), 0.11) or math.max(v23.Value, 0.11)
												flag3 = n16 >= attackSpeed
											end

											if flag3 then
												now3 = tick()
												n3 = now3
												bedwars.swingEffect(v32)
												bedwars.SwordController.lastSwing = now3
											end

											flag4 = v31 ~= v33 or n15 < -0.5

											if flag4 then
												now = tick()
											end

											now4 = tick()
											v31 = v33
											n9 = now4

											if not (bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE < n13.Magnitude) then
												now2 = tick()
												attackSpeed2 = v32 and v32.sword and v32.sword.attackSpeed or 0.3
												attribute = bedwars.swordSpeed(hand.tool.Name, attackSpeed2) / attackSpeed2
												flag5 = attackSpeed2 == 0.3
												n17 = flag5 and n5 or tbl3[attackSpeed2] or attackSpeed2 + n7
												n18 = n17 * attribute
												n19 = attackSpeed2 * attribute - 0.015211999922513961
												flag5 = flag5 and n6 * attribute or n18
												n20 = math.max(n4, n18, bedwars.SwordController.lastAttack + n19 - workspace:GetServerTimeNow())

												if v20.Enabled then
													n21 = math.max(getReach(hand.tool), 0.001)
													n22 = math.clamp(n20 * math.min((entity.character.RootPart.Position - v33.RootPart.Position).Magnitude, n21) / n21, flag5, n20)
												else
													n22 = n20
												end

												n23 = n10 + n22
												flag6 = tick() >= n23 and tick() - n11 >= flag5

												if flag6 then
													flag7 = v33.Humanoid and v33.Humanoid.FloorMaterial == Enum.Material.Air or math.abs(v33.RootPart.AssemblyLinearVelocity.Y) > 0.01
													lookVector = CFrame.lookAt(position, v33.RootPart.Position).LookVector
													n24 = position + lookVector * math.max(n13.Magnitude - getReach(hand.tool) - 0.001, 0)
													bedwars.SwordController.lastAttack = workspace:GetServerTimeNow()
													if v24.Enabled and not v18.Enabled then
														now3 = tick()
														n3 = now3
														bedwars.swingEffect(v32)
														bedwars.SwordController.lastSwing = now3
													end
													n2 = tick()
													n10 = math.max(n10 + n22, tick())
													n11 = tick()
													flag8 = not flag7 or v29:NextNumber(0, 100) <= v25:GetRandomValue()

													if flag8 then
														bedwars.Handler:Get("SwordHit"):Fire("SendToServer", {
															weapon = hand.tool,
															chargedAttack = { chargeRatio = 0 },
															entityInstance = v33.Character,
															validate = {
																raycast = {
																	cameraPosition = { value = currentCamera.CFrame.Position },
																	cursorDirection = { value = lookVector },
																},
																targetPosition = { value = v33.Character:GetPivot().Position },
																selfPosition = { value = n24 },
															},
														})
													end
												end
											end
										end
									end
								else
									n9 = 0
								end
							else
								boxHandleAdornment.Adornee = nil
								n9 = 0
							end

							if v11.Enabled then
								continue
							end
							break
						end
					end

					fn5()
				else
					if bedwars.SwordController.playSwordEffect == playSwordEffect then
						bedwars.SwordController.playSwordEffect = v30
					end

					v30 = nil
					playSwordEffect = nil
					n = 0
					n2 = 0
					n3 = 0

					if entity.isAlive then
						entity.character.Humanoid.AutoRotate = true
					end

					boxHandleAdornment.Adornee = nil
				end
			end,
			Tooltip = "Automatically aims and attacks nearby target",
		})

		v12 = v11:CreateTargets({ Players = true, NPCs = true })

		v13 = v11:CreateSlider({
			Name = "Aim speed",
			Min = 1,
			Max = 10,
			Default = 6,
			Decimal = 5,
			Tooltip = 'How fast it aims',
		})


		v14 = v11:CreateSlider({
			Name = "Extra swing distance",
			Tooltip = 'How far away it starts swinging',
			Min = 0,
			Max = 6,
			Suffix = function(arg)
				return arg <= 1 and "stud" or "studs"
			end,
			Decimal = 5,
			Default = 3,
		})

		v15 = v11:CreateSlider({ Name = "Max angle", Min = 1, Max = 360, Default = 180 })

		v25 = v11:CreateTwoSlider({
			Name = "Air hit chance",
			Min = 0,
			Max = 100,
			DefaultMin = 100,
			DefaultMax = 100,
			Tooltip = 'Chance to attack a target that is in the air',
		})

		local tbl4 = { "Lowest Health", "Damage", "Distance" }

		for _, v31 in sortlist, nil, nil do
			if not table.find(tbl4, v31) then
				table.insert(tbl4, v31)
			end
		end

		v16 = v11:CreateDropdown({
			Name = "Target mode",
			Default = "Lowest Health",
			List = tbl4,
			Tooltip = 'Who to prefer when several targets are in range',
		})


		v24 = v11:CreateToggle({
			Name = "Perfect Swing",
			Function = function(arg)
				if v23 then v23.Object.Visible = not arg end
			end,
			Default = true,
			Tooltip = 'Matches the sword\'s swing time',
		})
		v23 = v11:CreateSlider({
			Name = "Swing time",
			Darker = true,
			Visible = false,
			Min = 0,
			Max = 0.5,
			Default = 0.42,
			Decimal = 100,
		})

		v19 = v11:CreateToggle({ Name = "Require mouse down" })

		v20 = v11:CreateToggle({
			Name = "Dynamic hits",
			Function = function(arg)
				n5 = arg and 0.2925 or 0.296
				n6 = arg and 0.2925 or 0.296
			end,
			Default = true,
			Tooltip = 'Attacks slightly faster but can miss the odd hit',
		})

		v18 = v11:CreateToggle({ Name = "Swing only" })

		v22 = v11:CreateToggle({
			Name = "Silent Aim",
			Function = function(arg)
				if v17 then v17.Object.Visible = not arg end
			end,
			Default = true,
			Tooltip = 'Silently aims while looking legit',
		})
		v17 = v11:CreateDropdown({
			Name = "Target area",
			List = { "Center", "Closest" },
			Default = "Center",
			Visible = false,
			Tooltip = 'Where it aims',
		})

		v26 = v11:CreateGroup({
			Name = "Show target",
			Default = true,
		})

		v27 = v26:CreateColorSlider({ Name = "Target color", Darker = true, DefaultOpacity = 0.5, DefaultHue = 1 })
		v28 = v26:CreateColorSlider({ Name = "Attack color", Darker = true, DefaultOpacity = 0.5 })
		v21 = v11:CreateToggle({ Name = "Limit to items" })
	end)
