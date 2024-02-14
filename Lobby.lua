
--object for exposing public interface
local Public = {}

local _lobbySurfaceName = "Lobby"
function Public.Initialize()
    --create lobby surface
    local surface = game.create_surface(_lobbySurfaceName, {width = 1, height = 1})

    --set the one tile as out-of-map
    surface.set_tiles({{name = "out-of-map", position = {1,1}}})

    --return the newly created lobby suface
    return surface
end

function Public.GetLobbySurface()
    return game.surfaces[_lobbySurfaceName]
end

--return public interface
return Public