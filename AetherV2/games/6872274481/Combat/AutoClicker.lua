run(function()
	local AutoClicker
	local Attack
	local CPS
	local Place
	local Wool
	local Debug
	local BlockCPS = {}
	local held = false
	local nextPlace, nextClick = 0, 0
	local placeGap
	local LOG = 'aetherv2/profiles/autoclickerlog.txt'
	local logBuffer, logStart, logLines, lastFlush = nil, 0, 0, 0
	local lastSeenPlace, lastOwnPlace, lastHitSeen = nil, 0, nil
	local hitOld, hitHook
	local logLine, vec

	local function isCasting()
		local casting = lplr:GetAttribute('IsCasting')
		return casting and casting ~= 0 and casting ~= ''
	end

	local function canSwing()
		if type(bedwars.SwordController.getSwordSwingDisabled) ~= 'function' or bedwars.SwordController:getSwordSwingDisabled() or isCasting() then
			return false
		end

		local itemmeta = store.hand and store.hand.tool and bedwars.ItemMeta[store.hand.tool.Name]
		return itemmeta ~= nil and itemmeta.sword ~= nil and itemmeta.sword.chargedAttack == nil
	end

	local function canPlace()
		local controller = bedwars.BlockPlacementController
		return controller ~= nil and not controller.disabled and not isCasting()
	end

	local function getWoolBaseCps()
		if Wool.Enabled and store.hand and store.hand.tool then
			return store.hand.tool.Name:find('wool_') ~= nil
		end
		return not Wool.Enabled
	end

	local function placeInterval()
		local cps = BlockCPS:GetRandomValue()
		return math.max(1 / math.max(cps, 0.001), 1 / (bedwars.SharedConstants.BLOCK_PLACE_CPS or 12))
	end

	local function clickInterval()
		return 1 / math.max(CPS:GetRandomValue(), 0.001)
	end

	local function canClickBlock()
		if store.hand.toolType ~= 'block' or not Place.Enabled then return false end
		if not getWoolBaseCps() then return false end
		local blockPlacer = bedwars.BlockPlacementController.blockPlacer
		if not blockPlacer or not canPlace() then return false end
		return (workspace:GetServerTimeNow() - (bedwars.BlockCpsController.lastPlaceTimestamp or 0)) >= ((1 / (bedwars.SharedConstants.BLOCK_PLACE_CPS or 12)) * 0.5)
	end

	local function callAutoBridge(blockPlacer)
		task.spawn(function()
			pcall(function()
				local controller = bedwars.KnockbackController
				local sinceKnockback = controller and workspace:GetServerTimeNow() - controller:getLastKnockbackTime() or 0
				blockPlacer:autoBridge(sinceKnockback >= 0.2)
			end)
		end)
	end

	local function placeThroughCrosshair(blockPlacer)
		local selector = blockPlacer.clientManager and blockPlacer.clientManager:getBlockSelector()
		local mouseinfo = selector and selector:getMouseInfo(0)
		if mouseinfo and mouseinfo.placementPosition == mouseinfo.placementPosition then
			lastOwnPlace = tick()
			if logBuffer then
				local cell = mouseinfo.placementPosition
				task.spawn(function()
					local ok, res = pcall(blockPlacer.placeBlock, blockPlacer, cell, mouseinfo)
					logLine(string.format('placeBlock %s -> %s %s', vec(cell), tostring(ok), tostring(res)))
				end)
			else
				task.spawn(blockPlacer.placeBlock, blockPlacer, mouseinfo.placementPosition, mouseinfo)
			end
			return true
		end
		return false
	end

	local function placeSafelyDownwards(blockPlacer)
		if type(blockPlacer.autoBridge) ~= 'function' then return end
		local humanoid = entitylib.isAlive and entitylib.character and entitylib.character.Humanoid
		if not humanoid or humanoid.MoveDirection.Magnitude <= 0.1 then return end
		callAutoBridge(blockPlacer)
	end

	local function placeBlock()
		local blockPlacer = bedwars.BlockPlacementController.blockPlacer
		if not blockPlacer then return false end

		if inputService.TouchEnabled and type(blockPlacer.autoBridge) == 'function' then
			callAutoBridge(blockPlacer)
			return true
		end

		if placeThroughCrosshair(blockPlacer) then return true end
		local humanoid = entitylib.isAlive and entitylib.character and entitylib.character.Humanoid
		if type(blockPlacer.autoBridge) == 'function' and humanoid and humanoid.MoveDirection.Magnitude > 0.1 then
			placeSafelyDownwards(blockPlacer)
			return true
		end
		return false
	end

	logLine = function(text)
		if not logBuffer or logLines > 4000 then return end
		logLines += 1
		table.insert(logBuffer, string.format('%.3f %s', tick() - logStart, text))
	end

	local function flushLog(force)
		if not logBuffer or #logBuffer == 0 or (not force and tick() - lastFlush < 0.5) then return end
		lastFlush = tick()
		local text = table.concat(logBuffer, '\n')..'\n'
		table.clear(logBuffer)
		pcall(appendfile, LOG, text)
	end

	vec = function(v)
		return v and string.format('%.1f,%.1f,%.1f', v.X, v.Y, v.Z) or 'nil'
	end

	local function startLog()
		logBuffer, logStart, logLines, lastFlush = {}, tick(), 0, tick()
		local on = {}
		for _, name in {'FastPlace', 'AutoTool', 'MineThrough', 'Reach', 'Scaffold', 'AntiHit', 'AutoDodge', 'Breaker', 'BlockIn', 'AutoBuildUp', 'Speed', 'Fly', 'NoFallDamage', 'Velocity', 'Killaura'} do
			local module = vape.Modules[name]
			if module and module.Enabled then table.insert(on, name) end
		end
		local hand = store.hand or {}
		local header = string.format('--- hold %s | tool %s (%s) | BLOCK_PLACE_CPS %s | Block CPS %s-%s | CPS %s-%s | ping %.3f | on: %s',
			os.date('%H:%M:%S'), tostring(hand.itemType), tostring(hand.toolType), tostring(bedwars.SharedConstants.BLOCK_PLACE_CPS),
			tostring(BlockCPS.ValueMin), tostring(BlockCPS.ValueMax), tostring(CPS.ValueMin), tostring(CPS.ValueMax),
			lplr:GetNetworkPing(), table.concat(on, ','))
		pcall(function()
			if not isfile(LOG) or #readfile(LOG) > 400000 then
				writefile(LOG, '')
			end
		end)
		logLine(header)
		lastSeenPlace = bedwars.BlockCpsController.lastPlaceTimestamp
		local breaker = bedwars.BlockBreaker
		lastHitSeen = breaker and breaker.lastHitTime
	end

	local function logFrame(dt)
		if not logBuffer or tick() - logStart > 60 then return end
		local hand = store.hand or {}
		local root = entitylib.isAlive and entitylib.character.RootPart
		local hum = entitylib.isAlive and entitylib.character.Humanoid
		local parts = {string.format('dt %.3f%s', dt, dt > 0.05 and ' HITCH' or '')}
		if root then
			table.insert(parts, string.format('y %.2f vy %.1f %s', root.Position.Y, root.AssemblyLinearVelocity.Y, tostring(hum.FloorMaterial):gsub('Enum.Material.', '')))
		end
		local ok, err = pcall(function()
			if hand.toolType == 'block' then
				local placer = bedwars.BlockPlacementController.blockPlacer
				local selector = placer and placer.clientManager and placer.clientManager:getBlockSelector()
				local info = selector and selector:getMouseInfo(0)
				local pos = info and info.placementPosition
				table.insert(parts, 'cell '..(pos == nil and 'none' or pos ~= pos and 'nan' or vec(pos)))
				table.insert(parts, 'disabled '..tostring(bedwars.BlockPlacementController.disabled))
			else
				local breaker = bedwars.BlockBreaker
				local selector = breaker and breaker.clientManager and breaker.clientManager:getBlockSelector()
				local info = selector and selector:getMouseInfo(1, {range = breaker.range})
				local target = info and info.target
				table.insert(parts, 'target '..(target and (target.blockInstance.Name..' '..vec(target.blockRef.blockPosition)) or 'none'))
				table.insert(parts, string.format('health %s', tostring(breaker and breaker.blockHealth)))
			end
		end)
		if not ok then table.insert(parts, 'probe error '..tostring(err)) end
		local placed = bedwars.BlockCpsController.lastPlaceTimestamp
		if placed ~= lastSeenPlace then
			table.insert(parts, string.format('PLACED %s', tick() - lastOwnPlace < 0.1 and 'by us' or 'by the game'))
			lastSeenPlace = placed
		end
		local breaker = bedwars.BlockBreaker
		if breaker and breaker.lastHitTime ~= lastHitSeen then
			table.insert(parts, 'HIT')
			lastHitSeen = breaker.lastHitTime
		end
		logLine(table.concat(parts, ' | '))
		flushLog()
	end

	local function hookHitLog()
		local breaker = bedwars.BlockBreaker
		if hitHook or type(breaker) ~= 'table' or type(breaker.hitBlock) ~= 'function' then return end
		hitOld = breaker.hitBlock
		hitHook = function(self, maid, ray, ...)
			if not (logBuffer and AutoClicker.Enabled and Debug.Enabled) then
				return hitOld(self, maid, ray, ...)
			end
			local before = self.lastHitTime
			local source = 'unknown'
			pcall(function()
				source = debug.info(2, 's'):match('[^%.]+$') or 'unknown'
			end)
			local results = table.pack(pcall(hitOld, self, maid, ray, ...))
			logLine(string.format('hitBlock from %s ray %s -> %s%s', source, ray and 'given' or 'nil',
				self.lastHitTime ~= before and 'hit' or 'no hit', results[1] and '' or ' ERROR '..tostring(results[2])))
			if not results[1] then error(results[2], 0) end
			return table.unpack(results, 2, results.n)
		end
		breaker.hitBlock = hitHook
	end

	local function unhookHitLog()
		if hitHook and bedwars.BlockBreaker and bedwars.BlockBreaker.hitBlock == hitHook then
			bedwars.BlockBreaker.hitBlock = hitOld
			hitHook, hitOld = nil, nil
		end
	end

	local function clickOnce()
		local toolType = store.hand and store.hand.toolType
		if not ((toolType == 'block' and Place.Enabled) or (toolType == 'sword' and Attack.Enabled)) then return end
		local now = tick()
		if toolType == 'sword' and now < nextClick then return end
		if bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then return end
		if store.hand.toolType == 'block' then
			placeGap = placeGap or placeInterval()
			if now >= nextPlace and canClickBlock()
				and workspace:GetServerTimeNow() - (bedwars.BlockCpsController.lastPlaceTimestamp or 0) >= placeGap
				and placeBlock() then
				nextPlace = now + placeGap
				placeGap = placeInterval()
			end
		elseif Attack.Enabled and store.hand.toolType == 'sword' then
			if now < nextClick then return end
			nextClick = now + clickInterval()
			if inputService.TouchEnabled then
				local controller = bedwars.SwordController
				if controller.mobileSwingPressed then
					controller:mobileSwingPressed()
				end
			elseif canSwing() and not bedwars.SwordController.disableSwingState then
				bedwars.gatedSwing(bedwars.SwordController.swingSwordAtMouse, bedwars.SwordController, 0.39)
			end
		end
	end

	local warned = false
	local function stopClicking()
		if held and logBuffer then
			logLine('--- released')
			flushLog(true)
			logBuffer = nil
		end
		held = false
	end

	local function AutoClick()
		held = true
		warned = false
		local now = tick()
		nextClick = now + clickInterval()
		nextPlace = now + (store.hand and store.hand.toolType == 'block' and placeInterval() or 0)
		placeGap = nil
		if Debug.Enabled then
			startLog()
		end
	end

	local function isAttack(input)
		local keybinds = bedwars.KeybindLoadController and bedwars.KeybindLoadController:getKeybinds()
		local keyboard = keybinds and keybinds.keyboard and keybinds.keyboard.controlActions.Attack or Enum.UserInputType.MouseButton1
		local gamepad = keybinds and keybinds.gamepad and keybinds.gamepad.controlActions.Attack or Enum.KeyCode.ButtonR2
		return input.UserInputType == keyboard or input.KeyCode == keyboard or input.KeyCode == gamepad
	end

	AutoClicker = vape.Categories.Combat:CreateModule({
		Name = 'AutoClicker',
		ExtraText = function() return CPS.ValueMin..'-'..CPS.ValueMax end,
		Function = function(callback)
			if callback then
				if Debug.Enabled then hookHitLog() end
				AutoClicker:Clean(runService.Heartbeat:Connect(function(dt)
					if not held then return end
					if logBuffer then logFrame(dt) end
					local ok, err = pcall(clickOnce)
					if not ok and not warned then
						warned = true
						warn('[AetherV2] AutoClicker: '..tostring(err))
					end
				end))
				AutoClicker:Clean(inputService.InputBegan:Connect(function(input)
					if logBuffer and input.KeyCode == Enum.KeyCode.J then
						logLine('*** MARK')
					end
					if isAttack(input) then
						AutoClick()
					end
				end))

				AutoClicker:Clean(inputService.InputEnded:Connect(function(input)
					if isAttack(input) then
						stopClicking()
					end
				end))

				if inputService.TouchEnabled then
					local hooked = {}
					local function hookButton(button)
						if hooked[button] or not button:IsA('GuiButton') or not tonumber(button.Name) then return end
						hooked[button] = true
						AutoClicker:Clean(button.MouseButton1Down:Connect(AutoClick))
						AutoClicker:Clean(button.MouseButton1Up:Connect(stopClicking))
					end

					task.spawn(function()
						local mobileUI = lplr.PlayerGui:WaitForChild('MobileUI', 20)
						if not mobileUI or not AutoClicker.Enabled then return end

						for _, v in mobileUI:GetChildren() do
							hookButton(v)
						end
						AutoClicker:Clean(mobileUI.ChildAdded:Connect(hookButton))
					end)
				end
			else
				stopClicking()
				unhookHitLog()
			end
		end,
		Tooltip = 'Clicks for you while you hold the attack button'
	})

	Attack = AutoClicker:CreateGroup({
		Name = 'Attack',
		Default = true,
		Tooltip = 'Swings your sword while you hold attack'
	})
	CPS = Attack:CreateTwoSlider({
		Name = 'CPS',
		Min = 1,
		Max = 9,
		DefaultMin = 7,
		DefaultMax = 7
	})
	Place = AutoClicker:CreateGroup({
		Name = 'Place Blocks',
		Function = function(callback)
			if BlockCPS and BlockCPS.Object then
			end

		end,
		Default = true
	})
	Wool = Place:CreateToggle({Name = 'Wool only', Tooltip = 'Only clicks when you are holding wool', Darker = true})
	Debug = AutoClicker:CreateToggle({
		Name = 'Debug log',
		Tooltip = 'Logs what it does to a file. Press J to mark a moment',
		Function = function(callback)
			if callback and AutoClicker.Enabled then
				hookHitLog()
			elseif not callback then
				unhookHitLog()
			end
		end
	})
	BlockCPS = Place:CreateTwoSlider({
		Name = 'Block CPS',
		Min = 1,
		Max = 20,
		DefaultMin = 20,
		DefaultMax = 20,
		Darker = true
	})
end)
