run(function()
	local Entity = entitylib
	local LocalPlayer = lplr
	local TweenService = tweenService
	local SetEmote
	local Emote
	local Track: AnimationTrack?
	local Display: BillboardGui?

	local List, EmoteTypes = {}, {}
	for EmoteType: any, v: any in bedwars.EmoteMeta do
		if EmoteType ~= bedwars.EmoteType.NONE and v.name and not EmoteTypes[v.name] then
			EmoteTypes[v.name] = EmoteType
			table.insert(List, v.name)
		end
	end
	table.sort(List)

	local function CancelEmote()
		if Display then
			Display:Destroy()
			Display = nil
		end
		if Entity.isAlive then
			if Track then
				Track:Stop()
				Track:Destroy()
				Track = nil
			end
			if LocalPlayer.Character:GetAttribute("PlayingEmote") then
				LocalPlayer.Character:SetAttribute("PlayingEmote", nil)
			end
		end
	end

	SetEmote = vape.Categories.Utility:CreateModule({
		Name = "SetEmote",
		Function = function(Callback: boolean)
			if Callback then
				SetEmote:Toggle()
				if Entity.isAlive then
					local EmoteType = EmoteTypes[Emote.Value]
					local Meta = bedwars.EmoteMeta[EmoteType]
					if Meta then
						LocalPlayer.Character:SetAttribute("PlayingEmote", EmoteType)
						local PlayBeginSounds = bedwars.EmoteController.createEmoteBeginAudioPlayers or bedwars.EmoteController.playEmoteBeginSounds
						if PlayBeginSounds then
							PlayBeginSounds(bedwars.EmoteController, EmoteType, LocalPlayer)
						end
						local Animation = Meta.animation
						if not Animation and Meta.emoteDisplayType then
							local Display = bedwars.EmoteDisplayMeta[Meta.emoteDisplayType]
							Animation = Display and Display.animation
						end
						if Animation then
							Track = LocalPlayer.Character.Humanoid:LoadAnimation(bedwars.GameAnimationUtil:getAnimation(Animation.type))
							Track.Looped = Animation.looped or false
							Track:Play(nil, nil, Animation.speed or 1)
						end
						if not Meta.animation then
							if Display then Display:Destroy() end
							local Gui: BillboardGui = Instance.new("BillboardGui")
							Display = Gui
							Gui.Size = UDim2.fromScale(6, 2.5)
							Gui.StudsOffset = Vector3.new(0, 2, 0)
							Gui.AlwaysOnTop = true
							Gui.Adornee = LocalPlayer.Character.Head

							local Image: ImageLabel = Instance.new("ImageLabel")
							Image.AnchorPoint = Vector2.new(0.5, 1)
							Image.Position = UDim2.fromScale(0.5, 1)
							Image.Size = UDim2.fromScale(0, 0)
							Image.Image = Meta.image
							Image.BackgroundTransparency = 1
							Image.ImageTransparency = 1
							Image.ScaleType = Enum.ScaleType.Fit
							Image.Parent = Gui

							Gui.Parent = LocalPlayer.Character.Head
							TweenService:Create(Image, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
								Position = UDim2.fromScale(0.5, 0.5),
								Size = UDim2.fromScale(1, 1),
								ImageTransparency = 0
							}):Play()
						end
						if Meta.allowMovement then
							task.delay(6, CancelEmote)
						else
							LocalPlayer.Character.Humanoid:GetPropertyChangedSignal("MoveDirection"):Once(CancelEmote)
						end
					end
				end
			end
		end,
		Tooltip = 'Plays the selected emote on your character'
	})

	Emote = SetEmote:CreateDropdown({
		Name = "Emote",
		List = List,
		Default = "nightmare"
	})
end)
