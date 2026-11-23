run(function()
	local Lighting = lightingService
	local RunService = runService
	local BetterLighting
	local DayAmount
	local NightAmount
	local Balance
	local Grading
	local Haze
	local Bloom
	local SunRays
	local Cycle
	local CycleLength
	local NightSpeed
	local Created: {Instance} = {}
	local Drives: {any} = {}
	local Weights: {number} = {0, 0, 0, 0}
	local Targets: {number} = {0, 0, 0, 0}
	local Names: {string} = {"Day", "Dawn", "Dusk", "Night"}
	local Amount: number = 0
	local Fade: number = 0
	local Stamp: number = 0
	local Dirty: boolean = false
	local Clock: number?
	local OldClock: number?
	local Written: number?
	local Watched: {[string]: boolean} = {Atmosphere = true, BloomEffect = true, SunRaysEffect = true}
	local FullbrightOwned: {[string]: boolean} = {Brightness = true, Ambient = true, OutdoorAmbient = true}
	local Properties: {[string]: {string}} = {
		Lighting = {"Brightness", "ExposureCompensation", "Ambient", "OutdoorAmbient", "ShadowSoftness"},
		Atmosphere = {"Color", "Decay", "Glare", "Haze"},
		Grade = {"Brightness", "Contrast", "Saturation", "TintColor"},
		Bloom = {"Intensity", "Size", "Threshold"},
		Rays = {"Intensity", "Spread"}
	}
	local Neutral = {
		Grade = {Brightness = 0, Contrast = 0, Saturation = 0, TintColor = Color3.new(1, 1, 1)},
		Bloom = {Intensity = 0, Size = 24, Threshold = 2},
		Rays = {Intensity = 0, Spread = 0.8}
	}
	local Presets = {
		Day = {
			Lighting = {
				Brightness = {Scale = 1.05},
				ExposureCompensation = {Add = 0.05},
				Ambient = {Tone = Color3.fromRGB(150, 165, 195), Amount = 0.3, Scale = 0.92, Max = 0.6},
				OutdoorAmbient = {Tone = Color3.fromRGB(155, 175, 210), Amount = 0.3, Scale = 0.92, Max = 0.7}
			},
			Atmosphere = {
				Color = {Tone = Color3.fromRGB(178, 198, 226), Amount = 0.3, Scale = 1, Max = 1},
				Decay = {Tone = Color3.fromRGB(150, 135, 130), Amount = 0.3, Scale = 1, Max = 1},
				Glare = {Min = 0.2}
			},
			Grade = {Brightness = 0, Contrast = 0.07, Saturation = 0.08, TintColor = Color3.fromRGB(255, 249, 240)},
			Bloom = {Intensity = 0.25, Size = 24, Threshold = 1.6},
			Rays = {Intensity = 0.06, Spread = 0.8}
		},
		Dawn = {
			Lighting = {
				Brightness = {Scale = 0.98, Max = 3.5},
				ExposureCompensation = {Add = 0.06},
				Ambient = {Tone = Color3.fromRGB(170, 160, 205), Amount = 0.2, Scale = 0.95, Max = 0.52},
				OutdoorAmbient = {Tone = Color3.fromRGB(195, 175, 210), Amount = 0.2, Scale = 0.95, Max = 0.64},
				ShadowSoftness = {Add = 0.1, Max = 1}
			},
			Atmosphere = {
				Color = {Tone = Color3.fromRGB(218, 202, 228), Amount = 0.3, Scale = 1, Max = 1},
				Decay = {Tone = Color3.fromRGB(228, 165, 150), Amount = 0.35, Scale = 1, Max = 1},
				Glare = {Min = 0.35}
			},
			Grade = {Brightness = 0, Contrast = 0.05, Saturation = -0.02, TintColor = Color3.fromRGB(251, 244, 247)},
			Bloom = {Intensity = 0.28, Size = 26, Threshold = 1.5},
			Rays = {Intensity = 0.08, Spread = 0.85}
		},
		Dusk = {
			Lighting = {
				Brightness = {Scale = 0.97, Max = 3.5},
				ExposureCompensation = {Add = 0.08},
				Ambient = {Tone = Color3.fromRGB(190, 150, 130), Amount = 0.15, Scale = 0.97, Max = 0.5},
				OutdoorAmbient = {Tone = Color3.fromRGB(205, 160, 130), Amount = 0.15, Scale = 0.97, Max = 0.62},
				ShadowSoftness = {Add = 0.1, Max = 1}
			},
			Atmosphere = {
				Color = {Tone = Color3.fromRGB(232, 196, 170), Amount = 0.3, Scale = 1, Max = 1},
				Decay = {Tone = Color3.fromRGB(235, 150, 90), Amount = 0.4, Scale = 1, Max = 1},
				Glare = {Min = 0.5}
			},
			Grade = {Brightness = 0, Contrast = 0.06, Saturation = 0, TintColor = Color3.fromRGB(255, 243, 232)},
			Bloom = {Intensity = 0.3, Size = 28, Threshold = 1.4},
			Rays = {Intensity = 0.1, Spread = 0.9}
		},
		Night = {
			Lighting = {
				Brightness = {Scale = 0.85, Max = 1.7},
				ExposureCompensation = {Add = 0.3},
				Ambient = {Tone = Color3.fromRGB(45, 60, 110), Amount = 0.8, Scale = 0.9, Max = 0.33},
				OutdoorAmbient = {Tone = Color3.fromRGB(70, 90, 150), Amount = 0.8, Scale = 0.85, Max = 0.47},
				ShadowSoftness = {Add = 0.15, Max = 1}
			},
			Atmosphere = {
				Color = {Tone = Color3.fromRGB(50, 62, 100), Amount = 0.8, Scale = 0.3, Max = 0.2},
				Decay = {Tone = Color3.fromRGB(25, 32, 56), Amount = 0.6, Scale = 0.3, Max = 0.15},
				Glare = {Min = 0.1},
				Haze = {Min = 0.35}
			},
			Grade = {Brightness = 0, Contrast = 0.1, Saturation = -0.12, TintColor = Color3.fromRGB(205, 220, 255)},
			Bloom = {Intensity = 1.2, Size = 36, Threshold = 0.8},
			Rays = {Intensity = 0, Spread = 0.8}
		}
	}

	local function Luma(Color: Color3): number
		return Color.R * 0.2126 + Color.G * 0.7152 + Color.B * 0.0722
	end

	local function Smooth(Low: number, High: number, Value: number): number
		local Alpha: number = math.clamp((Value - Low) / (High - Low), 0, 1)
		return Alpha * Alpha * (3 - 2 * Alpha)
	end

	local function Lerp(From: any, To: any, Alpha: number): any
		if typeof(From) == "Color3" then
			return From:Lerp(To, Alpha)
		end

		return From + (To - From) * Alpha
	end

	local function Same(A: any, B: any): boolean
		if typeof(A) == "Color3" then
			return math.abs(A.R - B.R) < 0.008 and math.abs(A.G - B.G) < 0.008 and math.abs(A.B - B.B) < 0.008
		end

		return math.abs(A - B) < 0.002
	end

	local function Grade(Base: any, Spec: any): any
		if Spec == nil then
			return Base
		end

		if typeof(Spec) ~= "table" then
			return Spec
		end

		if typeof(Base) == "Color3" then
			local Toned: Color3 = Base:Lerp(Spec.Tone, Spec.Amount)
			local Current: number = Luma(Toned)
			if Current < 0.0001 then
				return Toned
			end

			local Factor: number = math.min(Luma(Base) * Spec.Scale, Spec.Max) / Current
			return Color3.new(math.min(Toned.R * Factor, 1), math.min(Toned.G * Factor, 1), math.min(Toned.B * Factor, 1))
		end

		return math.clamp(Base * (Spec.Scale or 1) + (Spec.Add or 0), Spec.Min or -math.huge, Spec.Max or math.huge)
	end

	local function SetWeights(Elevation: number, Morning: boolean, Blend: number): boolean
		local Light: number = Smooth(-0.1, 0.2, Elevation)
		local Warm: number = math.exp(-(((Elevation - 0.02) / 0.15) ^ 2))
		Targets[1] = (1 - Warm) * Light
		Targets[2] = Morning and Warm or 0
		Targets[3] = Morning and 0 or Warm
		Targets[4] = (1 - Warm) * (1 - Light)

		local Moved: boolean = false
		for i: number = 1, 4 do
			local Weight: number = Weights[i] + (Targets[i] - Weights[i]) * Blend
			if math.abs(Targets[i] - Weight) < 0.0005 then
				Weight = Targets[i]
			end

			if Weight ~= Weights[i] then
				Weights[i] = Weight
				Moved = true
			end
		end

		return Moved
	end

	local function GetAmount(): number
		local Day: number = DayAmount.Value / 100
		local Night: number = NightAmount.Value / 100
		local Twilight: number = Weights[2] + Weights[3]
		return (Weights[1] * Day + Twilight * (Day + Night) / 2 + Weights[4] * Night) * Smooth(0, 1, Fade)
	end

	local function Mix(Drive: any): any
		local Mixed: any
		local Total: number = 0
		for i: number, Name: string in Names do
			local Weight: number = Weights[i]
			if Weight > 0 then
				local Value: any = Grade(Drive.Base, Presets[Name][Drive.Group][Drive.Property])
				Total += Weight
				if Mixed == nil then
					Mixed = Value
				else
					Mixed = Lerp(Mixed, Value, Weight / Total)
				end
			end
		end

		if Mixed == nil then
			return Drive.Base
		end

		return Lerp(Drive.Base, Mixed, Amount)
	end

	local function Step(Drive: any)
		local Object: Instance = Drive.Object
		local Property: string = Drive.Property
		local Current: any = Object[Property]
		local Rebased: boolean = Drive.Neutral == nil and (Drive.Written == nil or not Same(Current, Drive.Written))
		if Rebased then
			Drive.Base = Current
		end

		if Rebased or Drive.Stamp ~= Stamp then
			Drive.Stamp = Stamp
			Drive.Goal = Mix(Drive)
			Drive.Written = Drive.Goal
		end

		if not Same(Current, Drive.Goal) then
			Object[Property] = Drive.Goal
		end
	end

	local function StopClock()
		if Written ~= nil and OldClock ~= nil and math.abs(Lighting.ClockTime - Written) < 0.05 then
			Lighting.ClockTime = OldClock
		end

		Clock, OldClock, Written = nil, nil, nil
	end

	local function StepClock(Delta: number, Elevation: number)
		local Timer: any = vape.Legit.Modules.TimeChanger
		if Timer and Timer.Enabled then
			Clock = nil
			return
		end

		local Current: number = Clock or Lighting.ClockTime
		OldClock = OldClock or Current

		local Speed: number = Lerp(NightSpeed.Value, 1, Smooth(-0.15, 0.05, Elevation))
		local Next: number = (Current + Delta * 24 / (CycleLength.Value * 60) * Speed) % 24
		Clock = Next
		if not Written or math.abs(Next - Written) > 0.003 then
			Written = Next
			Lighting.ClockTime = Next
		end
	end

	local function Restore()
		for _, Drive: any in Drives do
			if Drive.Neutral == nil and Drive.Written ~= nil and Drive.Object.Parent ~= nil and Same(Drive.Object[Drive.Property], Drive.Written) then
				Drive.Object[Drive.Property] = Drive.Base
			end
		end
		table.clear(Drives)

		for _, v: Instance in Created do
			v:Destroy()
		end
		table.clear(Created)
	end

	local function Make(Class: string, Values: {[string]: any}): Instance
		local Object: Instance = Instance.new(Class)
		for Property: string, Value: any in Values do
			Object[Property] = Value
		end
		table.insert(Created, Object)
		Object.Parent = Lighting
		return Object
	end

	local function Attach(Object: Instance, Group: string, Owned: boolean?)
		for _, Property: string in Properties[Group] do
			local Start: any = Owned and Neutral[Group][Property] or nil
			table.insert(Drives, {Object = Object, Group = Group, Property = Property, Neutral = Start, Base = Start})
		end
	end

	local function Foreign(Class: string): boolean
		for _, v: Instance in Lighting:GetChildren() do
			if v:IsA(Class) and not table.find(Created, v) then
				return true
			end
		end

		return false
	end

	local function Setup()
		Restore()

		if Balance.Enabled then
			Attach(Lighting, "Lighting")
		end

		if Haze.Enabled then
			local Fog: Instance? = Lighting:FindFirstChildOfClass("Atmosphere")
			if not Fog and Lighting.FogEnd > 50000 then
				Fog = Make("Atmosphere", {
					Density = 0.3,
					Offset = 0,
					Color = Color3.fromRGB(199, 199, 199),
					Decay = Color3.fromRGB(106, 112, 125),
					Glare = 0,
					Haze = 0
				})
			end

			if Fog then
				Attach(Fog, "Atmosphere")
			end
		end

		if Grading.Enabled then
			Attach(Make("ColorCorrectionEffect", Neutral.Grade), "Grade", true)
		end

		if Bloom.Enabled and not Foreign("BloomEffect") then
			Attach(Make("BloomEffect", Neutral.Bloom), "Bloom", true)
		end

		if SunRays.Enabled and not Foreign("SunRaysEffect") then
			Attach(Make("SunRaysEffect", Neutral.Rays), "Rays", true)
		end
	end

	local function Reload()
		if BetterLighting.Enabled then
			Setup()
		end
	end

	local function Changed(Child: Instance)
		if Watched[Child.ClassName] and not table.find(Created, Child) then
			Dirty = true
		end
	end

	local function Update(Delta: number)
		if Dirty then
			Dirty = false
			Setup()
		end

		local Blend: number = Fade == 0 and 1 or 1 - math.exp(-Delta * 4)
		Fade = math.min(Fade + Delta / 1.2, 1)

		local Elevation: number = Lighting:GetSunDirection().Y
		if Cycle.Enabled then
			StepClock(Delta, Elevation)
		end

		local Moved: boolean = SetWeights(Elevation, Lighting.ClockTime < 12, Blend)
		local Goal: number = GetAmount()
		if Moved or Goal ~= Amount then
			Amount = Goal
			Stamp += 1
		end

		local Bright: any = vape.Modules.Fullbright
		local Locked: boolean = Bright ~= nil and Bright.Enabled
		for _, Drive: any in Drives do
			if not (Locked and Drive.Object == Lighting and FullbrightOwned[Drive.Property]) then
				Step(Drive)
			end
		end
	end

	BetterLighting = vape.Categories.Render:CreateModule({
		Name = "BetterLighting",
		Function = function(Callback: boolean)
			if not Callback or not BetterLighting.Enabled then
				return
			end

			Fade = 0
			Dirty = false
			BetterLighting:Clean(Restore)
			BetterLighting:Clean(StopClock)
			Setup()
			BetterLighting:Clean(Lighting.ChildAdded:Connect(Changed))
			BetterLighting:Clean(Lighting.ChildRemoved:Connect(Changed))
			BetterLighting:Clean(RunService.RenderStepped:Connect(Update))
		end,
		Tooltip = "Cleaner, more realistic lighting that follows the time of day"
	})

	DayAmount = BetterLighting:CreateSlider({
		Name = "Day",
		Min = 0,
		Max = 100,
		Default = 100,
		Suffix = "%",
		Tooltip = "How strongly the daytime look is applied"
	})
	NightAmount = BetterLighting:CreateSlider({
		Name = "Night",
		Min = 0,
		Max = 100,
		Default = 100,
		Suffix = "%",
		Tooltip = "How strongly the nighttime look is applied"
	})
	local LightEffects
	LightEffects = BetterLighting:CreateMultiDropdown({
		Name = 'Effects',
		List = {'Light balance', 'Color grade', 'Haze', 'Bloom', 'Sun rays'},
		Default = {'Light balance', 'Color grade', 'Haze', 'Bloom', 'Sun rays'},
		Tooltip = 'Which lighting effects are added'
	})
	Balance = setmetatable({}, {__index = function(_, key) if key == 'Enabled' then return LightEffects:Has('Light balance') end end})
	Grading = setmetatable({}, {__index = function(_, key) if key == 'Enabled' then return LightEffects:Has('Color grade') end end})
	Haze = setmetatable({}, {__index = function(_, key) if key == 'Enabled' then return LightEffects:Has('Haze') end end})
	Bloom = setmetatable({}, {__index = function(_, key) if key == 'Enabled' then return LightEffects:Has('Bloom') end end})
	SunRays = setmetatable({}, {__index = function(_, key) if key == 'Enabled' then return LightEffects:Has('Sun rays') end end})
	Cycle = BetterLighting:CreateToggle({
		Name = "Day-night cycle",
		Function = function(Callback: boolean)
			CycleLength.Object.Visible = Callback
			NightSpeed.Object.Visible = Callback
			if not Callback then
				StopClock()
			end
		end,
		Tooltip = "Runs the day-night cycle. Takes over the game's clock, so it is off by default"
	})
	CycleLength = BetterLighting:CreateSlider({
		Name = "Day length",
		Min = 1,
		Max = 60,
		Default = 20,
		Visible = false,
		Darker = true,
		Suffix = function(Value: number)
			return Value > 1 and "minutes" or "minute"
		end,
		Tooltip = "Real minutes one full day takes"
	})
	NightSpeed = BetterLighting:CreateSlider({
		Name = "Night speed",
		Min = 1,
		Max = 4,
		Decimal = 10,
		Default = 1,
		Visible = false,
		Darker = true,
		Suffix = "x",
		Tooltip = "Makes the night pass faster than the day"
	})
end)
