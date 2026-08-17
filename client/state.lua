PlateNet = {
    paired = false,
    callsign = '',
    tabletOpen = false,
}

function PlateNetNotify(message)
    SetNotificationTextEntry('STRING')
    AddTextComponentSubstringPlayerName(message)
    DrawNotification(false, true)
end

RegisterNetEvent('platenet:notify', function(message)
    PlateNetNotify(message)
end)

RegisterNetEvent('platenet:paired', function(callsign)
    local wasPaired = PlateNet.paired
    PlateNet.paired = true
    PlateNet.callsign = callsign or ''
    if not wasPaired then
        PlateNetNotify(('PlateNet: connected as ~b~%s~s~.'):format(PlateNet.callsign))
    end
end)

RegisterNetEvent('platenet:unpaired', function()
    PlateNet.paired = false
    PlateNet.callsign = ''
    PlateNetNotify('PlateNet: pairing required. Open the tablet to continue.')
end)
