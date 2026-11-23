run(function()
	local NoClickDelay
	local SwingLock
	local Drill
	local old, olddrill, oldlock
	
	NoClickDelay = vape.Categories.Combat:CreateModule({
		Name = 'NoClickDelay',
		Function = function(callback)
			if callback then
				old = bedwars.SwordController.isClickingTooFast
				bedwars.SwordController.isClickingTooFast = function(self)
					self.lastSwing = tick()
					return false
				end
	
				if SwingLock.Enabled then
					oldlock = bedwars.SwordController.getSwordSwingDisabled
					bedwars.SwordController.getSwordSwingDisabled = function()
						return false
					end
				end
	
				if Drill.Enabled then
					olddrill = bedwars.DrillTabletController.isClickingTooFast
					bedwars.DrillTabletController.isClickingTooFast = function()
						return false
					end
				end
			else
				bedwars.SwordController.isClickingTooFast = old
	
				if oldlock then
					bedwars.SwordController.getSwordSwingDisabled = oldlock
					oldlock = nil
				end
	
				if olddrill then
					bedwars.DrillTabletController.isClickingTooFast = olddrill
					olddrill = nil
				end
			end
		end,
		Tooltip = 'Removes the limit on how fast you can swing'
	})
	SwingLock = NoClickDelay:CreateToggle({
		Name = 'Swing lock',
		Function = function()
			if NoClickDelay.Enabled then
				NoClickDelay:Toggle()
				NoClickDelay:Toggle()
			end
		end,
		Tooltip = 'Lets you swing while a kit ability would stop you'
	})
	Drill = NoClickDelay:CreateToggle({
		Name = 'Drill',
		Function = function()
			if NoClickDelay.Enabled then
				NoClickDelay:Toggle()
				NoClickDelay:Toggle()
			end
		end,
		Default = true,
		Tooltip = 'Removes the same cap on the drill tablet'
	})
end)
