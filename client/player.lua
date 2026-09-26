Map.player = {}

local HEADING_SIGN = -1.0

function Map.player.getMessage()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    if not Map.isFiniteNumber(coords.x)
        or not Map.isFiniteNumber(coords.y)
        or not Map.isFiniteNumber(coords.z)
    then
        return nil
    end

    local vehicle = GetVehiclePedIsIn(ped, false)

    local inVehicle = false
    local speedEntity = ped

    if vehicle ~= 0 and DoesEntityExist(vehicle) then
        inVehicle = true
        speedEntity = vehicle
    end

    local speed = GetEntitySpeed(speedEntity)

    if not Map.isFiniteNumber(speed) or speed < 0 then
        speed = 0.0
    end

    return {
        type = 'map:player',
        coords = {
            x = coords.x,
            y = coords.y,
            z = coords.z,
        },
        heading = HEADING_SIGN * math.rad(GetEntityHeading(ped)),
        camHeading = HEADING_SIGN * math.rad(GetGameplayCamRot(2).z),
        inVehicle = inVehicle,
        speed = speed,
    }
end

local COORD_EPSILON = 0.01
local ANGLE_EPSILON = 0.001
local SPEED_EPSILON = 0.05

local sent = {}

local function hasChanged(message)
    if sent.x == nil then
        return true
    end

    if sent.inVehicle ~= message.inVehicle then
        return true
    end

    local coords = message.coords

    return math.abs(coords.x - sent.x) > COORD_EPSILON
        or math.abs(coords.y - sent.y) > COORD_EPSILON
        or math.abs(coords.z - sent.z) > COORD_EPSILON
        or math.abs(message.heading - sent.heading) > ANGLE_EPSILON
        or math.abs(message.camHeading - sent.camHeading) > ANGLE_EPSILON
        or math.abs(message.speed - sent.speed) > SPEED_EPSILON
end

local function remember(message)
    sent.x = message.coords.x
    sent.y = message.coords.y
    sent.z = message.coords.z
    sent.heading = message.heading
    sent.camHeading = message.camHeading
    sent.inVehicle = message.inVehicle
    sent.speed = message.speed
end

local function forget()
    sent.x = nil
end


local function send(message)
    remember(message)

    return Map.send(message)
end

function Map.player.sendNow()
    local message = Map.player.getMessage()

    if not message then
        return false
    end

    return send(message)
end

Map.onReplay(Map.player.sendNow)

CreateThread(function()
    while true do
        if Map.state.ready and Map.isAnySurfaceVisible() then
            local message = Map.player.getMessage()

            if message and hasChanged(message) then
                send(message)
            end

            Wait(Map.config.updateIntervalMs)
        else
            forget()
            Wait(Map.config.idleIntervalMs)
        end
    end
end)
