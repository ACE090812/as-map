Map.nui = {}

local LIST_KEYS = { 'points', 'upsert', 'remove' }

local function encodeWithOption(payload)
    return json.encode(payload, { empty_table_as_array = true })
end

local function detectEmptyArraySupport()
    local ok, encoded = pcall(encodeWithOption, { probe = {} })

    return ok and encoded == '{"probe":[]}'
end

local supportsEmptyArray = detectEmptyArraySupport()

local function patchEmptyLists(body)
    for index = 1, #LIST_KEYS do
        body = body:gsub('("' .. LIST_KEYS[index] .. '":)%{%}', '%1[]')
    end

    return body
end

local function encode(payload)
    if supportsEmptyArray then
        return encodeWithOption(payload)
    end

    return patchEmptyLists(json.encode(payload))
end

function Map.send(payload)
    if not Map.state.ready then
        return false
    end

    SendNuiMessage(encode(payload))

    return true
end

function Map.nui.encode(payload)
    return encode(payload)
end

if not supportsEmptyArray then
    Map.log(
        'json.encode has no empty_table_as_array on this build; ' ..
        'empty lists are being patched into the JSON instead.'
    )
end
