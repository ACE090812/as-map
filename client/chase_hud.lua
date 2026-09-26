local HOST = 'as-hud'

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
    if GetResourceState(HOST) ~= 'started' then
        return
    end

    local ok, layout = pcall(function()
        return exports[HOST]:GetRadarLayout()
    end)

    if ok and layout then
        applyLayout(layout)
    end

    local okVisible, visible = pcall(function()
        return exports[HOST]:IsRadarVisible()
    end)

    if okVisible and visible ~= nil then
        applyVisible(visible)
    end
end

AddEventHandler('as-hud:radarLayout', applyLayout)
AddEventHandler('as-hud:radarVisible', applyVisible)

AddEventHandler('onClientResourceStart', function(name)
    if name == HOST then
        CreateThread(function()
            Wait(1000)
            pull()
        end)
    end
end)

AddEventHandler('onClientResourceStop', function(name)
    if name ~= HOST then
        return
    end

    hostVisible = nil
    Map.surface.setHostHidden(false)
    Map.minimapStyle.setHostFrame(nil)
end)

Map.onReplay(pull)

CreateThread(function()
    Wait(1500)
    pull()
end)
