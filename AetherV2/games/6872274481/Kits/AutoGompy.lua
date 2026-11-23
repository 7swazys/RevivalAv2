run(function()
	local AutoGompy
	local AutoCollect
	local Range
	local Delay
	local LimitToVacuum
	local Debug
	local collectRemote

	local function getRemote()
		if collectRemote then return collectRemote end

		local ok, remote = pcall(function() return bedwars.Handler:Get('CollectCollectableEntity') end)
		collectRemote = ok and remote or nil
		return collectRemote
	end

	local function collect(id)
		local remote = getRemote()
		if remote then
			return pcall(function() remote:Fire('SendToServer', {id = id}) end)
		end

		local ok, direct = pcall(function() return bedwars.Client:Get('CollectCollectableEntity') end)
		if ok and direct and type(direct.SendToServer) == 'function' then
			return (pcall(direct.SendToServer, direct, {id = id}))
		end
		return false
	end

	local function getGhostId(obj)
		return obj:GetAttribute('Id') or obj:GetAttribute('id') or obj:GetAttribute('CollectableId')
			or tonumber(obj.Name:match('%d+'))
	end

	local function holdingVacuum()
		local hand = store.hand
		return hand and hand.itemType ~= nil and hand.itemType:find('vacuum') ~= nil
	end

	local function collectPass()
		if not entitylib.isAlive then return end
		if LimitToVacuum.Enabled and not holdingVacuum() then return end

		local localPosition = entitylib.character.RootPart.Position
		for _, obj in collectionService:GetTagged('ghost') do
			if not AutoGompy.Enabled or not AutoCollect.Enabled then break end

			local part = not obj:IsA('Model') and obj or obj.PrimaryPart
			if part and (localPosition - part.Position).Magnitude <= Range.Value then
				local id = getGhostId(obj)
				if id then
					collect(id)
					if Delay.Value > 0 then
						task.wait(Delay.Value)
					end
				end
			end
		end
	end

	AutoGompy = kits:CreateModule({
		Name = 'AutoGompy',
		Function = function(callback)
			if not callback then return end

			AutoGompy:Clean(task.spawn(function()
				repeat
					local ok, err = pcall(collectPass)
					if not ok and Debug.Enabled then
						notif('AutoGompy', tostring(err), 6, 'warning')
					end
					task.wait(0.1)
				until not AutoGompy.Enabled or not AutoCollect.Enabled
			end))
		end,
		Tooltip = 'Vacuums up nearby ghosts'
	})

	AutoCollect = AutoGompy:CreateToggle({
		Name = 'Auto Collect',
		Default = true,
		Tooltip = 'Vacuums up nearby ghosts'
	})
	Range = AutoGompy:CreateSlider({
		Name = 'Range',
		Tooltip = 'How far it vacuums ghosts from',
		Min = 5,
		Max = 40,
		Default = 30
	})
	Delay = AutoGompy:CreateSlider({
		Name = 'Delay',
		Tooltip = 'Wait time between vacuums',
		Min = 0,
		Max = 1,
		Default = 0.1,
		Decimal = 100,
		Suffix = 's'
	})
	LimitToVacuum = AutoGompy:CreateToggle({
		Name = 'Limit to Vacuum',
		Tooltip = 'Only works while holding the item it uses'
	})
	Debug = AutoGompy:CreateToggle({
		Name = 'Debug',
		Tooltip = 'Logs what it does'
	})
end)
