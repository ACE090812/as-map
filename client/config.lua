Map.config = {
    updateIntervalMs = 100,

    idleIntervalMs = 250,

    minimapEnabled = true,

    dimension3dEnabled = true,

    units = 'imperial',

    inspectEnabled = true,

    inspectKey = 'M',

    inspectHoldMs = 250,

    pauseMenuFocusTimeoutMs = 1500,

    identity = {
        pollIntervalMs = 1000,
    },

    mugshot = {
        enabled = true,

        transparent = true,

        pollIntervalMs = 2000,

        pendingIntervalMs = 250,

        readyTimeoutMs = 2000,

        releaseGraceMs = 1000,
    },

    route = {
        enabled = true,

        watchIntervalMs = 500,

        pendingRetryMs = 10,

        pendingTimeoutMs = 1000,

        minRebuildIntervalMs = 1000,

        destinationEpsilon = 1.0,

        teleportDistance = 200.0,

        sampleStepMetres = 20.0,

        maxPoints = 1500,

        maxSampleDistance = 30000.0,

        yieldEverySamples = 100,

        onFootWorkaround = true,

        onFootRouteColour = 6,

        deleteNativeWaypointOnFoot = false,
    },

    nativeBlips = {
        enabled = true,

        scanIntervalMs = 1000,

        moveIntervalMs = 100,

        yieldEverySprites = 100,

        maxSpriteId = 900,

        skipPlayerBlip = true,

        skipWaypoint = true,

        skipShortRange = false,

        skipTransparent = false,

        areasEnabled = true,

        circleSegments = 48,
    },

    radarEnforceIntervalMs = 100,
}

local function warn(message)
    print(('[%s] config: %s'):format(GetCurrentResourceName(), message))
end

local function typed(path, value, kind, fallback)
    if value == nil then
        return fallback
    end

    if type(value) ~= kind then
        warn(('%s must be a %s, got %s -- keeping the default (%s)')
            :format(path, kind, type(value), tostring(fallback)))

        return fallback
    end

    return value
end

local function oneOf(path, value, allowed, names, fallback)
    if value == nil then
        return fallback
    end

    if type(value) ~= 'string' or not allowed[value] then
        warn(('%s is %s, which is not one of: %s -- keeping the default')
            :format(path, tostring(value), names))

        return fallback
    end

    return value
end

local function key(path, value, fallback)
    local name = typed(path, value, 'string', fallback)

    if name == '' then
        warn(('%s is empty -- keeping the default (%s)'):format(path, fallback))

        return fallback
    end

    return name
end

local MAP_STYLES = { game = true, print = true, render = true }
local MAP_UNITS = { imperial = true, metric = true }
local MAP_DIMENSIONS = { ['2d'] = true, ['3d'] = true }
local MAP_ACCENTS = {
    red = true, orange = true, amber = true, yellow = true, lime = true,
    green = true, emerald = true, teal = true, cyan = true, sky = true,
    blue = true, indigo = true, violet = true, purple = true, fuchsia = true,
    pink = true, rose = true,
}

local ACCENT_NAMES =
    'red, orange, amber, yellow, lime, green, emerald, teal, cyan, sky, ' ..
    'blue, indigo, violet, purple, fuchsia, pink, rose'

Map.config.defaults = {
    accent = nil,
    dimension = nil,
    style = nil,
}

do
    local owner = rawget(_G, 'MapConfig')

    if owner == nil then
        owner = {}
    elseif type(owner) ~= 'table' then
        warn('config.lua did not define a MapConfig table -- ignoring it')

        owner = {}
    end

    local config = Map.config

    config.inspectKey = key('inspectKey', owner.inspectKey, config.inspectKey)
    config.inspectHoldMs =
        typed('inspectHoldMs', owner.inspectHoldMs, 'number', config.inspectHoldMs)

    config.inspectEnabled =
        typed('inspectEnabled', owner.inspectEnabled, 'boolean', config.inspectEnabled)
    config.minimapEnabled =
        typed('minimapEnabled', owner.minimapEnabled, 'boolean', config.minimapEnabled)
    config.dimension3dEnabled = typed(
        'dimension3dEnabled', owner.dimension3dEnabled, 'boolean',
        config.dimension3dEnabled
    )
    config.units =
        oneOf('units', owner.units, MAP_UNITS, 'imperial, metric', config.units)

    local defaults = typed('defaults', owner.defaults, 'table', nil)

    if defaults then
        config.defaults.style =
            oneOf('defaults.style', defaults.style, MAP_STYLES, 'game, print, render', nil)
        config.defaults.dimension =
            oneOf('defaults.dimension', defaults.dimension, MAP_DIMENSIONS, '2d, 3d', nil)

        if config.defaults.dimension == '3d' and not config.dimension3dEnabled then
            warn('defaults.dimension is 3d but dimension3dEnabled is false ' ..
                '-- the map will start in 2d')

            config.defaults.dimension = nil
        end
        config.defaults.accent =
            oneOf('defaults.accent', defaults.accent, MAP_ACCENTS, ACCENT_NAMES, nil)
    end
end
