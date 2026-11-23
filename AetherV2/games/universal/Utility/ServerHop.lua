run(function()
    local ServerHop
    local Mode
    local SkipVisited

    ServerHop = vape.Categories.Utility:CreateModule({
	Name = 'ServerHop',
	Function = function(callback)
		if callback then
			ServerHop:Toggle()
			task.spawn(serverHop, nil, Mode.Value, SkipVisited.Enabled)
		end
	end,
	Tooltip = 'Teleports you to a different server',
    })
    Mode = ServerHop:CreateDropdown({
	Name = 'Mode',
	List = { 'Least Players', 'Most Players', 'Lowest Ping', 'Highest FPS', 'Random' },
	Default = 'Most Players',
	Tooltip = 'Least Players - the emptiest server\nMost Players - the fullest server with room\nLowest Ping - lowest average ping of the players in it\nHighest FPS - the smoothest running server\nRandom - any open server',
    })
    SkipVisited = ServerHop:CreateToggle({
	Name = 'Skip visited servers',
	Default = true,
	Tooltip = 'Never picks a server you already left this session',
    })
    ServerHop:CreateButton({
	Name = 'Rejoin Previous Server',
	Function = function()
		notif(
			'ServerHop',
			shared.vapeserverhopprevious and 'Rejoining previous server...' or 'Cannot find previous server',
			5
		)
		if shared.vapeserverhopprevious then
			teleportService:TeleportToPlaceInstance(game.PlaceId, shared.vapeserverhopprevious)
		end
	end,
    })
end)
