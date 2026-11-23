run(function()
	local Entity = entitylib
	local GetItem = getItem
	local LocalPlayer = lplr
	local Store = store
	local AutoReset
	local Delay
	local Pearl
	local Whisper
	local Lasso
	local LowestPoint: number = math.huge

	local function GetVoidLine(): number
		if LowestPoint == math.huge then
			for _, v: BasePart in Store.blocks do
				local Point: number = (v.Position.Y - (v.Size.Y / 2)) - 50
				if Point < LowestPoint then
					LowestPoint = Point
				end
			end
		end
		return LowestPoint
	end

	local function IsLassoed(): boolean
		for _, v: Instance in LocalPlayer.Character and LocalPlayer.Character:GetChildren() or {} do
			if v:IsA("Accessory") and v:FindFirstChild("Rope") then
				return true
			end
		end
		return false
	end

	local function CanSave(): boolean
		if Pearl.Enabled and GetItem("telepearl") then
			return true
		end
		if Whisper.Enabled and LocalPlayer:GetAttribute("IsOwlTarget") then
			return true
		end
		return Lasso.Enabled and IsLassoed()
	end

	AutoReset = vape.Categories.Utility:CreateModule({
		Name = "AutoReset",
		Function = function(Callback: boolean)
			if Callback then
				local Falling
				repeat
					if Store.matchState == 1 and Entity.isAlive then
						local Character = Entity.character
						local Root: BasePart = Character.RootPart
						if Falling and Falling ~= Character then
							Falling = nil
						end

						if not Falling and not CanSave() and Root.Position.Y < GetVoidLine() and Root.AssemblyLinearVelocity.Y < 0 and not workspace:Raycast(Root.Position, Vector3.new(0, -2000, 0), Store.airRay) then
							Falling = Character
							task.delay(Delay.Value, function()
								if AutoReset.Enabled and Entity.isAlive and Entity.character == Character and Root.Parent and not CanSave() and Root.AssemblyLinearVelocity.Y < 0 and not workspace:Raycast(Root.Position, Vector3.new(0, -2000, 0), Store.airRay) then
									bedwars.Handler:Get("ResetCharacter"):Fire("SendToServer")
								elseif Falling == Character then
									Falling = nil
								end
							end)
						end
					else
						Falling = nil
					end
					task.wait(0.05)
				until not AutoReset.Enabled
			end
		end,
		Tooltip = 'Resets when you fall into the void so you respawn sooner'
	})

	Delay = AutoReset:CreateSlider({
		Name = "Delay",
		Min = 0,
		Max = 2,
		Default = 0,
		Decimal = 10,
		Suffix = function(Value: number)
			return Value == 1 and "second" or "seconds"
		end,
		Tooltip = 'How long to wait before resetting'
	})
	local Checks
	Checks = AutoReset:CreateMultiDropdown({
		Name = 'Checks',
		List = {'Telepearl', 'Owl', 'Lasso'},
		Default = {'Telepearl', 'Owl', 'Lasso'},
		Tooltip = 'Does not reset while one of these can still save you'
	})
	Pearl = setmetatable({}, {__index = function(_, key) if key == 'Enabled' then return Checks:Has('Telepearl') end end})
	Whisper = setmetatable({}, {__index = function(_, key) if key == 'Enabled' then return Checks:Has('Owl') end end})
	Lasso = setmetatable({}, {__index = function(_, key) if key == 'Enabled' then return Checks:Has('Lasso') end end})
end)
