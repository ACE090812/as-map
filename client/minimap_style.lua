Map.minimapStyle = {}

local PERCENT = 100.0

local function screen()
    local width, height = GetActiveScreenResolution()

    if not Map.isFiniteNumber(width) or not Map.isFiniteNumber(height)
        or width <= 0 or height <= 0 then
        return 16.0, 1920.0, 1080.0
    end

    return math.min(width, height) / 67.5, width + 0.0, height + 0.0
end

local AXIS = { left = 'x', width = 'x', bottom = 'y', height = 'y' }

local function edgeToRem(percent, axis)
    local pxPerRem, screenWidth, screenHeight = screen()
    local edge = axis == 'x' and screenWidth or screenHeight

    return (percent / PERCENT) * edge / pxPerRem
end

local function edgeFromRem(rem, axis)
    local pxPerRem, screenWidth, screenHeight = screen()
    local edge = axis == 'x' and screenWidth or screenHeight

    return (rem * pxPerRem) / edge * PERCENT
end

local DECORATION_MAX = {
    borderWidth = 0.75,
    shadowBlur = 4,
    shadowSpread = 2,
    shadowOffsetX = 2,
    shadowOffsetY = 2,
}

local FIELDS = {
    left = 'edge',
    bottom = 'edge',
    width = 'edge',
    height = 'edge',
    borderWidth = 'decoration',
    shadowBlur = 'decoration',
    shadowSpread = 'decoration',
    shadowOffsetX = 'decoration',
    shadowOffsetY = 'decoration',
    cornerRadius = 'fraction',
    borderAlpha = 'fraction',
    shadowAlpha = 'fraction',
    borderColor = 'color',
    shadowColor = 'color',
}

local PIN_TOP_RIGHT = 'top-right'
local DEFAULT_INSETS = { right = 1.5, top = 2.375 }
-- ox_lib `--rs-hud-edge-padding`: 1.5rem of unscaled 16px html.
local NOTIFY_EDGE_PX = 24.0
local FRAME_ASPECT = 11.896 / 16.875
local INSPECT_BOX_SCALE = 1.8
local STACK_GAP_REM = 0.5

local DEFAULT_APPEARANCE = {
    left = 0,
    bottom = 0,
    pin = PIN_TOP_RIGHT,
    width = 16.875,
    height = 11.896,
    borderWidth = 0,
    borderColor = '#ffffff',
    borderAlpha = 1,
    cornerRadius = 0,
    shadowBlur = 0,
    shadowSpread = 0,
    shadowOffsetX = 0,
    shadowOffsetY = 0,
    shadowColor = '#000000',
    shadowAlpha = 0.5,
}

local PAGE_LIMITS = {
    left = { min = 0, max = 480 },
    bottom = { min = 0, max = 320 },
    width = { min = 8, max = 60 },
    height = { min = 6, max = 40 },
}

local function hudUiScale(screenWidth, screenHeight)
    local scale = math.min(screenWidth / 1920.0, screenHeight / 1080.0)

    if scale < 0.5 then
        return 0.5
    end

    if scale > 2.5 then
        return 2.5
    end

    return scale
end

local function notifyWidthPx()
    local _, screenWidth, screenHeight = screen()
    local rem = 16.0 * hudUiScale(screenWidth, screenHeight)

    return 1.5 * rem
        + 2 * (34.0 + 0.625 * rem + 0.0417 * screenWidth)
        + 2 * (0.625 * rem)
        + 1.0
end

local function notifyWidthRem()
    local pxPerRem = screen()

    return notifyWidthPx() / pxPerRem
end

local function applyTopRightPin(appearance)
    local pxPerRem, screenWidth, screenHeight = screen()
    local width = appearance.width or DEFAULT_APPEARANCE.width
    local height = appearance.height or DEFAULT_APPEARANCE.height
    local rightRem = NOTIFY_EDGE_PX / pxPerRem

    appearance.left = math.max(0, screenWidth / pxPerRem - width - rightRem)
    appearance.bottom = math.max(0, screenHeight / pxPerRem - height - DEFAULT_INSETS.top)
end

local function applyForcedFrame(appearance)
    local width = notifyWidthRem()

    appearance.width = width
    appearance.height = width * FRAME_ASPECT
    appearance.pin = PIN_TOP_RIGHT
    applyTopRightPin(appearance)
end

local PERCENT_LIMITS = {
    borderWidth = { min = 0, max = 100 },
    shadowBlur = { min = 0, max = 100 },
    shadowSpread = { min = -50, max = 100 },
    shadowOffsetX = { min = -100, max = 100 },
    shadowOffsetY = { min = -100, max = 100 },
    cornerRadius = { min = 0, max = 100 },
    borderAlpha = { min = 0, max = 100 },
    shadowAlpha = { min = 0, max = 100 },
}

local function warnOutOfRange(key, percent, kind)
    local limit = PERCENT_LIMITS[key]

    if kind == 'edge' then
        local page = PAGE_LIMITS[key]
        local axis = AXIS[key]

        limit = {
            min = edgeFromRem(page.min, axis),
            max = edgeFromRem(page.max, axis),
        }
    end

    if not limit then
        return
    end

    if percent < limit.min then
        Map.log(('minimap style: %s is %.4g%%, below the minimum %.4g%%; ' ..
            'it will be clamped'):format(key, percent, limit.min))
    elseif percent > limit.max then
        Map.log(('minimap style: %s is %.4g%%, above the maximum %.4g%%; ' ..
            'it will be clamped'):format(key, percent, limit.max))
    end
end

local function toPage(key, kind, percent)
    if kind == 'edge' then
        return edgeToRem(percent, AXIS[key])
    elseif kind == 'decoration' then
        return (percent / PERCENT) * DECORATION_MAX[key]
    end

    return percent / PERCENT
end

local function fromPage(key, kind, value)
    if kind == 'edge' then
        return edgeFromRem(value, AXIS[key])
    elseif kind == 'decoration' then
        return (value / DECORATION_MAX[key]) * PERCENT
    end

    return value * PERCENT
end

local function isHexColor(value)
    return type(value) == 'string' and value:match('^#%x%x%x%x%x%x$') ~= nil
end

local pending = nil

--- Screen-pixel rect supplied by a host HUD (as-hud). When set, the
--- minimap is drawn as a circle inside it instead of the top-right frame.
local hostFrame = nil

local function commit(style, reset)
    local appearance = {}
    local count = 0

    if style ~= nil then
        if type(style) ~= 'table' then
            Map.log('minimap style refused: expected a table of fields')

            return false
        end

        for key, value in pairs(style) do
            if key == 'pin' then
                appearance.pin = PIN_TOP_RIGHT
                count = count + 1
            else
                local kind = FIELDS[key]

                if not kind then
                    Map.log(('minimap style: no such field "%s"; ignored')
                        :format(tostring(key)))
                elseif kind == 'color' then
                    if isHexColor(value) then
                        appearance[key] = value
                        count = count + 1
                    else
                        Map.log(('minimap style: %s must be a "#rrggbb" string; ignored')
                            :format(key))
                    end
                elseif not Map.isFiniteNumber(value) then
                    Map.log(('minimap style: %s must be a finite number; ignored')
                        :format(key))
                else
                    warnOutOfRange(key, value, kind)

                    appearance[key] = toPage(key, kind, value)
                    count = count + 1
                end
            end
        end
    end

    if count == 0 and not reset then
        Map.debug('minimap style: nothing to change')

        return false
    end

    local payload = {
        type = 'minimap:style',
        appearance = appearance,
        reset = reset,
    }

    if not Map.send(payload) then
        pending = payload
        Map.debug('minimap style held until the page is ready')
    end

    return true
end

function Map.minimapStyle.set(style)
    return commit(style, false)
end

function Map.minimapStyle.reset(style)
    return commit(style, true)
end

local function hostAppearance(frame)
    local pxPerRem, _, screenHeight = screen()

    return {
        pin = 'free',
        left = frame.x / pxPerRem,
        bottom = math.max(0, (screenHeight - frame.y - frame.height) / pxPerRem),
        width = frame.width / pxPerRem,
        height = frame.height / pxPerRem,
        cornerRadius = 1,
        borderWidth = 0,
        shadowBlur = 0,
        shadowSpread = 0,
        shadowOffsetX = 0,
        shadowOffsetY = 0,
    }
end

local function sendPayload(payload)
    if not Map.send(payload) then
        pending = payload
    end
end

--- frame = { x, y, width, height } in screen pixels, or nil to go back to
--- the default top-right frame.
function Map.minimapStyle.setHostFrame(frame)
    if frame ~= nil then
        if type(frame) ~= 'table'
            or not Map.isFiniteNumber(frame.x) or not Map.isFiniteNumber(frame.y)
            or not Map.isFiniteNumber(frame.width) or not Map.isFiniteNumber(frame.height)
            or frame.width <= 0 or frame.height <= 0
        then
            return false
        end

        frame = { x = frame.x, y = frame.y, width = frame.width, height = frame.height }
    end

    local wasSet = hostFrame ~= nil
    hostFrame = frame

    if frame then
        sendPayload({ type = 'minimap:style', appearance = hostAppearance(frame), reset = false })
    elseif wasSet then
        sendPayload({ type = 'minimap:style', appearance = {}, reset = true })
    end

    Map.surface.publishMinimapRect()

    return true
end

function Map.minimapStyle.getHostFrame()
    return hostFrame
end

function Map.minimapStyle.getScreenRect()
    local visible = Map.isMinimapOnScreen()
    local inspecting = Map.state.inspect == true

    if not visible then
        return {
            height = 0,
            inspecting = false,
            screenHeight = select(3, screen()),
            screenWidth = select(2, screen()),
            stackTop = 0,
            visible = false,
            width = 0,
            x = 0,
            y = 0,
        }
    end

    local pxPerRem, screenWidth, screenHeight = screen()

    if hostFrame then
        return {
            height = hostFrame.height,
            inspecting = inspecting,
            screenHeight = screenHeight,
            screenWidth = screenWidth,
            stackTop = hostFrame.y + hostFrame.height + STACK_GAP_REM * pxPerRem,
            visible = true,
            width = hostFrame.width,
            x = hostFrame.x,
            y = hostFrame.y,
        }
    end

    local scale = inspecting and INSPECT_BOX_SCALE or 1.0
    local width = notifyWidthPx() * scale
    local height = width * FRAME_ASPECT
    local y = DEFAULT_INSETS.top * pxPerRem
    local x = math.max(0, screenWidth - width - NOTIFY_EDGE_PX)

    return {
        height = height,
        inspecting = inspecting,
        screenHeight = screenHeight,
        screenWidth = screenWidth,
        stackTop = y + height + STACK_GAP_REM * pxPerRem,
        visible = true,
        width = width,
        x = x,
        y = y,
    }
end

function Map.minimapStyle.get()
    local settings = Map.settings.get()
    local appearance = settings and settings.minimapAppearance

    if type(appearance) ~= 'table' then
        appearance = nil
    end

    local rem = {}

    for key, kind in pairs(FIELDS) do
        local value = appearance and appearance[key]

        if value == nil then
            value = DEFAULT_APPEARANCE[key]
        end

        rem[key] = value
    end

    applyForcedFrame(rem)

    local style = {}

    for key, kind in pairs(FIELDS) do
        style[key] = kind == 'color' and rem[key] or fromPage(key, kind, rem[key])
    end

    style.pin = PIN_TOP_RIGHT

    return style
end

Map.onReplay(function()
    if hostFrame then
        pending = nil
        Map.send({ type = 'minimap:style', appearance = hostAppearance(hostFrame), reset = false })
        return
    end

    local settings = Map.settings.get()
    local saved = settings and settings.minimapAppearance

    if type(saved) == 'table' and saved.pin == 'free' then
        -- host HUD gone: drop the saved circle frame
        Map.send({ type = 'minimap:style', appearance = {}, reset = true })
    end

    if not pending then
        return
    end

    local payload = pending
    pending = nil

    Map.send(payload)
end)
