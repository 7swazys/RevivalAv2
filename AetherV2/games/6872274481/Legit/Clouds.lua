run(function()
	local Clouds
	local Scale
	local CloudColor
	local Folder, FolderConnection
	local Reference = setmetatable({}, {__mode = "k"})

	local function ApplyAll()
		if not Clouds.Enabled or not Folder then return end
		for _, v: Instance in Folder:GetChildren() do
			if v:IsA("BasePart") then
				if not Reference[v] then
					Reference[v] = {v.Size, v.Color, v.Transparency}
				end
				v.Size = Reference[v][1] * (Scale.Value / 100)
				v.Color = Color3.fromHSV(CloudColor.Hue, CloudColor.Sat, CloudColor.Value)
				v.Transparency = 1 - CloudColor.Opacity
			end
		end
	end

	local function BindFolder(New: Instance?)
		if FolderConnection then
			FolderConnection:Disconnect()
			FolderConnection = nil
		end

		Folder = New
		if not Folder then return end

		FolderConnection = Folder.ChildAdded:Connect(function(Part: Instance)
			task.defer(function()
				if not Clouds.Enabled or not Part:IsA("BasePart") then return end
				if not Reference[Part] then
					Reference[Part] = {Part.Size, Part.Color, Part.Transparency}
				end
				Part.Size = Reference[Part][1] * (Scale.Value / 100)
				Part.Color = Color3.fromHSV(CloudColor.Hue, CloudColor.Sat, CloudColor.Value)
				Part.Transparency = 1 - CloudColor.Opacity
			end)
		end)
		ApplyAll()
	end

	Clouds = vape.Categories.Legit:CreateModule({
		Name = "Clouds",
		Function = function(Callback: boolean)
			if Callback then
				Clouds:Clean(workspace.ChildAdded:Connect(function(Child: Instance)
					if Child.Name == "Clouds" then
						BindFolder(Child)
					end
				end))
				BindFolder(workspace:FindFirstChild("Clouds"))
			else
				BindFolder(nil)
				for Part: BasePart, v: {any} in Reference do
					if Part.Parent then
						Part.Size = v[1]
						Part.Color = v[2]
						Part.Transparency = v[3]
					end
				end
				table.clear(Reference)
			end
		end,
		Tooltip = "Restyles the clouds around the map"
	})

	Scale = Clouds:CreateSlider({
		Name = "Size",
		Min = 5,
		Max = 300,
		Function = ApplyAll,
		Default = 100,
		Suffix = function()
			return "%"
		end
	})
	CloudColor = Clouds:CreateColorSlider({
		Name = "Color",
		DefaultSat = 0,
		Darker = true,
		Function = ApplyAll
	})
end)
