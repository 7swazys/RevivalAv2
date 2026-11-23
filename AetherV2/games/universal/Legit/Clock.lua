run(function()
	local GetFontBounds = getfontsize
	local GetVapeAsset = getcustomasset
	local UIPallet = vape.Libraries.uipallet
	local Clock
	local ClockType
	local ShowDate
	local TwentyFourHour
	local Background
	local BackgroundColor
	local Shadows: {[TextLabel]: TextLabel} = {}
	local SkippedTicks: {[number]: boolean} = {[8] = true, [9] = true, [10] = true, [14] = true, [15] = true, [16] = true, [20] = true, [21] = true, [22] = true}
	local LocalTime, UtcTime = os.date("*t"), os.date("!*t")
	local TimeZone: number = ((LocalTime.yday - UtcTime.yday) * 24) + LocalTime.hour - UtcTime.hour
	TimeZone = TimeZone > 12 and TimeZone - 24 or (TimeZone < -12 and TimeZone + 24 or TimeZone)
	local AmericanDate: boolean = TimeZone <= -2 and TimeZone >= -11
	local Holder, Analog, Digital, Hand
	local AnalogHour, AnalogMinute, AnalogWeekday, AnalogDate, AnalogMeridiem
	local DigitalHour, DigitalMinute, DigitalMeridiem, DigitalDate, DigitalWeekday

	local function AddLabel(Parent: Instance, TextSize: number, Alignment: Enum.TextXAlignment): TextLabel
		local Label: TextLabel = Instance.new("TextLabel")
		Label.BackgroundTransparency = 1
		Label.FontFace = UIPallet.FontDisplay
		Label.Size = UDim2.fromOffset(200, TextSize + 6)
		Label.Text = ""
		Label.TextColor3 = Color3.new(1, 1, 1)
		Label.TextSize = TextSize
		Label.TextXAlignment = Alignment
		Label.Parent = Parent
		local Shadow: TextLabel = Label:Clone()
		Shadow.Name = "Shadow"
		Shadow.TextColor3 = Color3.new()
		Shadow.TextTransparency = 0.498
		Shadow.Visible = false
		Shadow.ZIndex = 0
		Shadow.Parent = Parent
		Shadows[Label] = Shadow

		return Label
	end

	local function PlaceLabel(Label: TextLabel, X: number, CenterY: number)
		Label.Position = UDim2.fromOffset(Label.TextXAlignment == Enum.TextXAlignment.Right and X - 200 or X, CenterY - (Label.Size.Y.Offset / 2))
		Shadows[Label].Position = Label.Position + UDim2.fromOffset(1, 1)
	end

	local function RefreshSize()
		if ClockType.Value == "Digital" then
			Holder.Size = UDim2.fromOffset(140 + (ShowDate.Enabled and 48 or 0) + (TwentyFourHour.Enabled and 0 or 24), 64)
			return
		end

		Holder.Size = UDim2.fromOffset(140, 130)
	end

	local function Update()
		if vape.ThreadFix then
			setthreadidentity(8)
		end

		local Now = os.date("*t")
		local Hour: number = TwentyFourHour.Enabled and Now.hour or (Now.hour > 12 and Now.hour - 12 or (Now.hour == 0 and 12 or Now.hour))
		local HourText: string = string.format("%02d", Hour)
		local MinuteText: string = string.format("%02d", Now.min)
		local Meridiem: string = Now.hour >= 12 and "pm" or "am"
		local Weekday: string = os.date("%a"):lower()
		local DateText: string = string.format(ClockType.Value == "Digital" and "%02d / %02d" or "%02d/%02d", AmericanDate and Now.month or Now.day, AmericanDate and Now.day or Now.month)

		if ClockType.Value == "Digital" then
			DigitalHour.Text = HourText
			DigitalMinute.Text = MinuteText
			DigitalMeridiem.Text = Meridiem
			DigitalDate.Text = DateText
			DigitalWeekday.Text = Weekday
			Shadows[DigitalHour].Text = HourText
			Shadows[DigitalMinute].Text = MinuteText
			Shadows[DigitalMeridiem].Text = Meridiem
			Shadows[DigitalDate].Text = DateText
			Shadows[DigitalWeekday].Text = Weekday
			PlaceLabel(DigitalMeridiem, 78 + GetFontBounds(MinuteText, 48 * UIPallet.DisplayScale, UIPallet.FontDisplay).X, 46)
			PlaceLabel(DigitalDate, Holder.Size.X.Offset - 12, 24)
			PlaceLabel(DigitalWeekday, Holder.Size.X.Offset - 12, 40)

			return
		end

		AnalogHour.Text = HourText
		AnalogMinute.Text = MinuteText
		AnalogWeekday.Text = Weekday
		AnalogDate.Text = DateText
		AnalogMeridiem.Text = Meridiem
		Shadows[AnalogHour].Text = HourText
		Shadows[AnalogMinute].Text = MinuteText
		Shadows[AnalogWeekday].Text = Weekday
		Shadows[AnalogDate].Text = DateText
		Shadows[AnalogMeridiem].Text = Meridiem
		Hand.Rotation = (Hour * 30) + (Now.min / 2)
	end

	Clock = vape.Categories.Legit:CreateModule({
		Name = "Clock",
		Category = "HUD",
		Function = function(Callback: boolean)
			if Callback then
				repeat
					Update()
					task.wait(1)
				until not Clock.Enabled
			end
		end,
		Size = UDim2.fromOffset(140, 130),
		Tooltip = "Draws a clock with the current real-world time"
	})

	ClockType = Clock:CreateDropdown({
		Name = "Clock Type",
		List = {"Analog", "Digital"},
		Function = function(Value: string)
			if Holder then
				Analog.Visible = Value == "Analog"
				Digital.Visible = Value == "Digital"
				ShowDate.Object.Visible = Value == "Digital"
				RefreshSize()
				Update()
			end
		end
	})
	ShowDate = Clock:CreateToggle({
		Name = "Show date",
		Function = function(Callback: boolean)
			if Holder then
				DigitalDate.Visible = Callback
				DigitalWeekday.Visible = Callback
				Shadows[DigitalDate].Visible = Callback and not Background.Enabled
				Shadows[DigitalWeekday].Visible = Callback and not Background.Enabled
				RefreshSize()
			end
		end,
		Default = true
	})
	TwentyFourHour = Clock:CreateToggle({
		Name = "24 Hour Time",
		Function = function(Callback: boolean)
			if Holder then
				AnalogMeridiem.Visible = not Callback
				DigitalMeridiem.Visible = not Callback
				Shadows[AnalogMeridiem].Visible = not Callback and not Background.Enabled
				Shadows[DigitalMeridiem].Visible = not Callback and not Background.Enabled
				RefreshSize()
				Update()
			end
		end
	})
	Background = Clock:CreateToggle({
		Name = "Render background",
		Function = function(Callback: boolean)
			if BackgroundColor then
				Holder.BackgroundTransparency = Callback and 1 - BackgroundColor.Opacity or 1
				BackgroundColor.Object.Visible = Callback

				for Label: TextLabel, v: TextLabel in Shadows do
					v.Visible = not Callback and Label.Visible
				end
			end
		end,
		Default = true
	})
	BackgroundColor = Clock:CreateColorSlider({
		Name = "Background Color",
		DefaultHue = 0.8333,
		DefaultSat = 0.0385,
		DefaultValue = 0.102,
		DefaultOpacity = 0.4,
		Function = function(Hue: number, Sat: number, Val: number, Opacity: number)
			if Holder then
				Holder.BackgroundColor3 = Color3.fromHSV(Hue, Sat, Val)
				Holder.BackgroundTransparency = Background.Enabled and 1 - Opacity or 1
			end
		end,
		Darker = true
	})
	Holder = Clock.Children
	Holder.BackgroundColor3 = Color3.fromRGB(26, 25, 26)
	Holder.BackgroundTransparency = 0.6
	local HolderCorner: UICorner = Instance.new("UICorner")
	HolderCorner.CornerRadius = UDim.new(0, 4)
	HolderCorner.Parent = Holder
	Analog = Instance.new("Frame")
	Analog.BackgroundTransparency = 1
	Analog.Name = "Analog"
	Analog.Size = UDim2.fromScale(1, 1)
	Analog.Parent = Holder
	Digital = Instance.new("Frame")
	Digital.BackgroundTransparency = 1
	Digital.Name = "Digital"
	Digital.Size = UDim2.fromScale(1, 1)
	Digital.Visible = false
	Digital.Parent = Holder
	for i: number = 0, 23 do
		if not SkippedTicks[i] then
			local Angle: number = math.rad(i * 15) - (math.pi / 2)
			local X: number = math.cos(Angle) * 50 + 68.5
			local Y: number = math.sin(Angle) * 50 + 65.5
			local Tick: Frame = Instance.new("Frame")
			Tick.AnchorPoint = Vector2.new(0.5, 0.5)
			Tick.BackgroundColor3 = Color3.new(1, 1, 1)
			Tick.BorderSizePixel = 0
			Tick.Position = UDim2.fromOffset(X, Y)
			Tick.Size = UDim2.fromOffset(3, 3)
			Tick.Parent = Analog
			local Corner: UICorner = Instance.new("UICorner")
			Corner.CornerRadius = UDim.new(1, 0)
			Corner.Parent = Tick
		end
	end
	Hand = Instance.new("Frame")
	Hand.AnchorPoint = Vector2.new(0.5, 1)
	Hand.BackgroundColor3 = Color3.fromRGB(6, 161, 126)
	Hand.BorderSizePixel = 0
	Hand.Name = "Hand"
	Hand.Position = UDim2.fromOffset(70, 65)
	Hand.Size = UDim2.fromOffset(4, 52)
	Hand.Parent = Analog
	AnalogHour = AddLabel(Analog, 44 * UIPallet.DisplayScale, Enum.TextXAlignment.Right)
	AnalogMinute = AddLabel(Analog, 44 * UIPallet.DisplayScale, Enum.TextXAlignment.Right)
	AnalogWeekday = AddLabel(Analog, 13 * UIPallet.DisplayScale, Enum.TextXAlignment.Left)
	AnalogDate = AddLabel(Analog, 13 * UIPallet.DisplayScale, Enum.TextXAlignment.Left)
	AnalogMeridiem = AddLabel(Analog, 13 * UIPallet.DisplayScale, Enum.TextXAlignment.Right)
	DigitalHour = AddLabel(Digital, 48 * UIPallet.DisplayScale, Enum.TextXAlignment.Right)
	DigitalMinute = AddLabel(Digital, 48 * UIPallet.DisplayScale, Enum.TextXAlignment.Left)
	DigitalMeridiem = AddLabel(Digital, 16 * UIPallet.DisplayScale, Enum.TextXAlignment.Left)
	DigitalDate = AddLabel(Digital, 16 * UIPallet.DisplayScale, Enum.TextXAlignment.Right)
	DigitalWeekday = AddLabel(Digital, 16 * UIPallet.DisplayScale, Enum.TextXAlignment.Right)
	local Colon: Frame = Instance.new("Frame")
	Colon.AnchorPoint = Vector2.new(0.5, 0.5)
	Colon.BackgroundColor3 = Color3.new(1, 1, 1)
	Colon.BorderSizePixel = 0
	Colon.Name = "Colon"
	Colon.Position = UDim2.fromOffset(70, 32)
	Colon.Size = UDim2.fromOffset(4, 4)
	Colon.Parent = Digital
	local ColonCorner: UICorner = Instance.new("UICorner")
	ColonCorner.CornerRadius = UDim.new(1, 0)
	ColonCorner.Parent = Colon
	PlaceLabel(AnalogHour, 56, 37.5)
	PlaceLabel(AnalogMinute, 130, 88.7)
	PlaceLabel(AnalogWeekday, 20, 90.5)
	PlaceLabel(AnalogDate, 20, 106.5)
	PlaceLabel(AnalogMeridiem, 130, 18.1)
	PlaceLabel(DigitalHour, 60, 34)
	PlaceLabel(DigitalMinute, 78, 34)
	ShowDate.Object.Visible = ClockType.Value == "Digital"
	Update()
end)
