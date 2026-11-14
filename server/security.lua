-- PlateNet CAD/MDT | https://platenet.app | Copyright (c) 2026 scentral and PlateNet. All rights reserved. See license.md.

PlateNetSecurity = {
    -- Resources allowed to submit plate scans to PlateNet.
	-- Use the exact FiveM resource folder name and set it to true.
    PlateScanners = {
	
	['resource_name'] = false,
	
    },

    -- Resources listed here can ask PlateNet if a plate should trigger an alert.
	-- Use the exact FiveM resource folder name and set it to true.
    AlertChecks = {

	['resource_name'] = false,

    },

    -- Resources allowed to read a player's CAD access.
	-- Use the exact FiveM resource folder name and set it to true.
    PlayerAccess = {

	['platenet-radio'] = true,
	['resource_name'] = false,

    },

    -- Radio resource linked to PlateNet.
	-- Use the exact FiveM resource folder name of your radio.
    LinkedRadio = 'platenet-radio',
}
