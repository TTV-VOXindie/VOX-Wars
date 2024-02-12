
--object for exposing public interface
local Public = {}

local _lobbySurfaceName = "Lobby"
function Public.GetSurface()

    --if the lobby surface is already created
    if game.surfaces[_lobbySurfaceName] then 
        --return the lobby surface
        return game.surfaces[_lobbySurfaceName] 
    end

    --create lobby surface
    local surface = game.create_surface(_lobbySurfaceName, {width = 1, height = 1})

    --set the one tile as out-of-map
    surface.set_tiles({{name = "out-of-map", position = {1,1}}})

    --return the newly created lobby suface
    return surface
end

--return public interface
return Public