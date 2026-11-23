run(function()
	local v12 = nil
	local v13 = nil
	local RequestMatchHistory = bedwars.Handler:Get("RequestMatchHistory")
	local tbl3 = {}
	local tbl4 = {}

	local function fn6(arg)
		local userId = arg.UserId
		if tbl3[userId] then
			return tbl3[userId]
		end

		while tbl4[userId] do
			task.wait()
		end

		if tbl3[userId] then
			return tbl3[userId]
		end
		tbl4[userId] = true
		local CallServer = RequestMatchHistory:Fire("CallServer", tostring(arg.Name))
		local tbl5 = {}

		if type(CallServer) == "table" and type(CallServer.matchHistory) == "table" then
			table.sort(CallServer.matchHistory, function(arg2, arg3)
				return arg2.matchStartTime > arg3.matchStartTime
			end)

			for k, v14 in CallServer.matchHistory, nil, nil do
				if not (k > 8) then
					local players = v14.players or {}
					local str = "none"

					for _, v15 in players, nil, nil do
						if v15.playerInfo and v15.playerInfo.userId == userId then
							str = v15.bedwars and v15.bedwars.kit or "none"
							break
						end
					end

					table.insert(tbl5, str)
					continue
				end

				break
			end

			tbl3[userId] = tbl5
		end

		tbl4[userId] = nil
		return tbl5
	end

	local function fn7(parent, arg)
		local previousKits = parent:FindFirstChild("PreviousKits")

		if previousKits then
			previousKits:Destroy()
		end

		if not v13.Enabled then
			return
		end
		local frame = Instance.new("Frame")
		frame.Name = "PreviousKits"
		frame.AnchorPoint = Vector2.new(0.5, 0)
		frame.Position = UDim2.fromScale(0.5, 0.03)
		frame.Size = UDim2.fromScale(0.86, 0.24)
		frame.BackgroundColor3 = Color3.new()
		frame.BackgroundTransparency = 1
		frame.BorderSizePixel = 0
		frame.ClipsDescendants = true
		frame.ZIndex = 3
		frame.Parent = parent
		v12:Clean(frame)
		local uiCorner = Instance.new("UICorner")
		uiCorner.CornerRadius = UDim.new(0, 4)
		uiCorner.Parent = frame
		local uiPadding = Instance.new("UIPadding")
		uiPadding.PaddingLeft = UDim.new(0, 3)
		uiPadding.PaddingRight = UDim.new(0, 3)
		uiPadding.Parent = frame
		local uiListLayout = Instance.new("UIListLayout")
		uiListLayout.FillDirection = Enum.FillDirection.Horizontal
		uiListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
		uiListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		uiListLayout.Padding = UDim.new(0, 2)
		uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
		uiListLayout.Parent = frame
		local v14 = fn6(arg)
		if not v12.Enabled or not v13.Enabled or not frame.Parent then
			return
		end

		if #v14 == 0 then
			frame:Destroy()
			return
		end
		frame.BackgroundTransparency = 1

		for k, v15 in v14, nil, nil do
			local none = bedwars.BedwarsKitMeta[v15] or bedwars.BedwarsKitMeta.none
			local imageLabel = Instance.new("ImageLabel")
			imageLabel.Name = ("Kit%*"):format(k)
			imageLabel.LayoutOrder = k
			imageLabel.Size = UDim2.fromScale(1, 1)
			imageLabel.SizeConstraint = Enum.SizeConstraint.RelativeYY
			imageLabel.BackgroundTransparency = 1
			imageLabel.Image = none.renderImage
			imageLabel.ScaleType = Enum.ScaleType.Fit
			imageLabel.ZIndex = 4
			imageLabel.Parent = frame
			local textLabel = Instance.new("TextLabel")
			textLabel.Name = "Order"
			textLabel.Position = UDim2.fromOffset(1, 1)
			textLabel.Size = UDim2.fromOffset(13, 13)
			textLabel.BackgroundColor3 = Color3.new()
			textLabel.BackgroundTransparency = 1
			textLabel.BorderSizePixel = 0
			textLabel.FontFace = uipallet.FontBold
			textLabel.Text = tostring(k)
			textLabel.TextColor3 = Color3.new(1, 1, 1)
			textLabel.TextSize = 9
			textLabel.ZIndex = 5
			textLabel.Parent = imageLabel
			local uiCorner2 = Instance.new("UICorner")
			uiCorner2.CornerRadius = UDim.new(0, 4)
			uiCorner2.Parent = textLabel
		end
	end

	local fn8 = nil

	fn8 = function(child)
		task.wait(0.3)
		if not v12.Enabled or not child.Parent then
			return
		end
		local playerName = child:FindFirstChild("PlayerName", true)
		if not playerName then
			return
		end
		local v14 = nil

		for _, v15 in playersService:GetPlayers() do
			local streamerModeController = bedwars.StreamerModeController and bedwars.StreamerModeController:getDisplayName(v15)
			local flag = v15.Name == playerName.Text or v15.DisplayName == playerName.Text
			local flag2

			if flag then
				flag2 = flag
			else
				local text = playerName.Text
				flag2 = v15:GetAttribute("DisguiseDisplayName") == text
			end

			flag2 = flag2 or streamerModeController == playerName.Text
			if flag2 then
				v14 = v15
				break
			end
		end

		if not v14 then
			return
		end
		local n1 = child:FindFirstChild("1")
		n1 = n1 and n1:FindFirstChild("MatchDraftPlayerCard")
		if not n1 then
			return
		end
		local kitImage = n1:FindFirstChild("KitImage")
		local none = bedwars.BedwarsKitMeta[v14:GetAttribute("PlayingAsKits")] or bedwars.BedwarsKitMeta.none

		if not kitImage then
			kitImage = Instance.new("ImageLabel")
			kitImage.BackgroundTransparency = 1
			kitImage.AnchorPoint = Vector2.new(1, 0.5)
			kitImage.Position = UDim2.fromScale(1.05, 0)
			kitImage.Name = "KitImage"
			kitImage.Size = UDim2.fromScale(1.5, 1.5)
			kitImage.ZIndex = 1
			kitImage.ImageTransparency = 0.4
			kitImage.SliceCenter = Rect.new(0, 0, 0, 0)
			kitImage.SliceScale = 1
			kitImage.ScaleType = Enum.ScaleType.Crop
			kitImage.Parent = n1
			v12:Clean(kitImage)
			local uiAspectRatioConstraint = Instance.new("UIAspectRatioConstraint")
			uiAspectRatioConstraint.Name = "1"
			uiAspectRatioConstraint.AspectRatio = 1
			uiAspectRatioConstraint.AspectType = Enum.AspectType.FitWithinMaxSize
			uiAspectRatioConstraint.DominantAxis = Enum.DominantAxis.Width
			uiAspectRatioConstraint.Parent = kitImage
		end

		kitImage.Image = none.renderImage
		kitImage.Position = UDim2.fromScale(1.05, 0)
		tweenService:Create(kitImage, TweenInfo.new(0.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), { Position = UDim2.fromScale(1.05, 0.5) }):Play()
		task.spawn(fn7, n1, v14)

		local connection = v14:GetAttributeChangedSignal("PlayingAsKits"):Connect(function()
			if not v12.Enabled or not kitImage.Parent then
				return
			end
			none = bedwars.BedwarsKitMeta[v14:GetAttribute("PlayingAsKits")] or bedwars.BedwarsKitMeta.none
			kitImage.Image = none.renderImage
			kitImage.Position = UDim2.fromScale(1.05, 0)
			tweenService:Create(kitImage, TweenInfo.new(0.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), { Position = UDim2.fromScale(1.05, 0.5) }):Play()
		end)

		v12:Clean(playerName:GetPropertyChangedSignal("Text"):Once(function()
			if connection then
				connection:Disconnect()
				connection = nil
			end

			fn8(child)
		end))

		v12:Clean(connection)
	end

	v12 = kits:CreateModule({
		Name = "KitDisplay",
		Category = "Visual",
		Function = function(arg)
			if arg then
				local matchDraftApp

				while true do
					matchDraftApp = lplr.PlayerGui:FindFirstChild("MatchDraftApp")
					matchDraftApp = matchDraftApp and matchDraftApp:FindFirstChild("DraftAppBackground")
					matchDraftApp = matchDraftApp and matchDraftApp:FindFirstChild("1")
					matchDraftApp = matchDraftApp and matchDraftApp:FindFirstChild("BodyContainer")

					if not matchDraftApp then
						task.wait(0.1)
					end

					if not (matchDraftApp or not v12.Enabled) then
						continue
					end
					break
				end

				local v14

				for i = 1, 2 do
					if v12.Enabled then
						local n = tick() + 10

						while true do
							local findFirstChild = matchDraftApp.FindFirstChild
							local str = ("Team%*Column"):format(i)
							v14 = findFirstChild(matchDraftApp, str)

							if not v14 then
								task.wait(0.1)
							end

							if not (v14 or not v12.Enabled or tick() >= n) then
								continue
							end
							break
						end

						if v14 then
							v12:Clean(v14.ChildAdded:Connect(fn8))

							for _, v15 in v14:GetChildren() do
								task.spawn(fn8, v15)
							end
						end

						continue
					end

					break
				end
			end
		end,
		Tooltip = 'Shows enemy kits in the match draft',
	})

	v13 = v12:CreateToggle({
		Name = "Show previous kits",
		Function = function()
			if v12.Enabled then
				v12:Toggle()
				v12:Toggle()
			end
		end,
		Default = true,
		Tooltip = 'Shows the kits each player recently used',
	})
end)
