run(function()

	local util = vape.Libraries.bedwarsutil
	local AntiSuffocate
	local Mode
	local Height

	local offsets = {
		Vector3.new(0, 3, 0),
		Vector3.new(3, 0, 0),
		Vector3.new(-3, 0, 0),
		Vector3.new(0, 0, 3),
		Vector3.new(0, 0, -3),
		Vector3.new(0, -3, 0)
	}

	local function getEscape(position)
		for _, v in offsets do
			local target = position + v
			if not getPlacedBlock(target) and not getPlacedBlock(target + Vector3.new(0, 3, 0)) then
				return target
			end
		end
		return nil
	end

	AntiSuffocate = vape.Categories.Utility:CreateModule({
		Name = 'AntiSuffocate',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and store.matchState == 1 then
						local root = entitylib.character.RootPart
						local head = root.Position + Vector3.new(0, Height.Value, 0)
						local block = getPlacedBlock(head)
						if block then
							if Mode.Value == 'Break' then
								bedwars.breakBlock(block, true, true)
							else
								local escape = getEscape(roundPos(head))
								if escape then
									root.CFrame = CFrame.new(escape - Vector3.new(0, Height.Value, 0)) * (root.CFrame - root.Position)
									root.AssemblyLinearVelocity = Vector3.zero
								end
							end
						end
					end
					task.wait(0.1)
				until not AntiSuffocate.Enabled
			end
		end,
		Tooltip = 'Gets you out when you are stuck inside blocks'
	})

	Mode = AntiSuffocate:CreateDropdown({
		Name = 'Mode',
		List = {'TP', 'Break'},
		Tooltip = 'TP - moves you to the nearest open cell\nBreak - breaks the block you are stuck in'
	})
	Height = AntiSuffocate:CreateSlider({
		Name = 'Check height',
		Min = 0,
		Max = 4,
		Default = 1.5,
		Decimal = 10,
		Suffix = util.Studs,
		Tooltip = 'How high above you the check looks'
	})
end)
