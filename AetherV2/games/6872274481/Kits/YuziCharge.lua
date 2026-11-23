run(function()
	local YuziCharge
	local OldField
	local Hook

	YuziCharge = kits:CreateModule({
		Name = 'YuziCharge',
		Category = 'Ability',
		Function = function(callback)
			local controller = bedwars.DaoController
			if callback then
				if Hook or not controller or not controller.enterChargingState then
					return
				end

				local old = controller.enterChargingState
				OldField = rawget(controller, 'enterChargingState')
				Hook = function(self, ...)
					local result = old(self, ...)
					if YuziCharge.Enabled and self.chargingMaid then
						self.beginChargeTime = time() - 60
					end
					return result
				end
				controller.enterChargingState = Hook
			else
				if Hook and controller and rawget(controller, 'enterChargingState') == Hook then
					controller.enterChargingState = OldField
				end
				OldField, Hook = nil, nil
			end
		end,
		Tooltip = 'Your dao is fully charged the moment you start charging, so you can dash right away'
	})
end)
