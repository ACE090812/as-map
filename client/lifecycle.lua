--- Session lifecycle. Framework-agnostic: works with qbx_core, qb-core,
--- ox_core, es_extended, or plain FiveM (no framework) as a fallback.

local function started(name)
    return GetResourceState(name) == 'started'
end

local function tryCall(fn)
    local ok, result = pcall(fn)
    return ok and result or nil
end

local function isLoggedIn()
    -- qbx_core / qb-core set this statebag on character load
    if LocalPlayer.state.isLoggedIn then
        return true
    end

    if started('qbx_core') then
        local data = tryCall(function() return exports.qbx_core:GetPlayerData() end)
        return data ~= nil and data.citizenid ~= nil
    end

    if started('qb-core') then
        local data = tryCall(function()
            return exports['qb-core']:GetCoreObject().Functions.GetPlayerData()
        end)
        return data ~= nil and data.citizenid ~= nil
    end

    if started('ox_core') then
        local player = tryCall(function() return exports.ox_core:GetPlayer() end)
        return player ~= nil and (player.charId ~= nil or player.charid ~= nil)
    end

    if started('es_extended') then
        local loaded = tryCall(function()
            return exports.es_extended:getSharedObject().IsPlayerLoaded()
        end)
        return loaded == true
    end

    -- No known framework: treat as loaded once the ped is in the world.
    if not started('qbx_core') and not started('qb-core')
        and not started('ox_core') and not started('es_extended')
    then
        local ped = PlayerPedId()
        return NetworkIsSessionStarted() and ped ~= 0 and DoesEntityExist(ped)
    end

    return false
end

function Map.sessionActivate()
    if Map.state.playerLoaded then
        return
    end

    Map.setState('playerLoaded', true)
    Map.surface.applyWantedMinimap()

    if Map.state.ready then
        Map.runReplay()
    end
end

function Map.sessionDeactivate()
    if not Map.state.playerLoaded and not Map.state.minimap then
        DisplayRadar(true)
        return
    end

    if Map.inspect and Map.inspect.stop then
        Map.inspect.stop()
    end

    if Map.pauseMenu and Map.pauseMenu.close then
        Map.pauseMenu.close()
    end

    Map.surface.closeFullscreen()
    Map.setState('playerLoaded', false)
    Map.surface.suspend()
    DisplayRadar(true)

    if Map.surface.restoresdHud then
        Map.surface.restoresdHud()
    end
end

local function onLoaded()
    CreateThread(function()
        Wait(500)
        Map.sessionActivate()
    end)
end

-- Loaded events (qbx_core also fires the QBCore ones)
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', onLoaded)
RegisterNetEvent('ox:playerLoaded', onLoaded)
RegisterNetEvent('esx:playerLoaded', onLoaded)

-- Unload / logout events
RegisterNetEvent('QBCore:Client:OnPlayerUnload', Map.sessionDeactivate)
RegisterNetEvent('qbx_core:client:playerLoggedOut', Map.sessionDeactivate)
RegisterNetEvent('ox:playerLogout', Map.sessionDeactivate)
RegisterNetEvent('esx:onPlayerLogout', Map.sessionDeactivate)

AddStateBagChangeHandler('isLoggedIn', nil, function(bagName, _, value)
    if bagName ~= ('player:%s'):format(GetPlayerServerId(PlayerId())) then
        return
    end

    if value then
        onLoaded()
    else
        Map.sessionDeactivate()
    end
end)

-- Covers resource restarts and anything the events above miss.
CreateThread(function()
    while not Map.state.playerLoaded do
        Wait(1000)
        if isLoggedIn() then
            Map.sessionActivate()
            break
        end
    end
end)

RegisterNUICallback('map:ready', function(_, cb)
    Map.setState('ready', true)
    Map.log('NUI ready')

    if Map.state.playerLoaded then
        Map.runReplay()
    end

    cb({ ok = true })
end)

RegisterNUICallback('map:benchmarkResult', function(_, cb)
    cb({})
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    Map.focus.release()
    Map.mugshot.release()
    ClearGpsMultiRoute()
    DisplayRadar(true)

    if Map.surface and Map.surface.restoresdHud then
        Map.surface.restoresdHud()
    end
end)