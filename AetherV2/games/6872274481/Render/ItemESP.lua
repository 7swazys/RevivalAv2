run(function()
	local Main = vape.Libraries.mergedModule(vape.Categories.Render, {
		Name = 'ItemESP',
		Tooltip = 'Shows dropped items and their count through walls'
	})

run(function()
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui

	local function createSection()
		local section = {
			Enabled = false,
			Connections = {},
			Reference = {},
			Folder = Instance.new('Folder')
		}
		section.Folder.Parent = Folder
		function section:Clean(item)
			if type(item) == 'function' then
				table.insert(self.Connections, {Disconnect = item})
			elseif item then
				table.insert(self.Connections, item)
			end
		end
		function section:Clear()
			for _, connection in self.Connections do
				pcall(function() connection:Disconnect() end)
			end
			table.clear(self.Connections)
			if self.Stop then self.Stop(self) end
			for _, instance in self.Reference do
				pcall(function() instance:Destroy() end)
			end
			table.clear(self.Reference)
			self.Folder:ClearAllChildren()
		end
		function section:Set(callback)
			if callback == self.Enabled then return end
			self.Enabled = callback
			self:Clear()
			if callback and self.Start then self.Start(self) end
		end
		function section:Restart()
			if self.Enabled then
				self:Set(false)
				self:Set(true)
			end
		end
		return section
	end
	local Items = createSection()
	local ItemBox, ItemColor, ItemResources, ItemName, ItemDistance, ItemScale, ItemWhitelistOnly, ItemAllowed
	local resources = {}
	local boxes = {}

	local function itemColor(name)
		local option = ItemResources and ItemResources.Enabled and resources[name] or ItemColor
		return Color3.fromHSV(option.Hue, option.Sat, option.Value)
	end

	local function recolor()
		if not Items.Enabled then return end
		for ent, box in boxes do
			box.Color3 = itemColor(ent.Name)
			box.Transparency = 1 - ItemColor.Opacity
		end
		for ent, nametag in Items.Reference do
			nametag.TextColor3 = itemColor(ent.Name)
		end
	end

	local function restart()
		Items:Restart()
	end

	local ItemESP = Main:Part({
		Label = 'Item boxes',
		Name = 'ItemESP',
		Function = function(callback)
			Items:Set(callback)
		end,
		Tooltip = 'Shows dropped items and their count through walls'
	})
	ItemBox = ItemESP:CreateToggle({
		Name = 'Box',
		Default = true,
		Function = restart,
		Tooltip = 'Draws a see-through box around each item drop'
	})
	ItemColor = ItemESP:CreateColorSlider({
		Name = 'Colour',
		DefaultOpacity = 0.35,
		Function = recolor,
		Tooltip = 'Colour of the box and text'
	})
	ItemResources = ItemESP:CreateToggle({
		Name = 'Resource colours',
		Default = true,
		Function = function(callback)
			for _, option in resources do
				if option.Object then
					option.Object.Visible = callback
				end
			end
			recolor()
		end,
		Tooltip = 'Gives each resource its own colour'
	})
	for _, resource in {
		{'iron', 'Iron colour', 0, 0, 0.85},
		{'gold', 'Gold colour', 0.13, 0.85, 1},
		{'diamond', 'Diamond colour', 0.53, 0.7, 1},
		{'emerald', 'Emerald colour', 0.38, 0.8, 0.9}
	} do
		resources[resource[1]] = ItemESP:CreateColorSlider({
			Name = resource[2],
			DefaultHue = resource[3],
			DefaultSat = resource[4],
			DefaultValue = resource[5],
			Darker = true,
			Function = recolor
		})
	end
	ItemName = ItemESP:CreateToggle({
		Name = 'Show name',
		Default = true,
		Function = restart,
		Tooltip = 'Shows the item name next to its count'
	})
	ItemDistance = ItemESP:CreateToggle({
		Name = 'Item distance',
		Function = restart,
		Tooltip = 'Shows the distance of the item'
	})
	ItemScale = ItemESP:CreateSlider({
		Name = 'Item scale',
		Default = 1,
		Min = 0.1,
		Max = 1.5,
		Decimal = 10,
		Function = restart
	})
	ItemWhitelistOnly = ItemESP:CreateGroup({
		Name = 'Item whitelist only',
		Function = function(callback)
			restart()
		end,
		Tooltip = 'Only renders whitelisted items'
	})
	ItemAllowed = ItemWhitelistOnly:CreateItemPicker({
		Name = 'Item allowed items',
		Multi = true,
		Items = bedwars.itemPickerList(nil, {Relevant = {'shop', 'resources'}}),
		Function = restart,
		Darker = true
	})

	Items.Start = function(self)
		local names, sizes = {}, {}
		local function added(ent)
			if self.Reference[ent] or not ent:IsA('BasePart') then return end
			local name = bedwars.ItemMeta[ent.Name] and bedwars.ItemMeta[ent.Name].displayName or ent.Name
			if ItemWhitelistOnly.Enabled and not table.find(ItemAllowed.ListEnabled, name:lower()) then return end
			names[ent] = name
			local nametag = Instance.new('TextLabel')
			nametag.TextSize = 14 * ItemScale.Value
			nametag.Font = Enum.Font.Arial
			nametag.Name = ent.Name
			nametag.AnchorPoint = Vector2.new(0.5, 1)
			nametag.BackgroundColor3 = Color3.new()
			nametag.BackgroundTransparency = 0.5
			nametag.BorderSizePixel = 0
			nametag.Visible = false
			nametag.Text = ''
			nametag.TextColor3 = itemColor(ent.Name)
			nametag.RichText = true
			nametag.Parent = self.Folder
			self.Reference[ent] = nametag
			if ItemBox.Enabled then
				local box = Instance.new('BoxHandleAdornment')
				box.Adornee = ent
				box.Size = ent.Size + Vector3.new(0.3, 0.3, 0.3)
				box.AlwaysOnTop = true
				box.ZIndex = 1
				box.Color3 = itemColor(ent.Name)
				box.Transparency = 1 - ItemColor.Opacity
				box.Parent = self.Folder
				boxes[ent] = box
			end
		end
		local function removing(ent)
			if self.Reference[ent] then
				self.Reference[ent]:Destroy()
				self.Reference[ent] = nil
			end
			if boxes[ent] then
				boxes[ent]:Destroy()
				boxes[ent] = nil
			end
			names[ent], sizes[ent] = nil, nil
		end
		self:Clean(collectionService:GetInstanceAddedSignal('ItemDrop'):Connect(added))
		self:Clean(collectionService:GetInstanceRemovedSignal('ItemDrop'):Connect(removing))
		self:Clean(runService.PreRender:Connect(function()
			for ent, nametag in self.Reference do
				local headPos, headVis = gameCamera:WorldToViewportPoint(ent.Position + Vector3.new(0, 1, 0))
				nametag.Visible = headVis
				if not headVis then continue end
				local amount = ent:GetAttribute('Amount') or 1
				local mag = ItemDistance.Enabled and entitylib.isAlive
					and math.floor((entitylib.character.RootPart.Position - ent.Position).Magnitude) or nil
				local cache = tostring(mag or '') .. ':' .. tostring(amount)
				if sizes[ent] ~= cache then
					local text = ItemName.Enabled and names[ent] or ''
					if amount >= 2 or text == '' then
						text = text .. (text ~= '' and ' ' or '') .. 'x' .. tostring(amount)
					end
					if ItemDistance.Enabled then
						text = '<font color="rgb(85, 255, 85)">[</font><font color="rgb(255, 255, 255)">' .. tostring(mag or 0) .. '</font><font color="rgb(85, 255, 85)">]</font> ' .. text
					end
					nametag.Text = text
					local size = getfontsize(removeTags(text), nametag.TextSize, nametag.FontFace, Vector2.new(100000, 100000))
					nametag.Size = UDim2.fromOffset(size.X + 8, size.Y + 7)
					sizes[ent] = cache
				end
				nametag.Position = UDim2.fromOffset(headPos.X, headPos.Y)
			end
		end))
		for _, v in collectionService:GetTagged('ItemDrop') do
			added(v)
		end
		self.Stop = function()
			table.clear(names)
			table.clear(sizes)
			table.clear(boxes)
		end
	end
end)

run(function()
	local Folder = Instance.new('Folder')
	Folder.Parent = vape.gui

	local function createSection()
		local section = {
			Enabled = false,
			Connections = {},
			Reference = {},
			Folder = Instance.new('Folder')
		}
		section.Folder.Parent = Folder
		function section:Clean(item)
			if type(item) == 'function' then
				table.insert(self.Connections, {Disconnect = item})
			elseif item then
				table.insert(self.Connections, item)
			end
		end
		function section:Clear()
			for _, connection in self.Connections do
				pcall(function() connection:Disconnect() end)
			end
			table.clear(self.Connections)
			if self.Stop then self.Stop(self) end
			for _, instance in self.Reference do
				pcall(function() instance:Destroy() end)
			end
			table.clear(self.Reference)
			self.Folder:ClearAllChildren()
		end
		function section:Set(callback)
			if callback == self.Enabled then return end
			self.Enabled = callback
			self:Clear()
			if callback and self.Start then self.Start(self) end
		end
		return section
	end
	local Loot = createSection()
	local LootPick
	local Callbacks = {}
	local LootESP = Main:Part({
		Label = 'Loot icons',
		Default = false,
		Name = 'LootESP',
		Function = function(callback)
			Loot:Set(callback)
			for _, setting in {LootPick} do
				if setting and setting.Object then
					setting.Object.Visible = callback
				end
			end
		end,
		Tooltip = 'Shows iron, diamond and emerald drops'
	})
	LootPick = LootESP:CreateMultiDropdown({
		Name = 'Loot',
		List = {'Iron', 'Diamond', 'Emerald'},
		Default = {'Iron', 'Diamond', 'Emerald'},
		Visible = false,
		Function = function()
			for _, kind in {'Iron', 'Diamond', 'Emerald'} do
				local callback = Callbacks['Loot'..kind]
				if callback then callback() end
			end
		end,
		Tooltip = 'Which drops get an icon'
	})

	Loot.Start = function(self)
		local lootTypes = {
			iron = {keywords = {'iron'}, color = Color3.fromRGB(200, 200, 200), icon = 'iron', displayName = 'IRON'},
			diamond = {keywords = {'diamond'}, color = Color3.fromRGB(85, 200, 255), icon = 'diamond', displayName = 'DIAMOND'},
			emerald = {keywords = {'emerald'}, color = Color3.fromRGB(0, 255, 100), icon = 'emerald', displayName = 'EMERALD'}
		}
		local function getLootType(itemName)
			local nameLower = itemName:lower()
			for lootType, config in pairs(lootTypes) do
				for _, keyword in ipairs(config.keywords) do
					if nameLower:find(keyword, 1, true) then
						return lootType, config
					end
				end
			end
		end
		local function isLootEnabled(lootType)
			return LootPick:Has(lootType:sub(1, 1):upper()..lootType:sub(2))
		end
		local function added(lootHandle, lootType, config)
			if not isLootEnabled(lootType) then return end
			if self.Reference[lootHandle] then return end
			local billboard = Instance.new('BillboardGui')
			billboard.Parent = self.Folder
			billboard.Name = lootType
			billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
			billboard.Size = UDim2.fromOffset(40, 40)
			billboard.AlwaysOnTop = true
			billboard.ClipsDescendants = false
			billboard.Adornee = lootHandle
			local blur = addBlur(billboard)
			if blur then blur.Visible = true end
			local iconImage = bedwars.getIcon({itemType = config.icon}, true)
			if iconImage and iconImage ~= '' then
				local image = Instance.new('ImageLabel')
				image.Size = UDim2.fromOffset(40, 40)
				image.Position = UDim2.fromScale(0.5, 0.5)
				image.AnchorPoint = Vector2.new(0.5, 0.5)
				image.BackgroundColor3 = Color3.new(0, 0, 0)
				image.BackgroundTransparency = 0.3
				image.BorderSizePixel = 0
				image.Image = iconImage
				image.Parent = billboard
				local uicorner = Instance.new('UICorner')
				uicorner.CornerRadius = UDim.new(0, 4)
				uicorner.Parent = image
			else
				local frame = Instance.new('Frame')
				frame.Size = UDim2.fromScale(1, 1)
				frame.BackgroundColor3 = Color3.new(0, 0, 0)
				frame.BackgroundTransparency = 0.3
				frame.BorderSizePixel = 0
				frame.Parent = billboard
				local uicorner = Instance.new('UICorner')
				uicorner.CornerRadius = UDim.new(0, 4)
				uicorner.Parent = frame
				local textLabel = Instance.new('TextLabel')
				textLabel.Size = UDim2.fromScale(1, 1)
				textLabel.Position = UDim2.fromScale(0.5, 0.5)
				textLabel.AnchorPoint = Vector2.new(0.5, 0.5)
				textLabel.BackgroundTransparency = 1
				textLabel.Text = config.displayName
				textLabel.TextColor3 = config.color
				textLabel.TextScaled = true
				textLabel.Font = Enum.Font.GothamBold
				textLabel.TextStrokeTransparency = 0.5
				textLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
				textLabel.Parent = frame
			end
			self.Reference[lootHandle] = billboard
		end
		local function removed(lootHandle)
			if self.Reference[lootHandle] then
				self.Reference[lootHandle]:Destroy()
				self.Reference[lootHandle] = nil
			end
		end
		self.FindLoot = function()
			for _, drop in collectionService:GetTagged('ItemDrop') do
				local handle = drop:FindFirstChild('Handle')
				if handle then
					local lootType, config = getLootType(drop.Name)
					if lootType and isLootEnabled(lootType) and not self.Reference[handle] then
						added(handle, lootType, config)
					end
				end
			end
		end
		self.IsLootEnabled = isLootEnabled
		self.Added = added
		self.Removed = removed
		self.FindLoot()
		self:Clean(collectionService:GetInstanceAddedSignal('ItemDrop'):Connect(function(drop)
			if not self.Enabled then return end
			task.defer(function()
				local handle = drop:FindFirstChild('Handle')
				if not handle then return end
				local lootType, config = getLootType(drop.Name)
				if lootType and isLootEnabled(lootType) then
					added(handle, lootType, config)
				end
			end)
		end))
		self:Clean(collectionService:GetInstanceRemovedSignal('ItemDrop'):Connect(function(drop)
			local handle = drop:FindFirstChild('Handle')
			if handle then
				removed(handle)
			end
		end))
	end
	local lootConfigs = {
		iron = {icon = 'iron', displayName = 'IRON', color = Color3.fromRGB(200, 200, 200)},
		diamond = {icon = 'diamond', displayName = 'DIAMOND', color = Color3.fromRGB(85, 200, 255)},
		emerald = {icon = 'emerald', displayName = 'EMERALD', color = Color3.fromRGB(0, 255, 100)}
	}
	local function refreshLoot(section, lootType)
		if not Loot.Enabled then return end
		local enabled = section.IsLootEnabled and section.IsLootEnabled(lootType)
		if not enabled then
			for handle, billboard in Loot.Reference do
				if billboard.Name == lootType then
					billboard:Destroy()
					Loot.Reference[handle] = nil
				end
			end
		else
			for _, drop in collectionService:GetTagged('ItemDrop') do
				local handle = drop:FindFirstChild('Handle')
				if handle and not Loot.Reference[handle] then
					section.Added(handle, lootType, lootConfigs[lootType])
				end
			end
		end
	end
	Callbacks.LootIron = function() refreshLoot(Loot, 'iron') end
	Callbacks.LootDiamond = function() refreshLoot(Loot, 'diamond') end
	Callbacks.LootEmerald = function() refreshLoot(Loot, 'emerald') end
end)

end)
