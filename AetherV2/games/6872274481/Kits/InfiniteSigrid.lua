run(function()
	local Entity = entitylib
	local LocalPlayer = lplr
	local Store = store
	local InfiniteSigrid
	local Mounted
	local Summon
	local Combat
	local Charge
	local Targets
	local Range
	local ChargeRange
	local NextSummon, NextCharge = 0, 0
	local mount

	local function UpdateVisibility()
		if ChargeRange then
			Combat.Object.Visible = Summon.Enabled
			Range.Object.Visible = Summon.Enabled and Combat.Enabled
			ChargeRange.Object.Visible = Charge.Enabled
			Targets.Object.Visible = (Summon.Enabled and Combat.Enabled) or Charge.Enabled
		end
	end

	local function matchRunning()
		return Store.matchState ~= 0
	end

	InfiniteSigrid = kits:CreateModule({
		Name = "InfiniteSigrid",
		Category = "Ability",
		Function = function(Callback: boolean)
			if Callback then
				NextSummon, NextCharge = 0, 0

				repeat
					if Entity.isAlive and Store.equippedKit == "elk_master" then
						if Mounted.Enabled and matchRunning() then
							if not mount then
								pcall(function() mount = bedwars.Client:Get("ElkKitMounted") end)
							end
							if mount then pcall(mount.SendToServer, mount) end
						end

						if Summon.Enabled and tick() >= NextSummon and bedwars.AbilityController:canUseAbility("elk_summon", {disableBlockedAbilityAlert = true}) then
							local Wanted: boolean = not Combat.Enabled

							if not Wanted then
								Wanted = #Entity.AllPosition({
									Range = Range.Value,
									Part = "RootPart",
									Players = Targets.Players.Enabled,
									NPCs = Targets.NPCs.Enabled
								}) > 0
							end

							if Wanted then
								NextSummon = tick() + 1
								bedwars.AbilityController:useAbility("elk_summon")
							end
						end

						if Charge.Enabled and LocalPlayer.Character:FindFirstChild("elk") and tick() >= NextCharge and bedwars.AbilityController:canUseAbility("elk_antler_uppercut", {disableBlockedAbilityAlert = true}) then
							local Ent = Entity.EntityPosition({
								Range = ChargeRange.Value,
								Wallcheck = Targets.Walls.Enabled or nil,
								Part = "RootPart",
								Players = Targets.Players.Enabled,
								NPCs = Targets.NPCs.Enabled
							})

							if Ent then
								local Root: BasePart = Entity.character.RootPart
								local Flat: Vector3 = (Ent.RootPart.Position - Root.Position) * Vector3.new(1, 0, 1)
								if Flat.Magnitude > 0.001 then
									Root.CFrame = CFrame.lookAlong(Root.Position, Flat)
								end
								NextCharge = tick() + 1
								bedwars.AbilityController:useAbility("elk_antler_uppercut")
							end
						end
					end
					task.wait(0.1)
				until not InfiniteSigrid.Enabled
			end
		end,
		Tooltip = 'Keeps the elk summoned and can charge nearby enemies'
	})

	Targets = InfiniteSigrid:CreateTargets({
		Players = true,
		NPCs = true,
		Visible = false
	})
	Mounted = InfiniteSigrid:CreateToggle({
		Name = "Keep mounted",
		Default = true,
		Tooltip = 'Keeps you mounted on the elk'
	})
	Summon = InfiniteSigrid:CreateToggle({
		Name = "Auto summon",
		Default = true,
		Function = UpdateVisibility,
		Tooltip = 'Summons the elk when the ability is ready'
	})
	Combat = InfiniteSigrid:CreateToggle({
		Name = "Only in combat",
		Darker = true,
		Function = UpdateVisibility,
		Tooltip = 'Only summons with someone nearby'
	})
	Range = InfiniteSigrid:CreateSlider({
		Name = "Range",
		Min = 1,
		Max = 80,
		Default = 40,
		Darker = true,
		Visible = false,
		Suffix = function(Val: number)
			return Val <= 1 and "stud" or "studs"
		end
	})
	Charge = InfiniteSigrid:CreateToggle({
		Name = "Charge attack",
		Function = UpdateVisibility,
		Tooltip = 'Charges at enemies in range while riding the elk'
	})
	ChargeRange = InfiniteSigrid:CreateSlider({
		Name = "Charge range",
		Min = 1,
		Max = 40,
		Default = 20,
		Darker = true,
		Visible = false,
		Suffix = function(Val: number)
			return Val <= 1 and "stud" or "studs"
		end
	})
end)
