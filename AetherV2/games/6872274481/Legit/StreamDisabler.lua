run(function()
	local DisableStreamer
	local old = {}
	local oldLevels = {}
	local oldUsernames = {}
	local levelMap = {}
	local updaterThread = nil

	local function strip(plrs)
		if plrs == lplr then return end

		local disguiseName = plrs:GetAttribute("DisguiseDisplayName")
		if disguiseName and disguiseName ~= "" then
			old[plrs] = disguiseName
			plrs:SetAttribute("DisguiseDisplayName", "")
		end

		local disguiseUsername = plrs:GetAttribute("DisguiseUsername")
		if disguiseUsername and disguiseUsername ~= "" then
			oldUsernames[plrs] = disguiseUsername
			plrs:SetAttribute("DisguiseUsername", "")
		end

		local playerLevel = plrs:GetAttribute("PlayerLevel")
		if playerLevel then
			oldLevels[plrs] = playerLevel
			levelMap[plrs.Name] = playerLevel
		end
	end

	DisableStreamer = vape.Categories.Legit:CreateModule({
		Name = 'StreamDisabler',
		Function = function(callback)
			if callback then
				for _, plrs in playersService:GetPlayers() do
					strip(plrs)
				end

				pcall(function()
					bedwars.StreamerModeController:updateNametags(true)
				end)

				DisableStreamer:Clean(playersService.PlayerAdded:Connect(function(plrs)
					task.wait(1)
					if not DisableStreamer.Enabled or not plrs.Parent then return end
					strip(plrs)
					pcall(function()
						bedwars.StreamerModeController:updateNametags(true)
					end)
				end))
				DisableStreamer:Clean(playersService.PlayerRemoving:Connect(function(plrs)
					old[plrs], oldUsernames[plrs], oldLevels[plrs] = nil, nil, nil
					levelMap[plrs.Name] = nil
				end))

				updaterThread = task.spawn(function()
					while DisableStreamer.Enabled do
						local tabList = lplr.PlayerGui:FindFirstChild("TabListScreenGui")
						if tabList then
							for _, desc in tabList:GetDescendants() do
								if desc:IsA("TextLabel") and desc.Name == "PlayerLevel" then
									local text = desc.Text
									if text:find("%[%?%]") then
										local siblingName = desc.Parent:FindFirstChild("PlayerName")
										if siblingName then
											local currentNameText = siblingName.Text
											local cleanName = currentNameText:gsub("^@", ""):match("^%s*(.-)%s*$")

											local matchedPlayer = nil
											for _, plr in playersService:GetPlayers() do
												if plr == lplr then continue end
												if cleanName == plr.Name or cleanName == plr.DisplayName then
													matchedPlayer = plr
													break
												end
											end

											if matchedPlayer then
												local realLevel = levelMap[matchedPlayer.Name]
												if realLevel then
													desc.Text = '<font color="rgb(255,255,255)">[' .. tostring(realLevel) .. ']</font>'
												end
											end
										end
									end
								end
							end
						end
						task.wait(0.3)
					end
				end)
				DisableStreamer:Clean(updaterThread)
			else
				updaterThread = nil

				for _, plrs in playersService:GetPlayers() do
					if plrs == lplr then continue end

					if old[plrs] then
						plrs:SetAttribute("DisguiseDisplayName", old[plrs])
					end

					if oldUsernames[plrs] then
						plrs:SetAttribute("DisguiseUsername", oldUsernames[plrs])
					end

					if oldLevels[plrs] then
						plrs:SetAttribute("PlayerLevel", oldLevels[plrs])
					end
				end
				table.clear(old)
				table.clear(oldUsernames)
				table.clear(oldLevels)
				table.clear(levelMap)

				pcall(function()
					bedwars.StreamerModeController:updateNametags(true)
				end)

				task.spawn(function()
					local tabList = lplr.PlayerGui:FindFirstChild("TabListScreenGui")
					if tabList then
						tabList.Enabled = false
						task.wait()
						tabList.Enabled = true
					end
				end)
			end
		end,
		Tooltip = "Disables people's Streamer Modes"
	})
end)
