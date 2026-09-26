local ORIGINAL_BEGIN = BeginTextCommandSetBlipName
local ORIGINAL_END = EndTextCommandSetBlipName
local ORIGINAL_ADD_STRING = AddTextComponentString
local ORIGINAL_ADD_SUBSTRING = AddTextComponentSubstringPlayerName
local ORIGINAL_ADD_TEXT_LABEL = AddTextComponentSubstringTextLabel
local ORIGINAL_ADD_INTEGER = AddTextComponentInteger
local ORIGINAL_ADD_FORMATTED_INTEGER = AddTextComponentFormattedInteger
local ORIGINAL_ADD_BLIP_NAME = AddTextComponentSubstringBlipName
local ORIGINAL_FROM_TEXT_FILE = SetBlipNameFromTextFile
local ORIGINAL_TO_PLAYER_NAME = SetBlipNameToPlayerName
local ORIGINAL_ADD_RADIUS = AddBlipForRadius
local ORIGINAL_ADD_AREA = AddBlipForArea

local pendingLabel = nil
local pendingText = nil

local pendingTainted = false

local function append(text)
    if type(text) == 'string' then
        pendingText = (pendingText or '') .. text
    end
end

local function taint()
    pendingTainted = true
end

local function report(blip, title)
    if type(blip) ~= 'number' or type(title) ~= 'string' or title == '' then
        return
    end

    pcall(function()
        exports.as-map:SetNativeBlipTitle(blip, title)
    end)
end

local function reportRadius(blip, radius)
    if type(blip) ~= 'number' or type(radius) ~= 'number' then
        return
    end

    pcall(function()
        exports.as-map:SetNativeBlipRadius(blip, radius)
    end)
end

local function reportArea(blip, width, height)
    if type(blip) ~= 'number' or type(width) ~= 'number' or type(height) ~= 'number' then
        return
    end

    pcall(function()
        exports.as-map:SetNativeBlipArea(blip, width, height)
    end)
end

if ORIGINAL_BEGIN then
    function BeginTextCommandSetBlipName(label)
        pendingLabel = label
        pendingText = nil
        pendingTainted = false

        return ORIGINAL_BEGIN(label)
    end
end

if ORIGINAL_ADD_STRING then
    function AddTextComponentString(text)
        append(text)

        return ORIGINAL_ADD_STRING(text)
    end
end

if ORIGINAL_ADD_SUBSTRING then
    function AddTextComponentSubstringPlayerName(text)
        append(text)

        return ORIGINAL_ADD_SUBSTRING(text)
    end
end

if ORIGINAL_ADD_TEXT_LABEL then
    function AddTextComponentSubstringTextLabel(label)
        if type(label) == 'string' then
            local text = GetLabelText(label)

            if text == label or text == 'NULL' then
                taint()
            else
                append(text)
            end
        else
            taint()
        end

        return ORIGINAL_ADD_TEXT_LABEL(label)
    end
end

if ORIGINAL_ADD_INTEGER then
    function AddTextComponentInteger(value)
        if type(value) == 'number' then
            append(tostring(math.floor(value)))
        else
            taint()
        end

        return ORIGINAL_ADD_INTEGER(value)
    end
end

if ORIGINAL_ADD_FORMATTED_INTEGER then
    function AddTextComponentFormattedInteger(value, commaSeparated)
        if commaSeparated or type(value) ~= 'number' then
            taint()
        else
            append(tostring(math.floor(value)))
        end

        return ORIGINAL_ADD_FORMATTED_INTEGER(value, commaSeparated)
    end
end

local TAINTING_COMPONENTS = {
    'AddTextComponentFloat',
    'AddTextComponentSubstringTime',
    'AddTextComponentSubstringTextLabelHashKey',
    'AddTextComponentSubstringPhoneNumber',
    'AddTextComponentSubstringWebsite',
    'AddTextComponentSubstringKeyboardDisplay',
}

for index = 1, #TAINTING_COMPONENTS do
    local name = TAINTING_COMPONENTS[index]
    local original = _G[name]

    if original then
        _G[name] = function(...)
            taint()

            return original(...)
        end
    end
end

if ORIGINAL_ADD_BLIP_NAME then
    function AddTextComponentSubstringBlipName(blip)
        local ok, title = pcall(function()
            return exports.as-map:GetNativeBlipTitle(blip)
        end)

        if ok and type(title) == 'string' and title ~= '' then
            append(title)
        else
            taint()
        end

        return ORIGINAL_ADD_BLIP_NAME(blip)
    end
end

if ORIGINAL_END then
    function EndTextCommandSetBlipName(blip)
        local result = ORIGINAL_END(blip)

        local title = pendingText

        if not title
            and not pendingTainted
            and type(pendingLabel) == 'string'
            and pendingLabel ~= 'STRING'
        then
            title = GetLabelText(pendingLabel)

            if title == pendingLabel or title == 'NULL' then
                title = nil
            end
        end

        if not pendingTainted then
            report(blip, title)
        end

        pendingLabel = nil
        pendingText = nil
        pendingTainted = false

        return result
    end
end

if ORIGINAL_FROM_TEXT_FILE then
    function SetBlipNameFromTextFile(blip, label)
        local result = ORIGINAL_FROM_TEXT_FILE(blip, label)

        if type(label) == 'string' then
            local title = GetLabelText(label)

            if title ~= label and title ~= 'NULL' then
                report(blip, title)
            end
        end

        return result
    end
end

if ORIGINAL_TO_PLAYER_NAME then
    function SetBlipNameToPlayerName(blip, player)
        local result = ORIGINAL_TO_PLAYER_NAME(blip, player)
        local ok, name = pcall(GetPlayerName, player)

        if ok and type(name) == 'string' and name ~= '' then
            report(blip, name)
        end

        return result
    end
end

if ORIGINAL_ADD_RADIUS then
    function AddBlipForRadius(x, y, z, radius)
        local blip = ORIGINAL_ADD_RADIUS(x, y, z, radius)

        reportRadius(blip, radius)

        return blip
    end
end

if ORIGINAL_ADD_AREA then
    function AddBlipForArea(x, y, z, width, height)
        local blip = ORIGINAL_ADD_AREA(x, y, z, width, height)

        reportArea(blip, width, height)

        return blip
    end
end
