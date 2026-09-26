Map.mugshot = {}

local handle = nil

local texture = nil

local revision = 0

local sourcePed = nil
local sourceModel = nil

local forced = false

local MUGSHOT_VARIANT_RETRIES = 10

local capturing = false

local warnedAboutTimeout = false
local warnedAboutRefusal = false

local transparent = nil

local variantRetriesLeft = 0

function Map.mugshot.send()
    return Map.send({
        type = 'map:mugshot',
        texture = texture,
        revision = revision,
    })
end

local function release(target)
    if target and target ~= 0 then
        UnregisterPedheadshot(target)
    end
end

local function register(ped, preferredOnly)
    local wantsTransparent = Map.config.mugshot.transparent

    local taken

    if wantsTransparent then
        taken = RegisterPedheadshotTransparent(ped)
    else
        taken = RegisterPedheadshot(ped)
    end

    if taken ~= 0 then
        return taken, wantsTransparent
    end

    if preferredOnly then
        return 0, wantsTransparent
    end

    if wantsTransparent then
        return RegisterPedheadshot(ped), false
    end

    return RegisterPedheadshotTransparent(ped), true
end

local function waitUntilReady(target)
    local deadline = GetGameTimer() + Map.config.mugshot.readyTimeoutMs

    while not IsPedheadshotReady(target) or not IsPedheadshotValid(target) do
        if GetGameTimer() > deadline then
            return false
        end

        Wait(0)
    end

    return true
end

local function capture(ped, preferredOnly)
    local taken, gotTransparent = register(ped, preferredOnly)

    if preferredOnly and taken == 0 then
        variantRetriesLeft = variantRetriesLeft - 1

        if variantRetriesLeft == 0 then
            Map.log(('mugshot: the %s variant did not become available; keeping ' ..
                'the %s one for this session. If this happens every session, set ' ..
                'Map.config.mugshot.transparent = %s to stop asking.'):format(
                Map.config.mugshot.transparent and 'transparent' or 'opaque',
                Map.config.mugshot.transparent and 'opaque' or 'transparent',
                tostring(not Map.config.mugshot.transparent)
            ))
        end

        return false
    end

    if taken == 0 then
        if not warnedAboutRefusal then
            warnedAboutRefusal = true

            Map.log('mugshot: the game refused a pedheadshot handle for both the ' ..
                'transparent and opaque variants, which means the client\'s headshot ' ..
                'pool is full. This resource holds at most two slots; something else ' ..
                'is registering headshots without unregistering them. Retrying.')
        end

        return false
    end

    warnedAboutRefusal = false

    if gotTransparent ~= Map.config.mugshot.transparent then
        variantRetriesLeft = MUGSHOT_VARIANT_RETRIES

        Map.log(('mugshot: the %s variant refused, captured with the %s one instead. ' ..
            'Retrying briefly; set Map.config.mugshot.transparent = %s in ' ..
            'client/config.lua to ask for that one first.'):format(
            Map.config.mugshot.transparent and 'transparent' or 'opaque',
            gotTransparent and 'transparent' or 'opaque',
            tostring(gotTransparent)
        ))
    end

    if not waitUntilReady(taken) then
        release(taken)

        if not warnedAboutTimeout then
            warnedAboutTimeout = true

            Map.debug(('mugshot: the game did not render a headshot within %d ms; ' ..
                'retrying while the ped is not being drawn is normal')
                :format(Map.config.mugshot.readyTimeoutMs))
        end

        return false
    end

    local name = GetPedheadshotTxdString(taken)

    if type(name) ~= 'string' or name == '' then
        release(taken)
        Map.debug('mugshot: the game gave a rendered headshot no texture name')

        return false
    end

    local previous = handle

    handle = taken
    texture = name
    transparent = gotTransparent
    if gotTransparent == Map.config.mugshot.transparent then
        if variantRetriesLeft > 0 then
            Map.log(('mugshot: the %s variant became available; the avatar is now ' ..
                'the one config asked for.'):format(
                gotTransparent and 'transparent' or 'opaque'
            ))
        end

        variantRetriesLeft = 0
    end

    revision = revision + 1
    sourcePed = ped
    sourceModel = GetEntityModel(ped)
    warnedAboutTimeout = false

    Map.mugshot.send()
    Map.debug(('mugshot: %s (revision %d)'):format(tostring(texture), revision))

    if previous then
        SetTimeout(Map.config.mugshot.releaseGraceMs, function()
            release(previous)
        end)
    end

    return true
end

local function isStale(ped)
    return forced
        or texture == nil
        or handle == nil
        or not IsPedheadshotValid(handle)
        or ped ~= sourcePed
        or GetEntityModel(ped) ~= sourceModel
end

function Map.mugshot.refresh()
    forced = true

    return true
end

function Map.mugshot.getState()
    return {
        texture = texture,
        revision = revision,
        transparent = transparent,
        requestedTransparent = Map.config.mugshot.transparent,
        variantRetriesLeft = variantRetriesLeft,
        valid = handle ~= nil and IsPedheadshotValid(handle),
        url = texture and ('https://nui-img/%s/%s?v=%d'):format(texture, texture, revision)
            or nil,
    }
end

function Map.mugshot.release()
    release(handle)

    handle = nil
    texture = nil
end

if not Map.config.mugshot.enabled then
    return
end

Map.onReplay(function()
    Map.mugshot.send()
end)

CreateThread(function()
    while true do
        Wait(texture == nil
            and Map.config.mugshot.pendingIntervalMs
            or Map.config.mugshot.pollIntervalMs)

        if Map.state.ready and not capturing then
            local ped = PlayerPedId()

            local stale = isStale(ped)
            local upgrading = not stale and variantRetriesLeft > 0

            if DoesEntityExist(ped) and (stale or upgrading) then
                capturing = true

                local wasForced = forced

                forced = false

                local ok, captured = pcall(capture, ped, upgrading)

                capturing = false

                if not ok then
                    Map.log(('mugshot capture failed: %s'):format(tostring(captured)))
                end

                if wasForced and not (ok and captured) then
                    forced = true
                end
            end
        end
    end
end)
