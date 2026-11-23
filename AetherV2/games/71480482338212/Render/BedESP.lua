run(function()
	local BedESP
	local Mode
	local EnemyOnly
	local TeamColor
	local BedColor
	local Fill
	local Filled
	local Bounding
	local HealthBar
	local ShowName
	local ShowDistance
	local Background
	local DistanceCheck
	local BedDistance
	local Reference = {}
	local health = setmetatable({}, {__mode = 'k'})
	local folder = Instance.new('Folder')
	folder.Parent = vape.gui
	vape:Clean(folder)
	local BED_HEALTH = 50

	local function teamColor(name)
		local team = game:GetService('Teams'):FindFirstChild(tostring(name))
		return team and team.TeamColor.Color or Color3.fromRGB(220, 60, 60)
	end

	local function colourOf(bed)
		if TeamColor.Enabled then
			return teamColor(bed:GetAttribute('Team'))
		end
		return Color3.fromHSV(BedColor.Hue, BedColor.Sat, BedColor.Value)
	end

	local function set(obj, key, value)
		if obj[key] ~= value then
			obj[key] = value
		end
	end

	local function added(bed)
		if Reference[bed] then return end
		local hitbox = bed:IsA('Model') and bed:WaitForChild('BedHitbox', 5)
		if not hitbox or Reference[bed] or not BedESP.Enabled then return end
		local box = Instance.new('BoxHandleAdornment')
		box.Adornee = hitbox
		box.Size = hitbox.Size + Vector3.new(0.2, 0.2, 0.2)
		box.AlwaysOnTop = true
		box.ZIndex = 0
		box.Parent = folder
		local outline = Instance.new('SelectionBox')
		outline.Adornee = hitbox
		outline.LineThickness = 0.05
		outline.SurfaceTransparency = 1
		outline.Parent = folder
		local billboard = Instance.new('BillboardGui')
		billboard.Adornee = hitbox
		billboard.AlwaysOnTop = true
		billboard.Size = UDim2.fromOffset(160, 26)
		billboard.StudsOffset = Vector3.new(0, 4, 0)
		billboard.Parent = folder
		local label = Instance.new('TextLabel')
		label.Size = UDim2.new(1, 0, 0, 18)
		label.BackgroundColor3 = Color3.new()
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamMedium
		label.TextSize = 13
		label.TextStrokeTransparency = 0.4
		label.Parent = billboard
		local back = Instance.new('Frame')
		back.Size = UDim2.fromOffset(80, 4)
		back.Position = UDim2.new(0.5, -40, 0, 20)
		back.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		back.BorderSizePixel = 0
		back.Parent = billboard
		local fill = Instance.new('Frame')
		fill.Size = UDim2.fromScale(1, 1)
		fill.BorderSizePixel = 0
		fill.BackgroundColor3 = Color3.fromRGB(90, 220, 110)
		fill.Parent = back
		local square = Instance.new('Frame')
		square.BackgroundTransparency = 1
		square.Visible = false
		square.Parent = folder
		local stroke = Instance.new('UIStroke')
		stroke.Thickness = 1.5
		stroke.Parent = square
		Reference[bed] = {Box = box, Outline = outline, Billboard = billboard, Label = label, Back = back, Fill = fill, Square = square, Stroke = stroke, Hitbox = hitbox}
	end

	local function removed(bed)
		local ref = Reference[bed]
		if ref then
			Reference[bed] = nil
			ref.Box:Destroy()
			ref.Outline:Destroy()
			ref.Billboard:Destroy()
			ref.Square:Destroy()
		end
	end

	local function shownFor(bed, ref)
		if EnemyOnly.Enabled and bed:GetAttribute('Team') == (lplr.Team and lplr.Team.Name) then return false end
		if DistanceCheck.Enabled and entitylib.isAlive then
			local dist = (ref.Hitbox.Position - entitylib.character.RootPart.Position).Magnitude
			if dist < BedDistance.ValueMin or dist > BedDistance.ValueMax then return false end
		end
		return true
	end

	local function draw2D()
		for bed, ref in Reference do
			local visible = ref.Shown and Mode.Value == '2D'
			if visible then
				local cf, size = ref.Hitbox.CFrame, ref.Hitbox.Size / 2
				local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
				local front = false
				for x = -1, 1, 2 do
					for y = -1, 1, 2 do
						for z = -1, 1, 2 do
							local point, onScreen = gameCamera:WorldToViewportPoint(cf * Vector3.new(size.X * x, size.Y * y, size.Z * z))
							if point.Z > 0 then
								front = front or onScreen
								minX, minY = math.min(minX, point.X), math.min(minY, point.Y)
								maxX, maxY = math.max(maxX, point.X), math.max(maxY, point.Y)
							end
						end
					end
				end
				visible = front
				if visible then
					set(ref.Square, 'Position', UDim2.fromOffset(math.round(minX), math.round(minY)))
					set(ref.Square, 'Size', UDim2.fromOffset(math.round(maxX - minX), math.round(maxY - minY)))
				end
			end
			set(ref.Square, 'Visible', visible)
		end
	end

	BedESP = vape.Categories.Render:CreateModule({
		Name = 'BedESP',
		Function = function(callback)
			if callback then
				local function watch(container)
					BedESP:Clean(container.ChildAdded:Connect(function(bed)
						task.spawn(added, bed)
					end))
					BedESP:Clean(container.ChildRemoved:Connect(removed))
					for _, bed in container:GetChildren() do
						task.spawn(added, bed)
					end
				end
				BedESP:Clean(workspace.ChildAdded:Connect(function(v)
					if v.Name == 'BedsContainer' then
						watch(v)
					end
				end))
				if workspace:FindFirstChild('BedsContainer') then
					watch(workspace.BedsContainer)
				end
				local display = replicatedStorage:FindFirstChild('Remotes') and replicatedStorage.Remotes:FindFirstChild('DisplayBlockHealth')
				if display then
					BedESP:Clean(display.OnClientEvent:Connect(function(object, _, hp, max)
						if typeof(object) == 'Instance' and Reference[object] and type(hp) == 'number' then
							health[object] = {hp, type(max) == 'number' and max or BED_HEALTH}
						end
					end))
				end
				BedESP:Clean(runService.RenderStepped:Connect(function()
					if Mode.Value == '2D' then
						draw2D()
					end
				end))

				repeat
					for bed, ref in Reference do
						local shown = shownFor(bed, ref)
						ref.Shown = shown
						local color = colourOf(bed)
						local three = shown and Mode.Value == '3D'
						set(ref.Box, 'Visible', three and Filled.Enabled)
						set(ref.Box, 'Color3', color)
						set(ref.Box, 'Transparency', 1 - Fill.Value)
						set(ref.Outline, 'Visible', three and Bounding.Enabled)
						set(ref.Outline, 'Color3', color)
						set(ref.Stroke, 'Color', color)
						if not shown then set(ref.Square, 'Visible', false) end
						local hp = health[bed]
						local bar = shown and HealthBar.Enabled
						set(ref.Billboard, 'Enabled', shown and (ShowName.Enabled or ShowDistance.Enabled or bar))
						if ref.Billboard.Enabled then
							local text = ShowName.Enabled and tostring(bed:GetAttribute('Team'))..' Bed' or ''
							if ShowDistance.Enabled and entitylib.isAlive then
								text ..= string.format(' [%d]', (ref.Hitbox.Position - entitylib.character.RootPart.Position).Magnitude)
							end
							set(ref.Label, 'Text', text)
							set(ref.Label, 'TextColor3', color)
							set(ref.Label, 'BackgroundTransparency', Background.Enabled and text ~= '' and 0.5 or 1)
							set(ref.Back, 'Visible', bar)
							if bar then
								local ratio = hp and math.clamp(hp[1] / math.max(hp[2], 1), 0, 1) or 1
								set(ref.Fill, 'Size', UDim2.fromScale(ratio, 1))
								set(ref.Fill, 'BackgroundColor3', Color3.fromRGB(255, 80, 80):Lerp(Color3.fromRGB(90, 220, 110), ratio))
							end
						end
					end
					task.wait(0.2)
				until not BedESP.Enabled
			else
				for bed in table.clone(Reference) do
					removed(bed)
				end
			end
		end,
		Tooltip = 'Shows beds through walls'
	})
	Mode = BedESP:CreateDropdown({
		Name = 'Mode',
		List = {'3D', '2D'},
		Default = '3D',
		Tooltip = '3D - a box around the bed in the world\n2D - a square on your screen'
	})
	EnemyOnly = BedESP:CreateToggle({
		Name = 'Enemy only',
		Default = true,
		Tooltip = 'Hides your own bed'
	})
	TeamColor = BedESP:CreateToggle({
		Name = 'Use Team Color',
		Default = true
	})
	BedColor = BedESP:CreateColorSlider({
		Name = 'Bed Color',
		Darker = true,
		Visible = function()
			return not TeamColor.Enabled
		end
	})
	Filled = BedESP:CreateToggle({
		Name = 'Filled',
		Default = true,
		Visible = function()
			return Mode.Value == '3D'
		end
	})
	Fill = BedESP:CreateSlider({
		Name = 'Opacity',
		Min = 0.1,
		Max = 1,
		Default = 0.5,
		Decimal = 10,
		Darker = true,
		Visible = function()
			return Mode.Value == '3D' and Filled.Enabled
		end
	})
	Bounding = BedESP:CreateToggle({
		Name = 'Bounding Box',
		Visible = function()
			return Mode.Value == '3D'
		end,
		Tooltip = 'Draws an outline around the bed'
	})
	HealthBar = BedESP:CreateToggle({
		Name = 'Health Bar',
		Tooltip = 'Shows how damaged the bed is once someone mines it'
	})
	ShowName = BedESP:CreateToggle({
		Name = 'Team name',
		Default = true
	})
	ShowDistance = BedESP:CreateToggle({
		Name = 'Distance',
		Default = true
	})
	Background = BedESP:CreateToggle({
		Name = 'Show Background'
	})
	DistanceCheck = BedESP:CreateGroup({
		Name = 'Distance Check'
	})
	BedDistance = DistanceCheck:CreateTwoSlider({
		Name = 'Bed Distance',
		Min = 0,
		Max = 1000,
		DefaultMin = 0,
		DefaultMax = 300,
		Darker = true
	})
end)
