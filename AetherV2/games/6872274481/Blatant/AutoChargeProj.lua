run(function()
	local AutoChargeProj
	local Percentage
	local Items
	local removeHook

	local function allowed(projectile)
		local list = Items.ListEnabled
		if #list == 0 then return true end
		local tool = store.hand.tool
		return table.find(list, projectile) ~= nil or (tool ~= nil and table.find(list, tool.Name) ~= nil)
	end

	local function clearHook()
		if removeHook then
			removeHook()
			removeHook = nil
		end
	end

	AutoChargeProj = vape.Categories.Blatant:CreateModule({
		Name = 'AutoChargeProj',
		Function = function(enabled)
			clearHook()
			if not enabled then return end
			if not (bedwars.ProjectileLaunchHook and bedwars.ProjectileController) then
				notif('AutoChargeProj', 'Projectile controller is unavailable.', 5, 'warning')
				task.defer(function() if AutoChargeProj.Enabled then AutoChargeProj:Toggle() end end)
				return
			end
			removeHook = bedwars.ProjectileLaunchHook:Add('AutoChargeProj', 80, function(nextHook, self, launchData, ...)
				local metadata = launchData and bedwars.ProjectileMeta[launchData.projectile]
				if metadata and metadata.predictionLifetimeSec and launchData.drawDurationSeconds and allowed(launchData.projectile) then
					local charge = Percentage.Value / 100
					launchData.drawDurationSeconds = math.max(launchData.drawDurationSeconds, metadata.predictionLifetimeSec * charge)
					launchData.velocityMultiplier = math.max(launchData.velocityMultiplier or 0, charge)
				end
				return nextHook(self, launchData, ...)
			end)
			AutoChargeProj:Clean(clearHook)
		end,
		Tooltip = 'Instantly charges projectile items to the set charge'
	})
	Percentage = AutoChargeProj:CreateSlider({
		Name = 'Percentage',
		Min = 0,
		Max = 100,
		Default = 50,
		Suffix = '%'
	})
	Items = AutoChargeProj:CreateTextList({
		Name = 'Items',
		Placeholder = 'item or projectile id',
		Tooltip = 'Items to charge, empty charges everything'
	})
end)
