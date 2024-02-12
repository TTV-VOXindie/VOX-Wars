--a collection of things that need to be done on initialize

--add references to other files
local Data = require "Data"
local Forces = require "Forces"
local Map = require "Map"

--object for exposing our public functions
local Public = {}

function Public.Initialize()
	Data.Initialize()
	Forces.Initialize()
	Map.Initialize()

	--todo recreate players?
end

--return publicly facing functions
return Public