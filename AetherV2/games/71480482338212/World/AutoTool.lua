run(function()
	local AutoTool
	local Mode
	local Delay
	local SwitchBack
	local looking, lookUntil, previous = nil, 0, nil
	local held, current, started = false, nil, nil
	local gen, lookGen = 0, 0
	local oldRun, runHook, oldStop, stopHook
	local SERVER_RANGE = 21

	local function targetKind()
		local mouse = inputService:GetMouseLocation()
		local ray = gameCamera:ViewportPointToRay(mouse.X, mouse.Y)
		local length = (gameCamera.Focus.Position - ray.Origin).Magnitude + SERVER_RANGE
		local hit = workspace:Raycast(ray.Origin, ray.Direction * length, blockParams())
		if not hit or not entitylib.isAlive then return nil end
		local cell = snap(hit.Position - hit.Normal * 1.5)
		local body = (cell - entitylib.character.RootPart.Position).Magnitude
		if body > SERVER_RANGE then return nil end
		local server = (cell - realRoot().Position).Magnitude
		if server > SERVER_RANGE then return nil end

		local part = hit.Instance
		local team = lplr.Team and lplr.Team.Name
		local placed = workspace:FindFirstChild('PlayersBlocksContainer')
		if placed and part:IsDescendantOf(placed) then
			local object = part.Parent:IsA('Model') and part.Parent or part
			if team and object.Name == team..' Wool' then return nil end
			return object.Parent.Name, body, object
		end
		local beds = workspace:FindFirstChild('BedsContainer')
		if beds and part:IsDescendantOf(beds) then
			local bed = part
			while bed.Parent ~= beds do
				bed = bed.Parent
			end
			if team and bed:GetAttribute('Team') == team then return nil end
			return 'Bed', body, bed
		end
	end

	local function check()
		if tick() - (store.swordWanted or 0) < 0.5 then return end
		local kind, body = targetKind()
		if not kind then return end
		local tool, damage = getTool(kind)
		if not tool or (damage or 0) <= 0 or heldName() == tool then return end
		local data = bedfight.MiningData[tool]
		local reach = math.min(type(data) == 'table' and data.Range or 18, SERVER_RANGE)
		if body > reach then return end
		if not store.hotbarEquip(tool) then return end
		local deadline = tick() + 0.5
		repeat
			task.wait()
		until not (AutoTool.Enabled and held) or (current and current.Name == tool) or tick() > deadline
		if AutoTool.Enabled and held and current and current.Name == tool then
			if pcall(current.Activate, current) then
				started = current
			end
		end
	end

	local function lookStep()
		if not entitylib.isAlive or tick() - (store.swordWanted or 0) < 0.5 then return end
		local kind, body, object = targetKind()
		local tool, damage
		if kind then
			tool, damage = getTool(kind)
			local data = tool and bedfight.MiningData[tool]
			if (damage or 0) <= 0 or body > math.min(type(data) == 'table' and data.Range or 18, SERVER_RANGE) then
				kind = nil
			end
		end
		if not kind then
			looking = nil
			if SwitchBack.Enabled and previous then
				if heldName() ~= previous then
					store.hotbarEquip(previous)
				end
				previous = nil
			end
			return
		end
		if object ~= looking then
			looking, lookUntil = object, tick() + Delay:GetRandomValue()
			return
		end
		if tick() < lookUntil or heldName() == tool then return end
		local before = heldName()
		if store.hotbarEquip(tool) then
			previous = previous or before
		end
	end

	local function hook()
		local mining = bedfight.Mining
		if runHook or type(mining) ~= 'table' or type(mining.Run) ~= 'function' then return end
		oldRun, oldStop = mining.Run, mining.Stop
		runHook = function(self, ...)
			current = self
			return oldRun(self, ...)
		end
		stopHook = function(self, ...)
			if current == self then
				current = nil
			end
			return oldStop(self, ...)
		end
		mining.Run, mining.Stop = runHook, stopHook
	end

	local function unhook()
		local mining = bedfight.Mining
		if not runHook or type(mining) ~= 'table' then return end
		if mining.Run == runHook then
			mining.Run = oldRun
		end
		if mining.Stop == stopHook then
			mining.Stop = oldStop
		end
		if mining.Run ~= runHook and mining.Stop ~= stopHook then
			oldRun, runHook, oldStop, stopHook = nil, nil, nil, nil
		end
	end

	AutoTool = vape.Categories.World:CreateModule({
		Name = 'AutoTool',
		Function = function(callback)
			if callback then
				hook()
				lookGen += 1
				local loop = lookGen
				task.spawn(function()
					while AutoTool.Enabled and loop == lookGen do
						if Mode.Value == 'Look' then
							pcall(lookStep)
						end
						task.wait(0.05)
					end
				end)
				AutoTool:Clean(inputService.InputBegan:Connect(function(input, processed)
					if processed or input.UserInputType ~= Enum.UserInputType.MouseButton1 or Mode.Value ~= 'Break' then return end
					held = true
					gen += 1
					local id = gen
					task.spawn(function()
						while AutoTool.Enabled and held and id == gen do
							check()
							task.wait(0.1)
						end
					end)
				end))
				AutoTool:Clean(inputService.InputEnded:Connect(function(input)
					if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
					held = false
					if started then
						pcall(started.StopMining, started)
						started = nil
					end
				end))
			else
				gen += 1
				lookGen += 1
				held = false
				looking, previous = nil, nil
				if started then
					pcall(started.StopMining, started)
					started = nil
				end
				unhook()
			end
		end,
		Tooltip = 'Selects the right tool for what you are mining'
	})
	Mode = AutoTool:CreateDropdown({
		Name = 'Mode',
		List = {'Look', 'Break'},
		Default = 'Break',
		Tooltip = 'Look - swaps while you aim at a block\nBreak - swaps on the first hit'
	})
	Delay = AutoTool:CreateTwoSlider({
		Name = 'Delay',
		Min = 0,
		Max = 1,
		Decimal = 100,
		DefaultMin = 0.06,
		DefaultMax = 0.16,
		Darker = true,
		Suffix = 'seconds',
		Visible = function() return Mode.Value == 'Look' end,
		Tooltip = 'How long you look at a block before it swaps'
	})
	SwitchBack = AutoTool:CreateToggle({
		Name = 'Switch back',
		Darker = true,
		Visible = function() return Mode.Value == 'Look' end,
		Tooltip = 'Puts back the item you were holding once you look away'
	})
end)
