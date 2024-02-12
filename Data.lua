local Public =
{
  gui_actions = {},
  team_players = {},
  elements =
  {
    config = {},
    balance = {},
    import = {},
    admin = {},
    admin_button = {},
    spectate_button = {},
    join = {},
    progress_bar = {},
    team_frame = {},
    team_list_button = {},
    production_score_frame = {},
    production_score_inner_frame = {},
    recipe_frame = {},
    recipe_button = {},
    inventory = {},
    space_race_frame = {},
    kill_score_frame = {},
    oil_harvest_frame = {},
    teamSettingsTabContents = {},
    game_tab = {}
  },
  setup_finished = false,
  ready_players = {},
  config = 
  {
    teams = {}
  },
  round_number = 0,
  selected_recipe = {},
  random = nil,
  team_names = {}
}

return Public