run(function()
	local Camera = gameCamera
	local Lighting = lightingService
	local RunService = runService
	local MotionBlur
	local Turning
	local Movement
	local Maximum
	local Smoothing
	local BedFight: boolean = game.GameId == 7534782259

	local function BlurAllowed(): boolean
		local Bypass = vape.Modules.AntiBanwave
		return not BedFight or (Bypass ~= nil and Bypass.Enabled)
	end

	MotionBlur = vape.Categories.Legit:CreateModule({
		Name = "MotionBlur",
		Function = function(Callback: boolean)
			if Callback then
				local Blur: BlurEffect?
				local function DropBlur()
					if Blur then
						local Index: number? = vape.BlurEffects and table.find(vape.BlurEffects, Blur)
						if Index then
							table.remove(vape.BlurEffects, Index)
						end
						Blur:Destroy()
						Blur = nil
					end
				end
				MotionBlur:Clean(DropBlur)

				local LastLook, LastPosition, Size = Camera.CFrame.LookVector, Camera.CFrame.Position, 0
				MotionBlur:Clean(RunService.RenderStepped:Connect(function(Delta: number)
					local CameraCFrame: CFrame = Camera.CFrame
					local Step: number = math.max(Delta, 1 / 240)
					local Turn: number = math.deg(math.acos(math.clamp(CameraCFrame.LookVector:Dot(LastLook), -1, 1))) / Step
					local Travel: number = (CameraCFrame.Position - LastPosition).Magnitude / Step
					LastLook, LastPosition = CameraCFrame.LookVector, CameraCFrame.Position

					local Target: number = math.min((Turn * Turning.Value * 0.002) + (Travel * Movement.Value * 0.002), Maximum.Value)
					Size += (Target - Size) * math.clamp(Step * Smoothing.Value, 0, 1)
					if not BlurAllowed() then
						DropBlur()
						return
					end
					if not Blur then
						Blur = Instance.new("BlurEffect")
						Blur.Size = 0
						Blur.Parent = Lighting
						vape.BlurEffects = vape.BlurEffects or {}
						table.insert(vape.BlurEffects, Blur)
					end
					if Blur.Size ~= Size then
						Blur.Size = Size
					end
				end))
			end
		end,
		Tooltip = "Blurs the screen when you turn and move fast"
	})

	Turning = MotionBlur:CreateSlider({
		Name = "Turn amount",
		Min = 0,
		Max = 10,
		Default = 4,
		Decimal = 10,
		Tooltip = "How much your camera turning adds to the blur"
	})
	Movement = MotionBlur:CreateSlider({
		Name = "Movement amount",
		Min = 0,
		Max = 10,
		Default = 2,
		Decimal = 10,
		Tooltip = "How much your own speed adds to the blur"
	})
	Maximum = MotionBlur:CreateSlider({
		Name = "Max blur",
		Min = 1,
		Max = 56,
		Default = 14
	})
	Smoothing = MotionBlur:CreateSlider({
		Name = "Smoothing",
		Min = 1,
		Max = 30,
		Default = 12,
		Tooltip = "How fast the blur catches up, lower trails behind for longer"
	})
end)
