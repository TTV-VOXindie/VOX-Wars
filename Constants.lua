--collection of values that will be used throughout our scripts

--object for exposing our public things
local Public = {}

function Public.MainTeamNames()
	return {
		"Team 1",
		"Team 2"
	}
end

function Public.SpawnDelay()
	return 1 * 60 --1 second
end

function Public.CoinDelayTicks()
	return 60 * 60 --60 seconds
end

function Public.MaxNumPlayersOnTeam()
	return 10
end

--return publicly facing things
return Public