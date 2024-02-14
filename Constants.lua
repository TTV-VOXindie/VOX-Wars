--collection of values that will be used throughout our scripts

--object for exposing our public things
local Public = {}

function Public.EmptyAssemblerRecipe()
	return "empty-barrel"
end

function Public.MainTeamNames()
	return {
		"Team 1",
		"Team 2"
	}
end

function Public.TeamColors()
	return {
		{ 
			r = 1,
			g = 0,
			b = 0,
			a = 1
		},
		{ 
			r = 0,
			g = .2,
			b = 1,
			a = 1
		},
	}
end

function Public.MaxNumPlayersOnTeam()
	return 10
end

local _itemNameToRecipeName =
{
	["heavy-oil-barrel"] = "fill-heavy-oil-barrel",
	["lubricant-barrel"] = "fill-lubricant-barrel",
	["crude-oil-barrel"] = "fill-crude-oil-barrel",
	["water-barrel"] = "fill-water-barrel",
}

local _recipeNameToItemName = {}

function  Public.MapItemNameToRecipeName(itemName)
	return _itemNameToRecipeName[itemName] or itemName
end

function  Public.MapRecipeNameToItemName(recipeName)
	return _recipeNameToItemName[recipeName] or recipeName
end

function Public.Initialize()
	for itemName, recipeName in pairs(_itemNameToRecipeName) do
		_recipeNameToItemName[recipeName] = itemName
	end
end

--return publicly facing things
return Public