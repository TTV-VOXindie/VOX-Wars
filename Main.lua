--main file

--add references to other files
local Constants = require "Constants"
local Init = require "Init"
local Forces = require "Forces"
local Map = require "Map"
local GameStateEnum = require "GameStateEnum"
local GUI = require "GUI"
local Lobby = require "Lobby"
local Data = require "Data"

local util = require("util")

local function setPlayerToSpectator(player)
	--set the player as a spectator
	player.spectator = true

	--make them not show on the map
	player.show_on_map = false

	player.force = "player"

	local character = player.character
	player.character = nil
	if character then 
		character.destroy()
	end

	player.set_controller({type = defines.controllers.spectator})
end

--https://lua-api.factorio.com/latest/events.html#on_player_joined_game
local function on_player_joined_game(event)
	local player = game.players[event.player_index]

	--ignore if it's not a valid player
	if not (player and player.valid) then
		return
	end

	--if they are not on the player force, they have already picked a team this round
	if player.force.name ~= "player" then
		
		for _, other_player in pairs (game.connected_players) do
			--update_team_list_frame(other_player)
		end

		return
	end

	setPlayerToSpectator(player)

	if global.Data.GameState == GameStateEnum.Lobby then
		player.teleport({1, 1}, Lobby.GetLobbySurface())
	else
		local surface = game.surfaces.nauvis
		surface.print({"is-now-spectating", player.name})
	end
end

--when a player is created https://lua-api.factorio.com/latest/events.html#on_player_created
local function on_player_created(event)
	local playerIndex = event.player_index
	local player = game.players[playerIndex]

	if global.Data.GameState == GameStateEnum.Lobby then
		GUI.MakeLobbyGui(player)
	end

	--get the player by index
	local player = game.players[event.player_index]

	player.set_quick_bar_slot(1, "assembling-machine-2")

	local i = 2
	for itemName, unitRecipe in pairs(global.Data.UnitRecipes) do
		player.set_quick_bar_slot(i, itemName)
		i = i + 1
	end

	player.set_quick_bar_slot(11, "coin")
end

local function getSafeAreaAroundEntity(entity)
	local xAdjust =  ((entity.tile_width * .5) + 1)
	local yAdjust =  ((entity.tile_height * .5) + 1)
	return {
		left_top = 
		{ 
			x = entity.position.x - xAdjust, 
			y = entity.position.y - yAdjust 
		},
		right_bottom = 
		{
			x = entity.position.x + xAdjust, 
			y = entity.position.y + yAdjust
		}
	}
end

local function doesEntityHaveNeighbors(surface, entity, entitySafeArea)
	
	local entitiesInArea = surface.count_entities_filtered({
		area = entitySafeArea,
		collision_mask = "object-layer",
		limit = 2 --limit 2 beacuse we'd be including ourselves
	})

	--if there is more than one entity (ourself), then we have neighbors
	return entitiesInArea > 1
end

local function doesAreaContainUnspawnableTiles(surface, area)

	local tiles = surface.count_tiles_filtered({
		area = area,
		collision_mask = "player-layer",
		limit = 1
	})

	return tiles > 0
end

local function destroyBuiltEntityAndReturnToPlayerInventory(player, entity, message)
	util.insert_safe(player, {[entity.name] = 1})

	player.print(message)
	entity.destroy()
end


--when an entity is built https://lua-api.factorio.com/latest/events.html#on_built_entity
local on_built_entity = function(event)

	--if it's not an assembling machine
	if not (event.created_entity.name == "assembling-machine-1" or event.created_entity.name == "assembling-machine-2" or event.created_entity.name == "assembling-machine-3") then
		--ignore it
		return
	end

	local player = game.players[event.player_index]
	local surface = game.surfaces.nauvis
	local entitySafeArea = getSafeAreaAroundEntity(event.created_entity)

	local doesEntityHaveNeighbors = doesEntityHaveNeighbors(surface, event.created_entity, entitySafeArea)

	if doesEntityHaveNeighbors then
		destroyBuiltEntityAndReturnToPlayerInventory(player, event.created_entity, {"cannot-build-next-to-other-entities"})
		return
	end

	local doesAreaContainUnspawnableTiles = doesAreaContainUnspawnableTiles(surface, entitySafeArea)

	if doesAreaContainUnspawnableTiles then
		destroyBuiltEntityAndReturnToPlayerInventory(player, event.created_entity, {"cannot-build-next-to-boundary"})
		return
	end

	--set the recipe
	event.created_entity.set_recipe(Constants.EmptyAssemblerRecipe()) --not setting this to something breaks our setup because the assembler gui won't open

	--don't let the player change the recipe
	event.created_entity.recipe_locked = true
end

--https://lua-api.factorio.com/latest/events.html#on_gui_opened
local function on_gui_opened(event)

	--get the player by index
	local player = game.players[event.player_index]

	if event.gui_type ~= defines.gui_type.entity then
		return	
	end	

	local entity = event.entity

	if entity.name ~= "assembling-machine-2" then
		return
	end

	local cursor_stack = player.cursor_stack

	if cursor_stack == nil or not cursor_stack.valid_for_read then
		return
	end
	
	--close the gui the player had open (so don't open the entity gui)
	player.opened = nil
	
	local itemName = cursor_stack.name

	--if it's not a valid recipe
	if not global.Data.UnitRecipes[itemName] then
		--bail out
		return
	end

	--get the recipe name for the assembling machine
	local recipeName = Constants.MapItemNameToRecipeName(itemName)

	--get the current recipe in the assembler
	local currentRecipe = entity.get_recipe()

	

	--if there's already a recipe and it's the same as the one we're trying to assign
	if currentRecipe and currentRecipe.name == recipeName then
		--bail out
		return
	end	

	--set the recipe to be what was in the player cursor
	entity.set_recipe(recipeName)

	
	--get direction
	local direction = defines.direction.east
	if player.force.name == Constants.MainTeamNames()[2] then
		direction = defines.direction.west
	end

	--set direction
	entity.direction = direction

	--reduce the number of items in the stack
	cursor_stack.count = cursor_stack.count - 1

	--save spawner data
	global.Data.SpawnerData[#global.Data.SpawnerData + 1] =
	{
		spawner = entity,
		nextSpawnTick = event.tick + global.Data.UnitRecipes[itemName].spawnRate,
		itemName = itemName
	} 
end

--https://lua-api.factorio.com/latest/events.html#on_console_chat
local function on_console_chat(event)
	--get the player by index
	local player = game.players[event.player_index]
end


local function drawTeamCircles(surface, teamName)
	local entities = surface.find_units({
		area = {{-1000, -1000}, {1000, 1000}},
		force = teamName,
		condition = "friend"
		})

	local force = game.forces[teamName]

	for _, entity in pairs(entities) do
		rendering.draw_circle({
			color = force.color,
			radius = .75,
			width = 5,
			target = entity,
			surface = surface,
			time_to_live = 2,
			draw_on_ground = true
			})
	end
end

local function drawCircles()
	local mainTeamNames = Constants.MainTeamNames()
	local surface = game.surfaces.nauvis
	
	for _, teamName in ipairs(mainTeamNames) do
		drawTeamCircles(surface, teamName)
	end

	for _, player in (pairs(game.players)) do
		if player.spectator then
			return
		end
		rendering.draw_circle({
			color = player.force.color,
			radius = .75,
			width = 5,
			target = player.position,
			surface = surface,
			time_to_live = 2,
			draw_on_ground = true
			})
	  end
end


local function handleSpawner(tick, spawnerData)
	if tick < spawnerData.nextSpawnTick then	
		return
	end

	--get the team name
	local teamName = spawnerData.spawner.force.name
	
	local surface = game.surfaces.nauvis
	local biterForce = game.forces[teamName .. " Biters"] --TODO: make util for biter force (and maybe cache this)

	local enemyTeamName = Forces.GetEnemyTeamName(teamName)
	local enemySilo = Forces.GetSiloByTeamName(enemyTeamName)

	if not (enemySilo and enemySilo.valid) then
		return
	end

	local unitDirection = defines.direction.east
	local spawnOffsetDirection = 1
	if spawnerData.spawner.force.name == Constants.MainTeamNames()[2] then
		spawnOffsetDirection = -1
		unitDirection = defines.direction.west
	end

	local unitRecipe = global.Data.UnitRecipes[spawnerData.itemName]

	local desiredSpawnPosition = 
	{
		x = spawnerData.spawner.position.x + (spawnOffsetDirection * (spawnerData.spawner.tile_width + 1) * .5),
		y = spawnerData.spawner.position.y
	}

	local spawnPosition = surface.find_non_colliding_position(unitRecipe.unitName, desiredSpawnPosition, 1, .25)

	--create spitter spawner at spawn https://lua-api.factorio.com/latest/classes/LuaEntity.html
	local entity = surface.create_entity({
		name = unitRecipe.unitName, 
		position = spawnPosition,
		force = biterForce,
		direction = unitDirection
		})

	local pathfindFlags =
	{
		cache = false,
		low_priority = false,
		no_break = true
	}

	local command =
	{
		type = defines.command.compound,
		structure_type = defines.compound_command.return_last,
		commands =
		{
			{
				type = defines.command.go_to_location,
				destination_entity = enemySilo,
				distraction = defines.distraction.by_anything,
				radius = 3, --should be width of silo
				pathfind_flags = pathfindFlags
			},
			-- {
			-- type = defines.command.go_to_location,
			-- destination_entity = silo, --TODO: can only use this is I actually have an entity to path to
			-- distraction = defines.distraction.by_enemy,
			-- radius = get_base_radius() / 2,
			-- pathfind_flags = pathfindFlags
			-- },
			-- {
			-- 	type = defines.command.attack,
			-- 	target = silo,
			-- 	distraction = defines.distraction.by_damage
			-- }
		}
	}

	entity.set_command(command)

	spawnerData.nextSpawnTick = tick + unitRecipe.spawnRate
end

local function handleSpawners(tick)
	for i=#global.Data.SpawnerData, 1, -1 do
		local spawnerData = global.Data.SpawnerData[i]

		if spawnerData.spawner.valid then
			handleSpawner(tick, spawnerData)
		else
			table.remove(global.Data.SpawnerData, i)
		end
	end
end

local function handleCoins(tick)
	if tick < global.Data.NextCoinTick then	
		return
	end

	for _, player in pairs(game.players) do
		util.insert_safe(player, {["coin"] = 1})
	end

	global.Data.NextCoinTick = tick + global.Data.CoinRate
end

--https://lua-api.factorio.com/latest/events.html#on_tick
local function on_tick(event)
	local tick = event.tick
	--TODO: check win con

	if global.Data.GameState == GameStateEnum.Gameplay then
		drawCircles()
		handleSpawners(tick)
		handleCoins(tick)	
	end
end

--fire on ground as played moves
--on_event(defines.events.on_player_changed_position)
--player.surface.create_entity{name="fire-flame", position=player.position, force="neutral"}

local function on_chunk_generated(event)
	if global.Data.GameState == GameStateEnum.Gameplay then
		Map.OnChunkGenerated(event)
	end
end

local function on_surface_cleared(event)
	if global.Data.GameState == GameStateEnum.Gameplay then
		Map.OnSurfaceCleared(event)
	end
end

local function on_player_changed_position(event)
	--if the game state is not gameplay
	if global.Data.GameState ~= GameStateEnum.Gameplay then
		--we don't care about player position
		return
	end

	local player = game.players[event.player_index]

	--if the player is a spectator
	if player.spectator then
		--we don't need to limit their position
		return
	end

	local mainTeamNames = Constants.MainTeamNames()

	local mainTeamIndex
	for i, teamName in ipairs(mainTeamNames) do
		if player.force.name == teamName then
			mainTeamIndex = i
			break
		end
	end

	local xLimit = (Map.LaneWidth() / 2) - 1
	
	--have to subtract 1/256 or we get a rubber banding effect (1/256 is the minimal change in position, we could get away with any shift smaller than .03125 since that's the size of each pixel at 100% zoom)
	local newXWithOffset = xLimit - (1/256)

	if mainTeamIndex == 1 then
		if player.position.x > xLimit then
			player.print({"no-enemy-base-entry"})
			player.teleport({ x = newXWithOffset, y = player.position.y }, game.surfaces.nauvis)
		end
	else
		if player.position.x < -xLimit then
			player.print({"no-enemy-base-entry"})
			player.teleport({ x = -newXWithOffset, y = player.position.y }, game.surfaces.nauvis)
		end
	end
end

local function onRoundEnd()
	global.Data.GameState = GameStateEnum.Lobby
	
	Forces.OnRoundEnd()

	local lobbySurface = Lobby.GetLobbySurface()
	for _, player in ipairs(game.connected_players) do
		setPlayerToSpectator(player)
		player.teleport({1, 1}, lobbySurface)
		GUI.MakeLobbyGui(player)
	end
end

--https://lua-api.factorio.com/latest/events.html#on_entity_destroyed
local function on_entity_destroyed(event)
	--if we're not in the gameplay state
	if global.Data.GameState ~= GameStateEnum.Gameplay then
		--ignore since this is from clearing the surface after a round ends
		return
	end

	local teamName = Forces.GetTeamNameBySiloRegistrationNumber(event.registration_number)
	local force = game.forces[teamName]
	game.surfaces.nauvis.print(force.name .. " lost.")

	onRoundEnd()
end

--https://lua-api.factorio.com/latest/events.html#on_market_item_purchased
local function on_market_item_purchased(event)
	local player = game.players[event.player_index]

	util.insert_safe(player, {["assembling-machine-2"] = event.count})
end

--https://lua-api.factorio.com/latest/events.html#on_gui_click
local function on_gui_click(event)
	GUI.OnClick(event)
end

--https://lua-api.factorio.com/latest/events.html#on_gui_value_changed
local function on_gui_value_changed(event)
	GUI.OnValueChanged(event)
end

--https://lua-api.factorio.com/latest/events.html#on_gui_text_changed
local function on_gui_text_changed(event)
	GUI.OnTextChanged(event)
end
--https://lua-api.factorio.com/latest/events.html#on_player_removed
local function on_player_removed(event)
	global.playerData[event.player_index] = nil
end

local function on_gui_closed(event)
	if event.element and event.element.name == "ugg_main_frame" then
        local player = game.players[event.player_index]
        GUI.ToggleInterface(player)
    end
end

local function on_player_mined_entity(event)
	--if it's not an assembling machine
	if not (event.entity.name == "assembling-machine-1" or event.entity.name == "assembling-machine-2" or event.entity.name == "assembling-machine-3") then
		--ignore it
		return
	end

	local recipeName = event.entity.get_recipe().name
	local itemName = Constants.MapRecipeNameToItemName(recipeName)

	--if the item is the item used to indicate an empty assembler
	if itemName == Constants.EmptyAssemblerRecipe() then
		--don't do anything
		return
	end

	local player = game.players[event.player_index]
	util.insert_safe(player, {[itemName] = 1})
end

--this is just here to act as an interface with the game itself 
local voxWars = {}

--register all of the event handlers we use
voxWars.events =
{
	[defines.events.on_built_entity] = on_built_entity, --https://lua-api.factorio.com/latest/events.html#on_built_entity
	[defines.events.on_player_joined_game] = on_player_joined_game, --https://lua-api.factorio.com/latest/events.html#on_player_joined_game
	[defines.events.on_player_created] = on_player_created, --https://lua-api.factorio.com/latest/events.html#on_player_created
	[defines.events.on_gui_opened] = on_gui_opened, --https://lua-api.factorio.com/latest/events.html#on_gui_opened
	[defines.events.on_console_chat] = on_console_chat, --https://lua-api.factorio.com/latest/events.html#on_console_chat
	[defines.events.on_tick] = on_tick, --https://lua-api.factorio.com/latest/events.html#on_tick
	[defines.events.on_chunk_generated] = on_chunk_generated,
	[defines.events.on_surface_cleared] = on_surface_cleared,
	[defines.events.on_player_changed_position] = on_player_changed_position,
	[defines.events.on_entity_destroyed] = on_entity_destroyed, --https://lua-api.factorio.com/latest/events.html#on_entity_destroyed
	[defines.events.on_market_item_purchased] = on_market_item_purchased, --https://lua-api.factorio.com/latest/events.html#on_market_item_purchased
	[defines.events.on_gui_click] = on_gui_click, --https://lua-api.factorio.com/latest/events.html#on_gui_click
	[defines.events.on_gui_value_changed] = on_gui_value_changed, --https://lua-api.factorio.com/latest/events.html#on_gui_value_changed
	[defines.events.on_gui_text_changed] = on_gui_text_changed, --https://lua-api.factorio.com/latest/events.html#on_gui_text_changed
	[defines.events.on_player_removed] = on_player_removed, --https://lua-api.factorio.com/latest/events.html#on_player_removed
	[defines.events.on_gui_closed] = on_gui_closed, --https://lua-api.factorio.com/latest/events.html#on_gui_closed
	[defines.events.on_player_mined_entity] = on_player_mined_entity, --https://lua-api.factorio.com/latest/events.html#on_player_mined_entity
}



voxWars.on_init = function()
	--do initialize
	Init.Initialize()
end


voxWars.on_nth_tick =
{
  [5] = Map.ChartAll
}

--return our little interface so that the game can use it?
return voxWars