local GameStateEnum = require "GameStateEnum"

local Public = {}

local data =
{
  GameState = GameStateEnum.Lobby,
  SpawnerData = {},
  CoinRate = 60 / 10, --10 per second
	NextCoinTick = 0,
  SpawnRate = 30 * 60, --30 seconds
  NextSpawnTick = 0,
  UnitRecipes = 
  {
		["automation-science-pack"] =
    {
      unitName = "small-biter",
      price = 100
    },
		["logistic-science-pack"] =
    {
      unitName = "medium-biter",
      price = 200
    },
    ["military-science-pack"] =
    {
      unitName = "big-biter",
      price = 400
    },
    ["chemical-science-pack"] =
    {
      unitName = "behemoth-biter",
      price = 800
    },
    ["heavy-oil-barrel"] =
    {
      unitName = "small-spitter",
      price = 200,
      recipeNameForAssembler = "fill-heavy-oil-barrel"
    },
    ["lubricant-barrel"] =
    {
      unitName = "medium-spitter",
      price = 400,
      recipeNameForAssembler = "fill-lubricant-barrel"
    },
    ["crude-oil-barrel"] =
    {
      unitName = "big-spitter",
      price = 800,
      recipeNameForAssembler = "fill-crude-oil-barrel"
    },
    ["water-barrel"] =
    {
      unitName = "behemoth-spitter",
      price = 1600,
      recipeNameForAssembler = "fill-water-barrel"
    }
  },

  TurretRecipes = --TODO: make this valid
  {
    ["iron-plate"] =
    {
      unitName = "small-worm-turret",
      price = 1,
      spawnRate = 1 * 60 --1 second
    },
    ["copper-plate"] =
    {
      unitName = "medium-worm-turret",
      price = 2,
      spawnRate = 1 * 60 --1 second
    },
    ["steel-plate"] =
    {
      unitName = "big-worm-turret",
      price = 3,
      spawnRate = 1 * 60 --1 second
    },
    ["sulfur"] =
    {
      unitName = "behemoth-worm-turret",
      price = 4,
      spawnRate = 1 * 60 --1 second
    }
  },

  MapSettings = {
    BaseWidth = 75,
    BaseHeightPadding = 10,
    LaneWidth = 200,
    LaneHeight = 20,
    LaneSpacing = 20,
    NumLanes = 2
  },

  playerData = {},

	forces = {},
	teamNameBySiloRegistrationNumber = {},



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

function Public.Initialize()
  global.Data = data
end

return Public