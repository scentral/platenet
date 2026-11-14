-- PlateNet CAD/MDT | https://platenet.app | Copyright (c) 2026 scentral and PlateNet. All rights reserved. See license.md.

local base = Config.Commands.tablet or 'platenet'
local suggestions = {}
local HIDDEN_COMMANDS = {'platenet_respond'}

local function suggest(name, help, params)
    suggestions[#suggestions + 1] = {name = '/' .. name, help = help, params = params}
end

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

    if sub == 'alerts' then
        PlateNetToggleAlerts()
        return
    end

    if sub == 'anim' then
        PlateNetToggleTabletAnim()
        return
    end

    PlateNetNotify(('PlateNet: /%s opens · /%s set adjusts layout · /%s alerts turns call alerts on or off · /%s anim turns the tablet animation on or off'):format(base, base, base, base))
end, false)

suggest(base, 'Open PlateNet', {
    {name = 'action', help = 'set (layout), alerts (call alerts on or off) or anim (tablet animation on or off)'},
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

    suggest(emergencyCommand, 'Report an emergency to dispatch', {
        {name = 'service', help = 'leo, fire or ems'},
        {name = 'details', help = 'what is happening'},
    })
end

local panicCommand = Config.Commands and Config.Commands.panic
if panicCommand then
    RegisterCommand(panicCommand, function()
        TriggerServerEvent('platenet:panic', hereNow())
    end, false)

    suggest(panicCommand, 'Signal 100')
end

local function tidyChat()
    for _, name in ipairs(HIDDEN_COMMANDS) do
        TriggerEvent('chat:removeSuggestion', '/' .. name)
    end
    for _, item in ipairs(suggestions) do
        TriggerEvent('chat:removeSuggestion', item.name)
        TriggerEvent('chat:addSuggestion', item.name, item.help, item.params)
    end
end

AddEventHandler('onClientResourceStart', function()
    SetTimeout(1500, tidyChat)
end)

CreateThread(function()
    Wait(1500)
    tidyChat()
end)
