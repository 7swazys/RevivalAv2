run(function()
	local AntiEffect
	local Dizzy
	local Fear
	local Vignettes
	local oldvignettes
	
	AntiEffect = vape.Categories.Utility:CreateModule({
		Name = 'AntiEffect',
		Function = function(callback)
			if callback then
				if Dizzy.Enabled then
					runService:UnbindFromRenderStep('dizzy-status')
				end
	
				if Fear.Enabled then
					runService:UnbindFromRenderStep('werewolf-fear-status')
				end
	
				if Vignettes.Enabled then
					oldvignettes = bedwars.VignetteController.enableOnScreenEffects
					bedwars.VignetteController.enableOnScreenEffects = false
					bedwars.VignetteController:destroyAllVignettes()
				end
	
				local added = bedwars.SyncEvents.StatusEffectAdded:setPriority(1000):connect(function(event)
					if event.entityInstance ~= lplr.Character then return end
	
					if Dizzy.Enabled and event.statusEffect == bedwars.StatusEffectMeta.DIZZY then
						runService:UnbindFromRenderStep('dizzy-status')
					end
	
					if Fear.Enabled and event.statusEffect == bedwars.StatusEffectMeta.WEREWOLF_FEAR then
						runService:UnbindFromRenderStep('werewolf-fear-status')
					end
				end)
				AntiEffect:Clean(function()
					added:Destroy()
				end)
			else
				if oldvignettes ~= nil then
					bedwars.VignetteController.enableOnScreenEffects = oldvignettes
					oldvignettes = nil
				end
			end
		end,
		Tooltip = 'Removes debuff effects on your screen'
	})
	local VignettesState
	local VignettesChanged = function(callback)
			if AntiEffect.Enabled and callback then
				oldvignettes = bedwars.VignetteController.enableOnScreenEffects
				bedwars.VignetteController.enableOnScreenEffects = false
				bedwars.VignetteController:destroyAllVignettes()
			elseif AntiEffect.Enabled and oldvignettes ~= nil then
				bedwars.VignetteController.enableOnScreenEffects = oldvignettes
				oldvignettes = nil
			end
		end
	local Effects
	Effects = AntiEffect:CreateMultiDropdown({
		Name = 'Block',
		List = {'Dizzy', 'Werewolf fear', 'Vignettes'},
		Default = {'Dizzy', 'Werewolf fear', 'Vignettes'},
		Function = function()
			local on = Effects:Has('Vignettes')
			if VignettesState ~= on then
				VignettesState = on
				VignettesChanged(on)
			end
		end,
		Tooltip = 'Which effects to remove'
	})
	VignettesState = Effects:Has('Vignettes')
	Dizzy = setmetatable({}, {__index = function(_, key) if key == 'Enabled' then return Effects:Has('Dizzy') end end})
	Fear = setmetatable({}, {__index = function(_, key) if key == 'Enabled' then return Effects:Has('Werewolf fear') end end})
	Vignettes = setmetatable({}, {__index = function(_, key) if key == 'Enabled' then return Effects:Has('Vignettes') end end})
end)
