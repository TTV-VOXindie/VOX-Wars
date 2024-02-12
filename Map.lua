--map related things

--add references to other files
local Constants = require "Constants"
local Forces = require "Forces"

--object for exposing our public things
local Public = {}

local _mapSettings = {
	BaseWidth = 75,
	BaseHeightPadding = 10,
	LaneWidth = 200,
	LaneHeight = 20,
	LaneSpacing = 20,
	NumLanes = 2
}

local function makeSilo(teamIndex, teamName)
	local surface = game.surfaces.nauvis
	local force = game.forces[teamName]
	local origin = force.get_spawn_position(surface)

	local entityName = "rocket-silo"
	local xAdjust = (_mapSettings.BaseWidth - game.entity_prototypes[entityName].tile_width) / 2
	
	if teamIndex == 1 then
		xAdjust = -xAdjust
	end

	--create spitter spawner at spawn https://lua-api.factorio.com/latest/classes/LuaEntity.html
	local entity = surface.create_entity({
		name = entityName, 
		position = {origin.x + xAdjust, origin.y},
		force = force
		})

	entity.minable = false

	local registrationNumber = script.register_on_entity_destroyed(entity)

	Forces.SetSilo(teamName, entity, registrationNumber)
end

local function makeMarket(teamIndex, teamName)
	local surface = game.surfaces.nauvis
	local force = game.forces[teamName]
	local origin = force.get_spawn_position(surface)

	local entityName = "market"
	local xAdjust = game.entity_prototypes[entityName].tile_width

	if teamIndex == 1 then
		xAdjust = -xAdjust
	end
	
	--create spitter spawner at spawn https://lua-api.factorio.com/latest/classes/LuaEntity.html
	local entity = surface.create_entity({
		name = entityName, 
		position = {origin.x + xAdjust, origin.y},
		force = force
		})

	entity.destructible = false
	entity.minable = false

	local function setCoinPriceAtMarket(market, item, price)
		market.add_market_item({
			price={{"coin", price}}, 
			offer={type="give-item", item=item, count=1}
		})
	end

	--set red price
	setCoinPriceAtMarket(entity, "automation-science-pack", 1);

	--set green price
	setCoinPriceAtMarket(entity, "logistic-science-pack", 2);

	--set black price
	setCoinPriceAtMarket(entity, "military-science-pack", 3);

	--set blue price
	setCoinPriceAtMarket(entity, "chemical-science-pack", 4);

	--set purple price
	setCoinPriceAtMarket(entity, "production-science-pack", 5);

	--set yellow price
	setCoinPriceAtMarket(entity, "utility-science-pack", 6);
end


local function is_out_of_map(point)
	if point.x < _mapSettings.Left then 
		return true 
	end

	if point.x > _mapSettings.Right then 
		return true 
	end

	if point.y < _mapSettings.Top then 
		return true 
	end

	if point.y > _mapSettings.Bottom then 
		return true 
	end

	--point is somewhere within the lane area
	if point.x > -_mapSettings.LaneWidth / 2 and point.x < _mapSettings.LaneWidth / 2 then
		
		--if the number of lanes is even
		if _mapSettings.NumLanes % 2 == 0 then
			local absoluteY = math.abs(point.y)

			--even # of lanes means spacing is centered so first instance must be halved
			if absoluteY < .5 * _mapSettings.LaneSpacing then
				return true
			end

			--shift point down so we can calculate
			local yCalc = absoluteY - (.5 * _mapSettings.LaneSpacing)

			--take modulus of combined lane height + spacing
			yCalc = yCalc % (_mapSettings.LaneHeight + _mapSettings.LaneSpacing)

			--if the remainder is greater than the lane height, it's part of the lane spacing
			if yCalc > _mapSettings.LaneHeight then
				return true
			end
		else

		end
	end

	return false
end

local function isPlayerBoundary(point)
	if math.abs(point.x) == (_mapSettings.LaneWidth / 2) - 1 then
		return true
	end

	return false
end

function Public.OnChunkGenerated(event)
	local surface = event.surface

	for x = event.area.left_top.x, event.area.right_bottom.x, 1 do
		for y = event.area.left_top.y, event.area.right_bottom.y, 1 do
			local point = {x = x, y = y}			
			if is_out_of_map(point) then
				if point.x > _mapSettings.Left and point.x < _mapSettings.Right and point.y <= _mapSettings.Bottom and point.y >= _mapSettings.Top then
					surface.set_tiles({{name = "water", position = point}}, true)
				else
					surface.set_tiles({{name = "out-of-map", position = point}}, true) 
				end
			elseif isPlayerBoundary(point) then
				surface.set_tiles({{name = "hazard-concrete-right", position = point}}, true) 
			else
				surface.set_tiles({{name = "refined-concrete", position = point}}, true) 
			end
		end
	end
end

function Public.OnSurfaceCleared(event)

	local teamNames = Constants.MainTeamNames()
	
	for i, teamName in ipairs(teamNames) do
		makeSilo(i, teamName)
		makeMarket(i, teamName)
	end
	
	--TODO: figure out wtf force.chart_all() is?...probably have to track chunks that need to be generated and wait for events to fire for all
end

local function _setSpawnPoints()
	local surface = game.surfaces.nauvis;
	local mainTeamNames = Constants.MainTeamNames()

	for i, teamName in ipairs(mainTeamNames) do
		local force = game.forces[teamName]

		--get base center
		local x = (_mapSettings.BaseWidth + _mapSettings.LaneWidth) / 2

		--set first team to left side
		if i == 1 then
			x = -x
		end

		force.set_spawn_position(
			{ x = x, y = 0 },
			surface
		)
	end
end

function Public.Initialize()
	_mapSettings.Width = (_mapSettings.BaseWidth * 2) + _mapSettings.LaneWidth
	_mapSettings.Left = -_mapSettings.Width / 2
	_mapSettings.Right = _mapSettings.Width / 2
	_mapSettings.Height = (_mapSettings.LaneHeight * _mapSettings.NumLanes) + (_mapSettings.LaneSpacing * (_mapSettings.NumLanes - 1)) + (_mapSettings.BaseHeightPadding * 2)

	_mapSettings.Top = -_mapSettings.Height / 2
	_mapSettings.Bottom = _mapSettings.Height / 2

	local surface = game.surfaces.nauvis;
	surface.generate_with_lab_tiles = true

	local map_gen_settings = surface.map_gen_settings
	map_gen_settings.width = _mapSettings.Width
	map_gen_settings.height = _mapSettings.Height
	map_gen_settings.starting_area = 0
	surface.map_gen_settings = map_gen_settings
	
	surface.clear(true)

	for x = _mapSettings.Left, _mapSettings.Right, 32 do
		for y = _mapSettings.Top, _mapSettings.Bottom, 32 do 
			local chunk = {math.floor(x / 32), math.floor(y / 32)}
			surface.request_to_generate_chunks(chunk)
		end
	end

	surface.force_generate_chunk_requests()

	_setSpawnPoints()
end

function Public.LaneWidth()
	return _mapSettings.LaneWidth
end

function  Public.ChartAll()
	local mainTeamNames = Constants.MainTeamNames()
	local surface = game.surfaces.nauvis

	--create each force
	for _, teamName in ipairs(mainTeamNames) do

		local force = game.forces[teamName]

		force.chart(
			surface,
			{
				{
					_mapSettings.Left,
					_mapSettings.Top
				},
				{
					_mapSettings.Right,
					_mapSettings.Bottom
				}
			})
	end
end

--return publicly facing things
return Public