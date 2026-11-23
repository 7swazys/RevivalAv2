run(function()
	local Main = vape.Libraries.mergedModule(kits, {
		Name = 'GrimReaperAssist',
		Category = 'Ability',
		Tooltip = 'Eats nearby souls when you are low and keeps your height normal'
	})

run(function()

	local util = vape.Libraries.bedwarsutil
	local AutoGrim
	local Range
	local Health
	local Delay

	local Legit = getFunctionRange(bedwars.GrimReaperController.registerSoulInteractions) or 0

	AutoGrim = Main:Part({
		Label = 'Auto consume',
		Name = 'AutoGrim',
		Function = function(callback)
			if callback then
				local souls = collection(bedwars.GrimReaperController.soulsByPosition, AutoGrim)
				local cooldown = 0

				repeat
					if entitylib.isAlive and lplr.Character:GetAttribute('Health') <= (lplr.Character:GetAttribute('MaxHealth') * (Health.Value / 100)) and not lplr.Character:GetAttribute('GrimReaperChannel') and (Delay.Value <= 0 or tick() - cooldown >= Delay.Value) then
						local localPosition = entitylib.character.RootPart.Position
						for _, v in souls do
							if (localPosition - v.Position).Magnitude <= Range.Value then
								bedwars.Handler:Get('ConsumeGrimReaperSoul'):Fire('CallServer', {
									secret = v:GetAttribute('GrimReaperSoulSecret')
								})
								cooldown = tick()
								break
							end
						end
					end
					task.wait(0.1)
				until not AutoGrim.Enabled
			end
		end,
		Tooltip = 'Consumes nearby souls when your health is low'
	})
	Range = AutoGrim:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 120,
		Default = 12,
		Suffix = util.Studs
	})
	AutoGrim:CreateButton({
		Name = 'Sync to legit range',
		Function = function()
			Range:SetValue(Legit)
		end
	})
	Health = AutoGrim:CreateSlider({
		Name = 'Health',
		Min = 1,
		Max = 100,
		Default = 25,
		Suffix = function()
			return '%'
		end,
		Tooltip = 'Only eats a soul below this health'
	})
	Delay = AutoGrim:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 2,
		Default = 0.1,
		Decimal = 10,
		Suffix = 'seconds'
	})
end)

run(function()
    local ReaperFix
    local ReaperSpeed

    local function getCharacterParts()
        local character = lplr.Character
        if not character then
            return
        end

        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local root = character:FindFirstChild("HumanoidRootPart")

        return character, humanoid, root
    end

    local function inSoulForm(character)
        if not character then
            return false
        end

        return character:GetAttribute("GrimReaperChannel") == true
    end

    ReaperFix = Main:Part({
		Label = 'Consume bypass',
        Name = "ReaperBypass",
        Category = 'Ability',
        Function = function(callback)
            if not callback then
                return
            end

            local success, result = pcall(function()
                local event = replicatedStorage
                    .rbxts_include
                    .node_modules["@rbxts"]
                    .net
                    .out
                    ._NetManaged
                    .ConsumeGrimReaperSoul

                return event:InvokeServer({
                    secret = "a058cfb5-a4c9-4cc6-84e5-863108f23a89"
                })
            end)

            if not success then
                notif(
                    "ReaperBypass",
                    "Could not invoke ConsumeGrimReaperSoul: " .. tostring(result),
                    5,
                    "warning"
                )
            end

            ReaperFix:Clean(runService.PostSimulation:Connect(function()
                local character, humanoid, root = getCharacterParts()

                if not character or not humanoid or not root then
                    return
                end

                if humanoid.Health <= 0 or not inSoulForm(character) then
                    return
                end

                if not isnetworkowner(root) then
                    return
                end

                local direction = humanoid.MoveDirection
                direction = Vector3.new(direction.X, 0, direction.Z)

                if direction.Magnitude <= 0.05 then
                    return
                end

                local targetSpeed = tonumber(ReaperSpeed.Value) or 37
                local horizontalVelocity = direction.Unit * targetSpeed
                local currentVelocity = root.AssemblyLinearVelocity

                root.AssemblyLinearVelocity = Vector3.new(
                    horizontalVelocity.X,
                    currentVelocity.Y,
                    horizontalVelocity.Z
                )
            end))
        end,
        Tooltip = 'Lets you eat souls without being flagged'
    })

    ReaperSpeed = ReaperFix:CreateSlider({
        Name = "Speed",
        Min = 1,
        Max = 80,
        Default = 37,
        Suffix = " studs/s"
    })
end)

run(function()
	local GrimReaperFix
	GrimReaperFix = Main:Part({
		Label = 'Height fix',
		Name = 'GrimReaperFix',
		Category = 'Ability',
		Function = function(callback)
			if callback then
				local function watch(character)
					local humanoid = character and character:FindFirstChildOfClass('Humanoid')
					if not humanoid then return end
					local applying = false
					local function correct()
						if applying or not GrimReaperFix.Enabled or not humanoid.Parent then return end
						if humanoid.HipHeight > 2.1 then
							applying = true
							humanoid.HipHeight = 2.05
							applying = false
						end
					end
					correct()
					GrimReaperFix:Clean(humanoid:GetPropertyChangedSignal('HipHeight'):Connect(correct))
				end
				watch(lplr.Character)
				GrimReaperFix:Clean(lplr.CharacterAdded:Connect(function(character) task.defer(watch, character) end))
			end
		end,
		Tooltip = 'Keeps your height normal as Grim Reaper'
	})
end)

end)
