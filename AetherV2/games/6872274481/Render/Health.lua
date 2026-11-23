run(function()
    local Health

    local function read()
	local character = entitylib.isAlive and lplr.Character
	local health = character and tonumber(character:GetAttribute('Health'))
	if not health then
		return '', Color3.new()
	end
	local maxHealth = math.max(tonumber(character:GetAttribute('MaxHealth')) or health, 1)
	return math.round(health) .. ' ❤️', Color3.fromHSV(math.clamp(health / maxHealth, 0, 1) / 2.8, 0.86, 1)
    end

    Health = vape.Categories.Render:CreateModule({
	Name = 'Health',
	Function = function(callback)
		if callback then
			local label = Instance.new('TextLabel')
			label.Size = UDim2.fromOffset(100, 20)
			label.Position = UDim2.new(0.5, 6, 0.5, 30)
			label.BackgroundTransparency = 1
			label.AnchorPoint = Vector2.new(0.5, 0)
			label.Text, label.TextColor3 = read()
			label.TextSize = 18
			label.Font = Enum.Font.Arial
			label.Parent = vape.gui
			Health:Clean(label)
			Health:Clean(vapeEvents.AttributeChanged.Event:Connect(function()
				label.Text, label.TextColor3 = read()
			end))
		end
	end,
	Tooltip = 'Shows your health in the centre of your screen'
    })
end)
