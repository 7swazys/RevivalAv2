run(function()
	local EmoteWheelEditor
	local SLOTS = 8
	local Slots, Ids = {}, {}
	local list, types = {'Empty'}, {}
	for kind, meta in bedwars.EmoteMeta or {} do
		if kind ~= 'none' and type(meta) == 'table' and meta.name and not types[meta.name] then
			types[meta.name] = kind
			table.insert(list, meta.name)
		end
	end
	table.sort(list, function(a, b)
		if a == 'Empty' then return true end
		if b == 'Empty' then return false end
		return a < b
	end)
	local holds = {}
	local Track, Moved
	local oldEmote, ownEmote

	local function hold(slot, value)
		local attribute = 'EmoteTypeSlot'..slot
		local entry = holds[slot]
		if value == nil then
			if entry then
				holds[slot] = nil
				entry.Connection:Disconnect()
				lplr:SetAttribute(attribute, entry.Original)
			end
			return
		end
		if not entry then
			entry = {Original = lplr:GetAttribute(attribute)}
			entry.Connection = lplr:GetAttributeChangedSignal(attribute):Connect(function()
				local current = lplr:GetAttribute(attribute)
				if current ~= entry.Value then
					entry.Original = current
					lplr:SetAttribute(attribute, entry.Value)
				end
			end)
			holds[slot] = entry
		end
		entry.Value = value
		if lplr:GetAttribute(attribute) ~= value then
			lplr:SetAttribute(attribute, value)
		end
	end

	local function stopTrack()
		if Moved then
			Moved:Disconnect()
			Moved = nil
		end
		if Track then
			Track:Stop()
			Track:Destroy()
			Track = nil
		end
	end

	local function customFor(kind)
		for slot = 1, SLOTS do
			if types[Slots[slot].Value] == kind then
				local id = tostring(Ids[slot].Value or ''):match('%d+')
				if id then return id end
			end
		end
	end

	local function playCustom(id)
		stopTrack()
		local humanoid = lplr.Character and lplr.Character:FindFirstChildWhichIsA('Humanoid')
		local animator = humanoid and humanoid:FindFirstChildWhichIsA('Animator')
		if not animator then return end
		local animation = Instance.new('Animation')
		animation.AnimationId = 'rbxassetid://'..id
		local ok, track = pcall(animator.LoadAnimation, animator, animation)
		animation:Destroy()
		if not ok or not track then
			notif('EmoteWheelEditor', 'That animation could not be loaded', 4, 'warning')
			return
		end
		Track = track
		track:Play()
		Moved = humanoid:GetPropertyChangedSignal('MoveDirection'):Connect(function()
			if humanoid.MoveDirection.Magnitude > 0 then
				stopTrack()
			end
		end)
	end

	local function apply()
		if not EmoteWheelEditor.Enabled then return end
		for slot = 1, SLOTS do
			local kind = types[Slots[slot].Value]
			hold(slot, kind)
		end
	end

	local function hook()
		local controller = bedwars.EmoteController
		if type(controller) ~= 'table' or type(controller.emote) ~= 'function' or oldEmote then return end
		ownEmote = rawget(controller, 'emote') ~= nil
		oldEmote = controller.emote
		local old = oldEmote
		controller.emote = function(self, kind, ...)
			if not EmoteWheelEditor.Enabled then
				return old(self, kind, ...)
			end
			local custom = customFor(kind)
			if custom then
				playCustom(custom)
				return
			end
			local client = bedwars.Client
			if type(client) ~= 'table' or type(client.Get) ~= 'function' then
				return old(self, kind, ...)
			end
			local hadGet = rawget(client, 'Get')
			local realGet = client.Get
			client.Get = function(this, name, ...)
				local remote = realGet(this, name, ...)
				if name ~= 'Emote' or type(remote) ~= 'table' then
					return remote
				end
				local proxy = setmetatable({}, {__index = remote})
				function proxy:CallServer(...)
					local args = table.pack(...)
					task.spawn(function()
						pcall(remote.CallServer, remote, table.unpack(args, 1, args.n))
					end)
					return true
				end
				return proxy
			end
			local result = table.pack(pcall(old, self, kind, ...))
			if hadGet then
				client.Get = hadGet
			else
				client.Get = nil
			end
			if result[1] then
				local char = lplr.Character
				local maid = type(self.emoteMaids) == 'table' and self.emoteMaids[lplr.UserId]
				if char and type(maid) == 'table' and maid.GiveTask and char:GetAttribute('PlayingEmote') ~= kind then
					char:SetAttribute('PlayingEmote', kind)
					maid:GiveTask(function()
						if char:GetAttribute('PlayingEmote') == kind then
							char:SetAttribute('PlayingEmote', nil)
						end
					end)
				end
				return table.unpack(result, 2, result.n)
			end
		end
	end

	local function unhook()
		local controller = bedwars.EmoteController
		if oldEmote and type(controller) == 'table' then
			controller.emote = ownEmote and oldEmote or nil
		end
		oldEmote = nil
	end

	EmoteWheelEditor = vape.Categories.Utility:CreateModule({
		Name = 'EmoteWheelEditor',
		Function = function(callback)
			if callback then
				hook()
				apply()
			else
				unhook()
				stopTrack()
				for slot = 1, SLOTS do
					hold(slot, nil)
				end
			end
		end,
		Tooltip = 'Puts any emote or animation in your emote wheel. Ones you do not own only show on your screen'
	})
	for slot = 1, SLOTS do
		Slots[slot] = EmoteWheelEditor:CreateDropdown({
			Name = 'Slot '..slot,
			List = list,
			Default = 'Empty',
			Function = apply,
			Tooltip = 'Emote in this wheel slot, Empty keeps your own'
		})
		Ids[slot] = EmoteWheelEditor:CreateTextBox({
			Name = 'Slot '..slot..' animation',
			Placeholder = 'animation id (optional)',
			Darker = true,
			Visible = function()
				return Slots[slot].Value ~= 'Empty'
			end,
			Tooltip = 'Plays this Roblox animation instead of the emote when you pick the slot'
		})
	end
end)
