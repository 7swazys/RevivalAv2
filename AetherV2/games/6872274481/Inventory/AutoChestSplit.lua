run(function()
	local v2 = httpService
	local v3 = playersService
	local v4 = replicatedStorage
	local v5 = runService
	local v6 = inputService
	local v7 = tweenService
	local v8 = collectionService
	local v9 = guiService
	local v10 = game:GetService('TeleportService')
	local obj = debug
	local currentCamera = gameCamera
	local localPlayer = lplr
	local entity = entitylib
	local getfontbounds = getfontsize
	local getvapeasset = getcustomasset

		local v12 = nil
		local v13 = nil
		local v14 = nil
		local v15 = nil
		local v16 = nil
		local n = 0

		local function fn5(arg)
			for _, v17 in v8:GetTagged("personal-chest") do
				local primaryPart = not v17:IsA("Model") and v17 or v17.PrimaryPart or v17:FindFirstChildWhichIsA("BasePart", true)
				if primaryPart and (primaryPart.Position - arg).Magnitude <= v14.Value then
					return primaryPart
				end
			end

			return nil
		end

		local function fn6(arg)
			local attribute = localPlayer:GetAttribute("Team")
			local huge = math.huge
			local v17 = nil

			for _, v18 in v8:GetTagged("team-crate") do
				local primaryPart = not v18:IsA("Model") and v18 or v18.PrimaryPart or v18:FindFirstChildWhichIsA("BasePart", true)
				local magnitude = primaryPart and (primaryPart.Position - arg).Magnitude or math.huge

				if magnitude < huge then
					huge = magnitude
					v17 = v18
				end
			end

			return v17 ~= nil and v17:GetAttribute("Team") ~= attribute
		end

		local function fn7()
			local inventories = v4:FindFirstChild("Inventories")
			local v17

			if inventories then
				local findFirstChild = inventories.FindFirstChild
				local str = ("%*_personal"):format(localPlayer.Name)
				v17 = findFirstChild(inventories, str)
			else
				v17 = inventories
			end

			local v18 = v17 or nil
			if not v18 then
				return
			end

			for _, v19 in v13.ListEnabled, nil, nil do
				local v20 = getItem(v19)
				local flag

				if v20 then
					flag = (v20.amount or 1) >= v15.Value
				else
					flag = v20
				end

				if flag then
					task.spawn(function()
						bedwars.Client:GetNamespace("Inventory"):Get("ChestGiveItem"):CallServer(v18, v20.tool)
					end)
				end
			end
		end

		local v17

		v12 = vape.Categories.Inventory:CreateModule({
			Name = "AutoChestSplit",
			Function = function(arg)
				if arg then
					n = 0

					while true do
						task.wait()
						if not (store.matchState ~= 0 or not v12.Enabled) then
							continue
						end
						break
					end

					if not v12.Enabled then
						return
					end

					while true do
						if entity.isAlive and tick() >= n and #v13.ListEnabled > 0 then
							local position = entity.character.RootPart.Position

							if fn5(position) and (not v16.Enabled or fn6(position)) then
								local value = v17.Value
								n = tick() + value
								fn7()
							end
						end

						task.wait(0.1)
						if v12.Enabled then
							continue
						end
						break
					end
				end
			end,
			Tooltip = 'Banks the split in your personal chest when you reach one',
		})

		v13 = v12:CreateMultiDropdown({ Name = "Items", List = { "iron", "diamond", "emerald" }, Default = { "diamond", "emerald" }, Tooltip = "What counts as the split" })

		v14 = v12:CreateSlider({
			Name = "Range",
			Min = 1,
			Max = 18,
			Default = 18,
			Suffix = function(arg)
				return arg <= 1 and "stud" or "studs"
			end,
			Tooltip = 'How close to the chest you need to be',
		})

		v15 = v12:CreateSlider({
			Name = "Minimum",
			Min = 1,
			Max = 64,
			Default = 1,
			Tooltip = 'Only acts when you hold at least this many',
		})

		v16 = v12:CreateToggle({
			Name = "Enemy base only",
			Default = true,
			Tooltip = "Only banks at a chest that is closer to their generator than yours",
		})

		v17 = v12:CreateSlider({ Name = "Delay", Min = 0, Max = 5, Decimal = 10, Default = 0.5, Suffix = "seconds" })
	end)
