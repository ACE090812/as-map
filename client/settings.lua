Map.settings = {}

local KVP_KEY = 'as-map:settings'

local MAX_SETTINGS_BYTES = 8192

local stored = nil

local function load()
    local raw = GetResourceKvpString(KVP_KEY)

    if type(raw) ~= 'string' or raw == '' then
        return
    end

    if #raw > MAX_SETTINGS_BYTES then
        Map.log(('stored settings are %d bytes, over the %d cap; discarding')
            :format(#raw, MAX_SETTINGS_BYTES))
        DeleteResourceKvp(KVP_KEY)

        return
    end

    local ok, decoded = pcall(json.decode, raw)

    if not ok or type(decoded) ~= 'table' then
        Map.log('stored settings are not valid JSON; discarding')
        DeleteResourceKvp(KVP_KEY)

        return
    end

    stored = raw
end

load()

RegisterNUICallback('map:settingsChanged', function(data, cb)
    local raw = type(data) == 'table' and data.json or nil

    if type(raw) ~= 'string' or raw == '' or #raw > MAX_SETTINGS_BYTES then
        Map.debug('settings rejected: payload is not a JSON string within the cap')
        cb({})

        return
    end

    local ok, decoded = pcall(json.decode, raw)

    if not ok or type(decoded) ~= 'table' then
        Map.debug('settings rejected: payload is not a JSON object')
        cb({})

        return
    end

    if raw == stored then
        cb({})

        return
    end

    stored = raw
    SetResourceKvp(KVP_KEY, raw)
    Map.debug(('settings saved (%d bytes)'):format(#raw))

    cb({})
end)

function Map.settings.get()
    if not stored then
        return nil
    end

    local ok, decoded = pcall(json.decode, stored)

    return ok and decoded or nil
end

local function defaultDimension()
    local dimension = Map.config.defaults and Map.config.defaults.dimension

    if dimension == '3d' or dimension == '2d' then
        return dimension
    end

    return '2d'
end

local function resolveDimension(value)
    if not Map.config.dimension3dEnabled then
        return '2d'
    end

    if value == '3d' or value == '2d' then
        return value
    end

    return defaultDimension()
end

function Map.settings.getDimensions()
    local settings = Map.settings.get() or {}

    return {
        dimension3dEnabled = Map.config.dimension3dEnabled == true,
        fullscreen = resolveDimension(settings.fullscreenMode),
        minimap = resolveDimension(settings.minimapMode),
    }
end

function Map.settings.setDimension(surface, dimension)
    if surface ~= 'minimap' and surface ~= 'fullscreen' then
        return false
    end

    dimension = resolveDimension(dimension)

    local settings = Map.settings.get()

    if type(settings) ~= 'table' then
        settings = {}
        local defaults = Map.config.defaults

        if type(defaults) == 'table' then
            settings.accent = defaults.accent
            settings.mapStyle = defaults.style
            settings.fullscreenMode = defaultDimension()
            settings.minimapMode = defaultDimension()
        end
    end

    if surface == 'minimap' then
        settings.minimapMode = dimension
    else
        settings.fullscreenMode = dimension
    end

    local raw = json.encode(settings)

    if type(raw) == 'string' and raw ~= '' and #raw <= MAX_SETTINGS_BYTES then
        stored = raw
        SetResourceKvp(KVP_KEY, raw)
    end

    Map.send({
        type = 'map:settings',
        settings = settings,
    })

    return true
end

function Map.settings.clear()
    stored = nil
    DeleteResourceKvp(KVP_KEY)
end

local function sendDefaults()
    local defaults = Map.config.defaults

    if not defaults.accent and not defaults.dimension and not defaults.style then
        return
    end

    Map.send({
        type = 'map:defaults',
        accent = defaults.accent,
        dimension = defaults.dimension,
        style = defaults.style,
    })
end

Map.onReplay(function()
    Map.send({
        type = 'map:dimension3d',
        enabled = Map.config.dimension3dEnabled,
    })

    Map.send({
        type = 'map:units',
        units = Map.config.units,
    })

    local settings = Map.settings.get()

    if not settings then
        sendDefaults()

        return
    end

    Map.send({
        type = 'map:settings',
        settings = settings,
    })
end)
