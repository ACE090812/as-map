MapConfig = {
    --- Let players hold a key to pan and zoom the minimap in place. A tap
    --- opens the fullscreen map. They can keep driving while they inspect.
    inspectEnabled = true,

    --- Key for that. Players can rebind it in FiveM's keybind settings; this
    --- is only the starting binding. Tap opens the main map; hold inspects.
    inspectKey = 'M',

    --- How long the key must be held before inspect starts. A shorter press
    --- is treated as a tap and opens the fullscreen map.
    inspectHoldMs = 250,

    --- Show the minimap after the player loads. You can toggle it later with export.
    minimapEnabled = true,

    --- Offer the 3D map. Off removes the 2D/3D control, and the 3D model is
    --- then never downloaded.
    dimension3dEnabled = true,

    --- Units for the distances the map shows: 'imperial' (ft, mi) or 'metric'
    --- (m, km). Server-wide -- players do not choose this.
    units = 'imperial',

    --- How the map looks for a player who has never changed it. These apply on
    --- a first run only; after that the player's own choice wins.
    defaults = {
        --- 'game', 'print' or 'render'.
        style = 'game',

        --- '2d' or '3d'.
        dimension = '2d',

        --- red, orange, amber, yellow, lime, green, emerald, teal, cyan, sky,
        --- blue, indigo, violet, purple, fuchsia, pink or rose. nil keeps indigo.
        accent = nil,
    },
}
