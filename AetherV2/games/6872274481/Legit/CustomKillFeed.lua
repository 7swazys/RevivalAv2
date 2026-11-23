run(function()
	local CustomKillFeed
	local Position
	local MaxEntries
	local Duration
	local Filter
	local BedBreaks
	local HideDefault
	local holder
	local entries = {}
	local feedHook, feedOld, feedOwner
	local hiddenGui
	local ANCHORS = {
		['Top right'] = {Vector2.new(1, 0), UDim2.new(1, -12, 0, 70), Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Top},
		['Top left'] = {Vector2.new(0, 0), UDim2.new(0, 12, 0, 70), Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top},
		['Bottom right'] = {Vector2.new(1, 1), UDim2.new(1, -12, 1, -120), Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Bottom},
		['Bottom left'] = {Vector2.new(0, 1), UDim2.new(0, 12, 1, -120), Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Bottom}
	}

	local function teamColor(plr)
		if plr and plr.Team then
			return plr.TeamColor.Color
		end
		return Color3.fromRGB(235, 235, 235)
	end

	local function teamOf(plr)
		return plr and plr:GetAttribute('Team')
	end

	local function heldImage(plr)
		local hand = plr and plr.Character and plr.Character:FindFirstChild('HandInvItem')
		local tool = hand and hand.Value
		local meta = tool and bedwars.ItemMeta[tool.Name]
		return meta and meta.image or nil
	end

	local function shown(killer, victim)
		if Filter.Value == 'Mine' then
			return killer == lplr or victim == lplr
		elseif Filter.Value == 'My team' then
			local mine = teamOf(lplr)
			return mine ~= nil and (teamOf(killer) == mine or teamOf(victim) == mine)
		end
		return true
	end

	local function anchor()
		if not holder then return end
		local spot = ANCHORS[Position.Value] or ANCHORS['Top right']
		holder.AnchorPoint, holder.Position = spot[1], spot[2]
		holder.Layout.HorizontalAlignment, holder.Layout.VerticalAlignment = spot[3], spot[4]
	end

	local function label(parent, text, colour, order, bold)
		local obj = Instance.new('TextLabel')
		obj.AutomaticSize = Enum.AutomaticSize.X
		obj.Size = UDim2.fromOffset(0, 20)
		obj.BackgroundTransparency = 1
		obj.Text = text
		obj.TextColor3 = colour
		obj.TextSize = 14
		obj.Font = bold and Enum.Font.GothamBold or Enum.Font.GothamMedium
		obj.TextStrokeTransparency = 0.5
		obj.LayoutOrder = order
		obj.Parent = parent
		return obj
	end

	local function icon(parent, image, order)
		local obj = Instance.new('ImageLabel')
		obj.Size = UDim2.fromOffset(20, 20)
		obj.BackgroundTransparency = 1
		obj.Image = image
		obj.ScaleType = Enum.ScaleType.Fit
		obj.LayoutOrder = order
		obj.Parent = parent
		return obj
	end

	local function add(build, mine)
		if not holder then return end
		local row = Instance.new('Frame')
		row.AutomaticSize = Enum.AutomaticSize.X
		row.Size = UDim2.fromOffset(0, 26)
		row.BackgroundColor3 = mine and Color3.fromRGB(40, 40, 48) or Color3.fromRGB(14, 14, 18)
		row.BackgroundTransparency = mine and 0.15 or 0.4
		row.LayoutOrder = -os.clock() * 1000
		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(0, 5)
		corner.Parent = row
		local padding = Instance.new('UIPadding')
		padding.PaddingLeft, padding.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
		padding.Parent = row
		local layout = Instance.new('UIListLayout')
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.VerticalAlignment = Enum.VerticalAlignment.Center
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, 6)
		layout.Parent = row
		if mine then
			local stroke = Instance.new('UIStroke')
			stroke.Color = Color3.fromHSV(vape.GUIColor.Hue, vape.GUIColor.Sat, vape.GUIColor.Value)
			stroke.Thickness = 1.5
			stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			stroke.Parent = row
		end
		build(row)
		row.Parent = holder
		table.insert(entries, row)
		while #entries > MaxEntries.Value do
			table.remove(entries, 1):Destroy()
		end
		task.delay(Duration.Value, function()
			local ind = table.find(entries, row)
			if ind then
				table.remove(entries, ind)
			end
			row:Destroy()
		end)
	end

	local function onDeath(deathTable)
		local victim = playersService:GetPlayerFromCharacter(deathTable.entityInstance)
		if not victim then return end
		local killer = deathTable.fromEntity and playersService:GetPlayerFromCharacter(deathTable.fromEntity)
		if killer == victim then killer = nil end
		if not shown(killer, victim) then return end
		local image = killer and heldImage(killer)
		add(function(row)
			if killer then
				label(row, killer.DisplayName, teamColor(killer), 1, true)
			end
			if image then
				icon(row, image, 2)
			elseif killer then
				label(row, 'killed', Color3.fromRGB(170, 170, 170), 2)
			end
			label(row, victim.DisplayName, teamColor(victim), 3, true)
			if not killer then
				label(row, 'died', Color3.fromRGB(170, 170, 170), 4)
			end
			if deathTable.finalKill then
				label(row, 'FINAL', Color3.fromRGB(255, 90, 90), 5, true)
			end
		end, killer == lplr or victim == lplr)
	end

	local function onBed(bedTable)
		if not BedBreaks.Enabled then return end
		local breaker = bedTable.player
		local teamId = bedTable.brokenBedTeam and bedTable.brokenBedTeam.id
		local mineTeam = teamOf(lplr)
		if Filter.Value == 'Mine' and breaker ~= lplr and tostring(teamId) ~= tostring(mineTeam) then return end
		if Filter.Value == 'My team' and teamOf(breaker) ~= mineTeam and tostring(teamId) ~= tostring(mineTeam) then return end
		local teamName, colour = 'Team '..tostring(teamId), Color3.fromRGB(235, 235, 235)
		pcall(function()
			local team = bedwars.QueueMeta[store.queueType].teams[tonumber(teamId)]
			teamName = team.displayName
		end)
		for _, plr in playersService:GetPlayers() do
			if tostring(plr:GetAttribute('Team')) == tostring(teamId) and plr.Team then
				colour = plr.TeamColor.Color
				break
			end
		end
		local bedMeta = bedwars.ItemMeta.bed
		add(function(row)
			if breaker then
				label(row, breaker.DisplayName, teamColor(breaker), 1, true)
			end
			if bedMeta and bedMeta.image then
				icon(row, bedMeta.image, 2)
			end
			label(row, teamName..' bed', colour, 3, true)
		end, breaker == lplr or tostring(teamId) == tostring(mineTeam))
	end

	local function setDefault(hidden)
		local controller = bedwars.KillFeedController
		if not controller then return end
		local gui = lplr.PlayerGui:FindFirstChild('KillFeedGui')
		if hidden then
			if gui and gui:IsA('ScreenGui') and gui.Enabled then
				gui.Enabled = false
				hiddenGui = gui
			end
			if feedHook then return end
			feedOld = controller.addToKillFeed
			feedOwner = controller
			feedHook = function(...)
				if CustomKillFeed.Enabled and HideDefault.Enabled then return end
				return feedOld(...)
			end
			controller.addToKillFeed = feedHook
		elseif feedHook then
			if feedOwner.addToKillFeed == feedHook then
				feedOwner.addToKillFeed = feedOld
				feedHook, feedOld, feedOwner = nil, nil, nil
			end
		end
		if not hidden and hiddenGui then
			if hiddenGui.Parent then
				hiddenGui.Enabled = true
			end
			hiddenGui = nil
		end
	end

	CustomKillFeed = vape.Categories.Legit:CreateModule({
		Name = 'CustomKillFeed',
		Function = function(callback)
			if callback then
				holder = Instance.new('Frame')
				holder.Name = 'CustomKillFeed'
				holder.Size = UDim2.fromOffset(420, 300)
				holder.BackgroundTransparency = 1
				holder.Parent = vape.gui
				local layout = Instance.new('UIListLayout')
				layout.Name = 'Layout'
				layout.SortOrder = Enum.SortOrder.LayoutOrder
				layout.Padding = UDim.new(0, 4)
				layout.Parent = holder
				anchor()
				setDefault(HideDefault.Enabled)
				CustomKillFeed:Clean(vapeEvents.EntityDeathEvent.Event:Connect(onDeath))
				CustomKillFeed:Clean(vapeEvents.BedwarsBedBreak.Event:Connect(onBed))
				CustomKillFeed:Clean(lplr.PlayerGui.ChildAdded:Connect(function(child)
					if child.Name == 'KillFeedGui' and child:IsA('ScreenGui') and HideDefault.Enabled and child.Enabled then
						child.Enabled = false
						hiddenGui = child
					end
				end))
			else
				setDefault(false)
				if holder then
					holder:Destroy()
					holder = nil
				end
				table.clear(entries)
			end
		end,
		Tooltip = 'A customisable kill feed with team colours and weapon icons'
	})
	Position = CustomKillFeed:CreateDropdown({
		Name = 'Position',
		List = {'Top right', 'Top left', 'Bottom right', 'Bottom left'},
		Function = anchor
	})
	MaxEntries = CustomKillFeed:CreateSlider({
		Name = 'Max entries',
		Min = 1,
		Max = 12,
		Default = 6
	})
	Duration = CustomKillFeed:CreateSlider({
		Name = 'Duration',
		Min = 2,
		Max = 20,
		Default = 6,
		Suffix = function(val)
			return val == 1 and 'second' or 'seconds'
		end
	})
	Filter = CustomKillFeed:CreateDropdown({
		Name = 'Filter',
		List = {'All', 'Mine', 'My team'},
		Tooltip = 'Which kills to show'
	})
	BedBreaks = CustomKillFeed:CreateToggle({
		Name = 'Bed breaks',
		Default = true
	})
	HideDefault = CustomKillFeed:CreateToggle({
		Name = 'Hide default feed',
		Default = true,
		Function = function(callback)
			if CustomKillFeed.Enabled then
				setDefault(callback)
			end
		end
	})
end)
