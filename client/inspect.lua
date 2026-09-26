Map.inspect = {}

local DISABLED_CONTROLS = {
    1,
    2,
    14,
    15,
    19,
    24,
    25,
    37,
    68,
    69,
    70,
    99,
    100,
    106,
    142,
    257,
    263,
    264,
}

local function canInspect()
    return Map.config.inspectEnabled
        and Map.state.ready
        and Map.state.playerLoaded
        and Map.isMinimapOnScreen()
        and not Map.state.fullscreen
        and not Map.state.pauseMenu
end

local function suppressControls()
    CreateThread(function()
        while Map.state.inspect do
            if not canInspect() then
                Map.inspect.stop()
                break
            end

            for index = 1, #DISABLED_CONTROLS do
                DisableControlAction(0, DISABLED_CONTROLS[index], true)
            end

            Wait(0)
        end
    end)
end

function Map.inspect.start()
    if Map.state.inspect or not canInspect() then
        return
    end

    Map.setState('inspect', true)

    Map.send({
        type = 'minimap:inspect',
        active = true,
    })

    suppressControls()
    Map.surface.publishMinimapRect()
end

function Map.inspect.stop()
    if not Map.setState('inspect', false) then
        return
    end

    Map.send({
        type = 'minimap:inspect',
        active = false,
    })

    Map.surface.publishMinimapRect()
end

RegisterNUICallback('map:minimapInspectEnded', function(_, cb)
    Map.inspect.stop()
    cb({})
end)

local HOLD_MIN_MS = 50
local HOLD_MAX_MS = 2000

local function holdMs()
    local ms = Map.config.inspectHoldMs

    if type(ms) ~= 'number' then
        return 250
    end

    if ms < HOLD_MIN_MS then
        return HOLD_MIN_MS
    end

    if ms > HOLD_MAX_MS then
        return HOLD_MAX_MS
    end

    return math.floor(ms)
end

local pressAt = nil
local held = false

RegisterCommand('+nobitMapInspect', function()
    pressAt = GetGameTimer()
    held = false

    CreateThread(function()
        local started = pressAt

        Wait(holdMs())

        if pressAt ~= started then
            return
        end

        if not canInspect() then
            return
        end

        held = true
        Map.inspect.start()
    end)
end, false)

RegisterCommand('-nobitMapInspect', function()
    pressAt = nil

    if held or Map.state.inspect then
        Map.inspect.stop()
        held = false
        return
    end

    if Map.state.pauseMenu or not Map.state.playerLoaded then
        return
    end

    Map.surface.toggleFullscreen()
end, false)

RegisterKeyMapping(
    '+nobitMapInspect',
    'Open map (hold to inspect)',
    'keyboard',
    Map.config.inspectKey
)
