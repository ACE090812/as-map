Map.nativeBlips = {}

local ID_PREFIX = 'native:'

local WAYPOINT_SPRITE = 8

local ENTITY_BLIP_TYPES = {
    [1] = true,
    [2] = true,
    [3] = true,
}

local AREAL_BLIP_TYPES = {
    [7] = 'radius',
    [11] = 'area',
}

local ZONE_ID_PREFIX = 'nativeArea:'

local COORD_EPSILON = 0.01

local EXTENT_EPSILON = 0.01

local titles = {}

local extents = {}

local tracked = {}

local trackedZones = {}

local movingHandles = {}

local fallbackTitles = {}

local SPRITE_TITLES = {
    [1] = 'Standard',
    [2] = 'Lower',
    [3] = 'Police',
    [4] = 'Wanted',
    [5] = 'Area',
    [6] = 'Centre',
    [7] = 'North',
    [8] = 'Waypoint',
    [9] = 'Radius',
    [11] = 'Weapon',
    [12] = 'Weapon',
    [36] = 'Cable Car',
    [38] = 'Race',
    [40] = 'Safehouse',
    [41] = 'Police',
    [42] = 'Police Chase',
    [43] = 'Police Helicopter',
    [50] = 'Car Theft',
    [51] = 'Drugs',
    [52] = 'Store',
    [54] = 'Player',
    [56] = 'Police Patrol',
    [58] = 'Wanted',
    [59] = 'Heist',
    [60] = 'Police Station',
    [61] = 'Hospital',
    [62] = 'Assassin',
    [63] = 'Helicopter',
    [66] = 'Armored Truck',
    [67] = 'Bumps',
    [68] = 'Stranger',
    [71] = 'Barber',
    [72] = 'Los Santos Customs',
    [73] = 'Clothing',
    [75] = 'Tattoo',
    [76] = 'Armenian',
    [77] = 'Lester',
    [78] = 'Michael',
    [79] = 'Trevor',
    [80] = 'Jewelry Heist',
    [84] = 'Rampage',
    [85] = 'Vinewood Tours',
    [86] = 'Lamar',
    [88] = 'Franklin',
    [89] = 'Chinese',
    [90] = 'Flight School',
    [93] = 'Bar',
    [94] = 'Base Jump',
    [96] = 'Humane Labs',
    [99] = 'Car Wash',
    [100] = 'Comedy Club',
    [102] = 'Darts',
    [103] = 'Docks Heist',
    [108] = 'Bank',
    [109] = 'Golf',
    [110] = 'Ammu-Nation',
    [112] = 'Highway Patrol',
    [119] = 'Paleto Bank',
    [120] = 'Shooting Range',
    [122] = 'Strip Club',
    [126] = 'Off-Road Race',
    [127] = 'Police',
    [133] = 'Snitch',
    [135] = 'Cinema',
    [136] = 'Music Venue',
    [137] = 'Police Station',
    [140] = 'Weed',
    [141] = 'Hunting',
    [142] = 'Pool',
    [147] = 'Arms Dealing',
    [149] = 'Celebrity Theft',
    [162] = 'Point of Interest',
    [173] = 'Minigun',
    [175] = 'Grenade Launcher',
    [184] = 'Vagos',
    [188] = 'Bikers',
    [197] = 'Psychiatrist',
    [198] = 'Epsilon',
    [205] = 'Omega',
    [225] = 'Gang Vehicle',
    [226] = 'Biker Vehicle',
    [227] = 'Police Vehicle',
    [229] = 'Gun Van',
    [251] = 'Arms Dealing Air',
    [266] = 'Property',
    [267] = 'Gang',
    [269] = 'Altruist',
    [273] = 'Dead',
    [303] = 'Boost',
    [304] = 'Devin',
    [305] = 'Dock',
    [306] = 'Garage',
    [307] = 'Golf',
    [308] = 'Hangar',
    [310] = 'Helipad',
    [311] = 'Jerry Can',
    [312] = 'Mask Shop',
    [313] = 'Heist Setup',
    [314] = 'Incapacitated',
    [315] = 'Spawn',
    [317] = 'Garage',
    [318] = 'Garage For Sale',
    [326] = 'Off-Road Vehicle',
    [348] = 'Bat',
    [350] = 'Capture',
    [351] = 'Last Team Standing',
    [352] = 'Boat',
    [353] = 'Capture',
    [354] = 'GTA Race',
    [355] = 'Plane',
    [356] = 'Jet',
    [357] = 'Garage',
    [358] = 'Sports',
    [359] = 'Garage For Sale',
    [360] = 'Protection',
    [361] = 'Jerry Can',
    [362] = 'GTA Race',
    [363] = 'Team Deathmatch',
    [364] = 'Arm Wrestling',
    [365] = 'Ammu-Nation',
    [367] = 'Possession',
    [368] = 'Race Finish',
    [369] = 'Stacked Safety',
    [370] = 'Creative Studio',
    [371] = 'Hooker',
    [372] = 'GTA Race',
    [373] = 'Survival',
    [374] = 'Movie',
    [375] = 'Taxi',
    [376] = 'Police Occupation',
    [377] = 'Police Presence',
    [378] = 'Player',
    [380] = 'Capture the Flag',
    [381] = 'Last Team Standing',
    [382] = 'Boat',
    [383] = 'Capture the Flag',
    [384] = 'Gang Attack',
    [385] = 'GTA Race',
    [386] = 'Plane',
    [387] = 'Jet',
    [388] = 'Center',
    [389] = 'Trailer',
    [390] = 'VIP',
    [398] = 'Drop-off',
    [400] = 'Package',
    [401] = 'Capture',
    [402] = 'Jerry Can',
    [403] = 'Boost',
    [404] = 'Docks',
    [405] = 'Garage',
    [407] = 'Hangar',
    [408] = 'Helipad',
    [409] = 'Jerry Can',
    [410] = 'Mask',
    [411] = 'Heist',
    [415] = 'Spawn Point',
    [417] = 'Garage',
    [419] = 'Garage For Sale',
    [421] = 'Off-Road',
    [423] = 'Textiles',
    [424] = 'Vehicle',
    [425] = 'Bar',
    [426] = 'Drug Package',
    [427] = 'Package',
    [428] = 'Capture',
    [430] = 'Rampage',
    [431] = 'Vinewood Tours',
    [432] = 'Lamar',
    [433] = 'Franklin',
    [434] = 'Chinese',
    [435] = 'Flight School',
    [436] = 'Eye in the Sky',
    [437] = 'Air Hockey',
    [438] = 'Bar',
    [439] = 'Base Jump',
    [440] = 'Basketball',
    [441] = 'Biolab Heist',
    [442] = 'Bowling',
    [443] = 'Burger Shot',
    [444] = 'Cabaret Club',
    [445] = 'Car Wash',
    [446] = 'Cluckin Bell',
    [447] = 'Comedy Club',
    [448] = 'Darts',
    [449] = 'Docks Heist',
    [450] = 'FBI',
    [451] = 'FBI',
    [452] = 'Finale Bank Heist',
    [453] = 'Financial',
    [454] = 'Golf',
    [455] = 'Gun Shop',
    [456] = 'Highway Patrol',
    [457] = 'Hospital',
    [458] = 'Jeremys',
    [459] = 'Jewelry',
    [460] = 'Lesters',
    [461] = 'Letter S',
    [462] = 'Liquor Store',
    [463] = 'Michael',
    [464] = 'Mime',
    [465] = 'Movie Studio',
    [466] = 'Music Venue',
    [467] = 'Pizza',
    [468] = 'Police Station',
    [469] = 'Rural Bank Heist',
    [470] = 'Shooting Range',
    [471] = 'Solomon',
    [472] = 'Strip Club',
    [473] = 'Tennis',
    [474] = 'Trevor',
    [475] = 'Triathlon',
    [477] = 'Warehouse',
    [478] = 'Warehouse For Sale',
    [479] = 'Office',
    [480] = 'Office For Sale',
    [481] = 'Clubhouse',
    [482] = 'Clubhouse For Sale',
    [484] = 'Apartment',
    [485] = 'Apartment For Sale',
    [488] = 'Yacht',
    [489] = 'Garage',
    [490] = 'Garage For Sale',
    [492] = 'Repair',
    [494] = 'Crate Drop',
    [496] = 'Race',
    [498] = 'Deathmatch',
    [500] = 'Armored Truck',
    [501] = 'Race',
    [502] = 'Motorcycle Club',
    [503] = 'Motorcycle Club',
    [504] = 'Motorcycle Club',
    [505] = 'Motorcycle Club',
    [506] = 'Motorcycle Club',
    [507] = 'Motorcycle Club',
    [508] = 'Motorcycle Club',
    [512] = 'Biker Business',
    [513] = 'Biker Business',
    [514] = 'Biker Business',
    [515] = 'Biker Business',
    [516] = 'Biker Business',
    [521] = 'Document Forgery',
    [522] = 'Weed Farm',
    [523] = 'Vehicle Warehouse',
    [524] = 'Office Garage',
    [525] = 'Office Garage',
    [526] = 'Office Garage',
    [527] = 'Office Garage',
    [529] = 'Arena War',
    [532] = 'Battery',
    [534] = 'Dead Drop',
    [535] = 'Warehouse',
    [546] = 'Pickup',
    [557] = 'Arena War',
    [558] = 'Arena War',
    [559] = 'Arena War',
    [560] = 'Arena War',
    [561] = 'Arena War',
    [562] = 'Arena War',
    [563] = 'Arena War',
    [564] = 'Arena War',
    [565] = 'Arena War',
    [566] = 'Arena War',
    [567] = 'Arena War',
    [568] = 'Arena War',
    [569] = 'Arena War',
    [570] = 'Arena War',
    [571] = 'Arena War',
    [572] = 'Arena War',
    [573] = 'Arena War',
    [574] = 'Ruiner 2000',
    [575] = 'Blow Up',
    [576] = 'Race',
    [578] = 'Alien',
    [579] = 'Garage',
    [580] = 'Casino',
    [590] = 'Arcade',
    [597] = 'Agency',
    [598] = 'Agency',
    [600] = 'Auto Shop',
    [601] = 'Car Meet',
    [614] = 'Salvage Yard',
    [617] = 'Bail Office',
    [618] = 'Garment Factory',
    [620] = 'McKenzie Hangar',
    [679] = 'Smoke on the Water',
    [780] = 'LS Car Meet',
    [826] = 'FBI',
}

local function fallbackTitle(sprite)
    local title = fallbackTitles[sprite]

    if not title then
        title = SPRITE_TITLES[sprite] or ('Marker ' .. math.floor(tonumber(sprite) or 0))
        fallbackTitles[sprite] = title
    end

    return title
end

function Map.nativeBlips.setTitle(blip, title)
    if type(blip) ~= 'number' or type(title) ~= 'string' or title == '' then
        return false
    end

    if #title > 256 then
        title = title:sub(1, 256)
    end

    titles[blip] = title

    local entry = tracked[blip]

    if entry and entry.title ~= title then
        entry.title = title

        Map.blips.upsert({
            id = entry.id,
            title = title,
        })
    end

    return true
end

function Map.nativeBlips.getTitle(blip)
    if type(blip) ~= 'number' then
        return nil
    end

    return titles[blip]
end

local function isExtent(value)
    return type(value) == 'number'
        and value == value
        and value > 0.0
        and value < 100000.0
end

function Map.nativeBlips.setRadius(blip, radius)
    if type(blip) ~= 'number' or not isExtent(radius) then
        return false
    end

    extents[blip] = { shape = 'radius', radius = radius }

    return true
end

function Map.nativeBlips.setArea(blip, width, height)
    if type(blip) ~= 'number' or not isExtent(width) or not isExtent(height) then
        return false
    end

    extents[blip] = { shape = 'area', width = width, height = height }

    return true
end

function Map.nativeBlips.clearExtent(blip)
    if type(blip) ~= 'number' then
        return false
    end

    extents[blip] = nil

    return true
end

function Map.nativeBlips.getExtent(blip)
    if type(blip) ~= 'number' then
        return nil
    end

    return extents[blip]
end

local function shouldSkip(blip, sprite, playerBlip)
    local settings = Map.config.nativeBlips

    if settings.skipPlayerBlip and blip == playerBlip then
        return true
    end

    if settings.skipWaypoint and sprite == WAYPOINT_SPRITE then
        return true
    end

    if settings.skipShortRange and IsBlipShortRange(blip) then
        return true
    end

    if settings.skipTransparent and GetBlipAlpha(blip) == 0 then
        return true
    end

    return false
end

local function hasChanged(entry, sprite, color, title, moving, coords)
    if entry.sprite ~= sprite
        or entry.color ~= color
        or entry.title ~= title
        or entry.moving ~= moving
    then
        return true
    end

    if moving then
        return false
    end

    return math.abs(entry.coords.x - coords.x) > COORD_EPSILON
        or math.abs(entry.coords.y - coords.y) > COORD_EPSILON
end

local function tessellate(extent, coords)
    if extent.shape == 'area' then
        local halfWidth = extent.width * 0.5
        local halfHeight = extent.height * 0.5

        return {
            { x = coords.x - halfWidth, y = coords.y - halfHeight },
            { x = coords.x + halfWidth, y = coords.y - halfHeight },
            { x = coords.x + halfWidth, y = coords.y + halfHeight },
            { x = coords.x - halfWidth, y = coords.y + halfHeight },
        }
    end

    local segments = Map.config.nativeBlips.circleSegments
    local points = {}

    for index = 0, segments - 1 do
        local angle = (index / segments) * math.pi * 2.0

        points[index + 1] = {
            x = coords.x + math.cos(angle) * extent.radius,
            y = coords.y + math.sin(angle) * extent.radius,
        }
    end

    return points
end

local function zoneHasChanged(entry, color, title, extent, coords)
    if entry.color ~= color or entry.title ~= title then
        return true
    end

    if entry.shape ~= extent.shape then
        return true
    end

    if extent.shape == 'radius' then
        if math.abs(entry.radius - extent.radius) > EXTENT_EPSILON then
            return true
        end
    elseif math.abs(entry.width - extent.width) > EXTENT_EPSILON
        or math.abs(entry.height - extent.height) > EXTENT_EPSILON
    then
        return true
    end

    return math.abs(entry.coords.x - coords.x) > COORD_EPSILON
        or math.abs(entry.coords.y - coords.y) > COORD_EPSILON
        or math.abs(entry.coords.z - coords.z) > COORD_EPSILON
end

local function syncZone(blip, color, title, extent, raw)
    local entry = trackedZones[blip]
    local coords = Map.toCoords(raw)

    if entry and not zoneHasChanged(entry, color, title, extent, coords) then
        return
    end

    local id = entry and entry.id or (ZONE_ID_PREFIX .. blip)

    local applied = Map.zones.upsert({
        id = id,
        title = title,
        color = color,
        points = tessellate(extent, coords),
        minZ = coords.z - 2.0,
        maxZ = coords.z + 30.0,
    })

    if not applied then
        return
    end

    trackedZones[blip] = {
        id = id,
        color = color,
        title = title,
        shape = extent.shape,
        radius = extent.radius,
        width = extent.width,
        height = extent.height,
        coords = coords,
    }
end

local function dropZone(blip)
    local entry = trackedZones[blip]

    if not entry then
        return
    end

    Map.zones.remove(entry.id)
    trackedZones[blip] = nil
end

local function scan()
    local settings = Map.config.nativeBlips
    local playerBlip = settings.skipPlayerBlip and GetMainPlayerBlipId() or -1
    local seen = {}
    local moving = {}
    local upserts = {}
    local removals = {}

    for sprite = 0, settings.maxSpriteId do
        local blip = GetFirstBlipInfoId(sprite)

        while DoesBlipExist(blip) do
            if not shouldSkip(blip, sprite, playerBlip) then
                local raw = GetBlipInfoIdCoord(blip)

                if Map.isCoords(raw) then
                    local color = GetBlipColour(blip)
                    local title = titles[blip] or fallbackTitle(sprite)
                    local blipType = GetBlipInfoIdType(blip)
                    local extent = settings.areasEnabled
                        and AREAL_BLIP_TYPES[blipType]
                        and extents[blip]
                        or nil
                    local isMoving = ENTITY_BLIP_TYPES[blipType] == true
                    local entry = tracked[blip]

                    seen[blip] = true

                    if extent then
                        if entry then
                            removals[#removals + 1] = entry.id
                            tracked[blip] = nil
                        end

                        syncZone(blip, color, title, extent, raw)

                        goto continue
                    end

                    if trackedZones[blip] then
                        dropZone(blip)
                    end

                    if isMoving then
                        moving[#moving + 1] = blip
                    end

                    if not entry then
                        entry = {
                            id = ID_PREFIX .. blip,
                            sprite = sprite,
                            color = color,
                            title = title,
                            moving = isMoving,
                            coords = Map.toCoords(raw),
                        }
                        tracked[blip] = entry

                        upserts[#upserts + 1] = {
                            id = entry.id,
                            blipId = sprite,
                            color = color,
                            title = title,
                            coords = entry.coords,
                            scale = 1.0,
                            dynamic = isMoving,
                        }
                    elseif hasChanged(entry, sprite, color, title, isMoving, raw)
                    then
                        entry.sprite = sprite
                        entry.color = color
                        entry.title = title
                        entry.moving = isMoving
                        entry.coords = Map.toCoords(raw)

                        upserts[#upserts + 1] = {
                            id = entry.id,
                            blipId = sprite,
                            color = color,
                            title = title,
                            coords = entry.coords,
                            dynamic = isMoving,
                        }
                    end
                end
            end

            ::continue::

            blip = GetNextBlipInfoId(sprite)
        end

        if sprite % settings.yieldEverySprites == 0 then
            Wait(0)
        end
    end

    for blip, entry in pairs(tracked) do
        if not seen[blip] then
            removals[#removals + 1] = entry.id
            tracked[blip] = nil
            titles[blip] = nil
            extents[blip] = nil
        end
    end

    for blip in pairs(trackedZones) do
        if not seen[blip] then
            dropZone(blip)
            titles[blip] = nil
            extents[blip] = nil
        end
    end

    movingHandles = moving

    Map.blips.upsertBatch(upserts)
    Map.blips.removeBatch(removals)
end

local function trackMoving()
    local count = #movingHandles

    if count == 0 then
        return
    end

    local updates = {}

    for index = 1, count do
        local blip = movingHandles[index]
        local entry = tracked[blip]

        if entry and DoesBlipExist(blip) then
            local raw = GetBlipInfoIdCoord(blip)
            local stored = entry.coords

            if Map.isCoords(raw)
                and (math.abs(stored.x - raw.x) > COORD_EPSILON
                    or math.abs(stored.y - raw.y) > COORD_EPSILON)
            then
                local coords = Map.toCoords(raw)

                entry.coords = coords
                updates[#updates + 1] = { id = entry.id, coords = coords }
            end
        end
    end

    if #updates > 0 then
        Map.blips.updateDynamicCoordsBatch(updates)
    end
end

function Map.nativeBlips.stats()
    local count = 0

    for _ in pairs(tracked) do
        count = count + 1
    end

    return count, #movingHandles
end

CreateThread(function()
    while true do
        local settings = Map.config.nativeBlips

        if settings.enabled and Map.state.ready and Map.isAnySurfaceVisible() then
            scan()
            Wait(settings.scanIntervalMs)
        else
            Wait(1000)
        end
    end
end)

CreateThread(function()
    while true do
        local settings = Map.config.nativeBlips

        if settings.enabled and Map.state.ready and Map.isAnySurfaceVisible() then
            trackMoving()
            Wait(settings.moveIntervalMs)
        else
            Wait(500)
        end
    end
end)

Map.onReplay(function()
    for blip, entry in pairs(tracked) do
        entry.title = titles[blip] or entry.title
    end
end)
