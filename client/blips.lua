Map.blips = {}

local MAX_TITLE_LENGTH = 256
local MAX_ICON_ID = 10000
local MIN_SCALE = 0.05
local MAX_SCALE = 10.0

local SNAPSHOT_CHUNK = 1000

local REQUIRED_FIELDS = { 'blipId', 'color', 'coords', 'scale', 'title' }

local records = {}

local function reject(id, reason)
    Map.debug(('blip %s rejected: %s'):format(tostring(id), reason))

    return false
end

local function sendChunks(key, items)
    local total = #items

    for start = 1, total, SNAPSHOT_CHUNK do
        local chunk = {}

        for index = start, math.min(start + SNAPSHOT_CHUNK - 1, total) do
            chunk[#chunk + 1] = items[index]
        end

        Map.send({
            type = 'map:blips',
            [key] = chunk,
        })
    end
end

local function validateFields(update)
    if update.blipId ~= nil then
        if not Map.isIntegerNumber(update.blipId)
            or update.blipId < 0
            or update.blipId > MAX_ICON_ID
        then
            return false, 'blipId must be an integer 0-' .. MAX_ICON_ID
        end
    end

    if update.color ~= nil then
        local colorType = type(update.color)

        if colorType ~= 'number' and colorType ~= 'string' then
            return false, 'color must be a number or a CSS colour string'
        end

        if colorType == 'number' and not Map.isIntegerNumber(update.color) then
            return false, 'numeric color must be a whole-number palette index'
        end
    end

    if update.title ~= nil then
        if type(update.title) ~= 'string' or #update.title > MAX_TITLE_LENGTH then
            return false, 'title must be a string of at most ' .. MAX_TITLE_LENGTH
        end
    end

    if update.description ~= nil then
        if type(update.description) ~= 'string'
            or #update.description > MAX_TITLE_LENGTH
        then
            return false, 'description must be a string of at most ' .. MAX_TITLE_LENGTH
        end
    end

    if update.coords ~= nil and not Map.isCoords(update.coords) then
        return false, 'coords must be { x, y, z? } finite numbers'
    end

    if update.scale ~= nil then
        if not Map.isFiniteNumber(update.scale)
            or update.scale < MIN_SCALE
            or update.scale > MAX_SCALE
        then
            return false, ('scale must be %s-%s'):format(MIN_SCALE, MAX_SCALE)
        end
    end

    if update.dynamic ~= nil and type(update.dynamic) ~= 'boolean' then
        return false, 'dynamic must be a boolean'
    end

    return true
end

local function commit(update)
    if type(update) ~= 'table' then
        reject('?', 'update must be a table')

        return nil
    end

    if not Map.isId(update.id) then
        reject(update.id, 'id must be a non-empty string of at most 128 characters')

        return nil
    end

    local ok, reason = validateFields(update)

    if not ok then
        reject(update.id, reason)

        return nil
    end

    local record = records[update.id]
    local isNew = record == nil

    if isNew then
        record = {}
    end

    for key, value in pairs(update) do
        record[key] = value
    end

    record.id = update.id

    if update.coords ~= nil then
        record.coords = Map.toCoords(update.coords)
    end

    if isNew then
        for index = 1, #REQUIRED_FIELDS do
            local field = REQUIRED_FIELDS[index]

            if record[field] == nil then
                reject(update.id, 'a new blip needs ' .. field)

                return nil
            end
        end
    end

    records[update.id] = record

    return record
end

function Map.blips.upsert(update)
    local record = commit(update)

    if not record then
        return false
    end

    Map.send({
        type = 'map:blips',
        upsert = { record },
    })

    return true
end

function Map.blips.upsertBatch(updates)
    if type(updates) ~= 'table' then
        return 0
    end

    local upsert = {}

    for index = 1, #updates do
        local record = commit(updates[index])

        if record then
            upsert[#upsert + 1] = record
        end
    end

    if #upsert == 0 then
        return 0
    end

    sendChunks('upsert', upsert)

    return #upsert
end

function Map.blips.updateDynamicCoords(id, coords)
    local record = records[id]

    if not record then
        return reject(id, 'not registered')
    end

    if record.dynamic ~= true then
        return reject(id, 'not registered as dynamic = true')
    end

    local normalised = Map.toCoords(coords)

    if not normalised then
        return reject(id, 'coords must be { x, y, z? } finite numbers')
    end

    record.coords = normalised

    Map.send({
        type = 'map:blips',
        upsert = {
            { id = id, coords = record.coords },
        },
    })

    return true
end

function Map.blips.updateDynamicCoordsBatch(updates)
    if type(updates) ~= 'table' then
        return 0
    end

    local upsert = {}

    for index = 1, #updates do
        local update = updates[index]
        local record = type(update) == 'table' and records[update.id] or nil

        if record and record.dynamic == true then
            local normalised = Map.toCoords(update.coords)

            if normalised then
                record.coords = normalised
                upsert[#upsert + 1] = { id = update.id, coords = normalised }
            end
        end
    end

    if #upsert == 0 then
        return 0
    end

    Map.send({
        type = 'map:blips',
        upsert = upsert,
    })

    return #upsert
end

function Map.blips.remove(id)
    if not records[id] then
        return false
    end

    records[id] = nil

    Map.send({
        type = 'map:blips',
        remove = { id },
    })

    return true
end

function Map.blips.removeBatch(ids)
    if type(ids) ~= 'table' then
        return 0
    end

    local remove = {}

    for index = 1, #ids do
        local id = ids[index]

        if records[id] ~= nil then
            records[id] = nil
            remove[#remove + 1] = id
        end
    end

    if #remove == 0 then
        return 0
    end

    sendChunks('remove', remove)

    return #remove
end

function Map.blips.snapshot()
    local snapshot = {}

    for _, record in pairs(records) do
        snapshot[#snapshot + 1] = record
    end

    return snapshot
end

function Map.blips.sendSnapshot()
    local snapshot = Map.blips.snapshot()

    if #snapshot == 0 then
        return
    end

    sendChunks('upsert', snapshot)
end

Map.onReplay(Map.blips.sendSnapshot)
