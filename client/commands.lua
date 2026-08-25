local base = Config.Commands.tablet or 'platenet'

RegisterCommand(base, function(_source, args)
    local sub = (args[1] or ''):lower()

    if sub == '' then
        PlateNetToggleTablet()
        return
    end

    if sub == 'set' then
        PlateNetOpenSettings()
        return
    end

    PlateNetNotify(('PlateNet: /%s opens · /%s set adjusts layout'):format(base, base))
end, false)

TriggerEvent('chat:addSuggestion', '/' .. base, 'Open PlateNet', {
    {name = 'action', help = 'set (layout)'},
})

if Config.TabletKey then
    RegisterKeyMapping(base, 'Open PlateNet', 'keyboard', Config.TabletKey)
end


local SERVICES = {leo = 'LEO', police = 'LEO', fire = 'FIRE', ems = 'EMS', medical = 'EMS'}

local function hereNow()
    local coords = GetEntityCoords(PlayerPedId())
    local street, crossing = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local name = GetStreetNameFromHashKey(street) or ''
    if crossing and crossing ~= 0 then
        local cross = GetStreetNameFromHashKey(crossing)
        if cross and cross ~= '' and cross ~= name then
            name = ('%s / %s'):format(name, cross)
        end
    end
    local zone = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z))
    if zone and zone ~= '' and zone ~= 'NULL' then
        if name ~= '' then return ('%s, %s'):format(name, zone) end
        return zone
    end
    return name
end

local emergencyCommand = Config.Commands and Config.Commands.emergency
if emergencyCommand then
    RegisterCommand(emergencyCommand, function(_source, args)
        local service = SERVICES[(args[1] or ''):lower()]
        if not service then
            PlateNetNotify(('PlateNet: use /%s leo, /%s fire or /%s ems.'):format(
                emergencyCommand, emergencyCommand, emergencyCommand))
            return
        end
        table.remove(args, 1)

        local description = table.concat(args, ' '):gsub('^%s+', ''):gsub('%s+$', '')
        if description == '' then
            PlateNetNotify('PlateNet: now say what is happening.')
            return
        end

        TriggerServerEvent('platenet:emergency', service, description, hereNow())
    end, false)

    TriggerEvent('chat:addSuggestion', '/' .. emergencyCommand, 'Report an emergency to dispatch', {
        {name = 'service', help = 'leo, fire or ems'},
        {name = 'details', help = 'what is happening'},
    })
end

local panicCommand = Config.Commands and Config.Commands.panic
if panicCommand then
    RegisterCommand(panicCommand, function()
        TriggerServerEvent('platenet:panic', hereNow())
    end, false)

    TriggerEvent('chat:addSuggestion', '/' .. panicCommand, 'Signal 100')
end
