Map.assets = {}

Map.onReplay(function()
    if type(Map.assetKeyPart) ~= 'string' or Map.assetKeyPart == '' then
        Map.log(
            'no asset key to send: client/asset_key.lua is missing or empty, ' ..
            'so the page cannot decrypt its tiles or the 3D model. ' ..
            'Rebuild the web bundle, which regenerates it.'
        )

        return
    end

    Map.send({
        type = 'map:assetKey',
        part = Map.assetKeyPart,
    })
end)
