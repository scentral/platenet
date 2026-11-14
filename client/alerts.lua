-- PlateNet CAD/MDT | https://platenet.app | Copyright (c) 2026 scentral and PlateNet. All rights reserved. See license.md.

local MUTE_KEY = 'platenet_call_alerts_muted'
local CARD_MS = 15000
local muted = GetResourceKvpInt(MUTE_KEY) == 1
local cards = {}

local function clean(value, limit)
    if type(value) ~= 'string' then return '' end
    value = value:gsub('%c', ' '):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    if #value > limit then value = value:sub(1, limit) end
    return value
end

local function unitList(units, limit)
    local names = {}
    if type(units) == 'table' then
        for _, name in ipairs(units) do
            local callsign = clean(name, 20)
            if callsign ~= '' then names[#names + 1] = callsign end
        end
    end
    return clean(table.concat(names, ', '), limit)
end

local function keyName(command, fallback)
    local ok, raw = pcall(GetControlInstructionalButton, 0, GetHashKey(command) | 0x80000000, true)
    if ok and type(raw) == 'string' and raw:sub(1, 2) == 't_' and #raw > 2 then
        return raw:sub(3):upper()
    end
    return fallback
end

local function respondKey()
    return keyName('platenet_respond', 'F9')
end

local function tabletKey()
    local command = (Config.Commands and Config.Commands.tablet) or 'platenet'
    return keyName(command, Config.TabletKey or 'F6')
end

local function setWaypoint(x, y)
    x, y = tonumber(x), tonumber(y)
    if not x or not y then return false end
    SetNewWaypoint(x + 0.0, y + 0.0)
    return true
end

local function updateCard(id, text)
    SendNUIMessage({action = 'cardUpdate', id = id, text = text})
end

RegisterNetEvent('platenet:callAlert', function(alert)
    if muted or type(alert) ~= 'table' then return end
    local id = tonumber(alert.call_id)
    if not id then return end

    local respond = alert.kind ~= 'assigned'
    local routed = ''
    if not respond then
        routed = setWaypoint(alert.x, alert.y) and 'Waypoint set' or 'No map position'
    end

    local now = GetGameTimer()
    cards[id] = {at = now, expires = now + CARD_MS, respond = respond}
    SendNUIMessage({
        action = 'card',
        card = {
            id = id,
            kind = clean(alert.kind, 12),
            priority = tonumber(alert.priority) or 2,
            service = clean(alert.service, 8),
            call_type = clean(alert.call_type, 40),
            units = unitList(alert.units, 80),
            location = clean(alert.location, 70),
            postal = clean(alert.postal, 12),
            case_number = clean(alert.case_number, 20),
            department = clean(alert.department, 8),
            age = tonumber(alert.age) or 0,
            need = tonumber(alert.need) or 0,
            respond_key = respond and respondKey() or '',
            tablet_key = tabletKey(),
            routed = routed,
            duration = CARD_MS,
        },
    })
end)

local function latestRespondable()
    local now = GetGameTimer()
    local bestId, bestAt
    for id, card in pairs(cards) do
        if card.expires <= now then
            cards[id] = nil
        elseif card.respond and not card.pending and (not bestAt or card.at > bestAt) then
            bestId, bestAt = id, card.at
        end
    end
    return bestId
end

RegisterCommand('platenet_respond', function()
    local id = latestRespondable()
    if not id then return end
    cards[id].pending = true
    updateCard(id, 'Responding...')
    TriggerServerEvent('platenet:respond', id)
end, false)

RegisterKeyMapping('platenet_respond', 'PlateNet: respond to a call', 'keyboard', 'F9')

local ROUTED = {attached = true, already_on = true, routed = true, routed_dispatch = true}

RegisterNetEvent('platenet:respondResult', function(result)
    if type(result) ~= 'table' then return end
    local id = tonumber(result.call_id)
    if not id then return end
    local card = cards[id]
    if card then card.pending = false end

    local code = result.code
    local text
    if ROUTED[code] then
        local where = setWaypoint(result.x, result.y) and 'Waypoint set.' or 'No map position.'
        if code == 'routed' then
            text = where .. ' Still on your call.'
        elseif code == 'routed_dispatch' then
            text = where .. ' Dispatch assigns.'
        else
            text = 'On this call. ' .. where
        end
        if card then card.respond = false end
    elseif code == 'taken' then
        local units = unitList(result.units, 24)
        text = (units ~= '' and ('Taken by ' .. units .. '.') or 'Already taken.')
            .. (' %s to attach.'):format(tabletKey())
        if card then card.respond = false end
    elseif code == 'on_call' then
        text = 'Clear your current call first.'
    elseif code == 'off_duty' then
        text = 'Go on duty first.'
    elseif code == 'closed' then
        text = 'Call closed.'
        if card then card.respond = false end
    elseif code == 'other_department' then
        text = 'Another department\'s call.'
        if card then card.respond = false end
    elseif code == 'unpaired' then
        text = 'Pair your tablet first.'
    else
        local reason = clean(result.error, 60)
        text = reason ~= '' and ('Refused. ' .. reason) or 'Could not respond. Try again.'
    end
    updateCard(id, text)
end)

function PlateNetToggleAlerts()
    muted = not muted
    SetResourceKvpInt(MUTE_KEY, muted and 1 or 0)
    if muted then
        cards = {}
        SendNUIMessage({action = 'cardsClear'})
    end
    PlateNetNotify(muted and 'PlateNet: call alerts off.' or 'PlateNet: call alerts on.')
end
