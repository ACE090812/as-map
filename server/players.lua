local function playerCount()
    return #GetPlayers()
end

RegisterNetEvent('as-map:requestPlayersOnline', function()
    local source = source
    TriggerClientEvent('as-map:playersOnline', source, playerCount())
end)

AddEventHandler('playerJoining', function()
    TriggerClientEvent('as-map:playersOnline', -1, playerCount())
end)

AddEventHandler('playerDropped', function()
    TriggerClientEvent('as-map:playersOnline', -1, math.max(0, playerCount() - 1))
end)
