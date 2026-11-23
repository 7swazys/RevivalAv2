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
		local v17 = nil
		local tbl3 = { "gg", "gg2", "DV", "DV2" }

		local tbl4 = {
			1502104539,
			3826146717,
			4531785383,
			1049767300,
			4926350670,
			653085195,
			184655415,
			2752307430,
			5087196317,
			5744061325,
			1536265275,
		}

		local tbl5 = {}
		local tbl6 = {}
		local tbl7 = {}
		local tbl8 = { Spectate = 0, Mod = 0, Impossible = 0 }
		local tbl9 = { Spectate = "rgb(236,129,43)", Mod = "rgb(250,50,56)", Impossible = "rgb(180,90,250)" }
		local tbl10 = {}
		local textButton = nil
		local textLabel = nil
		local flag = nil
		local uninjecting = false

		local function fn5()
			if not textButton then
				return
			end
			local flag2 = flag and #tbl10 > 0
			local tbl11 = { "<b>StaffDetector</b>", "<font size=\"4\"> </font>" }

			for _, v18 in { "Spectate", "Mod", "Impossible" }, nil, nil do
				local insert = table.insert
				local str = ("<font color=\"%*\">%*: %*</font>"):format(tbl9[v18], v18, tbl8[v18])
				insert(tbl11, str)
			end

			if flag2 then
				table.insert(tbl11, "<font size=\"4\"> </font>")

				for k, v18 in tbl10, nil, nil do
					if not (k > 8) then
						local insert = table.insert
						local str = ("%* <font color=\"%*\">%*</font>"):format(v18.Name, tbl9[v18.Category], v18.Reason)
						insert(tbl11, str)
						continue
					end

					break
				end
			end

			textLabel.Text = table.concat(tbl11, "\n")
			local textSize = textLabel.TextSize
			local fontFace = textLabel.FontFace
			local v18 = getfontbounds(removeTags(textLabel.Text), textSize, fontFace)
			textButton.Size = UDim2.fromOffset(math.max(v18.X, getfontbounds("StaffDetector", textLabel.TextSize, Font.new(textLabel.FontFace.Family, Enum.FontWeight.Bold)).X) + 16, v18.Y + (flag2 and -8 or 4))
		end

		local function fn6(arg, arg2)
			if not vape.Loaded then
				repeat
					task.wait()
				until vape.Loaded or vape.Loaded == nil
			end
			if not vape.Loaded or uninjecting then
				return
			end

			notif("StaffDetector", ("Staff Detected (%*): %* (%*)"):format(arg2, arg.Name, arg.UserId), 60, "alert")
			whitelist.customtags[arg.Name] = { { text = "GAME STAFF", color = Color3.new(1, 0, 0) } }
			local str = arg2 == "impossible_join" and "Impossible" or arg2 == "spectator" and "Spectate" or "Mod"
			tbl8[str] = tbl8[str] + 1
			table.insert(tbl10, 1, { Name = arg.Name, Reason = arg2, Category = str })
			fn5()

			if v15.Enabled and not arg2:find("clan") then
				bedwars.PartyController:leaveParty()
			end

			if v13.Value == "Uninject" then
				uninjecting = true
				task.spawn(function()
					vape:Uninject()
				end)

				game:GetService("StarterGui"):SetCore("SendNotification", {
					Title = "StaffDetector",
					Text = ("Staff Detected (%*)\n%* (%*)"):format(arg2, arg.Name, arg.UserId),
					Duration = 60,
				})
			elseif v13.Value == "Requeue" then
				bedwars.QueueController:joinQueue(store.queueType)
			elseif v13.Value == "Profile" then
				vape.Save = function()
				end

				if vape.Profile ~= v16.Value then
					vape:Load(true, v16.Value)
				end
			elseif v13.Value == "AutoConfig" then
				local tbl11 = { "AutoClicker", "Reach", "Sprint", "HitFix", "StaffDetector" }

				vape.Save = function()
				end

				for k, v18 in vape.Modules, nil, nil do
					if not (table.find(tbl11, k) or v18.Category == "Render") then
						if v18.Enabled then
							v18:Toggle()
						end

						v18:SetBind({})
					end
				end
			end
		end

		local function fn7(arg, arg2)
			notif("StaffDetector", ("Spectator %* joined %*"):format(arg.Name, arg2), 20, "warning")
			tbl8.Spectate = tbl8.Spectate + 1
			table.insert(tbl10, 1, { Name = arg.Name, Reason = "spectator", Category = "Spectate" })
			fn5()
		end

		local function fn8(arg, arg2)
			local attribute = arg:GetAttribute("Team") or not arg:GetAttribute("Spectator") or store.matchState ~= 1 or bedwars.Store:getState().Game.customMatch

			if not attribute then
				attribute = tick() - (tbl7[arg.UserId] or 0) > 20
			end

			if attribute then
				return
			end
			arg2:Disconnect()
			task.wait(5)
			if not v12.Enabled or arg.Parent ~= v3 or arg:GetAttribute("Team") or not arg:GetAttribute("Spectator") then
				return
			end

			if tbl6[arg.UserId] then
				fn7(arg, "back after leaving")
				return
			end

			if arg.FollowUserId ~= 0 and tbl5[arg.FollowUserId] then
				local v18 = fn7
				local str = ("following %*"):format(tbl5[arg.FollowUserId])
				v18(arg, str)
				return
			end

			local ok, result = pcall(v3.GetFriendsAsync, v3, arg.UserId)
			if not ok then
				return
			end
			local isFinished = result.IsFinished
			local v18 = nil

			for i = 1, 6 do
				for _, v19 in result:GetCurrentPage() do
					if tbl5[v19.Id] then
						v18 = tbl5[v19.Id]
						break
					end
				end

				if v18 or isFinished then
					break
				end

				if not pcall(result.AdvanceToNextPageAsync, result) then
					return
				end
				isFinished = result.IsFinished
			end

			if v18 then
				local v19 = fn7
				local str = ("from %*"):format(v18)
				v19(arg, str)
			elseif isFinished then
				fn6(arg, "impossible_join")
				return true
			end
		end

		local function fn9(player)
			if tbl5[player.UserId] then
				tbl6[player.UserId] = true
			end

			tbl5[player.UserId] = player.Name
			local attribute = player:GetAttribute("LastTeleported")
			local v18 = tbl7
			local userId = player.UserId

			if attribute then
				local min = math.min
				local v19 = workspace
				attribute = tick() - min(v19:GetServerTimeNow() - attribute, 60)
			end

			v18[userId] = attribute or tick()
			if player == localPlayer then
				return
			end

			if table.find(tbl4, player.UserId) or table.find(v17.ListEnabled, tostring(player.UserId)) then
				fn6(player, "blacklisted_user")
			else
				local ok, result = pcall(function()
					return player:GetRankInGroup(5774246)
				end)

				if not ok then
					notif("StaffDetector", result, 30, "alert")
				end

				if (ok and result or 0) >= 100 then
					fn6(player, "staff_role")
				else
					local connection = nil

					connection = player:GetAttributeChangedSignal("Spectator"):Connect(function()
						fn8(player, connection)
					end)

					v12:Clean(connection)
					if fn8(player, connection) then
						return
					end

					if not player:GetAttribute("ClanTag") then
						player:GetAttributeChangedSignal("ClanTag"):Wait()
					end

					if table.find(tbl3, player:GetAttribute("ClanTag")) and vape.Loaded and v14.Enabled then
						connection:Disconnect()
						local v19 = fn6
						local str = ("blacklisted_clan_%*"):format(player:GetAttribute("ClanTag"):lower())
						v19(player, str)
					end
				end
			end
		end

		v12 = vape.Categories.Utility:CreateModule({
			Name = "StaffDetector",
			Function = function(arg)
				if arg then
					v12:Clean(v3.PlayerAdded:Connect(fn9))

					for _, v18 in v3:GetPlayers() do
						task.spawn(fn9, v18)
					end
				else
					table.clear(tbl5)
					table.clear(tbl6)
					table.clear(tbl7)
				end
			end,
			Tooltip = 'Detects staff in your server',
		})

		v13 = v12:CreateDropdown({
			Name = "Mode",
			List = { "Uninject", "Profile", "Requeue", "AutoConfig", "Notify" },
			Function = function(arg)
				if v16 and v16.Object then
					v16.Object.Visible = arg == "Profile"
				end
			end,
		})
		v16 = v12:CreateTextBox({ Name = "Profile", Default = "default", Darker = true, Visible = false })

		v14 = v12:CreateToggle({ Name = "Blacklist clans", Default = true })
		v15 = v12:CreateToggle({ Name = "Leave party" })
		v17 = v12:CreateTextList({ Name = "Users", Placeholder = "player (userid)" })

		v12:CreateToggle({
			Name = "Viewer",
			Function = function(visible)
				if visible and not textButton then
					textButton = Instance.new("TextButton")
					textButton.Name = "StaffDetectorViewer"
					textButton.Position = UDim2.fromOffset(12, 120)
					textButton.BackgroundColor3 = Color3.new()
					textButton.BackgroundTransparency = 0.5
					textButton.Text = ""
					textButton.AutoButtonColor = false
					textButton.Parent = vape.gui.ScaledGui
					addBlur(textButton)
					local uiCorner = Instance.new("UICorner")
					uiCorner.CornerRadius = UDim.new(0, 5)
					uiCorner.Parent = textButton
					textLabel = Instance.new("TextLabel")
					textLabel.Size = UDim2.new(1, -16, 1, -16)
					textLabel.Position = UDim2.fromOffset(8, 8)
					textLabel.BackgroundTransparency = 1
					textLabel.TextXAlignment = Enum.TextXAlignment.Left
					textLabel.TextYAlignment = Enum.TextYAlignment.Top
					textLabel.TextSize = 16
					textLabel.TextColor3 = Color3.new(1, 1, 1)
					textLabel.TextStrokeColor3 = Color3.new()
					textLabel.TextStrokeTransparency = 0.8
					textLabel.Font = Enum.Font.Arial
					textLabel.RichText = true
					textLabel.Parent = textButton

					textButton.MouseButton1Click:Connect(function()
						flag = not flag
						fn5()
					end)
				end

				if textButton then
					textButton.Visible = visible
					fn5()
				end
			end,
			Tooltip = 'Shows a panel of who was detected',
		})

		task.spawn(function()
			while true do
				task.wait(1)
				if not (vape.Loaded or vape.Loaded == nil) then
					continue
				end
				break
			end

			if vape.Loaded and not v12.Enabled then
				v12:Toggle()
			end
		end)
	end)
