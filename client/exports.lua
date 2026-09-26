exports('IsMapReady', function()
    return Map.state.ready
end)

exports('UpsertMapBlip', function(update)
    return Map.blips.upsert(update)
end)

exports('UpsertMapBlipBatch', function(updates)
    return Map.blips.upsertBatch(updates)
end)

exports('UpdateDynamicMapBlipCoords', function(id, coords)
    return Map.blips.updateDynamicCoords(id, coords)
end)

exports('UpdateDynamicMapBlipCoordsBatch', function(updates)
    return Map.blips.updateDynamicCoordsBatch(updates)
end)

exports('RemoveMapBlip', function(id)
    return Map.blips.remove(id)
end)

exports('RemoveMapBlipBatch', function(ids)
    return Map.blips.removeBatch(ids)
end)

exports('SetNativeBlipTitle', function(blip, title)
    return Map.nativeBlips.setTitle(blip, title)
end)

exports('GetNativeBlipTitle', function(blip)
    return Map.nativeBlips.getTitle(blip)
end)

exports('SetNativeBlipRadius', function(blip, radius)
    return Map.nativeBlips.setRadius(blip, radius)
end)

exports('SetNativeBlipArea', function(blip, width, height)
    return Map.nativeBlips.setArea(blip, width, height)
end)

exports('ClearNativeBlipExtent', function(blip)
    return Map.nativeBlips.clearExtent(blip)
end)

exports('GetNativeBlipExtent', function(blip)
    return Map.nativeBlips.getExtent(blip)
end)

exports('UpsertMapZone', function(update)
    return Map.zones.upsert(update)
end)

exports('RemoveMapZone', function(id)
    return Map.zones.remove(id)
end)

exports('GetMapAccentColor', function()
    return Map.accent.color
end)

exports('GetMapAccentName', function()
    return Map.accent.name
end)

exports('RefreshMapRoute', function()
    return Map.route.refresh()
end)

exports('SetMapBlipRoute', function(blip, enabled)
    return Map.route.setBlipRoute(blip, enabled ~= false)
end)

exports('GetMapBlipRoute', function()
    return Map.route.getBlipRoute()
end)

exports('SetMapPlayerName', function(name)
    return Map.identity.setName(name)
end)

exports('RefreshMapMugshot', function()
    return Map.mugshot.refresh()
end)

exports('SetMinimapVisible', function(visible)
    Map.surface.setMinimapVisible(visible)
end)

exports('SetMinimapStyle', function(style)
    return Map.minimapStyle.set(style)
end)

exports('ResetMinimapStyle', function(style)
    return Map.minimapStyle.reset(style)
end)

exports('GetMinimapStyle', function()
    return Map.minimapStyle.get()
end)

exports('GetMinimapScreenRect', function()
    return Map.minimapStyle.getScreenRect()
end)

exports('GetMapSettings', function()
    return Map.settings.get()
end)

exports('GetMapDimensions', function()
    return Map.settings.getDimensions()
end)

exports('SetMapDimension', function(surface, dimension)
    return Map.settings.setDimension(surface, dimension)
end)

exports('OpenFullscreenMap', function()
    return Map.surface.openFullscreen()
end)

exports('CloseFullscreenMap', function()
    Map.surface.closeFullscreen()
end)

exports('IsPauseMenuOpen', function()
    return Map.state.pauseMenu
end)

exports('OpenPauseMenu', function()
    Map.pauseMenu.open()
end)

exports('ClosePauseMenu', function()
    Map.pauseMenu.close()
end)

local function assembleAssetKey()
    if type(Map.assetKeyParts) ~= 'table' or type(Map.assetKeyPart) ~= 'string' then
        return ''
    end

    return table.concat(Map.assetKeyParts) .. Map.assetKeyPart
end

exports('GetAssetKeyPart', function()
    return Map.assetKeyPart
end)

exports('GetAssetKey', function()
    return assembleAssetKey()
end)
