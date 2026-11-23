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

		local v12 = nil
		local v13 = nil
		local v14 = nil
		local v15 = nil
		local v16 = nil
		local tbl3 = { "telepearl", "boba_pearl", "teleport_hat" }
		local raycastParams = RaycastParams.new()
		raycastParams.RespectCanCollide = true

		v12 = vape.Categories.Legit:CreateModule({
			Name = "BedAlarm",
			Category = "Game",
			Function = function(arg)
				if arg then
					local obj2 = setmetatable({}, { __mode = "k" })
					local n = 0

					local v17 = bedwars.SyncEvents.ProjectileLaunched:connect(function(arg2)
						if not v14.Enabled or not table.find(tbl3, arg2.projectileType) or typeof(arg2.origin) ~= "Vector3" or typeof(arg2.launchVelocity) ~= "Vector3" then
							return
						end
						local v17 = entity.getEntity(arg2.shooter)
						local isAlive = v17 and v17.Targetable and entity.isAlive
						local v18 = nil

						if isAlive then
							v18 = nil

							for _, v19 in v8:GetTagged("bed") do
								if tonumber(v19:GetAttribute("TeamId")) == tonumber(localPlayer:GetAttribute("Team")) then
									v18 = v19
									break
								else
									v18 = nil
								end
							end
						end

						if not v18 or os.clock() < n then
							return
						end
						local v19 = bedwars.ProjectileMeta[arg2.projectileType]
						local vector = Vector3.new(0, -(v19 and v19.gravitationalAcceleration or 196.2), 0)
						local filterDescendantsInstances = { arg2.shooter }

						for _, v20 in entity.List, nil, nil do
							table.insert(filterDescendantsInstances, v20.Character)
						end

						raycastParams.FilterDescendantsInstances = filterDescendantsInstances
						local origin = arg2.origin

						for i = 1, 100 do
							local n2 = i * 0.05
							local n3 = arg2.origin + arg2.launchVelocity * n2 + vector * 0.5 * n2 * n2
							local v20 = workspace:Raycast(origin, n3 - origin, raycastParams)

							if v20 then
								origin = v20.Position
								break
							else
								origin = n3
							end
						end

						if v15.Value < (origin - v18.Position).Magnitude then
							return
						end
						n = os.clock() + 3.05

						if v13.Enabled and v17.Player and not obj2[v17.Character] then
							obj2[v17.Character] = true
							bedwars.BedAlarmController:addIntruderPlayerHighlight(v17.Player)
						end

						bedwars.NotificationController:sendInfoNotification({ message = "[Bed Alarm]: An intruder pearled to your bed!" })
						local flag = (entity.character.RootPart.Position - v18.Position).Magnitude < 30
						bedwars.AudioManager:playAudio(flag and bedwars.SoundList.BED_ALARM or bedwars.SoundList.BED_ALARM_TRIGGERED_FAR, { volumeMultiplier = v16.Value, position = flag and v18.Position or nil, rollOffMaxDistance = 100 })
					end)

					v12:Clean(function()
						v17:Destroy()
					end)
					;(function(...) end)()
				end
			end,
			Tooltip = "Notifies when an enemy is near your bed",
		})

		v13 = v12:CreateToggle({
			Name = "Highlight intruders",
			Default = true,
			Tooltip = 'Outlines intruders through walls',
		})

		v14 = v12:CreateToggle({
			Name = "Pearl detection",
			Default = true,
			Tooltip = 'Also warns you of pearls landing at your bed',
		})

		v15 = v12:CreateSlider({
			Name = "Range",
			Min = 1,
			Max = 100,
			Default = 70,
			Suffix = function(arg)
				return arg == 1 and "stud" or "studs"
			end,
		})

		v16 = v12:CreateSlider({ Name = "Volume multiplier", Min = 0.1, Max = 2, Default = 1.4, Decimal = 100 })
	end)
