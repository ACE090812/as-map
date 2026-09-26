Map.zones = {}

local MAX_TITLE_LENGTH = 256
local MIN_POINTS = 3
local MAX_POINTS = 256
local MAX_ABSOLUTE_COORDINATE = 10000000.0

local SNAPSHOT_CHUNK = 64
local SNAPSHOT_POINT_BUDGET = 4000

local REQUIRED_FIELDS = { 'color', 'points', 'title' }

local DEFAULT_BAND_HEIGHT = 40.0

local RING_CLOSE_EPSILON = 0.01

local records = {}

local function reject(id, reason)
    Map.debug(('zone %s rejected: %s'):format(tostring(id), reason))

    return false
end

local function normaliseRing(points)
    if type(points) ~= 'table' then
        return nil, 'points must be an array of { x, y, z? }'
    end

    local ring = {}

    for index = 1, #points do
        local point = Map.toCoords(points[index])

        if not point then
            return nil, ('point %d must be { x, y, z? } finite numbers'):format(index)
        end

        ring[#ring + 1] = point
    end

    local count = #ring

    if count >= 2 then
        local first = ring[1]
        local last = ring[count]

        if math.abs(first.x - last.x) < RING_CLOSE_EPSILON
            and math.abs(first.y - last.y) < RING_CLOSE_EPSILON
        then
            ring[count] = nil
            count = count - 1
        end
    end

    if count < MIN_POINTS then
        return nil, ('a ring needs at least %d distinct points'):format(MIN_POINTS)
    end

    if count > MAX_POINTS then
        return nil, ('a ring may have at most %d points'):format(MAX_POINTS)
    end

    return ring
end

local function deriveBand(record)
    if record.minZ ~= nil and record.maxZ ~= nil then
        return
    end

    local lowest = nil
    local highest = nil

    for index = 1, #record.points do
        local z = record.points[index].z

        if z ~= nil then
            lowest = lowest == nil and z or math.min(lowest, z)
            highest = highest == nil and z or math.max(highest, z)
        end
    end

    if lowest == nil then
        Map.debug(('zone %s has no z on any point; its band is 0 to %.0f')
            :format(record.id, DEFAULT_BAND_HEIGHT))

        lowest = 0.0
        highest = 0.0
    end

    record.minZ = record.minZ or lowest
    record.maxZ = record.maxZ or (highest + DEFAULT_BAND_HEIGHT)

    if record.maxZ - record.minZ < DEFAULT_BAND_HEIGHT then
        record.maxZ = record.minZ + DEFAULT_BAND_HEIGHT
    end
end

local function validateFields(update)
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

    for _, field in ipairs({ 'minZ', 'maxZ' }) do
        local value = update[field]

        if value ~= nil then
            if not Map.isFiniteNumber(value)
                or math.abs(value) > MAX_ABSOLUTE_COORDINATE
            then
                return false, field .. ' must be a finite number'
            end
        end
    end

    return true
end

function Map.zones.upsert(update)
    if type(update) ~= 'table' then
        return reject('?', 'update must be a table')
    end

    if not Map.isId(update.id) then
        return reject(update.id, 'id must be a non-empty string of at most 128 characters')
    end

    local ok, reason = validateFields(update)

    if not ok then
        return reject(update.id, reason)
    end

    local ring = nil

    if update.points ~= nil then
        ring, reason = normaliseRing(update.points)

        if not ring then
            return reject(update.id, reason)
        end
    end

    local existing = records[update.id]
    local isNew = existing == nil

    local record = {}

    if existing then
        for key, value in pairs(existing) do
            record[key] = value
        end
    end

    for key, value in pairs(update) do
        record[key] = value
    end

    record.id = update.id

    if ring then
        record.points = ring
    end

    if isNew then
        for index = 1, #REQUIRED_FIELDS do
            local field = REQUIRED_FIELDS[index]

            if record[field] == nil then
                return reject(update.id, 'a new zone needs ' .. field)
            end
        end
    end

    deriveBand(record)

    if record.maxZ < record.minZ then
        return reject(update.id, 'maxZ must not be below minZ')
    end

    records[update.id] = record

    Map.send({
        type = 'map:zones',
        upsert = { record },
    })

    return true
end

function Map.zones.remove(id)
    if not records[id] then
        return false
    end

    records[id] = nil

    Map.send({
        type = 'map:zones',
        remove = { id },
    })

    return true
end

function Map.zones.snapshot()
    local snapshot = {}

    for _, record in pairs(records) do
        snapshot[#snapshot + 1] = record
    end

    return snapshot
end

function Map.zones.sendSnapshot()
    local snapshot = Map.zones.snapshot()
    local total = #snapshot

    if total == 0 then
        return
    end

    local chunk = {}
    local points = 0

    local function flush()
        if #chunk == 0 then
            return
        end

        Map.send({
            type = 'map:zones',
            upsert = chunk,
        })

        chunk = {}
        points = 0
    end

    for index = 1, total do
        local record = snapshot[index]

        if #chunk > 0
            and (#chunk >= SNAPSHOT_CHUNK
                or points + #record.points > SNAPSHOT_POINT_BUDGET)
        then
            flush()
        end

        chunk[#chunk + 1] = record
        points = points + #record.points
    end

    flush()
end

Map.onReplay(Map.zones.sendSnapshot)
