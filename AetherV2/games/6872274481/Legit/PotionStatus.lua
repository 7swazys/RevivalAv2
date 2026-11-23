run(function()
	local GetFontBounds = getfontsize
	local Entity = entitylib
	local GetVapeAsset = getcustomasset
	local LocalPlayer = lplr
	local UIPallet = uipallet
	local PotionStatus
	local ShowPositive
	local ShowNegative
	local Background
	local BackgroundColor
	local Effects: {[string]: number} = {}
	local Seen: {[string]: boolean} = {}
	local Replacements: {[string]: string} = {
		speed = "rbxassetid://71873445837330"
	}
	local Negative: {[string]: boolean} = {
		bleed = true,
		burn = true,
		cold = true,
		curse_of_the_altar = true,
		decay = true,
		dizzy = true,
		feeble = true,
		frost_bite = true,
		frosted = true,
		frozen = true,
		grave_trap = true,
		greased = true,
		grounded = true,
		grounded_enchant = true,
		hungry = true,
		infected_poison = true,
		isabel_shield_broken = true,
		lunar_venom = true,
		mage_burn = true,
		oil_spilled = true,
		oiled = true,
		on_ice = true,
		owl_target = true,
		poison = true,
		powdered = true,
		shield_down = true,
		shrink = true,
		silas_halloween_hex = true,
		silence = true,
		skeleton_poison = true,
		snae_poison_arrow = true,
		snake_poison_sword = true,
		soaked = true,
		SPIDER_WEB_SLOW = true,
		stacking_decay = true,
		Vengeful_venom = true,
		void_hunter_marked = true,
		weak_armor = true,
		werewolf_fear = true,
		zapped_1 = true,
		zapped_2 = true,
		zapped_3 = true
	}
	local AccentColor: Color3 = Color3.fromRGB(5, 134, 105)
	local WarnColor: Color3 = Color3.fromRGB(236, 129, 44)
	local DangerColor: Color3 = Color3.fromRGB(250, 50, 56)
	local HalfCut: NumberSequence = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(0.501, 1),
		NumberSequenceKeypoint.new(1, 1)
	})
	local Holder: Frame

	local function Added(Active)
		if vape.ThreadFix then
			setthreadidentity(8)
		end

		Effects[Active.statusEffect] = Active.expireTime
		local Duration: number = Active.expireTime - workspace:GetServerTimeNow()
		if Duration <= 0 then
			Effects[Active.statusEffect] = nil
			return
		end

		local ItemMeta = bedwars.ItemMeta[Active.statusEffect] or bedwars.ItemMeta[`{Active.statusEffect}_potion`]
		local Effect: Frame = Instance.new("Frame")
		Effect.BackgroundTransparency = 1
		Effect.Parent = Holder
		local Ring: Frame = Instance.new("Frame")
		Ring.BackgroundTransparency = 1
		Ring.Position = UDim2.fromOffset(0, 4)
		Ring.Size = UDim2.fromOffset(50, 50)
		Ring.Parent = Effect
		local Backing: Frame = Instance.new("Frame")
		Backing.BackgroundTransparency = 1
		Backing.Position = UDim2.fromOffset(4.5, 4.5)
		Backing.Size = UDim2.fromOffset(41, 41)
		Backing.Parent = Ring
		local BackingCorner: UICorner = Instance.new("UICorner")
		BackingCorner.CornerRadius = UDim.new(1, 0)
		BackingCorner.Parent = Backing
		local BackingStroke: UIStroke = Instance.new("UIStroke")
		BackingStroke.Color = Color3.new()
		BackingStroke.Thickness = 3.6
		BackingStroke.Transparency = 0.216
		BackingStroke.Parent = Backing
		local Gradients, Strokes = {}, {}

		for _, Side: string in {"Left", "Right"} do
			local Clip: Frame = Instance.new("Frame")
			Clip.BackgroundTransparency = 1
			Clip.ClipsDescendants = true
			Clip.Position = UDim2.fromOffset(Side == "Right" and 25 or 0, 0)
			Clip.Size = UDim2.fromOffset(25, 50)
			Clip.Parent = Ring
			local Arc: Frame = Instance.new("Frame")
			Arc.BackgroundTransparency = 1
			Arc.Position = UDim2.fromOffset(Side == "Right" and -21 or 4, 4)
			Arc.Size = UDim2.fromOffset(42, 42)
			Arc.Parent = Clip
			local ArcCorner: UICorner = Instance.new("UICorner")
			ArcCorner.CornerRadius = UDim.new(1, 0)
			ArcCorner.Parent = Arc
			local ArcStroke: UIStroke = Instance.new("UIStroke")
			ArcStroke.Color = AccentColor
			ArcStroke.Thickness = 4
			ArcStroke.Parent = Arc
			local ArcGradient: UIGradient = Instance.new("UIGradient")
			ArcGradient.Transparency = HalfCut
			ArcGradient.Parent = ArcStroke
			Gradients[Side] = ArcGradient
			Strokes[Side] = ArcStroke
		end

		local Sidebar: Frame = Instance.new("Frame")
		Sidebar.AnchorPoint = Vector2.new(0, 0.5)
		Sidebar.BackgroundColor3 = Color3.fromRGB(170, 170, 170)
		Sidebar.BackgroundTransparency = 0.5
		Sidebar.BorderSizePixel = 0
		Sidebar.Position = UDim2.new(0, 53, 0.5, 1)
		Sidebar.Size = UDim2.fromOffset(2, 27)
		Sidebar.Parent = Effect
		local EffectImage: ImageLabel = Instance.new("ImageLabel")
		EffectImage.AnchorPoint = Vector2.new(0, 0.5)
		EffectImage.BackgroundTransparency = 1
		EffectImage.Image = Replacements[Active.statusEffect] or (ItemMeta and ItemMeta.image) or bedwars.ImageList.POTION_ART
		EffectImage.Position = UDim2.new(0, 10, 0.5, 0)
		EffectImage.Size = UDim2.fromOffset(30, 30)
		EffectImage.Parent = Effect
		local EffectName: TextLabel = Instance.new("TextLabel")
		EffectName.BackgroundTransparency = 1
		EffectName.FontFace = UIPallet.FontSemiBold
		EffectName.Position = UDim2.fromOffset(67, 10)
		EffectName.Size = UDim2.fromOffset(108, 20)
		EffectName.Text = (`{Active.statusEffect:sub(0, 1):upper()}{Active.statusEffect:sub(2, #Active.statusEffect)}`):gsub("_", " ")
		EffectName.TextColor3 = Color3.new(1, 1, 1)
		EffectName.TextSize = 15
		EffectName.TextXAlignment = Enum.TextXAlignment.Left
		EffectName.Parent = Effect
		local NameShadow: TextLabel = EffectName:Clone()
		NameShadow.Position += UDim2.fromOffset(1, 1)
		NameShadow.TextColor3 = Color3.new()
		NameShadow.TextTransparency = 0.5
		NameShadow.ZIndex = 0
		NameShadow.Parent = Effect
		Effect.Size = UDim2.fromOffset(GetFontBounds(EffectName.Text, 15, UIPallet.FontSemiBold).X + 80, 57)
		local EffectDuration: TextLabel = EffectName:Clone()
		EffectDuration.Position = UDim2.fromOffset(67, 29)
		EffectDuration.Text = "00:00"
		EffectDuration.TextSize = 14
		EffectDuration.Parent = Effect
		local DurationShadow: TextLabel = EffectDuration:Clone()
		DurationShadow.Position += UDim2.fromOffset(1, 1)
		DurationShadow.TextColor3 = Color3.new()
		DurationShadow.TextTransparency = 0.5
		DurationShadow.ZIndex = 0
		DurationShadow.Parent = Effect
		local Seconds: number = 0
		local ShownSeconds: number?
		local ShownColor: Color3?

		repeat
			local Remaining: number = math.max(Active.expireTime - workspace:GetServerTimeNow(), 0)
			local Percent: number = Remaining / Duration
			local RingColor: Color3 = Percent > 0.5 and AccentColor or (Percent > 0.25 and WarnColor or DangerColor)
			local Theta: number = math.min(Percent, 1) * 360
			Seconds = math.floor(Remaining)
			Gradients.Left.Rotation = math.clamp(Theta, 180, 360)
			Gradients.Right.Rotation = math.clamp(Theta, 0, 180)
			if RingColor ~= ShownColor then
				ShownColor = RingColor
				Strokes.Left.Color = RingColor
				Strokes.Right.Color = RingColor
				EffectDuration.TextColor3 = RingColor
			end
			if Seconds ~= ShownSeconds then
				ShownSeconds = Seconds
				local Text: string = ("%02d:%02d"):format(Seconds // 60, Seconds % 60)
				EffectDuration.Text = Text
				DurationShadow.Text = Text
			end
			task.wait(0.1)
		until Seconds <= 0 or Effects[Active.statusEffect] ~= Active.expireTime or not PotionStatus.Enabled

		Effect:Destroy()

		if Effects[Active.statusEffect] == Active.expireTime then
			Effects[Active.statusEffect] = nil
		end
	end

	PotionStatus = vape.Categories.Legit:CreateModule({
		Name = "PotionStatus",
		Category = "Hud",
		Function = function(Callback: boolean)
			if Callback then
				repeat
					table.clear(Seen)

					if Entity.isAlive then
						for _, v: any in bedwars.StatusEffectUtil:getAllActive(LocalPlayer.Character) do
							if (v.expireTime or 0) - workspace:GetServerTimeNow() > 0 and (Negative[v.statusEffect] and ShowNegative.Enabled or not Negative[v.statusEffect] and ShowPositive.Enabled) then
								Seen[v.statusEffect] = true

								if Effects[v.statusEffect] ~= v.expireTime then
									task.spawn(Added, v)
								end
							end
						end
					end

					for StatusEffect: string in Effects do
						if not Seen[StatusEffect] then
							Effects[StatusEffect] = nil
						end
					end

					task.wait(0.1)
				until not PotionStatus.Enabled

				table.clear(Effects)
			end
		end,
		Size = UDim2.fromOffset(240, 64),
		Tooltip = "Shows your currently active effects"
	})

	Holder = PotionStatus.Children
	Holder.BackgroundColor3 = Color3.new()
	Holder.BackgroundTransparency = 0.5
	local HolderCorner: UICorner = Instance.new("UICorner")
	HolderCorner.CornerRadius = UDim.new(0, 4)
	HolderCorner.Parent = Holder
	local Layout: UIListLayout = Instance.new("UIListLayout")
	Layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	Layout.SortOrder = Enum.SortOrder.LayoutOrder
	Layout.Parent = Holder
	vape:Clean(Layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		if vape.ThreadFix then
			setthreadidentity(8)
		end

		Holder.Size = UDim2.fromOffset(Layout.AbsoluteContentSize.X, Layout.AbsoluteContentSize.Y)
	end))
	local ShowKinds
	ShowKinds = PotionStatus:CreateMultiDropdown({
		Name = 'Show',
		List = {'Positive', 'Negative'},
		Default = {'Positive', 'Negative'},
		Tooltip = 'Which kinds of effects are listed'
	})
	ShowPositive = setmetatable({}, {__index = function(_, key) if key == 'Enabled' then return ShowKinds:Has('Positive') end end})
	ShowNegative = setmetatable({}, {__index = function(_, key) if key == 'Enabled' then return ShowKinds:Has('Negative') end end})
	Background = PotionStatus:CreateGroup({
		Name = "Render background",
		Function = function(Callback: boolean)
			if BackgroundColor then
				Holder.BackgroundTransparency = Callback and 1 - BackgroundColor.Opacity or 1
			end
		end,
		Default = true
	})
	BackgroundColor = Background:CreateColorSlider({
		Name = "Background Color",
		DefaultValue = 0,
		DefaultOpacity = 0.5,
		Function = function(Hue: number, Sat: number, Val: number, Opacity: number)
			Holder.BackgroundColor3 = Color3.fromHSV(Hue, Sat, Val)
			Holder.BackgroundTransparency = Background.Enabled and 1 - Opacity or 1
		end,
		Darker = true
	})
end)
