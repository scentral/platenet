-- PlateNet CAD/MDT | https://platenet.app | Copyright (c) 2026 scentral and PlateNet. All rights reserved. See license.md.

Config = {}

-- PlateNet game service URL. (DO NOT MODIFY)
Config.GameUrl = 'https://game.platenet.app'

-- Commands. Set any of these to false to disable that command entirely.
Config.Commands = {
    tablet = 'platenet',

    -- Emergency call. Anyone may use it; no pairing is required w/the CAD.
    --   /911 <leo|fire|ems> <description of what is happening>
    -- A service must be chosen or the call is refused without one.
    emergency = '911',

    -- Unit emergency (Signal 100). Units and dispatchers only, players must have their tablet paired.
    panic = 'panic',
}

-- Seconds a player must wait between their own emergency calls, default is 5 minutes.
Config.EmergencyCooldownSeconds = 300

-- Seconds a unit must wait between their own panics, default is 1 minute.
Config.PanicCooldownSeconds = 60

-- Default key used to open the PlateNet tablet.
Config.TabletKey = 'F6'

-- Speed unit shown in PlateNet.
Config.SpeedUnit = 'mph'

-- Automatically set players off duty when they disconnect.
Config.AutoOffDutyOnDisconnect = true

-- Show a popup in game for new calls and assigned units. Set to false to turn it off on this server.
Config.CallAlerts = true

-- Hold a tablet while PlateNet is open on foot. Set to false to turn it off on this server.
Config.TabletAnimation = true


-- To allow plugins and resources such as an ALPR, see server/security.lua.