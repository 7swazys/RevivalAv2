run(function()
	local SendNotification = notif
	local Store = store
	local AutoVote
	local Option
	local Delay
	local Notify

	local Request = bedwars.Handler:Get("CastPregameVote")
	local Voted: boolean

	AutoVote = vape.Categories.Utility:CreateModule({
		Name = "AutoVote",
		Function = function(Callback: boolean)
			if Callback then
				Voted = false

				repeat
					if Store.matchState == 0 then
						if not Voted then
							Request:Fire("SendToServer", {votingOptionIndex = Option.Value - 1})
							Voted = true

							if Notify.Enabled then
								SendNotification("AutoVote", `Voted for option {Option.Value}`, 4)
							end
						end
					else
						Voted = false
					end
					task.wait(Delay.Value)
				until not AutoVote.Enabled
			else
				Voted = false
			end
		end,
		Tooltip = 'Votes for your map when voting opens'
	})

	Option = AutoVote:CreateSlider({
		Name = "Option",
		Min = 1,
		Max = 4,
		Default = 1,
		Tooltip = 'Which voting option to pick, from the left'
	})
	Delay = AutoVote:CreateSlider({
		Name = "Delay",
		Min = 0.5,
		Max = 10,
		Default = 1,
		Decimal = 10,
		Suffix = "seconds"
	})
	Notify = AutoVote:CreateToggle({
		Name = "Notify",
		Default = true,
		Tooltip = "Tells you when the vote goes in"
	})
end)
