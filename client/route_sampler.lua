Map.routeSampler = {}

local WAYPOINT_ONLY = { 0 }
local WAYPOINT_AND_OWN_MULTI_ROUTE = { 0, 1 }

local ALL_SLOTS = { 0, 1, 2 }

local lastSlot = nil

local MIN_SEPARATION_SQUARED = 0.25

local ARRIVAL_SQUARED = 40.0 * 40.0

local MAX_COINCIDENT_SAMPLES = 25

local available = type(GetPosAlongGpsTypeRoute) == 'function'

if not available then
    Map.log('GetPosAlongGpsTypeRoute is unavailable on this build; ' ..
        'waypoint routes will not be drawn.')
end

function Map.routeSampler.isAvailable()
    return available
end

function Map.routeSampler.lastSlot()
    return lastSlot
end

function Map.routeSampler.describeSlots()
    if not available then
        return 'GetPosAlongGpsTypeRoute unavailable'
    end

    local parts = {}

    for index = 1, #ALL_SLOTS do
        local slot = ALL_SLOTS[index]
        local ok, position = GetPosAlongGpsTypeRoute(true, 0.0, slot)

        parts[#parts + 1] = ('%d=%s'):format(
            slot,
            (ok and position) and 'ROUTE' or 'empty'
        )
    end

    return table.concat(parts, '  ')
end

function Map.routeSampler.hasSlotRoute(slot)
    if not available then
        return false
    end

    local ok, position = GetPosAlongGpsTypeRoute(true, 0.0, slot)

    return (ok and position) and true or false
end

function Map.routeSampler.hasWaypointRoute()
    if not available then
        return false
    end

    local ok, position = GetPosAlongGpsTypeRoute(true, 0.0, 0)

    return (ok and position) and true or false
end

local function slotCandidates()
    if Map.route and Map.route.hasOnFootRoute and Map.route.hasOnFootRoute() then
        return WAYPOINT_AND_OWN_MULTI_ROUTE
    end

    return WAYPOINT_ONLY
end

local function isAtDestination(point, target)
    if not target then
        return true
    end

    local dx = point.x - target.x
    local dy = point.y - target.y

    return dx * dx + dy * dy <= ARRIVAL_SQUARED
end

local function routeDestination()
    if Map.route and Map.route.getDestination then
        return Map.route.getDestination()
    end

    return nil
end

local function resolveSlot()
    local candidates = slotCandidates()

    for index = 1, #candidates do
        local slot = candidates[index]
        local ok, position = GetPosAlongGpsTypeRoute(true, 0.0, slot)

        if ok and position then
            return slot
        end
    end

    return nil
end

local walkSlot

local walking = false

function Map.routeSampler.collect()
    if not available then
        return nil
    end

    local slot = resolveSlot()

    lastSlot = slot

    if not slot then
        return nil
    end

    return walkSlot(slot, routeDestination())
end

function Map.routeSampler.collectFromSlot(slot, target)
    if not available then
        return nil
    end

    local ok, position = GetPosAlongGpsTypeRoute(true, 0.0, slot)

    if not (ok and position) then
        return nil
    end

    return walkSlot(slot, target)
end

walkSlot = function(slot, target)
    if walking then
        return nil
    end

    walking = true

    local settings = Map.config.route

    local limit = settings.maxSampleDistance

    local points = {}
    local distance = 0.0
    local samples = 0

    local coincident = 0

    SetBigmapActive(true, false)
    Wait(0)

    while distance <= limit and #points < settings.maxPoints do
        local ok, position = GetPosAlongGpsTypeRoute(
            true,
            distance,
            slot
        )

        if not ok or not position then
            break
        end

        local previous = points[#points]

        if not previous then
            points[1] = { x = position.x, y = position.y, z = position.z }
        else
            local dx = position.x - previous.x
            local dy = position.y - previous.y

            if dx * dx + dy * dy <= MIN_SEPARATION_SQUARED then
                coincident = coincident + 1

                if isAtDestination(previous, target)
                    or coincident >= MAX_COINCIDENT_SAMPLES
                then
                    break
                end
            else
                coincident = 0

                points[#points + 1] = {
                    x = position.x,
                    y = position.y,
                    z = position.z,
                }
            end
        end

        distance = distance + settings.sampleStepMetres
        samples = samples + 1

        if samples % settings.yieldEverySamples == 0 then
            Wait(0)
        end
    end

    SetBigmapActive(false, false)

    walking = false

    if #points < 2 then
        return nil
    end

    return points
end
