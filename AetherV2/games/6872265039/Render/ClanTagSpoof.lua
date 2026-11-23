run(function()
	local ClanTagSpoof
	local Tags
	local Equipped
	local Colour

	local function apply()
		if not ClanTagSpoof.Enabled then return end
		local tag = Equipped and Equipped.Value
		if not tag or tag == '' or tag == 'None' then
			spoof.Hold('ClanTagSpoof', lplr, 'ClanTag', nil)
			return
		end
		local colour = Color3.fromHSV(Colour.Hue, Colour.Sat, Colour.Value)
		local hex = string.format('#%02X%02X%02X', colour.R * 255, colour.G * 255, colour.B * 255)
		spoof.Hold('ClanTagSpoof', lplr, 'ClanTag', '<font color="'..hex..'">'..tag..'</font>')
	end

	ClanTagSpoof = vape.Categories.Render:CreateModule({
		Name = 'ClanTagSpoof',
		Function = function(callback)
			if callback then
				apply()
			else
				spoof.Hold('ClanTagSpoof', lplr, 'ClanTag', nil)
			end
		end,
		Tooltip = 'Shows a clan tag of your choice next to your name, only on your screen'
	})
	Tags = ClanTagSpoof:CreateTextList({
		Name = 'Clan tags',
		Placeholder = 'Add a tag',
		Function = function(list)
			local options = {}
			for _, tag in list do
				if tag ~= '' and not table.find(options, tag) then
					table.insert(options, tag)
				end
			end
			if Equipped then
				Equipped:Change(#options > 0 and options or {'None'})
				apply()
			end
		end
	})
	Equipped = ClanTagSpoof:CreateDropdown({
		Name = 'Tag',
		List = {'None'},
		Function = apply,
		Tooltip = 'The tag to show'
	})
	Colour = ClanTagSpoof:CreateColorSlider({
		Name = 'Tag colour',
		Function = apply
	})
	if Tags.ListEnabled and #Tags.ListEnabled > 0 then
		Equipped:Change(Tags.ListEnabled)
	end
end)
