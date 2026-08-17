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
