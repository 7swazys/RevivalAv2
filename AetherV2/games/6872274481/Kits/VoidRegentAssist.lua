run(function()
	local Main = vape.Libraries.mergedModule(kits, {
		Name = 'VoidRegentAssist',
		Category = 'Ability',
		Tooltip = 'Dashes you back to ground and slams before landing'
	})

run(function()

	local util = vape.Libraries.bedwarsutil
	local VoidRegentAutoClutch
	local Range
	local FaceGround
	local lastClutch = 0

	VoidRegentAutoClutch = Main:Part({
		Label = 'Void clutch',
		Name = 'VoidRegentAutoClutch',
		Category = 'Ability',
		Function = function(callback)
			if callback then
				VoidRegentAutoClutch:Clean(runService.Heartbeat:Connect(function()
					if entitylib.isAlive and store.equippedKit == 'regent' and store.airRay and tick() >= lastClutch and bedwars.VoidAxeController then
						local root = entitylib.character.RootPart
						if store.inVoid(root) and bedwars.AbilityController:canUseAbility('void_axe_jump', {disableBlockedAbilityAlert = true}) then
							local ground = getNearGround(Range.Value / 3)
							local delta = ground and (ground - root.Position) * Vector3.new(1, 0, 1)
							if delta and delta.Magnitude > 0 then
								lastClutch = tick() + 0.5
								if FaceGround.Enabled then
									root.CFrame = CFrame.lookAt(root.Position, root.Position + delta.Unit)
								end
								bedwars.VoidAxeController:useVoidAxe()
							end
						end
					end
				end))
			end
		end,
		Tooltip = 'Dashes you back to ground when you fall off the map'
	})
	Range = VoidRegentAutoClutch:CreateSlider({
		Name = 'Range',
		Min = 10,
		Max = 60,
		Default = 45,
		Suffix = util.Studs,
		Tooltip = 'How far to look for ground to dash back to'
	})
	FaceGround = VoidRegentAutoClutch:CreateToggle({
		Name = 'Face ground',
		Default = true,
		Tooltip = 'Faces the ground before dashing'
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
	local VOID_AXE_COOLDOWN = (bedwars.VoidRegentBalance and bedwars.VoidRegentBalance.AXE_COOLDOWN) or 6

		local v12 = nil
		local v13 = nil
		local v14 = nil
		local v15 = nil
		local tbl3 = {}
		local v16 = nil
		local n = 0

		local function fn5(arg)
			if store.hand.tool ~= arg.tool then
				if v15.Enabled then
					hotbarSwitch(getHotbar(arg.tool))
				else
					switchItem(arg.tool, 0)
				end

				task.wait(tbl3.Value)
			end

			if v12.Enabled and entity.isAlive and bedwars.AbilityController:canUseAbility("void_axe_jump", { disableBlockedAbilityAlert = true }) then
				bedwars.VoidAxeController:useVoidAxe()
			end
		end

		v12 = Main:Part({
		Label = 'Auto slam',
			Name = "AutoVoidRegent",
			Function = function(arg)
				if arg then
					n = 0

					v12:Clean(v5.Heartbeat:Connect(function()
						if not entity.isAlive or store.equippedKit ~= "regent" or tick() < n or not bedwars.VoidAxeController then
							return
						end
						local rootPart = entity.character.RootPart
						if -v14.Value < rootPart.AssemblyLinearVelocity.Y then
							return
						end

						if not bedwars.AbilityController:canUseAbility("void_axe_jump", { disableBlockedAbilityAlert = true }) then
							return
						end
						local airRay = store.airRay
						if not workspace:Raycast(rootPart.Position, Vector3.new(0, -v13.Value, 0), airRay) then
							return
						end
						local hand

						if store.hand.tool and store.hand.tool.Name == "void_axe" then
							hand = store.hand
						else
							hand = nil

							if not v16.Enabled then
								hand = getItem("void_axe")
							end
						end

						if not hand then
							return
						end
						local axeCooldown = VOID_AXE_COOLDOWN
						n = tick() + axeCooldown
						task.spawn(fn5, hand)
					end))
				end
			end,
			Tooltip = "Slams the void axe down right before you land",
		})

		v13 = v12:CreateSlider({
			Name = "Height",
			Min = 3,
			Max = 60,
			Default = 15,
			Suffix = function(arg)
				return arg <= 1 and "stud" or "studs"
			end,
			Tooltip = "Slams once the ground is this close beneath you",
		})

		v14 = v12:CreateSlider({
			Name = "Slam fall speed",
			Min = 0,
			Max = 100,
			Default = 10,
			Tooltip = "Only slams once you are dropping this fast",
		})

		v15 = v12:CreateGroup({
			Name = "Legit switch",
			Function = function(visible)
				if tbl3.Object then
				end
			end,
			Tooltip = 'Visibly switches items on your hotbar',
		})

		tbl3 = v15:CreateSlider({
			Name = "Switch delay",
			Min = 0,
			Max = 1,
			Decimal = 100,
			Default = 0.05,
			Darker = true,
			Suffix = "seconds",
		})

		v16 = v12:CreateToggle({ Name = "Limit to items", Tooltip = 'Only works while holding the item it uses' })
	end)

end)
