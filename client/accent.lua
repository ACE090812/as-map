Map.accent = {
    name = 'indigo',
    color = '#7c86ff',
}

local listeners = {}

function Map.accent.onChange(listener)
    listeners[#listeners + 1] = listener
end

RegisterNUICallback('map:accentChanged', function(data, cb)
    local color = type(data) == 'table' and data.color or nil
    local name = type(data) == 'table' and data.name or nil

    if name == nil and type(data) == 'table' then
        name = data.accent
    end

    if type(color) ~= 'string' or color == '' then
        cb({})

        return
    end

    if color == Map.accent.color then
        cb({})

        return
    end

    Map.accent.color = color

    if type(name) == 'string' and name ~= '' then
        Map.accent.name = name
    end

    Map.debug(('accent is now %s (%s)'):format(Map.accent.name, Map.accent.color))

    for index = 1, #listeners do
        local ok, err = pcall(listeners[index], Map.accent.color, Map.accent.name)

        if not ok then
            Map.log(('accent listener %d failed: %s'):format(index, tostring(err)))
        end
    end

    cb({})
end)
