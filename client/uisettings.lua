--- Forwards ave_hud UI knobs (colorMode / transparency / radius / gradient / perspective) into map NUI.

local DEFAULT_UI_SETTINGS = {
    transparency = 80,
    borderRadius = 0,
    gradientIntensity = 0,
    perspective = 'none',
    colorMode = 'light',
}

local function mergeUiSettings(settings)
    local merged = {}

    for key, value in pairs(DEFAULT_UI_SETTINGS) do
        merged[key] = value
    end

    if settings then
        for key, value in pairs(settings) do
            if value ~= nil then
                merged[key] = value
            end
        end
    end

    return merged
end

local function getHudSettings()
    local ok, settings = pcall(function()
        return exports.ave_hud:getUiSettings()
    end)

    return ok and settings or nil
end

local function pushSettings(settings)
    SendNUIMessage({
        action = 'uiSettings',
        data = mergeUiSettings(settings),
    })
end

RegisterNUICallback('getUiSettings', function(_, cb)
    cb(mergeUiSettings(getHudSettings()))
end)

AddEventHandler('ave:uiSettingsChanged', function(settings)
    pushSettings(settings)
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= 'ave_hud' and resource ~= GetCurrentResourceName() then return end

    CreateThread(function()
        Wait(1000)
        pushSettings(getHudSettings())
    end)
end)
