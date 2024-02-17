--a collection of things that need to be done on initialize

--add references to other files
local Constants = require "Constants"
local Data = require "Data"
local Forces = require "Forces"
local Map = require "Map"
local Lobby = require "Lobby"

--object for exposing our public functions
local Public = {}

function Public.Initialize()
	Data.Initialize()
	Forces.Initialize()
	Map.Initialize()
	Lobby.Initialize()
end

--return publicly facing functions
return Public