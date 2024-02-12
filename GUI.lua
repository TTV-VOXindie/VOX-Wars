local Constants = require "Constants"
local Data = require "Data"
--object for exposing our public functions
local Public = {}

local set_team = function(playerIndex, team)
	--see if the player is already on a team
	local currentTeam = Data.team_players[playerIndex]

	--if the player is on a team
	if currentTeam then
		--remove the player from the team
	  currentTeam.members[playerIndex] = nil
	end

	--if we passed in a team
	if team then
		--assign the player to the team
		team.members[playerIndex] = game.players[playerIndex]
	  	Data.team_players[playerIndex] = team
	else
		--clear the player's team
		Data.team_players[playerIndex] = nil
	end

	--mark player as not ready since they just switched teams
	Data.ready_players[playerIndex] = nil
end
local function register_gui_action(gui, param)
	local gui_actions = Data.gui_actions
	local player_gui_actions = gui_actions[gui.player_index]
	
	if not player_gui_actions then
	  gui_actions[gui.player_index] = {}
	  player_gui_actions = gui_actions[gui.player_index]
	end

	player_gui_actions[gui.index] = param
end

local red = function(str)
	return "[color=1,0.2,0.2]"..str.."[/color]"
end
  
local green = function(str)
	return "[color=0.2,1,0.2]"..str.."[/color]"
end

local function addTeamFrame(team, flow, current_team, admin)
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
	local ready_data = Data.ready_players

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
	local teamSettingsTabContents = Data.elements.teamSettingsTabContents[player.index]

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

	local currentTeam = Data.team_players[player.index]

	local teamsFlow = teamsFrame.add({
		type = "flow",
		direction = "horizontal"
	})
  
	for _, team in pairs (Data.config.teams) do
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
		game.surfaces.nauvis.print("join team")
		updateTeamGui() --refresh_config() --update guis
		--check_all_ready() --start countdown for ready
	end,
	leaveTeam = function(event, param)
		set_team(event.player_index)
		game.surfaces.nauvis.print("leave team")
		updateTeamGui() --refresh_config() --update guis
		--check_all_ready() --start countdown for ready
	end,
}
local function build_sprite_buttons(player)
    local player_global = global.playerData[player.index]

    local button_table = player.gui.screen.ugg_main_frame.content_frame.contentFlow.button_frame.button_table
    button_table.clear()

    local number_of_buttons = player_global.button_count
	for i = 1, number_of_buttons do
        local sprite_name = item_sprites[i]
        local button_style = (sprite_name == player_global.selected_item) and "yellow_slot_button" or "recipe_slot_button"
        button_table.add{type="sprite-button", sprite=("item/" .. sprite_name), tags={action="ugg_select_button", item_name=sprite_name}, style=button_style}
    end
end

local function addMapSettingsTab(tabPane)
	--add tab
	local tab = tabPane.add({
		type = "tab", 
		caption = {"map-settings"}
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

	Data.elements.teamSettingsTabContents[player.index] = flow

	update_team_tab(player)
end

function Public.SetPlayerGui(player) --create_config)_gui
	
	--if the player is not valid and connected
	if not (player and player.valid and player.connected) then 

		--the gui won't be used
		return
	end

	local isPlayerAdmin = player.admin

	local playerData = global.playerData[player.index]

	--get reference to the screen
	local gui = player.gui.screen

	--add config window
	local configWindow = gui.add({
		type = "frame",
		caption = {"configuration-title"},
		direction = "vertical"
	})

	configWindow.style.vertically_stretchable = false

	--TODO: keep references
	--script_data.elements.config[player.index] = configWindow

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

	addMapSettingsTab(tabPane)

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
	--register_gui_action(start_button, {type = "start_round"})
	configWindow.auto_center = true

	if true then
		return
	end


	--set to screen
	local screen_element = player.gui.screen

	--make the main window
	local main_frame = screen_element.add{type="frame", name="ugg_main_frame", direction="vertical"}

	local title_flow = main_frame.add{type = "flow", direction = "horizontal"}
	title_flow.style.horizontally_stretchable = true
	title_flow.style.horizontal_spacing = 8
  
	local title_label = title_flow.add{type = "label", caption = {"scenario-name"}, style = "frame_title"}
	title_label.drag_target = main_frame
  
	local title_pusher = title_flow.add{type = "empty-widget", style = "draggable_space_header"}
	title_pusher.style.height = 24
	title_pusher.style.horizontally_stretchable = true
	title_pusher.drag_target = main_frame

	local title_close_button = title_flow.add{type = "sprite-button", style = "frame_action_button", sprite = "utility/close_white"}
	--register_gui_action(title_close_button, {type = "spectator_join_team_button"})

	--center it on screen
	main_frame.auto_center = true

	--
	player.opened = main_frame

	--make internal window for content
	local content_frame = main_frame.add{type="frame", name="content_frame", direction="vertical", style="inside_shallow_frame_with_padding"}

	local contentFlow = content_frame.add{type="flow", name="contentFlow", direction="vertical"}
	contentFlow.style.vertical_spacing = 12

	--make thing inside content frame
	local controls_flow = contentFlow.add{type="flow", name="controls_flow", direction="horizontal"}

	--add button
	local button_caption = (playerData.controls_active) and {"scenario-name"} or "activate"
	controls_flow.add{type="button", name="ugg_controls_toggle", caption=button_caption}

	local initial_button_count = playerData.button_count
    controls_flow.add{type="slider", name="ugg_controls_slider", value=initial_button_count, minimum_value=0, maximum_value=#item_sprites, style="notched_slider", enabled=playerData.controls_active}
    controls_flow.add{type="textfield", name="ugg_controls_textfield", text=tostring(initial_button_count), numeric=true, allow_decimal=false, allow_negative=false, enabled=playerData.controls_active}

    local button_frame = contentFlow.add{type="frame", name="button_frame", direction="horizontal", style="inside_shallow_frame_with_padding"}
    button_frame.add{type="table", name="button_table", column_count=#item_sprites, style="filter_slot_table"}
    build_sprite_buttons(player)
end

function Public.OnClick(event)
	local gui = event.element
	if not (gui and gui.valid) then
		return 
	end

	local player_gui_actions = Data.gui_actions[gui.player_index]
	
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
	if event.element.name == "ugg_controls_slider" then
        local player = game.players[event.player_index]
        local player_global = global.playerData[player.index]

        local new_button_count = event.element.slider_value
        player_global.button_count = new_button_count

        local controls_flow = player.gui.screen.ugg_main_frame.content_frame.contentFlow.controls_flow
        controls_flow.ugg_controls_textfield.text = tostring(new_button_count)

		build_sprite_buttons(player)
    end
end

function Public.OnTextChanged(event)
    if event.element.name == "ugg_controls_textfield" then
        local player = game.players[event.player_index]
        local player_global = global.playerData[player.index]

        local new_button_count = tonumber(event.element.text) or 0
        local capped_button_count = math.min(new_button_count, #item_sprites)
        player_global.button_count = capped_button_count

        local controls_flow = player.gui.screen.ugg_main_frame.content_frame.contentFlow.controls_flow
        controls_flow.ugg_controls_slider.slider_value = capped_button_count

		build_sprite_buttons(player)
    end
end


function Public.ToggleInterface(player)
    local main_frame = player.gui.screen.ugg_main_frame

    if main_frame == nil then
        Public.SetPlayerGui(player)
    else
        main_frame.destroy()
    end	
end

--return publicly facing functions
return Public