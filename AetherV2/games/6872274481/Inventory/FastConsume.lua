run(function()
	local FastConsume
	local Value
	local realDuration = setmetatable({}, {__mode = 'k'})
	local realHold = setmetatable({}, {__mode = 'k'})
	local oldStart, oldUpdate, startHook, updateHook

	local function factor()
		return math.clamp(Value.Value / 40, 0, 1)
	end

	local function scaleClick(self)
		local base = realDuration[self]
		if base == nil then
			base = self.durationSeconds
			realDuration[self] = base
		end
		if type(base) == 'number' then
			self.durationSeconds = base * factor()
		end
	end

	local function scalePrompt(prompt)
		local base = realHold[prompt]
		if base == nil then
			base = prompt.HoldDuration
			realHold[prompt] = base
		end
		local scaled = base * factor()
		if prompt.HoldDuration ~= scaled then prompt.HoldDuration = scaled end
	end

	FastConsume = vape.Categories.Inventory:CreateModule({
		Name = 'FastConsume',
		Function = function(callback)
			local class = bedwars.ClickHold
			if callback then
				if class and not startHook then
					oldStart, oldUpdate = class.startClick, class.updateDuration
					startHook = function(self, ...)
						if FastConsume.Enabled then scaleClick(self) end
						return oldStart(self, ...)
					end
					updateHook = function(self, seconds, ...)
						realDuration[self] = seconds
						local result = oldUpdate(self, seconds, ...)
						if FastConsume.Enabled and type(seconds) == 'number' then self.durationSeconds = seconds * factor() end
						return result
					end
					class.startClick = startHook
					class.updateDuration = updateHook
				end
				FastConsume:Clean(proximityPromptService.PromptShown:Connect(scalePrompt))
				FastConsume:Clean(proximityPromptService.PromptButtonHoldBegan:Connect(scalePrompt))
			else
				if class and startHook then
					if rawget(class, 'startClick') == startHook then class.startClick = oldStart end
					if rawget(class, 'updateDuration') == updateHook then class.updateDuration = oldUpdate end
					if class.startClick ~= startHook then startHook, updateHook = nil, nil end
				end
				for self, base in realDuration do
					self.durationSeconds = base
				end
				table.clear(realDuration)
				for prompt, base in realHold do
					if prompt.Parent and prompt.HoldDuration ~= base then prompt.HoldDuration = base end
				end
				table.clear(realHold)
			end
		end,
		Tooltip = 'Eats, drinks, opens and finishes every hold action faster, including hold prompts'
	})
	Value = FastConsume:CreateSlider({
		Name = 'Multiplier',
		Min = 0,
		Max = 100,
		Function = function()
			if not FastConsume.Enabled then return end
			for prompt in realHold do
				if prompt.Parent then scalePrompt(prompt) end
			end
		end,
		Tooltip = 'How long hold actions take; 40 is the normal time and 0 is instant'
	})
end)
