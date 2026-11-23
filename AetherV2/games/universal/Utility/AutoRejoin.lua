run(function()
    local AutoRejoin
    local Mode

    AutoRejoin = vape.Categories.Utility:CreateModule({
	Name = 'AutoRejoin',
	Function = function(callback)
		if callback then
			local check
			AutoRejoin:Clean(guiService.ErrorMessageChanged:Connect(function(str)
				if
					(not check or guiService:GetErrorCode() ~= Enum.ConnectionError.DisconnectLuaKick)
					and guiService:GetErrorCode() ~= Enum.ConnectionError.DisconnectConnectionLost
					and not str:lower():find('ban')
				then
					check = true
					task.spawn(serverHop, nil, Mode.Value)
				end
			end))
		end
	end,
	Tooltip = 'Rejoins a new server if you get disconnected or kicked',
    })
    Mode = AutoRejoin:CreateDropdown({
	Name = 'Mode',
	List = { 'Least Players', 'Most Players', 'Lowest Ping', 'Highest FPS', 'Random' },
	Default = 'Most Players',
	Tooltip = 'Least Players - the emptiest server\nMost Players - the fullest server with room\nLowest Ping - lowest average ping of the players in it\nHighest FPS - the smoothest running server\nRandom - any open server',
    })
end)
