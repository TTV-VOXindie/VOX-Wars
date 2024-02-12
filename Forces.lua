--a collection of force related things

--add references to other files
local Constants = require "Constants"
local Data = require "Data"

local _data = 
{
	forces = {},
	teamNameBySiloRegistrationNumber = {}
}

--object for exposing our public functions
local Public = {}

local function getBiterTeamName(teamName)
	return teamName .. " Biters"
end

local function setupBiterForce(teamName)

	--get the biter team name
	local biterTeamName = getBiterTeamName(teamName)

	--get the force from the game script
	local force = game.forces[biterTeamName]

	--no friendly fire
	force.friendly_fire = false

	--add main team as friend
	force.set_friend(teamName, true)
end

local function setupForce(teamName)
	
	--get the force from the game script
	local force = game.forces[teamName]

	--if we leave friendly fire on, biters will attack players for some reason
	force.friendly_fire = false

	--add biter team as friend
	local biterTeamName = getBiterTeamName(teamName)
	force.set_friend(biterTeamName, true)

	force.disable_all_prototypes()
	force.disable_research()

	setupBiterForce(teamName)

	--setup empty data object for team
	_data.forces[teamName] = {}

	------------------
    local team =
    {
      name = teamName,
      --color = script_data.config.colors[math.random(#script_data.config.colors)].name,
      members = {},
      team = "-"
    }
    table.insert(Data.config.teams, team)
	------------------
end

local function makeForces()
	local mainTeamNames = Constants.MainTeamNames()

	--create each force
	for _, teamName in ipairs(mainTeamNames) do
		game.create_force(teamName)
		game.create_force(getBiterTeamName(teamName))
	end

	--setup each force
	for _, teamName in ipairs(mainTeamNames) do
		setupForce(teamName)
	end
end

function Public.Initialize()
	makeForces()
end

function  Public.GetSiloByTeamName(teamName)
	return _data.forces[teamName].silo
end

function Public.GetTeamNameBySiloRegistrationNumber(registrationNumber)
	return _data.teamNameBySiloRegistrationNumber[registrationNumber]
end

function  Public.SetSilo(teamName, silo, registrationNumber)
	_data.forces[teamName].silo = silo
	_data.teamNameBySiloRegistrationNumber[registrationNumber] = teamName
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