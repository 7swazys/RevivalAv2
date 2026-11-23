run(function()
	local CollectionService = collectionService
	local Entity = entitylib
	local LocalPlayer = lplr
	local AutoCollect
	local Collectables
	local Range
	local Delay
	local Animation

	local Request = bedwars.Handler:Get("CollectCollectableEntity")
	local Cooldowns: {[Instance]: number} = {}

	AutoCollect = vape.Categories.Utility:CreateModule({
		Name = "AutoCollect",
		Function = function(Callback: boolean)
			if Callback then
				repeat
					if Entity.isAlive then
						local LocalPosition: Vector3 = Entity.character.RootPart.Position
						for _, v: string in Collectables.ListEnabled do
							for _, Collectable: Instance in CollectionService:GetTagged(v) do
								local Part = Collectable:IsA("Model") and Collectable.PrimaryPart or Collectable
								local Id = Collectable:GetAttribute("Id")
								if Part and Id and tick() > (Cooldowns[Collectable] or 0) and (LocalPosition - Part.Position).Magnitude <= Range.Value then
									if Animation.Enabled then
										bedwars.GameAnimationUtil:playAnimation(LocalPlayer.Character, bedwars.AnimationType.PUNCH)
										bedwars.ViewmodelController:playAnimation(bedwars.AnimationType.FP_USE_ITEM)
									end

									Request:Fire("SendToServer", {
										id = Id,
										collectableName = Collectable.Name
									})
									Cooldowns[Collectable] = tick() + 1
								end
							end
						end
					end
					task.wait(Delay.Value)
				until not AutoCollect.Enabled
			else
				table.clear(Cooldowns)
			end
		end,
		Tooltip = 'Picks up nearby kit collectables'
	})

	Range = AutoCollect:CreateSlider({
		Name = "Range",
		Min = 1,
		Max = 20,
		Default = 11,
		Suffix = function(Val: number)
			return Val <= 1 and "stud" or "studs"
		end,
		Tooltip = 'How close something must be to collect it'
	})
	Delay = AutoCollect:CreateSlider({
		Name = "Delay",
		Min = 0.05,
		Max = 1,
		Default = 0.1,
		Decimal = 100,
		Suffix = "seconds"
	})
	Animation = AutoCollect:CreateToggle({
		Name = "Animation",
		Default = true,
		Tooltip = "Plays the pickup animation"
	})
	Collectables = AutoCollect:CreateTextList({
		Name = "Collectables",
		Default = {
			"alchemist_ingedients",
			"alchemy_crystal",
			"crystalheart_seed",
			"forest_environment_plant",
			"jailor_soul",
			"murder_coin",
			"shadow_coin",
			"soulvine_seed",
			"spirit_gardener_energy",
			"spirit_gardener_seeds",
			"tearbloom_seed"
		},
		Darker = true,
		Tooltip = 'Collectables to pick up'
	})
end)
