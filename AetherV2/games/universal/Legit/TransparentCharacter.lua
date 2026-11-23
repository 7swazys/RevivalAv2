run(function()
	local TransparentCharacter
	local Amount
	local originals = setmetatable({}, {__mode = 'k'})
	local watchedCharacter
	local descendantConnection

	local function desiredTransparency()
		return Amount.Value / 100
	end

	local function fade(obj)
		if not obj:IsA('BasePart') or obj.Name == 'HumanoidRootPart' or obj.Name == 'Hitbox' then return end
		local base = originals[obj]
		if base == nil then
			base = obj.Transparency
			if base >= 1 then return end
			originals[obj] = base
		end
		local value = math.max(base, desiredTransparency())
		if obj.Transparency ~= value then obj.Transparency = value end
	end

	local function applyTransparency(char)
		if not char or char ~= watchedCharacter or not Amount then return end
		for _, obj in char:GetDescendants() do
			fade(obj)
		end
	end

	local function restoreTransparency()
		for obj, value in originals do
			if obj.Parent then obj.Transparency = value end
		end
		table.clear(originals)
	end
	local function watchCharacter(char)
		if descendantConnection then
			descendantConnection:Disconnect()
			descendantConnection = nil
		end
		restoreTransparency()
		watchedCharacter = char
		applyTransparency(char)
		if char then
			descendantConnection = char.DescendantAdded:Connect(function(obj)
				if obj:IsA('BasePart') and char == watchedCharacter and TransparentCharacter.Enabled then
					task.defer(function()
						if obj.Parent and char == watchedCharacter and TransparentCharacter.Enabled then
							fade(obj)
						end
					end)
				end
			end)
		end
	end

	TransparentCharacter = vape.Categories.Legit:CreateModule({
		Name = 'TransparentCharacter',
		Tooltip = 'Makes your character see-through on your screen',
		Function = function(callback)
			if callback then
				watchCharacter(lplr.Character)
				TransparentCharacter:Clean(lplr.CharacterAdded:Connect(watchCharacter))
				
				
				
			else
				if descendantConnection then descendantConnection:Disconnect(); descendantConnection = nil end
				restoreTransparency()
				watchedCharacter = nil
			end
		end
	})
	Amount = TransparentCharacter:CreateSlider({
		Name = 'Transparency',
		Min = 0,
		Max = 100,
		Default = 50,
		Suffix = '%',
		Function = function()
			if TransparentCharacter.Enabled then applyTransparency(lplr.Character) end
		end
	})
	TransparentCharacter:CreateButton({
		Name = 'Reset to default appearance',
		Tooltip = 'Makes your character fully visible again',
		Function = function()
			Amount:SetValue(0)
		end,
	})
end)
