local Constants = require "Constants"
local GameStateEnum = require "GameStateEnum"
local Map = require "Map"

--object for exposing our public functions
local Public = {}

local set_team = function(playerIndex, team)
	--see if the player is already on a team
	local currentTeam = global.Data.team_players[playerIndex]

	--if the player is on a team
	if currentTeam then
		--remove the player from the team
	  currentTeam.members[playerIndex] = nil
	end

	--if we passed in a team
	if team then
		--assign the player to the team
		team.members[playerIndex] = game.players[playerIndex]
		global.Data.team_players[playerIndex] = team
	else
		--clear the player's team
		global.Data.team_players[playerIndex] = nil
	end

	--mark player as not ready since they just switched teams
	global.Data.ready_players[playerIndex] = nil
end

local function register_gui_action(gui, param)
	log("gui_actions")
	local gui_actions = global.Data.gui_actions
	log("player_gui_actions")
	local player_gui_actions = gui_actions[gui.player_index]
	
	log("if not player_gui_actions")
	if not player_gui_actions then
	  gui_actions[gui.player_index] = {}
	  player_gui_actions = gui_actions[gui.player_index]
	end

	log("player_gui_actions = param")
	player_gui_actions[gui.index] = param
end

local red = function(str)
	return "[color=1,0.2,0.2]"..str.."[/color]"
end
  
local green = function(str)
	return "[color=0.2,1,0.2]"..str.."[/color]"
end

local function addTeamFrame(team, flow, current_team, admin)
	log("in addTeamFrame")
	local teamFrame = flow.add({
		type = "frame",
		direction = "vertical",
		style = "bordered_frame"
	})

	teamFrame.style.padding = 12

	teamFrame.style.horizontally_stretchable = true

	local teamTitleFlow = teamFrame.add({
		type = "flow",
		direction = "horizontal"
	})
	teamTitleFlow.style.vertical_align = "center"

	local teamNameLabel = teamTitleFlow.add({
		type = "label",
		caption = team.name,
		style = "caption_label"
	})
	--teamNameLabel.style.font_color = get_color(team, true)

	local titlePusher = teamTitleFlow.add({
		type = "empty-widget"
	})

	titlePusher.style.horizontally_stretchable = true

	local player_count = 0
	if current_team == team then
		local leaveTeamButton = teamTitleFlow.add({
			type = "button",
			caption = {"leave"}
		})
		leaveTeamButton.style.font = "default"
		leaveTeamButton.style.height = 24
		leaveTeamButton.style.top_padding = 0
		leaveTeamButton.style.bottom_padding = 0
		log("register leave team")
		register_gui_action(leaveTeamButton, {type = "leaveTeam"})
	elseif player_count < Constants.MaxNumPlayersOnTeam() then
		local joinTeamButton = teamTitleFlow.add({
			type = "button",
			caption = {"join"}
		})

		joinTeamButton.style.font = "default"
		joinTeamButton.style.height = 24
		joinTeamButton.style.top_padding = 0
		joinTeamButton.style.bottom_padding = 0
		log("register join team")
		register_gui_action(joinTeamButton, {type = "joinTeam", team = team})
	end

	local teamLine = teamFrame.add({
		type = "line",
		direction = "horizontal"
	})

	local teamMemberTable = teamFrame.add({
		type = "table",
		column_count = 2
	})

	local teamMembersLabel = teamMemberTable.add({
		type = "label",
		caption = {"", {"members"}, {"colon"}},
		style = "description_label"
	})
  	teamMembersLabel.style.minimal_width = 150

	local membersText = ""
	local isFirstMember = true
	local ready_data = global.Data.ready_players

	log("member shit")
	for k, member in pairs(team.members or {}) do
		player_count = player_count + 1
		if isFirstMember then
			isFirstMember = false
		else
			membersText = membersText..", "
		end

		if ready_data[k] then
			membersText = membersText .. green(member.name)
		else
			membersText = membersText .. red(member.name)
		end
	end

	if membersText == "" then
		membersText = {"none"}
	end

	local label = teamMemberTable.add{type = "label", caption = membersText, style = "description_label"}
	label.style.single_line = false
	label.style.maximal_width = 400
	
end

local function update_team_tab(player)
	--cache if player is admin
	local isPlayerAdmin = player.admin

	--get the contents of the team tab
	local teamSettingsTabContents = global.Data.elements.teamSettingsTabContents[player.index]

	--if the contents are invalid, ignore
	if not (teamSettingsTabContents and teamSettingsTabContents.valid) then 
		return 
	end

	--clear the contents
	teamSettingsTabContents.clear()

	--add a frame
	local teamsFrame = teamSettingsTabContents.add({
		type = "frame",
		direction = "vertical",
		style = "borderless_frame"
	})

	teamsFrame.style.vertically_stretchable = true
	teamsFrame.style.horizontally_stretchable = true

	local currentTeam = global.Data.team_players[player.index]

	local teamsFlow = teamsFrame.add({
		type = "flow",
		direction = "horizontal"
	})
  
	for _, team in pairs (global.Data.config.teams) do
	  addTeamFrame(team, teamsFlow, currentTeam, isPlayerAdmin)
	end
end

local function updateTeamGui()
	for _, player in pairs (game.connected_players) do
		update_team_tab(player)
	end
end

local guiFunctions =
{
	joinTeam = function(event, param)
		set_team(event.player_index, param.team)
		updateTeamGui() --refresh_config() --update guis
		--check_all_ready() --start countdown for ready
	end,
	leaveTeam = function(event, param)
		set_team(event.player_index)
		updateTeamGui() --refresh_config() --update guis
		--check_all_ready() --start countdown for ready
	end,
	startRound = function (event, param)
		if global.Data.GameState ~= GameStateEnum.Lobby then
			return	
		end

		--TODO: should probably move this shit somewhere

		Map.SetupForRound()

		local surface = game.surfaces.nauvis

		global.Data.GameState = GameStateEnum.Gameplay
		for _, player in pairs (game.connected_players) do

			local team = global.Data.team_players[player.index]

			if team then
				player.spectator = false
				player.show_on_map = true
				player.force = team.name
			end

			local desiredSpawnPosition = player.force.get_spawn_position(surface)
			local spawnPosition = surface.find_non_colliding_position("character", desiredSpawnPosition, 1, .25)
			player.teleport(spawnPosition, surface)

			if team then
				player.character = nil
				local character = surface.create_entity({name = "character", position = spawnPosition, force = player.force})
				player.set_controller
				{
					type = defines.controllers.character,
					character = character
				}
				player.show_on_map = true

				player.print({"you-were-assigned-to", team.name})
				player.print({"shout-reminder", {"spectators-and-other-teams"}})
			else
				player.print({"you-were-assigned-to", {"spectator"}})
				player.print({"shout-reminder", {"players-not-spectating"}})
			end

			--destroy the lobby gui
			global.Data.elements.config[player.index].destroy()
		end
	end
}

local function addTeamSettingsTab(tabPane)
	--add tab
	local tab = tabPane.add({
		type = "tab", 
		caption = {"team-settings"}
	})

	--add flow
	local flow = tabPane.add({
		type = "flow"
	})

	flow.style.left_padding = 5
	flow.style.right_padding = 5

	--add tab and flow to tab pane
	tabPane.add_tab(tab, flow)

	--get player
	local player = game.players[tabPane.player_index]

	global.Data.elements.teamSettingsTabContents[player.index] = flow

	update_team_tab(player)
end

function Public.MakeLobbyGui(player)
	--if the player is not valid and connected
	if not (player and player.valid and player.connected) then 
		--the gui won't be used
		return
	end

	local isPlayerAdmin = player.admin

	--get reference to the screen
	local gui = player.gui.screen

	--add config window
	local configWindow = gui.add({
		type = "frame",
		caption = {"configuration-title"},
		direction = "vertical"
	})

	configWindow.style.vertically_stretchable = false

	global.Data.elements.config[player.index] = configWindow

	--add deep frame for tabs
	local deepFrame = configWindow.add({
		type = "frame",
		style = "inside_deep_frame_for_tabs",
		direction = "vertical"
	})

	--add tab pane
	local tabPane = deepFrame.add({
		type = "tabbed-pane"
	})

	tabPane.style.horizontally_stretchable = true
	tabPane.selected_tab_index = 1
	tabPane.style.maximal_height = 1080 * 0.8

	addTeamSettingsTab(tabPane)

	local footer = configWindow.add({
		type = "flow",
		style = "dialog_buttons_horizontal_flow"
	})

	footer.style.vertical_align = "center"

	local footerPusher = footer.add({
		type = "empty-widget",
		style = "draggable_space_with_no_left_margin"
	})

	footerPusher.style.horizontally_stretchable = true
	footerPusher.style.vertically_stretchable = true
	footerPusher.drag_target = configWindow

	local ready = false --script_data.ready_players[player.index] or false
	local readyCheckbox = footer.add({
		type = "checkbox",
		caption = {"ready"},
		state = ready
	})
	readyCheckbox.style.right_padding = 8
  
	--register_gui_action(readyCheckbox, {type = "ready_up"})
	local startButton = footer.add({
		type = "button",
		style = "confirm_button",
		caption = {"start-round"},
		enabled = isPlayerAdmin
	})

	startButton.style.minimal_width = 250
	register_gui_action(startButton, {type = "startRound"})
	configWindow.auto_center = true
end

function Public.OnClick(event)
	local gui = event.element
	if not (gui and gui.valid) then
		return 
	end

	local player_gui_actions = global.Data.gui_actions[gui.player_index]
	
	--if the player doesn't have registered actions
	if not player_gui_actions then
		--ignore
		return
	end

	--get the registered actions
	local action = player_gui_actions[gui.index]

	if action then
		guiFunctions[action.type](event, action)
		return true
	end	  
end

function Public.OnValueChanged(event)
	
end

function Public.OnTextChanged(event)
    
end


function Public.ToggleInterface(player)
    local main_frame = player.gui.screen.ugg_main_frame

    if main_frame == nil then
        Public.MakeLobbyGui(player)
    else
        main_frame.destroy()
    end	
end

--return publicly facing functions
return Public