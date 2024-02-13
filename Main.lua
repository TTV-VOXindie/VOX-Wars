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


--https://lua-api.factorio.com/latest/events.html#on_player_joined_game
local function on_player_joined_game(event)
	local player = game.players[event.player_index]

	--ignore if it's not a valid player (idk how that would happen)
	if not (player and player.valid) then
		return
	end

	--set the player as a spectator
	player.spectator = true

	--if they are not on the player force, they have already picked a team this round
	if player.force.name ~= "player" then
		
		for _, other_player in pairs (game.connected_players) do
			--update_team_list_frame(other_player)
		end

		return
	end

	local character = player.character
	player.character = nil
	if character then 
		character.destroy()
	end

	player.set_controller{type = defines.controllers.spectator}
	player.teleport({1, 1}, Lobby.GetSurface())
end

--when a player is created https://lua-api.factorio.com/latest/events.html#on_player_created
local function on_player_created(event)
	local playerIndex = event.player_index
	local player = game.players[playerIndex]

	GUI.SetPlayerGui(player)

	-- local player = game.get_player(event.playerIndex)
    -- local anchor = {gui=defines.relative_gui_type.market_gui, position=defines.relative_gui_position.right}
    -- local frame = player.gui.relative.add{type="frame", anchor=anchor}
    -- frame.add{type="label", caption=player.name}

	--get the player by index
	local player = game.players[event.player_index]

	--TODO: make this not suck
	if global.Data.GameState == GameStateEnum.Running then
		local teamIndex = (event.player_index % 2) + 1

		--get the first team name
		local teamName = Constants.MainTeamNames()[teamIndex]

		--assign the player to the team
		player.force = teamName; --TODO: don't set force until GUI is up and running

		local surface = game.surfaces.nauvis
		local spawnPoint = player.force.get_spawn_position(surface)

		-- player.character = nil
		-- local character = surface.create_entity{name = "character", position = spawnPoint, force = player.force}
		-- player.show_on_map = true

		player.teleport(spawnPoint, surface)
		local message = "Player " .. player.name .. " was assigned to " .. teamName;

		--write a message
		player.print(message)
	end

	-- player.set_controller
	-- {
	-- 	type = defines.controllers.character,
	-- 	character = character
	-- }
	--player.color = get_color(team)
	--player.chat_color = get_color(team, true)

	player.set_quick_bar_slot(1, "assembling-machine-1")
	player.set_quick_bar_slot(2, "automation-science-pack")
	player.set_quick_bar_slot(3, "logistic-science-pack")
	player.set_quick_bar_slot(4, "military-science-pack")
	player.set_quick_bar_slot(5, "chemical-science-pack")
	player.set_quick_bar_slot(6, "production-science-pack")
	player.set_quick_bar_slot(7, "utility-science-pack")

	player.set_quick_bar_slot(11, "coin")
end

--when an entity is built https://lua-api.factorio.com/latest/events.html#on_built_entity
local on_built_entity = function(event)
	--if the entity is an assembler
	if event.created_entity.name == "assembling-machine-1" or event.created_entity.name == "assembling-machine-2" or event.created_entity.name == "assembling-machine-3" then
		--set the recipe
		event.created_entity.set_recipe("empty-barrel") --not setting this to something breaks our setup because the assembler gui won't open

		--red: "automation-science-pack"
		--green: "logistic-science-pack"
		--black: "military-science-pack"
		--blue: "chemical-science-pack"
		--purple: "production-science-pack"
		--yellow: "utility-science-pack"
		--(can't be used as a recipe) white: "space-science-pack"

		--don't let the player change the recipe
		event.created_entity.recipe_locked = true
	end
end

--https://lua-api.factorio.com/latest/events.html#on_gui_opened
local function on_gui_opened(event)

	-- if event.gui_type == defines.gui_type.entity and event.entity.type == "market" then
    --     local player = game.players[event.player_index]
    --     local custom_frame = player.gui.screen.add{type="frame", caption="Custom Market Interface"}
    --     player.opened = custom_frame
    -- end

	--get the player by index
	local player = game.players[event.player_index]

	if event.gui_type ~= defines.gui_type.entity then
		return	
	end	

	local entity = event.entity

	if entity.name ~= "assembling-machine-1" then
		return
	end

	local cursor_stack = player.cursor_stack

	if cursor_stack == nil or not cursor_stack.valid_for_read then
		return
	end
	
	--close the gui the player had open (so don't open the entity gui)
	player.opened = nil

	--get the current recipe in the assembler
	local currentRecipe = entity.get_recipe()

	--if there's already a recipe and it's the same as the one we're trying to assign
	if currentRecipe and currentRecipe.name == cursor_stack.name then
		--bail out
		return
	end

	--set the recipe to be what was in the player cursor
	entity.set_recipe(cursor_stack.name)

	--reduce the number of items in the stack
	cursor_stack.count = cursor_stack.count - 1

	--save spawner data
	global.Data.SpawnerData[#global.Data.SpawnerData + 1] =
	{
		shouldSpawn = true,
		spawner = entity,
		nextSpawnTick = 0	
	} 
end

--https://lua-api.factorio.com/latest/events.html#on_console_chat
local function on_console_chat(event)
	--get the player by index
	local player = game.players[event.player_index]
end

local function drawCircles()
	local firstTeamName = Constants.MainTeamNames()[1]
	local surface = game.surfaces.nauvis
	local entities = surface.find_units({
		area = {{-1000, -1000}, {1000, 1000}},
		force = firstTeamName,
		condition = "friend"
		})

	local force = game.forces[firstTeamName]

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

	for _, player in (pairs(game.players)) do
		rendering.draw_circle({
			color = force.color,
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
	if not spawnerData.shouldSpawn then
		return
	end

	if tick < spawnerData.nextSpawnTick then	
		return
	end

	if not spawnerData.spawner and not spawnerData.spawner.valid then
		game.surfaces.nauvis.print("yo dawg handle ur broken shit")
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

	--create spitter spawner at spawn https://lua-api.factorio.com/latest/classes/LuaEntity.html
	local entity = surface.create_entity({
		name = "small-biter", 
		position = {spawnerData.spawner.position.x + 1.5, spawnerData.spawner.position.y},
		force = biterForce
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
				destination = enemySilo.position,
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

	spawnerData.nextSpawnTick = tick + Constants.SpawnDelay()
end

local function handleSpawners(tick)

	for _, spawnerData in ipairs(global.Data.SpawnerData) do
		handleSpawner(tick, spawnerData)
	end
	
end

local function handleCoins(tick)
	if tick < global.Data.NextCoinTick then	
		return
	end

	for _, player in pairs(game.players) do
		util.insert_safe(player, {["coin"] = 1})
	end

	global.Data.NextCoinTick = tick + Constants.CoinDelayTicks()
end

--https://lua-api.factorio.com/latest/events.html#on_tick
local function on_tick(event)
	local tick = event.tick
	--TODO: check win con

	if global.Data.GameState == GameStateEnum.Running then
		drawCircles()
		handleSpawners(tick)
		handleCoins(tick)	
	end
end

--fire on ground as played moves
--on_event(defines.events.on_player_changed_position)
--player.surface.create_entity{name="fire-flame", position=player.position, force="neutral"}

local function on_chunk_generated(event)
	if global.Data.GameState == GameStateEnum.Running then
		Map.OnChunkGenerated(event)
	end
end

local function on_surface_cleared(event)
	if global.Data.GameState == GameStateEnum.Running then
		Map.OnSurfaceCleared(event)
	end
end

local function on_player_changed_position(event)
	--if the game state is not running
	if global.Data.GameState ~= GameStateEnum.Running then
		--we don't care about player position
		return
	end
	local player = game.players[event.player_index]

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

--https://lua-api.factorio.com/latest/events.html#on_entity_destroyed
local function on_entity_destroyed(event)
	local teamName = Forces.GetTeamNameBySiloRegistrationNumber(event.registration_number)
	local force = game.forces[teamName]


	game.surfaces.nauvis.print(event.registration_number .. " destroyed.")
	game.surfaces.nauvis.print(force.name .. " lost.")

	global.Data.GameState = GameStateEnum.Lobby
end
--https://lua-api.factorio.com/latest/events.html#on_market_item_purchased
local function on_market_item_purchased(event)
	local player = game.players[event.player_index]

	util.insert_safe(player, {["assembling-machine-1"] = 1})
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
	[defines.events.on_gui_closed] = on_gui_closed, --https://lua-api.factorio.com/latest/events.html#on_gui_closed\
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