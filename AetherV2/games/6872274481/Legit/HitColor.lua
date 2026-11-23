run(function()
	local Main = vape.Libraries.mergedModule(vape.Categories.Legit, {
		Name = 'HitColour',
		Tooltip = 'Changes or removes the flash when players are hit'
	})

run(function()
    local HitColor
    local Color
    local done = setmetatable({}, {__mode = 'k'})

    HitColor = Main:Part({
		Label = 'Custom colour',
        Name = 'HitColour',
        Function = function(callback)
            if callback then
                repeat
                    local fill = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
                    for _, v in entitylib.List do
                        local highlight = v.Character and v.Character:FindFirstChild('_DamageHighlight_')
                        if highlight then
                            done[highlight] = true
                            highlight.FillColor = fill
                            highlight.FillTransparency = Color.Opacity
                        end
                    end
                    task.wait(0.1)
                until not HitColor.Enabled
            else
                for highlight in done do
                    pcall(function()
                        highlight.FillColor = Color3.new(1, 0, 0)
                        highlight.FillTransparency = 0.4
                    end)
                end
                table.clear(done)
            end
        end,
        Tooltip = 'Customize the hit highlight options'
    })
    Color = HitColor:CreateColorSlider({
        Name = 'Colour',
        DefaultOpacity = 0.4
    })
end)

run(function()
	local WhiteHits
	WhiteHits = Main:Part({
		Label = 'No red flash',
		Default = false,
		Name = "WhiteHits",
		Function = function(callback)
			if callback then
				repeat
					for i, v in entitylib.List do
						local highlight = v.Character and v.Character:FindFirstChild('_DamageHighlight_')
						if highlight then
							highlight:Destroy()
						end
					end
					task.wait(0.1)
				until not WhiteHits.Enabled
			end
		end,
		Tooltip = 'Removes the red flash players get when they are hit'
	})
end)

end)
