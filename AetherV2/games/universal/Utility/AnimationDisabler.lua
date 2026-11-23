run(function()
	local AnimationDisabler
	local scriptStates = {}

	local function stopTrack(track)
		pcall(track.Stop, track, 0)
	end

	local function suppress(character)
		if not AnimationDisabler.Enabled then return end
		local animators = {}

		local function inspect(obj)
			if obj:IsA('LocalScript') and obj.Name == 'Animate' and scriptStates[obj] == nil then
				scriptStates[obj] = obj.Disabled
				obj.Disabled = true
				AnimationDisabler:Clean(obj:GetPropertyChangedSignal('Disabled'):Connect(function()
					if AnimationDisabler.Enabled and not obj.Disabled then
						obj.Disabled = true
					end
				end))
			elseif obj:IsA('Animator') and not animators[obj] then
				animators[obj] = true
				for _, track in obj:GetPlayingAnimationTracks() do
					stopTrack(track)
				end
				AnimationDisabler:Clean(obj.AnimationPlayed:Connect(function(track)
					if AnimationDisabler.Enabled then
						stopTrack(track)
					end
				end))
			end
		end

		for _, obj in character:GetDescendants() do
			inspect(obj)
		end
		AnimationDisabler:Clean(character.DescendantAdded:Connect(inspect))
	end

	AnimationDisabler = vape.Categories.Utility:CreateModule({
		Name = 'AnimationDisabler',
		Function = function(callback)
			if callback then
				if lplr.Character then
					suppress(lplr.Character)
				end
				AnimationDisabler:Clean(lplr.CharacterAdded:Connect(suppress))
			else
				for obj, wasDisabled in scriptStates do
					pcall(function()
						obj.Disabled = wasDisabled
					end)
				end
				table.clear(scriptStates)
			end
		end,
		Tooltip = 'Stops every animation on your character'
	})
end)
