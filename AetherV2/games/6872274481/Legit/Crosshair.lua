run(function()
	local GetVapeAsset = getcustomasset
	local Old: {string}?
	local Preset
	local Image

	if not (bedwars.Images and bedwars.Images.ui) then
		return
	end

	local Presets: {[string]: string} = {
		PC = bedwars.Images.ui.hud.viewmodel_crosshair,
		Mobile = bedwars.Images.ui.mobile_controls.mobile_crosshairs,
		Turret = bedwars.Images.ui.common.turret_crosshair,
		["Mouse lock"] = "rbxasset://textures/MouseLockedCursor.png"
	}

	local Crosshair = vape.Categories.Legit:CreateModule({
		Name = "Crosshair",
		Category = "Game",
		Function = function(Callback: boolean)
			if Callback then
				Old = {bedwars.Images.ui.hud.viewmodel_crosshair, bedwars.Images.ui.mobile_controls.mobile_crosshairs}
				bedwars.Images.ui.hud.viewmodel_crosshair = Presets[Preset.Value] or tonumber(Image.Value) and `rbxassetid://{Image.Value}` or Image.Value
				bedwars.Images.ui.mobile_controls.mobile_crosshairs = Presets[Preset.Value] or tonumber(Image.Value) and `rbxassetid://{Image.Value}` or Image.Value
			elseif Old then
				bedwars.Images.ui.hud.viewmodel_crosshair = Old[1]
				bedwars.Images.ui.mobile_controls.mobile_crosshairs = Old[2]
			end

			if bedwars.ViewmodelController.crosshair then
				bedwars.ViewmodelController:hideCrosshair()
				bedwars.ViewmodelController:showCrosshair()
			end
		end,
		Tooltip = "First person crosshair that uses the image you pick"
	})

	Preset = Crosshair:CreateDropdown({
		Name = "Preset",
		List = {"Custom", "PC", "Mobile", "Turret", "Mouse lock"},
		Function = function(Val: string)
			if Image then
				Image.Object.Visible = Val == "Custom"
			end
			if Crosshair.Enabled then
				Crosshair:Toggle()
				Crosshair:Toggle()
			end
		end,
		Tooltip = "Pick one of the games own crosshairs, Custom uses the image id below"
	})
	Image = Crosshair:CreateTextBox({
		Name = "Image",
		Placeholder = "image id (roblox)",
		Function = function(Enter: boolean)
			if Enter and Crosshair.Enabled then
				Crosshair:Toggle()
				Crosshair:Toggle()
			end
		end
	})
end)
