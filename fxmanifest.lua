fx_version 'cerulean'
game 'gta5'

author 'ACE Studios'
name 'as-map'
description '3D GTA 5 Map for FiveM'
version '1.0.0'

ui_page 'web/build/index.html'

files {
    'shim/blip_names.lua',
    'web/build/index.html',
    'web/build/**/*',
}

client_scripts {
    'client/core.lua',
    'config.lua',
    'client/config.lua',
    'client/nui.lua',
    'client/uisettings.lua',
    'client/asset_key.lua',
    'client/assets.lua',
    'client/focus.lua',
    'client/settings.lua',
    'client/minimap_style.lua',
    'client/accent.lua',
    'client/player.lua',
    'client/identity.lua',
    'client/mugshot.lua',
    'client/blips.lua',
    'client/zones.lua',
    'client/native_blips.lua',
    'client/route_sampler.lua',
    'client/route.lua',
    'client/surface.lua',
    'client/inspect.lua',
    'client/pausemenu.lua',
    'client/as-hud.lua',
    'client/exports.lua',
    'client/lifecycle.lua',
}

server_script 'server/players.lua'