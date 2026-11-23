run(function()
	local Main = vape.Libraries.mergedModule(kits, {
		Name = 'AutoFortify',
		Category = 'Auto',
		Tooltip = 'Fortifies your bed\'s blocks from anywhere and the blocks you place'
	})

run(function()
	local AutoFortify
	local Layers
	local Debug
	local fortified = {}
	local fortifyRemote

	local function getRemote()
		if fortifyRemote then return fortifyRemote end

		local ok, remote = pcall(function() return bedwars.Client:Get('FortifyBlock') end)
		fortifyRemote = ok and remote or nil
		return fortifyRemote
	end

	local function fortify(remote, position)
		if type(remote.SendToServer) == 'function' then
			return pcall(remote.SendToServer, remote, position)
		end
		if remote.instance then
			return pcall(function() remote.instance:FireServer(position) end)
		end
		return false
	end

	local function getPyramid(size, grid)
		local positions = {}
		for h = size, 0, -1 do
			for w = h, 0, -1 do
				table.insert(positions, Vector3.new(w, (size - h), ((h + 1) - w)) * grid)
				table.insert(positions, Vector3.new(w * -1, (size - h), ((h + 1) - w)) * grid)
				table.insert(positions, Vector3.new(w, (size - h), (h - w) * -1) * grid)
				table.insert(positions, Vector3.new(w * -1, (size - h), (h - w) * -1) * grid)
			end
		end
		return positions
	end

	local function getMyBedCFrame()
		local team = lplr:GetAttribute('Team')
		if not team then return nil end

		for _, bed in collectionService:GetTagged('bed') do
			if bed and bed.Parent and bed:GetAttribute('Team'..team..'NoBreak') then
				return bed:IsA('BasePart') and bed.CFrame or (bed.PrimaryPart and bed.PrimaryPart.CFrame or bed:GetPivot())
			end
		end
		return nil
	end

	local function fortifyPass(bedCFrame)
		local remote = getRemote()
		if not remote then return end

		for layer = 0, Layers.Value - 1 do
			local pending = false
			for _, pos in getPyramid(layer + 1, 3) do
				if not AutoFortify.Enabled then return end

				local block, roundedPos = getPlacedBlock((bedCFrame * CFrame.new(pos)).Position)
				if block and block.Name ~= 'bed' then
					local key = tostring(roundedPos)
					if fortified[key] ~= block then
						fortify(remote, roundedPos)
						fortified[key] = block
						pending = true
						task.wait(0.05)
					end
				end
			end

			if pending then
				return
			end
		end
	end

	AutoFortify = Main:Part({
		Label = 'Fortify bed',
		Name = 'AutoFortify',
		Function = function(callback)
			if not callback then
				table.clear(fortified)
				return
			end

			AutoFortify:Clean(task.spawn(function()
				table.clear(fortified)
				repeat
					if entitylib.isAlive then
						local bedCFrame = getMyBedCFrame()
						if bedCFrame then
							local ok, err = pcall(fortifyPass, bedCFrame)
							if not ok and Debug.Enabled then
								notif('AutoFortify', tostring(err), 6, 'warning')
							end
						end
					end
					task.wait(0.1)
				until not AutoFortify.Enabled
			end))
		end,
		Tooltip = 'Fortifies the blocks on your bed from anywhere'
	})

	Layers = AutoFortify:CreateSlider({
		Name = 'Layers',
		Min = 1,
		Max = 10,
		Default = 3,
		Suffix = ' layers',
		Tooltip = 'How many layers to check'
	})
	Debug = AutoFortify:CreateToggle({
		Name = 'Debug',
		Tooltip = 'Logs what it does'
	})
end)

run(function()
	local AutoBuilder
	local Animation
	local Blacklist
	local BedCheck
	local Limit

	local function getBed(pos)
		local bed, lastmag = nil, math.huge
		for _, v in collectionService:GetTagged('bed') do
			local mag = (pos - v.Position).Magnitude
			if mag < lastmag and v:GetAttribute(`Team{lplr:GetAttribute('Team') or -1}NoBreak`) then
				bed, lastmag = v, mag
			end
		end
		return bed
	end

	AutoBuilder = Main:Part({
		Label = 'Fortify placed blocks',
		Name = 'AutoBuilder',
		Function = function(callback)
			if callback then
				repeat
					task.wait()
				until store.matchState ~= 0 and store.equippedKit == 'builder' or not AutoBuilder.Enabled
				if not AutoBuilder.Enabled then
					return
				end

				local blocks = collection('block', AutoBuilder, function(tab, obj)
					task.delay(0, function()
						if not obj:GetAttribute('NoBreak') and obj:GetAttribute('PlacedByUserId') then
							table.insert(tab, obj)
						end
					end)
				end)

				repeat
					if entitylib.isAlive and (not Limit.Enabled and getItem('hammer') or Limit.Enabled and store.hand.tool and store.hand.tool.Name == 'hammer') then
						local bed = getBed(entitylib.character.RootPart.Position)

						for _, v in blocks do
							if not BedCheck.Enabled or bed and (bed.Position - v.Position).Magnitude <= 30 then
								local name = v.Name:find('wool_') and 'wool' or v.Name
								if not table.find(Blacklist.ListEnabled, name) and not v:FindFirstChild('BuilderFortify') then
									bedwars.Handler:Get('FortifyBlock'):Fire('SendToServer', ({getPlacedBlock(v.Position)})[2])

									if Animation.Enabled then
										bedwars.GameAnimationUtil:playAnimation(lplr, bedwars.GameAnimationUtil:getAssetId(bedwars.AnimationType.BUILDER_HAMMER_HIT), {
											fadeInTime = 0.02
										})
										bedwars.AudioManager:playAudio(bedwars.SoundList.FORTIFY_BLOCK, {
											position = entitylib.character.RootPart.Position
										})
									end
								end
							end
						end
					end
					task.wait(0.1)
				until not AutoBuilder.Enabled
			end
		end,
		Tooltip = 'Fortifies your blocks with the builder hammer'
	})
	BedCheck = AutoBuilder:CreateToggle({
		Name = 'Bed Check',
		Tooltip = 'Checks if the block is near your bed'
	})
	Animation = AutoBuilder:CreateToggle({
		Name = 'Animation',
		Default = true,
		Tooltip = 'Plays the build effects'
	})
	Limit = AutoBuilder:CreateToggle({
		Name = 'Limit to items',
		Default = true
	})
	Blacklist = AutoBuilder:CreateTextList({
		Name = 'Blacklists',
		Placeholder = 'block',
		Default = {'cannon', 'wool'}
	})
end)

end)
