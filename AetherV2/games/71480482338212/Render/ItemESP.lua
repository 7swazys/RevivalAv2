run(function()
	local ItemESP
	local MaxDistance
	local ShowAmount
	local ShowDistance
	local Resources
	local ShowBox
	local Colour
	local ResourceColours
	local ShowName
	local Scale
	local Whitelist
	local Allowed
	local Reference = {}
	local colors = {
		Emerald = Color3.fromRGB(50, 220, 80),
		Diamond = Color3.fromRGB(60, 200, 220),
		Iron = Color3.new(1, 1, 1)
	}
	local folder = Instance.new('Folder')
	folder.Parent = vape.gui
	vape:Clean(folder)

	local function itemName(drop)
		return drop:GetAttribute('Name') or drop.Name:match('^(.-)_%d+$') or drop.Name
	end

	local function rebuild()
		if ItemESP.Enabled then
			ItemESP:Toggle()
			ItemESP:Toggle()
		end
	end

	local function colourFor(name)
		if ResourceColours.Enabled and colors[name] then return colors[name] end
		return Color3.fromHSV(Colour.Hue, Colour.Sat, Colour.Value)
	end

	local function allowed(name)
		if not Whitelist.Enabled then return true end
		local lower = name:lower()
		for _, v in Allowed.ListEnabled do
			if lower == v:lower() then return true end
		end
		return false
	end

	local function added(drop)
		if Reference[drop] or not drop:IsA('Model') or not ItemESP.Enabled then return end
		local part = drop:FindFirstChild('Hitbox') or drop:FindFirstChildWhichIsA('BasePart')
		if not part then return end
		local name = itemName(drop)
		if Resources.Enabled and not colors[name] then return end
		if not allowed(name) then return end
		local color = colourFor(name)
		local box
		if ShowBox.Enabled then
			box = Instance.new('BoxHandleAdornment')
			box.Adornee = part
			box.Size = part.Size + Vector3.new(0.1, 0.1, 0.1)
			box.AlwaysOnTop = true
			box.ZIndex = 0
			box.Transparency = 0.6
			box.Color3 = color
			box.Parent = folder
		end
		local billboard = Instance.new('BillboardGui')
		billboard.Adornee = part
		billboard.AlwaysOnTop = true
		billboard.Size = UDim2.fromOffset(170 * Scale.Value, 16 * Scale.Value)
		billboard.StudsOffset = Vector3.new(0, 2.5, 0)
		billboard.Parent = folder
		local label = Instance.new('TextLabel')
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamMedium
		label.TextSize = math.round(12 * Scale.Value)
		label.TextColor3 = color
		label.TextStrokeTransparency = 0.4
		label.Parent = billboard
		Reference[drop] = {Billboard = billboard, Label = label, Part = part, Name = name, Box = box}
	end

	local function removed(drop)
		local ref = Reference[drop]
		if ref then
			Reference[drop] = nil
			ref.Billboard:Destroy()
			if ref.Box then ref.Box:Destroy() end
		end
	end

	ItemESP = vape.Categories.Render:CreateModule({
		Name = 'ItemESP',
		Function = function(callback)
			if callback then
				local container = workspace:FindFirstChild('DroppedItemsContainer')
				if not container then
					notif('ItemESP', 'This server has no dropped item folder yet.', 5, 'warning')
					return
				end
				ItemESP:Clean(container.ChildAdded:Connect(function(drop)
					task.defer(added, drop)
				end))
				ItemESP:Clean(container.ChildRemoved:Connect(removed))
				for _, drop in container:GetChildren() do
					added(drop)
				end

				repeat
					local origin = entitylib.isAlive and entitylib.character.RootPart.Position or gameCamera.CFrame.Position
					for drop, ref in Reference do
						local dist = (ref.Part.Position - origin).Magnitude
						local near = dist <= MaxDistance.Value
						if ref.Box and ref.Box.Visible ~= near then ref.Box.Visible = near end
						if ref.Billboard.Enabled ~= near then ref.Billboard.Enabled = near end
						if near then
							local color = colourFor(ref.Name)
							if ref.Label.TextColor3 ~= color then
								ref.Label.TextColor3 = color
								if ref.Box then ref.Box.Color3 = color end
							end
							if ref.Scale ~= Scale.Value then
								ref.Scale = Scale.Value
								ref.Billboard.Size = UDim2.fromOffset(170 * Scale.Value, 16 * Scale.Value)
								ref.Label.TextSize = math.round(12 * Scale.Value)
							end
							local text = ShowName.Enabled and ref.Name or ''
							local amount = drop:GetAttribute('Amount')
							if ShowAmount.Enabled and type(amount) == 'number' and amount > 1 then
								text ..= ' x'..amount
							end
							if ShowDistance.Enabled then
								text ..= string.format(' [%d]', dist)
							end
							text = text:gsub('^ ', '')
							if ref.Label.Text ~= text then ref.Label.Text = text end
						end
					end
					task.wait(0.2)
				until not ItemESP.Enabled
			else
				for drop in table.clone(Reference) do
					removed(drop)
				end
			end
		end,
		Tooltip = 'Shows dropped items and their count through walls'
	})
	Resources = ItemESP:CreateToggle({
		Name = 'Resources only',
		Function = function()
			rebuild()
		end,
		Tooltip = 'Only iron, diamonds and emeralds'
	})
	MaxDistance = ItemESP:CreateSlider({
		Name = 'Max distance',
		Min = 20,
		Max = 600,
		Default = 150,
		Suffix = 'studs'
	})
	ShowAmount = ItemESP:CreateToggle({
		Name = 'Amount',
		Default = true
	})
	ShowDistance = ItemESP:CreateToggle({
		Name = 'Distance',
		Default = true
	})
	ShowName = ItemESP:CreateToggle({
		Name = 'Show name',
		Default = true
	})
	ShowBox = ItemESP:CreateToggle({
		Name = 'Box',
		Function = rebuild,
		Tooltip = 'Draws a box around each drop'
	})
	ResourceColours = ItemESP:CreateToggle({
		Name = 'Resource colours',
		Default = true,
		Tooltip = 'Colours iron, diamonds and emeralds by type'
	})
	Colour = ItemESP:CreateColorSlider({
		Name = 'Colour',
		DefaultHue = 0.12,
		DefaultSat = 0.53,
		DefaultValue = 1
	})
	Scale = ItemESP:CreateSlider({
		Name = 'Item scale',
		Min = 0.5,
		Max = 2,
		Default = 1,
		Decimal = 10
	})
	Whitelist = ItemESP:CreateGroup({
		Name = 'Item whitelist only',
		Function = rebuild,
		Tooltip = 'Only shows the items in the list'
	})
	Allowed = Whitelist:CreateItemPicker({
		Name = 'Item allowed items',
		Multi = true,
		Items = store.itemPickerList(),
		Function = rebuild
	})
end)
