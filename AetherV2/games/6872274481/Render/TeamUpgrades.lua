run(function()
	local GetFontBounds = getfontsize
	local Camera = gameCamera
	local CollectionService = collectionService
	local LocalPlayer = lplr
	local RunService = runService
	local TeamUpgrades
	local Session = nil
	local OwnTeam
	local BedUpgrades
	local Color
	local Transparency
	local Scale
	local Reference = {}
	local Folder: Folder = Instance.new("Folder")
	if vape.ThreadFix then
		setthreadidentity(8)
	end
	Folder.Parent = vape.gui

	local Numerals: {string} = {"I", "II", "III", "IV", "V"}

	local function GetAnchor(Object: Instance)
		return Object:IsA("Model") and (Object.PrimaryPart or Object:FindFirstChildWhichIsA("BasePart")) or Object
	end

	local function GetText(Team: string)
		local State = bedwars.Store:getState().Bedwars
		local Upgrades = State.teamUpgrades[Team] or {}
		local Bought: {string} = {}

		for UpgradeId: string, v: any in bedwars.TeamUpgradeMeta do
			local Tier: number? = Upgrades[UpgradeId]
			if Tier and Tier > 0 then
				table.insert(Bought, `{v.name} {Numerals[Tier] or Tier}`)
			end
		end

		table.sort(Bought)

		if BedUpgrades.Enabled then
			local Bed = State.bedTeamUpgrades[Team] or {}
			if Bed.bed_shield then
				table.insert(Bought, "Bed Shield")
			end
			if Bed.bed_alarm then
				table.insert(Bought, "Bed Alarm")
			end
		end

		return `Team {Team} | {#Bought > 0 and table.concat(Bought, ", ") or "No upgrades"}`
	end

	local function Added(Object: Instance, Tag: string)
		local Team: string? = Tag:match("^(%d+)_TeamOreGenerator")
		local Anchor: Instance? = Team and GetAnchor(Object)
		if not Anchor then return end
		if not OwnTeam.Enabled and Team == LocalPlayer:GetAttribute("Team") then return end

		local NameTag: TextLabel = Instance.new("TextLabel")
		NameTag.Name = `Team{Team}`
		NameTag.Text = GetText(Team)
		NameTag.TextSize = 14 * Scale.Value
		NameTag.Font = Enum.Font.Arial
		local Size: Vector2 = GetFontBounds(NameTag.Text, NameTag.TextSize, NameTag.FontFace)
		NameTag.Size = UDim2.fromOffset(Size.X + 8, Size.Y + 7)
		NameTag.AnchorPoint = Vector2.new(0.5, 1)
		NameTag.BackgroundColor3 = Color3.new()
		NameTag.BackgroundTransparency = Transparency.Value
		NameTag.BorderSizePixel = 0
		NameTag.Visible = false
		NameTag.TextColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
		NameTag.Parent = Folder
		Reference[Anchor] = {Label = NameTag, Team = Team}
	end

	local function Refresh()
		for _, v: {Label: TextLabel, Team: string} in Reference do
			v.Label.Text = GetText(v.Team)
			local Size: Vector2 = GetFontBounds(v.Label.Text, v.Label.TextSize, v.Label.FontFace)
			v.Label.Size = UDim2.fromOffset(Size.X + 8, Size.Y + 7)
		end
	end

	TeamUpgrades = vape.Categories.Render:CreateModule({
		Name = "TeamUpgrades",
		Function = function(Callback: boolean)
			if Callback then
				local Current = {}
				Session = Current
				for _, Tag: string in CollectionService:GetAllTags() do
					if Tag:match("^%d+_TeamOreGenerator$") then
						for _, v: Instance in CollectionService:GetTagged(Tag) do
							Added(v, Tag)
						end
						TeamUpgrades:Clean(CollectionService:GetInstanceAddedSignal(Tag):Connect(function(Object: Instance)
							Added(Object, Tag)
						end))
					end
				end

				TeamUpgrades:Clean(RunService.PreRender:Connect(function()
					for Anchor: BasePart, v: {Label: TextLabel, Team: string} in Reference do
						if not Anchor.Parent then
							v.Label:Destroy()
							Reference[Anchor] = nil
							continue
						end

						local ScreenPos, Visible = Camera:WorldToViewportPoint(Anchor.Position + Vector3.new(0, 4, 0))
						v.Label.Visible = Visible
						if not Visible then continue end
						v.Label.Position = UDim2.fromOffset(ScreenPos.X, ScreenPos.Y)
					end
				end))

				repeat
					Refresh()
					task.wait(0.5)
				until not TeamUpgrades.Enabled or Session ~= Current
			else
				for Anchor: Instance, v: {Label: TextLabel, Team: string} in Reference do
					v.Label:Destroy()
					Reference[Anchor] = nil
				end
			end
		end,
		Tooltip = 'Shows each team\'s upgrades over their generator'
	})

	OwnTeam = TeamUpgrades:CreateToggle({
		Name = "Show own team",
		Function = function()
			if TeamUpgrades.Enabled then
				TeamUpgrades:Toggle()
				TeamUpgrades:Toggle()
			end
		end
	})
	BedUpgrades = TeamUpgrades:CreateToggle({
		Name = "Bed upgrades",
		Default = true,
		Function = function()
			if TeamUpgrades.Enabled then
				Refresh()
			end
		end,
		Tooltip = 'Shows bed shields and alarms'
	})
	Color = TeamUpgrades:CreateColorSlider({
		Name = "Text Color",
		Function = function(Hue: number, Sat: number, Val: number)
			for _, v: {Label: TextLabel, Team: string} in Reference do
				v.Label.TextColor3 = Color3.fromHSV(Hue, Sat, Val)
			end
		end,
		DefaultSat = 0,
		DefaultValue = 1
	})
	Transparency = TeamUpgrades:CreateSlider({
		Name = "Transparency",
		Min = 0,
		Max = 1,
		Decimal = 100,
		Default = 0.5,
		Function = function(Value: number)
			for _, v: {Label: TextLabel, Team: string} in Reference do
				v.Label.BackgroundTransparency = Value
			end
		end
	})
	Scale = TeamUpgrades:CreateSlider({
		Name = "Scale",
		Min = 0.1,
		Max = 1.5,
		Decimal = 10,
		Default = 1,
		Function = function(Value: number)
			for _, v: {Label: TextLabel, Team: string} in Reference do
				v.Label.TextSize = 14 * Value
				local Size: Vector2 = GetFontBounds(v.Label.Text, v.Label.TextSize, v.Label.FontFace)
				v.Label.Size = UDim2.fromOffset(Size.X + 8, Size.Y + 7)
			end
		end
	})
end)
