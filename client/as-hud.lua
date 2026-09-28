-- Which HUD resource frames the minimap. Set MapConfig.hostHud in config.lua
-- to force one; otherwise the first of these that is running wins (checked
-- in order, so a newer HUD takes priority over the older one).
local HOST_CANDIDATES = { MapConfig and MapConfig.hostHud, 'karma-hud-v', 'as-hud' }

local HOST = nil

local function resolveHost()
    if HOST and GetResourceState(HOST) == 'started' then
        return HOST
    end

    HOST = nil

    for _, name in ipairs(HOST_CANDIDATES) do
        if type(name) == 'string' and name ~= '' and GetResourceState(name) == 'started' then
            HOST = name
            break
        end
    end

    return HOST
end

local hostVisible = nil

local function toPixels(layout)
    if type(layout) ~= 'table' then
        return nil
    end

    local width, height = GetActiveScreenResolution()

    if not width or not height or width <= 0 or height <= 0 then
        return nil
    end

    local left, top = tonumber(layout.left), tonumber(layout.top)
    local w, h = tonumber(layout.width), tonumber(layout.height)

    if not left or not top or not w or not h then
        return nil
    end

    return {
        x = left * width,
        y = top * height,
        width = w * width,
        height = h * height,
    }
end

local function applyLayout(layout)
    local frame = toPixels(layout)

    if frame then
        Map.minimapStyle.setHostFrame(frame)
    end
end

local function applyVisible(visible)
    hostVisible = visible == true
    Map.surface.setHostHidden(not hostVisible)
end

local function pull()
    local host = resolveHost()

    if not host then
        return
    end

    local ok, layout = pcall(function()
        return exports[host]:GetRadarLayout()
    end)

    if ok and layout then
        applyLayout(layout)
    end

    local okVisible, visible = pcall(function()
        return exports[host]:IsRadarVisible()
    end)

    if okVisible and visible ~= nil then
        applyVisible(visible)
    end
end

AddEventHandler('as-hud:radarLayout', applyLayout)
AddEventHandler('as-hud:radarVisible', applyVisible)

AddEventHandler('onClientResourceStart', function(name)
    for _, candidate in ipairs(HOST_CANDIDATES) do
        if name == candidate then
            CreateThread(function()
                Wait(1000)
                pull()
            end)
            break
        end
    end
end)

AddEventHandler('onClientResourceStop', function(name)
    if name ~= HOST then
        return
    end

    HOST = nil
    hostVisible = nil
    Map.surface.setHostHidden(false)
    Map.minimapStyle.setHostFrame(nil)

    -- another candidate (e.g. the older as-hud) might still be running
    CreateThread(function()
        Wait(0)
        pull()
    end)
end)

Map.onReplay(pull)

CreateThread(function()
    Wait(1500)
    pull()
end)
