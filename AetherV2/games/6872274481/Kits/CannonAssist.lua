run(function()
	local Main = vape.Libraries.mergedModule(kits, {
		Name = 'CannonAssist',
		Category = 'Ability',
		Tooltip = 'Breaks the cannon or jumps on launch, and changes launch speed'
	})

run(function()
	local AutoDavey
	local Switch
	local Break
	local Jump
	local LimitItem

	local old, oldAim

	local function canBreak()
		if not LimitItem.Enabled then return true end
		local itemmeta = store.hand.tool and bedwars.ItemMeta[store.hand.tool.Name]
		return itemmeta ~= nil and itemmeta.breakBlock ~= nil
	end

	local function breakCannon(block, keepLast)
		local deadline = tick() + 0.6 + (store.ping.total or 0)
		local hits = keepLast and math.max(math.ceil(getBlockHits(block, block.Position)) - 1, 0) or math.huge

		repeat
			if not AutoDavey.Enabled or not entitylib.isAlive or not canBreak() or hits <= 0 then return end
			if (block.Position - entitylib.character.RootPart.Position).Magnitude > 30 then return end
			bedwars.breakBlock(block, true, true, nil, Switch.Enabled)
			hits -= 1
			task.wait(0.1)
		until not block.Parent or tick() > deadline
	end

	AutoDavey = Main:Part({
		Label = 'Launch helper',
		Name = 'AutoDavey',
		Function = function(callback)
			if callback then
				oldAim = bedwars.CannonController.startAiming
				bedwars.CannonController.startAiming = function(self, block, ...)
					local call = oldAim(self, block, ...)

					if Break.Enabled and block and block.Parent and entitylib.isAlive and canBreak() and getBlockHits(block, block.Position) > 1 then
						task.spawn(breakCannon, block, true)
					end

					return call
				end

				old = bedwars.CannonHandController.launchSelf
				bedwars.CannonHandController.launchSelf = function(self, block, ...)
					if Break.Enabled and block and block.Parent and entitylib.isAlive and (block.Position - entitylib.character.RootPart.Position).Magnitude <= 30 and canBreak() then
						task.spawn(breakCannon, block)
					end

					local call = old(self, block, ...)

					if Jump.Enabled and entitylib.isAlive then
						entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
					end
					return call
				end
			else
				bedwars.CannonHandController.launchSelf = old
				bedwars.CannonController.startAiming = oldAim
			end
		end,
		Tooltip = 'Breaks the cannon or jumps when you launch'
	})
	Jump = AutoDavey:CreateToggle({Name = 'Jump on impact'})

	Break = AutoDavey:CreateToggle({Name = 'Break on impact'})

	Switch = AutoDavey:CreateToggle({Name = 'Legit switch'})

	LimitItem = AutoDavey:CreateToggle({
		Name = 'Limit to items',
		Tooltip = 'Only works while holding the item it uses'
	})
end)

run(function()
	local CannonSpeed
	local Speed
	local originalSpeed

	local function setSpeed(value)
		local controller = bedwars.CannonHandController
		if not (canDebug and controller and type(controller.launchSelf) == 'function' and debug.setconstant) then
			return false
		end
		return pcall(debug.setconstant, controller.launchSelf, 15, value)
	end

	CannonSpeed = Main:Part({
		Label = 'Cannon speed',
		Name = 'CannonSpeed',
		Category = 'Ability',
		Function = function(enabled)
			if enabled then
				local controller = bedwars.CannonHandController
				local ok, value = pcall(function()
					return canDebug and debug.getconstant and controller and debug.getconstant(controller.launchSelf, 15)
				end)
				originalSpeed = ok and value or nil
				if not setSpeed(Speed.Value) then
					notif('CannonSpeed', 'Cannon speed is unavailable in this BedWars build.', 5, 'warning')
					task.defer(function() if CannonSpeed.Enabled then CannonSpeed:Toggle() end end)
				end
			elseif originalSpeed ~= nil then
				setSpeed(originalSpeed)
				originalSpeed = nil
			end
		end,
		Tooltip = 'Changes the cannon\'s launch speed'
	})
	Speed = CannonSpeed:CreateSlider({
		Name = 'Speed',
		Min = 1,
		Max = 400,
		Default = 200,
		Suffix = ' studs',
		Function = function(value)
			if CannonSpeed.Enabled then setSpeed(value) end
		end
	})
	CannonSpeed:CreateButton({
		Name = 'Sync to legit speed',
		Function = function() Speed:SetValue(200) end
	})
end)

end)
