run(function()

	local util = vape.Libraries.bedwarsutil
	local CryptAura
	local Claim
	local Range
	local Delay
	local ESP
	local Background
	local Color
	local nextClaim = 0

	local claimed = setmetatable({}, {__mode = 'k'})
	local tracked = {}
	local espConnections = {}
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui

	local Activate = bedwars.Handler:Get('ActivateGravestone')

	local function icon()
		local ok, image = pcall(function() return bedwars.getIcon({itemType = 'gravestone'}, true) end)
		return ok and image or ''
	end

	local function add(obj)
		if tracked[obj] or not obj or not obj.Parent then return end

		local part = not obj:IsA('Model') and obj or (obj.PrimaryPart or obj:FindFirstChildWhichIsA('BasePart', true))
		if not part then return end

		local billboard = Instance.new('BillboardGui')
		billboard.Name = 'gravestone'
		billboard.Size = UDim2.fromOffset(36, 36)
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
		billboard.AlwaysOnTop = true
		billboard.ClipsDescendants = false
		billboard.Adornee = part
		billboard.Parent = Folder

		local blur = addBlur(billboard)
		blur.Visible = Background.Enabled

		local image = Instance.new('ImageLabel')
		image.Name = 'Icon'
		image.Size = UDim2.fromOffset(36, 36)
		image.Position = UDim2.fromScale(0.5, 0.5)
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		image.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
		image.BorderSizePixel = 0
		image.Image = icon()
		image.Parent = billboard

		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(0, 4)
		corner.Parent = image

		tracked[obj] = billboard
	end

	local function remove(obj)
		if not tracked[obj] then return end
		tracked[obj]:Destroy()
		tracked[obj] = nil
	end

	local function stopEsp()
		for _, connection in espConnections do
			pcall(function() connection:Disconnect() end)
		end
		table.clear(espConnections)
		for _, billboard in tracked do
			billboard:Destroy()
		end
		table.clear(tracked)
	end

	local function startEsp()
		stopEsp()
		for _, obj in collectionService:GetTagged('Gravestone') do
			add(obj)
		end
		table.insert(espConnections, collectionService:GetInstanceAddedSignal('Gravestone'):Connect(add))
		table.insert(espConnections, collectionService:GetInstanceRemovedSignal('Gravestone'):Connect(remove))
	end

	CryptAura = kits:CreateModule({
		Name = 'CryptAura',
		Category = 'Aim',
		Function = function(callback)
			if not callback then
				stopEsp()
				return
			end
			if ESP.Enabled then startEsp() end
			nextClaim = 0
			table.clear(claimed)
			repeat
				if Claim.Enabled and entitylib.isAlive and store.equippedKit == 'necromancer' and tick() >= nextClaim then
					local origin = entitylib.character.RootPart.Position
					for _, v in collectionService:GetTagged('Gravestone') do
						if not claimed[v] and v:GetAttribute('GravestoneSecret') and (v:GetPivot().Position - origin).Magnitude <= Range.Value then
							claimed[v] = true
							nextClaim = tick() + Delay.Value
							Activate:Fire('CallServer', {
								secret = v:GetAttribute('GravestoneSecret'),
								position = v:GetAttribute('GravestonePosition'),
								skeletonData = {
									associatedPlayerUserId = v:GetAttribute('GravestonePlayerUserId'),
									armorType = v:GetAttribute('ArmorType'),
									weaponType = v:GetAttribute('SwordType'),
									bowType = v:GetAttribute('BowType')
								}
							})
							break
						end
					end
				end
				task.wait(0.1)
			until not CryptAura.Enabled
		end,
		Tooltip = 'Claims enemy gravestones for your undead army'
	})
	Claim = CryptAura:CreateGroup({
		Name = 'Claim gravestones',
		Default = true,
	})
	Range = Claim:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 40,
		Default = 12,
		Darker = true,
		Suffix = util.Studs
	})
	Delay = Claim:CreateSlider({
		Name = 'Delay',
		Min = 0.1,
		Max = 3,
		Default = 0.3,
		Decimal = 10,
		Darker = true,
		Suffix = util.Seconds
	})
	ESP = CryptAura:CreateToggle({
		Name = 'Gravestone ESP',
		Tooltip = 'Shows gravestones through walls',
		Function = function(enabled)
			if Background and Background.Object then Background.Object.Visible = enabled end
			if Color and Color.Object then Color.Object.Visible = (enabled and Background.Enabled) end
			if not CryptAura.Enabled then return end
			if enabled then startEsp() else stopEsp() end
		end
	})
	Background = CryptAura:CreateToggle({
		Name = 'Background',
		Default = true,
		Darker = true,
		Tooltip = 'Draws a box behind the icon',
		Function = function(enabled)
			if Color and Color.Object then Color.Object.Visible = (enabled and ESP.Enabled) end
			for _, billboard in tracked do
				local blur = billboard:FindFirstChild('Blur')
				if blur then blur.Visible = enabled end
				local image = billboard:FindFirstChild('Icon')
				if image then image.BackgroundTransparency = 1 - (enabled and Color.Opacity or 0) end
			end
		end
	})
	Color = CryptAura:CreateColorSlider({
		Name = 'Background Color',
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Darker = true,
		Function = function(hue, sat, val, opacity)
			for _, billboard in tracked do
				local image = billboard:FindFirstChild('Icon')
				if image then
					image.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
					image.BackgroundTransparency = 1 - opacity
				end
			end
		end
	})

	task.defer(function()
		if Background and Background.Object then Background.Object.Visible = ESP.Enabled end
		if Color and Color.Object then Color.Object.Visible = (ESP.Enabled and Background.Enabled) end
	end)
end)
