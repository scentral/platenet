fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'platenet'
description 'PlateNet CAD/MDT | www.platenet.app'
author 'scentral'
version '1.8.0'
shared_script 'config.lua'

client_scripts {
    'client/state.lua',
    'client/streets.lua',
    'client/tablet.lua',
    'client/commands.lua',
}

server_scripts {
    'server/banner.lua',
    'server/security.lua',
    'server/http.lua',
    'server/session.lua',
    'server/main.lua',
    'server/positions.lua',
}

files {
    'nui/index.html',
}

ui_page 'nui/index.html'
