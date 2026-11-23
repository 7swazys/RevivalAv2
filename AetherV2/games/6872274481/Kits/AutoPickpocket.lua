run(function()
	local Entity = entitylib
	local GetFunctionRange = getFunctionRange
	local LocalPlayer = lplr
	local SortMethods = sortmethods
	local Store = store
	local AutoPickpocket
	local Targets
	local Range
	local Hidden

	local Legit: number = GetFunctionRange(bedwars.MimicController.onKitLocalActivated) or 25
	local MimicPickPocket = bedwars.Handler:Get("MimicBlockPickPocketPlayer")
	local Sounds = {bedwars.SoundList.MIMIC_PICKPOCKET_1, bedwars.SoundList.MIMIC_PICKPOCKET_2, bedwars.SoundList.MIMIC_PICKPOCKET_3}
	local RandomGenerator: Random = Random.new()
	local Attempted = setmetatable({}, {__mode = "k"})
	local Ready, Warned = false, 0

	AutoPickpocket = kits:CreateModule({
		Name = "AutoPickpocket",
		Function = function(Callback: boolean)
			if Callback then
				Ready = false
				AutoPickpocket:Clean(bedwars.Client:Get("MimicBlockPickPocketReady"):Connect(function(Event)
					if Event.player == LocalPlayer then
						Ready = Event.ready and true or false
					end
				end))

				repeat
					local Success, Error = pcall(function()
						if not Entity.isAlive or Store.equippedKit ~= "mimic" then
							return
						end
						local LocalPosition: Vector3 = Entity.character.RootPart.Position
						local NearbyTargets = Entity.AllPosition({
							Range = Range.Value,
							Origin = LocalPosition,
							Wallcheck = Targets.Walls.Enabled or nil,
							Part = "RootPart",
							Players = true,
							Sort = SortMethods.Distance
						})

						for _, v: any in NearbyTargets do
							if not Ready then
								break
							end
							if not v.Character:HasTag("MimicBLockPickPocketPlayer") then
								continue
							end
							if Attempted[v.Character] and tick() - Attempted[v.Character] < 0.5 then
								continue
							end
							Attempted[v.Character] = tick()
							Ready = false

							if MimicPickPocket:Fire("CallServer", v.Player) then
								bedwars.AudioManager:playAudio(Sounds[RandomGenerator:NextInteger(1, #Sounds)], {
									playbackSpeedMultiplier = 1.27,
									position = LocalPosition
								})
							end
							break
						end

						if #NearbyTargets <= 0 and Hidden.Enabled and bedwars.AbilityController:canUseAbility("MIMIC_BLOCK_HIDDEN", {disableBlockedAbilityAlert = true}) then
							bedwars.AbilityController:useAbility("MIMIC_BLOCK_HIDDEN")
						end
					end)

					if not Success and tick() - Warned > 5 then
						Warned = tick()
						warn(`[AetherV2] AutoPickpocket: {Error}`)
					end
					task.wait(0.1)
				until not AutoPickpocket.Enabled
				table.clear(Attempted)
			end
		end,
		Tooltip = 'Pickpockets enemies with the Milo kit'
	})

	Targets = AutoPickpocket:CreateTargets({Players = true, Walls = true})

	Range = AutoPickpocket:CreateSlider({
		Name = "Range",
		Min = 1,
		Max = 30,
		Default = Legit,
		Suffix = function(Val: number)
			return Val <= 1 and "stud" or "studs"
		end
	})
	AutoPickpocket:CreateButton({
		Name = "Sync to legit range",
		Function = function()
			Range:SetValue(Legit)
		end
	})
	Hidden = AutoPickpocket:CreateToggle({
		Name = "Hide when clear",
		Tooltip = "Goes back into the block once nobody is in range"
	})
end)
