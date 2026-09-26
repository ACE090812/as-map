Map.identity = {}

local sent = {
    name = nil,
    serverId = nil,
    street = nil,
    playersOnline = nil,
}

local override = nil

local playersOnline = nil

local PLACEHOLDER_NAMES = {
    ['**Invalid**'] = true,
    ['** Invalid **'] = true,
    ['unknown'] = true,
    ['Unknown'] = true,
    ['player'] = true,
    ['Player'] = true,
}

local MAX_LENGTH = 64

local function clean(value)
    if type(value) ~= 'string' then
        return nil
    end

    local trimmed = value:match('^%s*(.-)%s*$')

    if trimmed == '' or PLACEHOLDER_NAMES[trimmed] then
        return nil
    end

    if #trimmed > MAX_LENGTH then
        trimmed = trimmed:sub(1, MAX_LENGTH)
    end

    return trimmed
end

local function readName()
    if override then
        return override
    end

    return clean(GetPlayerName(PlayerId()))
end

local function readServerId()
    local id = GetPlayerServerId(PlayerId())

    if type(id) ~= 'number' or id < 1 then
        return nil
    end

    return id
end

local function readStreet(ped)
    local coords = GetEntityCoords(ped)
    local streetHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local street = streetHash ~= 0 and clean(GetStreetNameFromHashKey(streetHash)) or nil

    if street then
        return street
    end

    local zoneKey = GetNameOfZone(coords.x, coords.y, coords.z)

    if type(zoneKey) ~= 'string' or zoneKey == '' or not DoesTextLabelExist(zoneKey) then
        return nil
    end

    local zone = clean(GetLabelText(zoneKey))

    if zone and zone ~= 'NULL' and zone ~= zoneKey then
        return zone
    end

    return nil
end

function Map.identity.send()
    return Map.send({
        type = 'map:identity',
        name = sent.name,
        serverId = sent.serverId,
        street = sent.street,
        playersOnline = sent.playersOnline,
    })
end

local function commit(name, serverId, street, count)
    if sent.name == name
        and sent.serverId == serverId
        and sent.street == street
        and sent.playersOnline == count
    then
        return false
    end

    sent.name = name
    sent.serverId = serverId
    sent.street = street
    sent.playersOnline = count

    Map.identity.send()
    Map.debug(('identity: %s (id %s) on %s, %s online'):format(
        tostring(name), tostring(serverId), tostring(street), tostring(count)
    ))

    return true
end

local function refresh()
    local ped = PlayerPedId()
    local street = DoesEntityExist(ped) and readStreet(ped) or sent.street

    return commit(readName(), readServerId(), street, playersOnline)
end

function Map.identity.setName(value)
    if value ~= nil and type(value) ~= 'string' then
        return false
    end

    override = value == nil and nil or clean(value)

    refresh()

    return true
end

function Map.identity.getState()
    return {
        name = sent.name,
        override = override,
        gameName = GetPlayerName(PlayerId()),
        serverId = sent.serverId,
        street = sent.street,
        playersOnline = sent.playersOnline,
    }
end

RegisterNetEvent('as-map:playersOnline', function(count)
    if type(count) ~= 'number' or count ~= count or count < 1 then
        return
    end

    playersOnline = math.floor(count)

    refresh()
end)

Map.onReplay(function()
    if not refresh() then
        Map.identity.send()
    end

    TriggerServerEvent('as-map:requestPlayersOnline')
end)

CreateThread(function()
    while true do
        Wait(Map.config.identity.pollIntervalMs)

        if Map.state.ready and Map.isAnySurfaceVisible() then
            refresh()
        end
    end
end)
