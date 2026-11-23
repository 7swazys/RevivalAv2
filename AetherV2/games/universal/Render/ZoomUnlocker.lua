run(function()
	local LocalPlayer = lplr
	local ZoomUnlocker
	local Distance
	local FirstPerson

	local OldMax, OldMin

	ZoomUnlocker = vape.Categories.Render:CreateModule({
		Name = "ZoomUnlocker",
		Function = function(Callback: boolean)
			if Callback then
				OldMax, OldMin = LocalPlayer.CameraMaxZoomDistance, LocalPlayer.CameraMinZoomDistance

				repeat
					local MinZoom: number = FirstPerson.Enabled and 0.5 or math.min(OldMin, Distance.Value)

					if LocalPlayer.CameraMinZoomDistance ~= MinZoom or LocalPlayer.CameraMaxZoomDistance ~= Distance.Value then
						LocalPlayer.CameraMinZoomDistance = MinZoom
						LocalPlayer.CameraMaxZoomDistance = Distance.Value
					end
					task.wait()
				until not ZoomUnlocker.Enabled
			else
				LocalPlayer.CameraMinZoomDistance = OldMin
				LocalPlayer.CameraMaxZoomDistance = OldMax
			end
		end,
		Tooltip = "Removes the zoom limit the game puts on your camera"
	})

	Distance = ZoomUnlocker:CreateSlider({
		Name = "Distance",
		Min = 1,
		Max = 500,
		Default = 128,
		Suffix = function(Val: number)
			return Val > 1 and "studs" or "stud"
		end
	})
	FirstPerson = ZoomUnlocker:CreateToggle({
		Name = "Allow first person",
		Default = true,
		Tooltip = "Also unlocks zooming all the way in"
	})
end)
