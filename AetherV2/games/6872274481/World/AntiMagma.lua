run(function()
	local AntiMagma

	local function disableMagmaPart(v)
		local name = v.Name
		if not (name:find('agma', 1, true) or name:find('AGMA', 1, true)) then return end
		if not v:IsA('BasePart') then return end
		if not string.find(string.lower(name), 'magma', 1, true) then return end
		for _, stuff in v:GetDescendants() do
			if stuff:IsA('TouchTransmitter') then
				pcall(function() stuff:Destroy() end)
			end
		end
	end

	AntiMagma = vape.Categories.World:CreateModule({
		Name = 'AntiMagma',
		Tooltip = 'Stops magma killing you',
		Function = function(callback)
			if callback then
				scanDescendants(workspace, disableMagmaPart, AntiMagma)

				AntiMagma:Clean(workspace.DescendantAdded:Connect(function(v)
					disableMagmaPart(v)
				end))

				local worldFolder = getWorldFolder()
				if not worldFolder then return end
				local blocks = worldFolder:FindFirstChild('Blocks')
				if not blocks then return end
				AntiMagma:Clean(blocks.ChildAdded:Connect(function(v)
					disableMagmaPart(v)
				end))
			end
		end
	})
end)
