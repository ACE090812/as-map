Map = {}


Map.state = {
    ready = false,
    playerLoaded = false,
    fullscreen = false,
    inventory = false,
    minimap = false,
    nativeMenu = false,
    pauseMenu = false,
    pauseMenuSettled = false,
    inspect = false,
    hostHidden = false,
}

function Map.setState(key, value)
    if Map.state[key] == value then
        return false
    end

    Map.state[key] = value

    if Map.focus then
        Map.focus.apply()
    end

    return true
end

function Map.isMinimapOnScreen()
    return Map.state.minimap
        and not Map.state.nativeMenu
        and not Map.state.inventory
        and (not Map.state.hostHidden or Map.state.inspect)
end

function Map.isAnySurfaceVisible()
    return Map.state.fullscreen or Map.isMinimapOnScreen() or Map.state.pauseMenu
end

local replaySteps = {}

function Map.onReplay(step)
    replaySteps[#replaySteps + 1] = step
end

function Map.runReplay()
    for index = 1, #replaySteps do
        local ok, err = pcall(replaySteps[index])

        if not ok then
            Map.log(('replay step %d failed: %s'):format(index, tostring(err)))
        end
    end
end

function Map.log(message)
end

function Map.debug(message)
end

function Map.isFiniteNumber(value)
    return type(value) == 'number'
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

function Map.isCoords(coords)
    local kind = type(coords)

    if kind ~= 'table' and kind ~= 'vector3' and kind ~= 'vector4' then
        return false
    end

    if not Map.isFiniteNumber(coords.x) or not Map.isFiniteNumber(coords.y) then
        return false
    end

    return coords.z == nil or Map.isFiniteNumber(coords.z)
end

function Map.toCoords(coords)
    if not Map.isCoords(coords) then
        return nil
    end

    return { x = coords.x, y = coords.y, z = coords.z }
end

function Map.isIntegerNumber(value)
    return Map.isFiniteNumber(value) and math.floor(value) == value
end

function Map.isId(id)
    return type(id) == 'string' and id ~= '' and #id <= 128
end
