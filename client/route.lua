Map.route = {}

local WAYPOINT_SPRITE = 8

local sequence = 0

local lastDestination = nil

local lastBuiltAt = 0

local lastPoints = nil

local function getWaypointCoords()
    if not IsWaypointActive() then
        return nil
    end

    local blip = GetFirstBlipInfoId(WAYPOINT_SPRITE)

    if blip == 0 or not DoesBlipExist(blip) then
        return nil
    end

    return Map.toCoords(GetBlipInfoIdCoord(blip))
end

local WAYPOINT_BLIP_ID = 'as-map:waypoint'

local WAYPOINT_SPRITE_ICON = 8

local waypointBlipAt = nil

local WAYPOINT_BLIP_EPSILON = 0.5

local function syncWaypointBlip(coords)
    if coords == nil then
        if waypointBlipAt ~= nil then
            waypointBlipAt = nil
            Map.blips.remove(WAYPOINT_BLIP_ID)
        end

        return
    end

    if waypointBlipAt
        and math.abs(waypointBlipAt.x - coords.x) <= WAYPOINT_BLIP_EPSILON
        and math.abs(waypointBlipAt.y - coords.y) <= WAYPOINT_BLIP_EPSILON
    then
        return
    end

    waypointBlipAt = coords

    Map.blips.upsert({
        id = WAYPOINT_BLIP_ID,
        blipId = WAYPOINT_SPRITE_ICON,
        color = Map.accent.color,
        title = 'Waypoint',
        coords = coords,
        scale = 1.0,
        dynamic = false,
    })
end

Map.accent.onChange(function(color)
    if waypointBlipAt == nil then
        return
    end

    Map.blips.upsert({
        id = WAYPOINT_BLIP_ID,
        color = color,
    })
end)

local DIRECT_ROUTE_VEHICLE_TYPES = {
    boat = true,
    heli = true,
    plane = true,
}

local wasDirect = false

local function wantsDirectRoute()
    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)

    if vehicle == 0 or not DoesEntityExist(vehicle) then
        return false
    end

    return DIRECT_ROUTE_VEHICLE_TYPES[GetVehicleType(vehicle)] == true
end

local function buildDirectRoute(coords)
    local player = GetEntityCoords(PlayerPedId())

    return {
        { x = player.x, y = player.y, z = player.z },
        { x = coords.x, y = coords.y, z = coords.z or player.z },
    }
end

local lastDirect = false

local function sendPoints(points, withSequence, direct)
    lastPoints = points
    lastDirect = direct == true

    Map.send({
        type = 'map:route',
        points = points,
        sequence = withSequence,
        direct = lastDirect,
        slot = 0,
    })
end

function Map.route.clear()
    if lastPoints == nil then
        return
    end

    lastPoints = nil
    lastDirect = false

    Map.send({
        type = 'map:route',
        points = {},
        direct = false,
    })
end

local traceEnabled = false

local function traceLog(message)
    if traceEnabled then
        Map.log('route| ' .. message)
    end
end

local pending = nil

local function sendRoute(withSequence, force)
    if not Map.config.route.enabled then
        return false
    end

    local now = GetGameTimer()

    if not force and now - lastBuiltAt < Map.config.route.minRebuildIntervalMs then
        return false
    end

    lastBuiltAt = now

    local direct = wantsDirectRoute()
    local destination = direct and Map.route.getDestination() or nil
    local points = direct
        and (destination and buildDirectRoute(destination) or nil)
        or Map.routeSampler.collect()

    if not points then
        lastBuiltAt = 0

        return false
    end

    sendPoints(points, withSequence, direct)

    return true, #points
end

function Map.route.refresh()
    sequence = sequence + 1

    return sendRoute(sequence, true)
end

RegisterNUICallback('map:routeRequested', function(data, cb)
    if getWaypointCoords() == nil then
        Map.route.clear()
        cb({})

        return
    end

    local requested = type(data) == 'table' and data.sequence or nil

    if Map.isIntegerNumber(requested) and requested >= 0 then
        sequence = math.max(sequence, requested)
    end

    sendRoute(sequence, false)
    cb({})
end)

RegisterNUICallback('map:waypointRequested', function(data, cb)
    local coords = type(data) == 'table' and Map.toCoords(data.coords) or nil

    if coords then
        SetNewWaypoint(coords.x + 0.0, coords.y + 0.0)

        syncWaypointBlip(coords)

        Map.route.kick()
    end

    cb({})
end)

RegisterNUICallback('map:waypointCleared', function(_, cb)
    SetWaypointOff()

    Map.route.clearOnFootRoute()

    syncWaypointBlip(nil)

    lastDestination = nil
    Map.route.clear()

    cb({})
end)

local multiRouteDestination = nil

local blipMultiRouteDestination = nil

local function blipOwnsMultiRoute()
    return blipMultiRouteDestination ~= nil
end

local borrowingMultiRoute = false

local borrowCancelled = false

function Map.route.hasOnFootRoute()
    return multiRouteDestination ~= nil
end

local function ownedDestination()
    if not Map.config.route.deleteNativeWaypointOnFoot then
        return nil
    end

    return multiRouteDestination
end

function Map.route.getDestination()
    return getWaypointCoords() or ownedDestination()
end

local function isOnFoot()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)

    return not (vehicle ~= 0 and DoesEntityExist(vehicle))
end

function Map.route.convertToRouteOnFoot(coords)
    local settings = Map.config.route

    traceLog(('raising on-foot multi-route to %.1f, %.1f (slot 0 was empty)')
        :format(coords.x, coords.y))

    if settings.deleteNativeWaypointOnFoot then
        DeleteWaypointsFromThisPlayer()
    end

    ClearGpsMultiRoute()
    StartGpsMultiRoute(settings.onFootRouteColour, true, true)
    AddPointToGpsMultiRoute(coords.x, coords.y, coords.z or 0.0)
    SetGpsMultiRouteRender(true)

    blipMultiRouteDestination = nil
    multiRouteDestination = coords
end

function Map.route.clearOnFootRoute()
    if borrowingMultiRoute then
        borrowCancelled = true

        return
    end

    if multiRouteDestination == nil then
        return
    end

    multiRouteDestination = nil

    SetGpsMultiRouteRender(false)
    ClearGpsMultiRoute()
end

local function syncOnFootRoute(destination, onFoot)
    local settings = Map.config.route

    if borrowingMultiRoute then
        return false
    end

    local wanted = settings.onFootWorkaround
        and onFoot
        and destination ~= nil
        and not Map.routeSampler.hasWaypointRoute()

    if not wanted then
        if multiRouteDestination ~= nil then
            Map.route.clearOnFootRoute()

            return true
        end

        return false
    end

    if multiRouteDestination ~= nil
        and math.abs(multiRouteDestination.x - destination.x) <= settings.destinationEpsilon
        and math.abs(multiRouteDestination.y - destination.y) <= settings.destinationEpsilon
    then
        return false
    end

    Map.route.convertToRouteOnFoot(destination)

    return true
end

local wasDead = false

local lastPlayerPosition = nil

local teleportPending = false

local function watchForTeleport()
    local ped = PlayerPedId()
    local position = GetEntityCoords(ped)
    local dead = IsPedDeadOrDying(ped, true)
    local moved = lastPlayerPosition and #(position - lastPlayerPosition) or 0.0
    local jumped = moved > Map.config.route.teleportDistance
    local respawned = wasDead and not dead

    wasDead = dead
    lastPlayerPosition = position

    if respawned then
        teleportPending = true

        traceLog('respawned -- the route the game holds still starts where the ' ..
            'player died')
    elseif jumped then
        teleportPending = true

        traceLog(('player jumped %.0f m -- the route the game holds still ' ..
            'starts where they were'):format(moved))
    end

    if not teleportPending
        or dead
        or jumped
        or not IsScreenFadedIn()
    then
        return false
    end

    teleportPending = false

    return true
end

local function recomputeGameRoute(waypoint, reason)
    if waypoint then
        DeleteWaypointsFromThisPlayer()
        Wait(0)
        SetNewWaypoint(waypoint.x + 0.0, waypoint.y + 0.0)
    end

    Map.route.clearOnFootRoute()

    lastDestination = nil

    pending = nil

    traceLog(('%s -- making the game work the route out again'):format(reason))
end

local function tick()
    local settings = Map.config.route
    local waypoint = getWaypointCoords()
    local coords = waypoint or ownedDestination()
    local direct = wantsDirectRoute()
    local leftDirectVehicle = wasDirect and not direct

    wasDirect = direct

    local teleported = watchForTeleport()
    local staleReason = nil

    if leftDirectVehicle then
        staleReason = 'left a boat/heli/plane'
    elseif teleported then
        staleReason = 'settled after a respawn or teleport'
    end

    if staleReason and coords then
        recomputeGameRoute(waypoint, staleReason)
    end

    local sourceChanged = syncOnFootRoute(coords, isOnFoot())

    syncWaypointBlip(coords)

    if coords == nil then
        if lastDestination ~= nil then
            lastDestination = nil
            pending = nil
            Map.route.clear()
            traceLog('destination gone, route cleared')
        end

        return true
    end

    local styleChanged = direct ~= lastDirect
    local needsRebuild = sourceChanged
        or styleChanged
        or lastDestination == nil
        or math.abs(coords.x - lastDestination.x) > settings.destinationEpsilon
        or math.abs(coords.y - lastDestination.y) > settings.destinationEpsilon

    if not needsRebuild then
        return true
    end

    local chasingSomethingElse = pending and (
        math.abs(coords.x - pending.x) > settings.destinationEpsilon
        or math.abs(coords.y - pending.y) > settings.destinationEpsilon
    )

    if not pending or chasingSomethingElse or sourceChanged or styleChanged then
        pending = {
            startedAt = GetGameTimer(),
            attempts = 0,
            x = coords.x,
            y = coords.y,
        }

        traceLog(('rebuild wanted -> %.1f, %.1f  (%s%s)'):format(
            coords.x,
            coords.y,
            isOnFoot() and 'on foot' or 'in vehicle',
            sourceChanged and ', geometry source changed' or ''
        ))
    end

    pending.attempts = pending.attempts + 1

    local sent, pointCount = sendRoute(sequence + 1, true)
    local elapsed = GetGameTimer() - pending.startedAt

    if sent then
        sequence = sequence + 1
        lastDestination = coords

        traceLog(('drawn after %d ms, %d attempt(s): %d points from GPS slot %s')
            :format(
                elapsed,
                pending.attempts,
                pointCount,
                tostring(Map.routeSampler.lastSlot())
            ))

        pending = nil

        return true
    end

    if elapsed >= settings.pendingTimeoutMs then
        if not pending.gaveUp then
            pending.gaveUp = true

            traceLog(('gave up after %d ms, %d attempts: no geometry in any ' ..
                'GPS slot for %.1f, %.1f -- the game may not be able to route ' ..
                'there. Still watching, at %d ms.  [%s]'):format(
                    elapsed,
                    pending.attempts,
                    coords.x,
                    coords.y,
                    settings.watchIntervalMs,
                    Map.routeSampler.describeSlots()
                ))
        end

        return true
    end

    return false
end

local kicking = false

function Map.route.kick()
    if kicking or not Map.config.route.enabled then
        return
    end

    kicking = true

    CreateThread(function()
        local settings = Map.config.route
        local deadline = GetGameTimer() + settings.pendingTimeoutMs

        Wait(0)

        traceLog('kick: chasing a waypoint we just set')

        while Map.state.ready
            and not tick()
            and GetGameTimer() < deadline
        do
            Wait(settings.pendingRetryMs)
        end

        if GetGameTimer() >= deadline then
            traceLog(('kick: gave up after %d ms -- the game may not be able to ' ..
                'route there. Handing back to the watcher.')
                :format(settings.pendingTimeoutMs))
        end

        kicking = false
    end)
end

CreateThread(function()
    while true do
        local settings = Map.config.route
        local settled = true

        if settings.enabled
            and Map.state.ready
            and Map.routeSampler.isAvailable()
            and not kicking
        then
            settled = tick()
        end

        Wait(settled and settings.watchIntervalMs or settings.pendingRetryMs)
    end
end)

Map.onReplay(function()
    if lastPoints then
        Map.send({
            type = 'map:route',
            points = lastPoints,
            direct = lastDirect,
            slot = 0,
        })
    end
end)

local blipRoute = nil

local lastBlipPoints = nil

local lastBlipColor = nil

local lastBlipDestination = nil

local function blipRouteDestination()
    if not blipRoute or not DoesBlipExist(blipRoute) then
        return nil
    end

    return Map.toCoords(GetBlipInfoIdCoord(blipRoute))
end

local function syncBlipOnFootRoute()
    local settings = Map.config.route
    local destination = blipRouteDestination()

    local wanted = settings.onFootWorkaround
        and destination ~= nil
        and isOnFoot()
        and not Map.route.hasOnFootRoute()
        and (blipOwnsMultiRoute() or not Map.routeSampler.hasSlotRoute(1))

    if not wanted then
        if blipOwnsMultiRoute() then
            blipMultiRouteDestination = nil

            SetGpsMultiRouteRender(false)
            ClearGpsMultiRoute()

            return true
        end

        return false
    end

    if blipOwnsMultiRoute()
        and math.abs(blipMultiRouteDestination.x - destination.x)
            <= settings.destinationEpsilon
        and math.abs(blipMultiRouteDestination.y - destination.y)
            <= settings.destinationEpsilon
    then
        return false
    end

    ClearGpsMultiRoute()
    StartGpsMultiRoute(settings.onFootRouteColour, true, true)
    AddPointToGpsMultiRoute(destination.x, destination.y, destination.z or 0.0)
    SetGpsMultiRouteRender(true)

    blipMultiRouteDestination = destination

    return true
end

local function clearBlipRoute()
    lastBlipDestination = nil
    lastBlipColor = nil

    if blipOwnsMultiRoute() then
        blipMultiRouteDestination = nil

        SetGpsMultiRouteRender(false)
        ClearGpsMultiRoute()
    end

    if lastBlipPoints == nil then
        return
    end

    lastBlipPoints = nil

    Map.send({
        type = 'map:route',
        points = {},
        direct = false,
        slot = 1,
    })
end

local BLIP_ROUTE_ARRIVAL_SQUARED = 60.0 * 60.0

local function reachesDestination(points, destination)
    local last = points[#points]
    local dx = last.x - destination.x
    local dy = last.y - destination.y

    return dx * dx + dy * dy <= BLIP_ROUTE_ARRIVAL_SQUARED
end

local BORROW_POLL_MS = 100
local BORROW_MAX_POLLS = 10

local function borrowMultiRoute(destination)
    local settings = Map.config.route
    local restore = multiRouteDestination

    borrowingMultiRoute = true
    borrowCancelled = false
    multiRouteDestination = nil

    ClearGpsMultiRoute()
    StartGpsMultiRoute(settings.onFootRouteColour, true, true)
    AddPointToGpsMultiRoute(destination.x, destination.y, destination.z or 0.0)
    SetGpsMultiRouteRender(true)

    local points = nil

    for _ = 1, BORROW_MAX_POLLS do
        Wait(BORROW_POLL_MS)

        if Map.routeSampler.hasSlotRoute(1) then
            points = Map.routeSampler.collectFromSlot(1, destination)

            if points then
                break
            end
        end
    end

    ClearGpsMultiRoute()

    if borrowCancelled then
        restore = nil
    end

    if restore then
        StartGpsMultiRoute(settings.onFootRouteColour, true, true)
        AddPointToGpsMultiRoute(restore.x, restore.y, restore.z or 0.0)
        SetGpsMultiRouteRender(true)
    end

    multiRouteDestination = restore
    borrowingMultiRoute = false
    borrowCancelled = false

    return points
end

local function sampleBlipRoute(destination)
    if not Map.route.hasOnFootRoute() then
        return Map.routeSampler.collectFromSlot(1, destination)
    end

    return borrowMultiRoute(destination)
end

local function sendBlipRoute()
    local destination = blipRouteDestination()

    if not destination then
        clearBlipRoute()

        return false
    end

    local points = sampleBlipRoute(destination)

    if not points then
        lastBlipDestination = nil

        return false
    end

    if not reachesDestination(points, destination) then
        lastBlipDestination = nil

        return false
    end

    lastBlipPoints = points
    lastBlipDestination = destination
    lastBlipColor = GetBlipColour(blipRoute)

    Map.send({
        type = 'map:route',
        points = points,
        direct = false,
        slot = 1,
        color = GetBlipColour(blipRoute),
    })

    return true
end

function Map.route.setBlipRoute(blip, enabled)
    if type(blip) ~= 'number' or not DoesBlipExist(blip) then
        return false
    end

    if enabled == false then
        SetBlipRoute(blip, false)

        if blipRoute == blip then
            blipRoute = nil
            clearBlipRoute()
        end

        return true
    end

    if blipRoute and blipRoute ~= blip and DoesBlipExist(blipRoute) then
        SetBlipRoute(blipRoute, false)
    end

    if blipRoute ~= blip then
        clearBlipRoute()
    end

    blipRoute = blip

    SetBlipRoute(blip, true)

    syncBlipOnFootRoute()

    return true
end

function Map.route.getBlipRoute()
    return blipRoute
end

CreateThread(function()
    while true do
        local settings = Map.config.route
        local settled = true

        if settings.enabled and Map.state.ready and Map.routeSampler.isAvailable()
        then
            if blipRoute and not DoesBlipExist(blipRoute) then
                blipRoute = nil
                clearBlipRoute()
            elseif blipRoute then
                local destination = blipRouteDestination()
                local sourceChanged = syncBlipOnFootRoute()

                local moved = destination ~= nil
                    and (lastBlipDestination == nil
                        or math.abs(lastBlipDestination.x - destination.x)
                            > settings.destinationEpsilon
                        or math.abs(lastBlipDestination.y - destination.y)
                            > settings.destinationEpsilon)

                if moved or (sourceChanged and destination ~= nil) then
                    settled = sendBlipRoute()
                elseif destination == nil then
                    clearBlipRoute()
                elseif lastBlipPoints
                    and GetBlipColour(blipRoute) ~= lastBlipColor
                then
                    lastBlipColor = GetBlipColour(blipRoute)

                    Map.send({
                        type = 'map:route',
                        points = lastBlipPoints,
                        direct = false,
                        slot = 1,
                        color = lastBlipColor,
                    })
                end
            end
        end

        Wait(settled and settings.watchIntervalMs or settings.pendingRetryMs)
    end
end)

Map.onReplay(function()
    if lastBlipPoints then
        Map.send({
            type = 'map:route',
            points = lastBlipPoints,
            direct = false,
            slot = 1,
            color = (blipRoute and DoesBlipExist(blipRoute))
                and GetBlipColour(blipRoute)
                or nil,
        })
    end
end)
