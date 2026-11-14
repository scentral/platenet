-- PlateNet CAD/MDT | https://platenet.app | Copyright (c) 2026 scentral and PlateNet. All rights reserved. See license.md.

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'platenet'
description 'PlateNet CAD/MDT'
author 'scentral | PlateNet CAD/MDT | platenet.app'
version '1.19.8'
shared_script 'config.lua'

client_scripts {
    'client/state.lua',
    'client/streets.lua',
    'client/tablet.lua',
    'client/radio.lua',
    'client/alerts.lua',
    'client/commands.lua',
}

server_scripts {
    'server/banner.lua',
    'server/security.lua',
    'server/version_check.lua',
    'server/http.lua',
    'server/session.lua',
    'server/main.lua',
    'server/positions.lua',
}

files {
    'nui/index.html',
}

ui_page 'nui/index.html'
