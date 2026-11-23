run(function()
	local HitregAdjuster, Hitreg, Memory
	local firstConnection, restoreConnection
	local timing = vape.Libraries.swordtiming
	local memoryText, memoryTable = nil, {}
	local lastItem

	local function readMemory()
		local text = Memory and Memory.Value or ''
		if text ~= memoryText then
			memoryText = text
			local ok, data = pcall(httpService.JSONDecode, httpService, text ~= '' and text or '{}')
			memoryTable = ok and type(data) == 'table' and data or {}
		end
		return memoryTable
	end

	local function writeMemory()
		local ok, text = pcall(httpService.JSONEncode, httpService, memoryTable)
		if ok and text ~= Memory.Value then
			memoryText = text
			Memory:SetValue(text)
		end
	end

	local function heldSword()
		local item = store.hand and store.hand.itemType
		local meta = item and bedwars.ItemMeta[item]
		return meta and meta.sword and item or nil
	end

	local function swapItem()
		local item = heldSword()
		if item == lastItem then return end
		local data = readMemory()
		if lastItem then
			local saved = data[lastItem]
			if not saved or saved[1] ~= Hitreg.ValueMin or saved[2] ~= Hitreg.ValueMax then
				data[lastItem] = {Hitreg.ValueMin, Hitreg.ValueMax}
				writeMemory()
			end
		end
		lastItem = item
		local saved = item and data[item]
		if type(saved) == 'table' and tonumber(saved[1]) and tonumber(saved[2]) then
			if Hitreg.ValueMin ~= saved[1] then Hitreg:SetValue(false, saved[1]) end
			if Hitreg.ValueMax ~= saved[2] then Hitreg:SetValue(true, saved[2]) end
		end
	end

	HitregAdjuster = vape.Categories.Combat:CreateModule({
		Name = 'HitregAdjuster',
		Function = function(enabled)
			if not enabled then
				if lastItem then
					readMemory()[lastItem] = {Hitreg.ValueMin, Hitreg.ValueMax}
					writeMemory()
				end
				lastItem = nil
				return
			end
			local sync = bedwars.SyncEvents and bedwars.SyncEvents.SwordSwing
			if not sync then
				notif('HitregAdjuster', 'Sword swing events are unavailable.', 5, 'warning')
				HitregAdjuster:Toggle()
				return
			end
			lastItem = nil
			swapItem()
			HitregAdjuster:Clean(vapeEvents.InventoryChanged.Event:Connect(swapItem))
			local original
			firstConnection = sync:setPriority(150):connect(function(event)
				original = nil
				if event:isCancelled() or store.matchState == (bedwars.MatchStates and bedwars.MatchStates.POST or 2) then return end
				local speed = tonumber(event.attackSpeed)
				if not speed or speed <= 0 then return end
				original = speed
				event.attackSpeed = timing.Spacing(Hitreg:GetRandomValue(), speed)
			end)
			restoreConnection = sync:setPriority(300):connect(function(event)
				if original ~= nil then event.attackSpeed = original end
				original = nil
			end)
			HitregAdjuster:Clean(function()
				if firstConnection then firstConnection:Destroy(); firstConnection = nil end
				if restoreConnection then restoreConnection:Destroy(); restoreConnection = nil end
			end)
		end,
		Tooltip = 'Sets how many hits your own sword swings land every 10 seconds, remembered per item'
	})
	Hitreg = HitregAdjuster:CreateTwoSlider({
		Name = 'Hitreg',
		Min = 1,
		Max = 36,
		DefaultMin = 35,
		DefaultMax = 35,
		Suffix = ' hits / 10s',
		Tooltip = "Uses the same timing as Killaura's Hitreg modes (33 Legit to 36 Max), scaled for slower swords"
	})
	Memory = HitregAdjuster:CreateTextBox({
		Name = 'Item memory',
		Default = '',
		Visible = false
	})
end)
