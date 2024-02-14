--a collection of force related things

--add references to other files
local Constants = require "Constants"
local Data = require "Data"

--object for exposing our public functions
local Public = {}

local function getBiterTeamName(teamName)
	return teamName .. " Biters"
end

local function setupBiterForce(teamName, color)

	--get the biter team name
	local biterTeamName = getBiterTeamName(teamName)

	--get the force from the game script
	local force = game.forces[biterTeamName]

	--no friendly fire
	force.friendly_fire = false
	force.custom_color = color
	force.share_chart = true

	--add main team as friend
	force.set_friend(teamName, true)

	--add spectator team as friend
	force.set_friend("player", true)
end

local function setupForce(teamName, color)
	
	--get the force from the game script
	local force = game.forces[teamName]

	--if we leave friendly fire on, biters will attack players for some reason
	force.friendly_fire = false
	force.custom_color = color
	force.share_chart = true

	--add biter team as friend
	local biterTeamName = getBiterTeamName(teamName)
	force.set_friend(biterTeamName, true)

	force.disable_all_prototypes()
	force.disable_research()

	--add spectator team as friend
	force.set_friend("player", true)

	setupBiterForce(teamName, color)

	--setup empty data object for team
	global.Data.forces[teamName] = {}

	------------------
    local team =
    {
      name = teamName,
      members = {}
    }
	
    table.insert(global.Data.config.teams, team)
	------------------
end

local function makeForces()
	local mainTeamNames = Constants.MainTeamNames()
	local teamColors = Constants.TeamColors()

	--create each force
	for _, teamName in ipairs(mainTeamNames) do
		game.create_force(teamName)
		game.create_force(getBiterTeamName(teamName))
	end

	--setup each force
	for i, teamName in ipairs(mainTeamNames) do
		setupForce(teamName, teamColors[i])
	end
end

function Public.Initialize()
	makeForces()
end

function  Public.GetSiloByTeamName(teamName)
	return global.Data.forces[teamName].silo
end

function Public.GetTeamNameBySiloRegistrationNumber(registrationNumber)
	return global.Data.teamNameBySiloRegistrationNumber[registrationNumber]
end

function  Public.SetSilo(teamName, silo, registrationNumber)
	global.Data.forces[teamName].silo = silo
	global.Data.forces[teamName].siloRegistrationNumber = registrationNumber
	global.Data.teamNameBySiloRegistrationNumber[registrationNumber] = teamName
end

function Public.OnRoundEnd()
	local mainTeamNames = Constants.MainTeamNames()

	for _, teamName in ipairs(mainTeamNames) do

		local silo = global.Data.forces[teamName].silo
		if silo and silo.valid then
			silo.destroy()
		end

		--clear out silo
		global.Data.forces[teamName].silo = nil

		--cache silo registration number
		local siloRegistrationNumber = global.Data.forces[teamName].siloRegistrationNumber

		--clear team name lookup
		global.Data.teamNameBySiloRegistrationNumber[siloRegistrationNumber] = nil

		--clear silo registration number
		global.Data.forces[teamName].siloRegistrationNumber = nil
	end
end

function Public.GetEnemyTeamName(teamName)
	local mainTeamNames = Constants.MainTeamNames()

	for i, mainTeamName in ipairs(mainTeamNames) do
		if teamName == mainTeamName then
			if i == 1 then
				return mainTeamNames[2]
			elseif i == 2 then
				return mainTeamNames[1]
			end
		end
	end

	return nil
end


--return publicly facing functions
return Public