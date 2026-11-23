run(function()

	local util = vape.Libraries.bedwarsutil
	local BlockReach
		local BlockRange
		local BreakReach
		local BreakRange
		local SwordReach
		local SwordRange
		local AirHits
		local oldSend, sendHook
		local rng = Random.new()

		local old
		local hook

		Reach = vape.Categories.Combat:CreateModule({
			Name = 'Reach',
			ExtraText = function() return tostring(SwordRange.Value) end,
			Tooltip = 'Lets you hit, place and mine from further away',
			Function = function(callback)
				bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = callback and SwordReach.Enabled and SwordRange.Value + 2 or 14.4
				if callback then
					if hook then return end
					old = bedwars.BlockSelector.getMouseInfo
					hook = function(...)
						local Self, Select, Args = ...
						if not Reach.Enabled then
							return old(...)
						end
						local range
						if Select == 0 and BlockReach.Enabled then
							range = BlockRange.Value
						elseif Select == 1 and BreakReach.Enabled then
							range = BreakRange.Value
						end
						if range ~= nil then
							Args = Args or {}
							Args.range = range
						end
						return old(Self, Select, Args)
					end
					bedwars.BlockSelector.getMouseInfo = hook
					local controller = bedwars.SwordController
					if not sendHook and controller and type(controller.sendServerRequest) == 'function' then
						oldSend = controller.sendServerRequest
						sendHook = function(self, ent, ...)
							if Reach.Enabled and SwordReach.Enabled and entitylib.isAlive then
								local ok, blocked = pcall(function()
									local character = ent and ent:getInstance()
									local root = character and character.PrimaryPart
									if not root then return false end
									local humanoid = character:FindFirstChildWhichIsA('Humanoid')
									local airborne = (humanoid and humanoid.FloorMaterial == Enum.Material.Air) or math.abs(root.AssemblyLinearVelocity.Y) > 0.01
									return airborne and (root.Position - entitylib.character.RootPart.Position).Magnitude > getReach(self:getHandItem().tool) and rng:NextNumber(0, 100) > AirHits:GetRandomValue()
								end)
								if ok and blocked then return end
							end
							return oldSend(self, ent, ...)
						end
						controller.sendServerRequest = sendHook
					end
				else
					if bedwars.BlockSelector.getMouseInfo == hook then
						bedwars.BlockSelector.getMouseInfo = old
						hook = nil
						old = nil
					end
					local controller = bedwars.SwordController
					if sendHook and controller and controller.sendServerRequest == sendHook then
						controller.sendServerRequest = oldSend
						sendHook, oldSend = nil, nil
					end
				end
			end,
		})
		SwordReach = Reach:CreateGroup({
			Name = 'Sword Reach',
			Default = true,
			Function = function(callback)
				if SwordRange then bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = Reach.Enabled and callback and SwordRange.Value + 2 or 14.4 end
			end,
		})
		SwordRange = SwordReach:CreateSlider({
			Name = 'Sword Range',
			Min = 1,
			Max = 18,
			Default = 18,
			Decimal = 5,
			Darker = true,
			Suffix = util.Studs,
			Function = function(val)
				bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = Reach.Enabled and SwordReach.Enabled and val + 2 or 14.4
			end,
		})
		AirHits = SwordReach:CreateTwoSlider({
			Name = 'Air reach hit chance',
			Min = 0,
			Max = 100,
			DefaultMin = 100,
			DefaultMax = 100,
			Suffix = '%',
			Tooltip = 'Chance for a hit past normal reach to go through while the target is in the air'
		})
		BlockReach = Reach:CreateGroup({
			Name = 'Placement Reach',
		})
		BlockRange = BlockReach:CreateSlider({
			Name = 'Placement Range',
			Min = 1,
			Max = 60,
			Default = 18,
			Darker = true,
			Suffix = util.Studs,
		})
		BreakReach = Reach:CreateGroup({
			Name = 'Break Reach',
		})
		BreakRange = BreakReach:CreateSlider({
			Name = 'Break Range',
			Min = 1,
			Max = 30,
			Default = 30,
			Decimal = 5,
			Darker = true,
			Suffix = util.Studs,
		})
		Reach:CreateButton({
			Name = 'Reset to default reach',
			Tooltip = 'Sets every range back to the game\'s default',
			Function = function()
				BreakRange:SetValue(18)
				BlockRange:SetValue(24)
				SwordRange:SetValue(12.4)
			end,
		})
	end)
