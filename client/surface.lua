Map.surface = {}

local publishedMinimap = nil

local function publishMinimapVisibility()
    local visible = Map.isMinimapOnScreen()

    if publishedMinimap == visible then
        return
    end

    publishedMinimap = visible

    Map.send({
        type = 'minimap:visibility',
        visible = visible,
    })

    Map.surface.publishMinimapRect()
end

function Map.surface.publishMinimapRect()
    TriggerEvent('sd-map:minimapRect', Map.minimapStyle.getScreenRect())
end

local function hideNativeRadar()
    DisplayRadar(false)
end

local mapHidHud = false

local function setsdHud(visible)
    if GetResourceState('sd-map') ~= 'started' then
        return
    end

    pcall(function()
        exports.sd_map:show(visible)
    end)
end

local function hidesdHud()
    if mapHidHud then
        return
    end

    mapHidHud = true
    setsdHud(false)
end

local function restoresdHud()
    if not mapHidHud then
        return
    end

    mapHidHud = false
    setsdHud(true)
end

function Map.surface.restoresdHud()
    restoresdHud()
end

local wantedMinimap = Map.config.minimapEnabled == true

function Map.surface.setMinimapVisible(visible)
    visible = visible == true
    wantedMinimap = visible

    if not Map.state.playerLoaded then
        if Map.state.minimap then
            Map.setState('minimap', false)
            publishMinimapVisibility()
        end
        return
    end

    if not Map.setState('minimap', visible) then
        return
    end

    if visible then
        hideNativeRadar()
    end

    publishMinimapVisibility()
end

function Map.surface.applyWantedMinimap()
    Map.surface.setMinimapVisible(wantedMinimap)
end

function Map.surface.suspend()
    if Map.setState('minimap', false) then
        publishMinimapVisibility()
    end
end

function Map.surface.setNativeMenuActive(active)
    if not Map.setState('nativeMenu', active == true) then
        return
    end

    publishMinimapVisibility()
end

--- A host HUD (as-hud) hiding its radar frame hides the minimap with it.
function Map.surface.setHostHidden(hidden)
    if not Map.setState('hostHidden', hidden == true) then
        return
    end

    publishMinimapVisibility()
end

function Map.surface.setInventoryOpen(open)
    if not Map.setState('inventory', open == true) then
        return
    end

    publishMinimapVisibility()
end

local function syncInventoryOpen()
    Map.surface.setInventoryOpen(LocalPlayer.state.invOpen == true)
end

AddStateBagChangeHandler('invOpen', nil, function(bagName, _, value)
    if bagName ~= ('player:%s'):format(GetPlayerServerId(PlayerId())) then
        return
    end

    Map.surface.setInventoryOpen(value == true)
end)

AddEventHandler('onClientResourceStart', function(name)
    if name == 'ox_inventory' then
        syncInventoryOpen()
    end

    if name == 'ox_lib' then
        Map.surface.publishMinimapRect()
    end
end)

syncInventoryOpen()

Map.onReplay(function()
    if not Map.state.playerLoaded then
        return
    end

    if Map.state.minimap then
        hideNativeRadar()
    end

    publishedMinimap = nil

    publishMinimapVisibility()
end)

function Map.surface.openFullscreen()
    if not Map.state.ready or not Map.state.playerLoaded then
        return false
    end

    if Map.state.fullscreen then
        hidesdHud()
        return true
    end

    Map.player.sendNow()

    Map.setState('fullscreen', true)
    hidesdHud()

    Map.send({
        type = 'map:visibility',
        visible = true,
    })

    return true
end

function Map.surface.closeFullscreen()
    if not Map.setState('fullscreen', false) then
        return
    end

    restoresdHud()

    Map.send({
        type = 'map:visibility',
        visible = false,
    })
end

function Map.surface.toggleFullscreen()
    if Map.state.fullscreen then
        Map.surface.closeFullscreen()
    else
        Map.surface.openFullscreen()
    end
end

RegisterNUICallback('map:closeRequested', function(_, cb)
    if Map.state.pauseMenu then
        Map.pauseMenu.close()
    else
        Map.surface.closeFullscreen()
    end

    cb({ ok = true })
end)

Map.onReplay(function()
    Map.send({
        type = 'map:visibility',
        visible = Map.state.fullscreen,
    })
end)

CreateThread(function()
    while true do
        if Map.state.minimap then
            DisplayRadar(false)
            Wait(Map.config.radarEnforceIntervalMs)
        else
            Wait(500)
        end
    end
end)
