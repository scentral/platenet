-- PlateNet CAD/MDT | https://platenet.app | Copyright (c) 2026 scentral and PlateNet. All rights reserved. See license.md.

if GetCurrentResourceName() ~= 'platenet' then
    error('Rename this resource folder to "platenet".')
end

CreateThread(function()
    PlateNetRequireCurrentVersion(function(versionOk)
        if not versionOk then return end

        local ready = true

        if not PlateNetBootstrapKeyConfigured() then
            print('^1[PlateNet CAD] Setup required: add platenet_api_key to server.cfg.^7')
            ready = false
        end
        if not Config.GameUrl or Config.GameUrl == '' then
            print('^1[PlateNet CAD] Setup required: set Config.GameUrl in config.lua.^7')
            ready = false
        elseif not PlateNetGameUrlTrusted(Config.GameUrl) then
            print('^1[PlateNet CAD] Setup required: Config.GameUrl must use HTTPS.^7')
            ready = false
        end

        if ready then
            PlateNetWarmServerAuth(function(ok)
                if ok then
                    if PlateNetCadEnabled() then
                        print('^2[PlateNet CAD] Connected.^7')
                    end
                else
                    print('^1[PlateNet CAD] Connection failed. Check the PlateNet setup.^7')
                end
            end)
        end
    end)
end)

local eventCooldowns = {}
local cooldownPruneAt = 0

local function allowClientAction(src, action, cooldownMs)
    local now = GetGameTimer()
    if now >= cooldownPruneAt then
        cooldownPruneAt = now + 300000
        for key, actions in pairs(eventCooldowns) do
            local live = false
            for _, untilAt in pairs(actions) do
                if untilAt > now then
                    live = true
                    break
                end
            end
            if not live then eventCooldowns[key] = nil end
        end
    end
    local key = PlateNetIdentifier(src) or ('src:' .. tostring(src))
    eventCooldowns[key] = eventCooldowns[key] or {}
    if now < (eventCooldowns[key][action] or 0) then
        return false
    end
    eventCooldowns[key][action] = now + cooldownMs
    return true
end

local resumePending = {}
local resumeNextAllowed = {}
local resumeLastRefusal = {}

function PlateNetAttemptResume(src, cb)
    local identifier = PlateNetIdentifier(src)
    if not identifier then
        if cb then cb(false, nil, nil) end
        return
    end

    if resumePending[src] then
        if cb then resumePending[src][#resumePending[src] + 1] = cb end
        return
    end
    if GetGameTimer() < (resumeNextAllowed[src] or 0) then
        if cb then
            local last = resumeLastRefusal[src]
            if last then
                cb(false, last.data, last.status)
            else
                cb(false, {success = false, error = 'PlateNet is unavailable. Try again.'}, 0)
            end
        end
        return
    end
    resumePending[src] = cb and {cb} or {}

    PlateNetRequest('resume', {
        game_identifier = identifier,
        player_name = GetPlayerName(src) or '',
        game_server_id = GetConvar('sv_hostname', ''),
    }, nil, function(ok, data, status)

        if PlateNetIdentifier(src) ~= identifier then return end

        local callbacks = resumePending[src]
        resumePending[src] = nil

        if GetPlayerName(src) == nil then return end

        local resumed = ok and type(data.token) == 'string' and data.token ~= ''
        if resumed then
            resumeNextAllowed[src] = nil
            resumeLastRefusal[src] = nil
            PlateNetSetSession(src, data.token, data.callsign)
            TriggerClientEvent('platenet:paired', src, data.callsign)
            PlateNetSyncRadioId(src)
        else
            resumeNextAllowed[src] = GetGameTimer() + 8000
            if (status == 401 or status == 403) and type(data) == 'table' and type(data.error) == 'string' then
                resumeLastRefusal[src] = {data = data, status = status}
            else
                resumeLastRefusal[src] = nil
            end
        end
        if callbacks then
            for _, fn in ipairs(callbacks) do fn(resumed, data, status) end
        end
    end)
end

local pairWatch = {}
local pairPending = {}
local pairNextAllowed = {}
local pairLaunch = {}

local function watchForPairing(src)
    if pairWatch[src] then return end
    pairWatch[src] = true
    CreateThread(function()
        local deadline = GetGameTimer() + 330000
        while pairWatch[src] and GetGameTimer() < deadline do
            Wait(5000)
            if not pairWatch[src] then return end
            if GetPlayerName(src) == nil or PlateNetGetSession(src) then break end
            PlateNetAttemptResume(src, nil)
        end
        pairWatch[src] = nil
        pairLaunch[src] = nil
    end)
end

local function beginPairing(src)
    local now = GetGameTimer()
    local existing = pairLaunch[src]
    if existing and now < existing.expiresAt then
        TriggerClientEvent('platenet:openTablet', src, existing.payload)
        return
    end
    if pairPending[src] or now < (pairNextAllowed[src] or 0) then return end

    local identifier = PlateNetIdentifier(src)
    if not identifier then
        TriggerClientEvent('platenet:notify', src, 'PlateNet: unable to pair. Reconnect and try again.')
        return
    end

    pairPending[src] = true
    pairNextAllowed[src] = now + 15000

    PlateNetRequest('pair', {
        game_identifier = identifier,
        player_name = GetPlayerName(src) or '',
        game_server_id = GetConvar('sv_hostname', ''),
    }, nil, function(ok, data)
        if PlateNetIdentifier(src) ~= identifier then return end
        pairPending[src] = nil
        if GetPlayerName(src) == nil then return end

        if not ok then
            TriggerClientEvent('platenet:notify', src, 'PlateNet: unable to pair. Try again.')
            return
        end
        if type(data.authorization_id) ~= 'number'
            or type(data.browser_nonce) ~= 'string' or data.browser_nonce == ''
            or type(data.code) ~= 'string' or data.code == '' then
            TriggerClientEvent('platenet:notify', src, 'PlateNet: unable to pair. Try again.')
            return
        end

        local payload = {
            url = ('%s/tablet?c=%s#a=%s&n=%s&code=%s'):format(
                Config.GameUrl:gsub('/+$', ''),
                tostring(data.community_id or ''),
                tostring(data.authorization_id),
                token_urlencode(data.browser_nonce),
                token_urlencode(data.code)
            ),
            callsign = '',
        }
        pairLaunch[src] = {
            payload = payload,
            expiresAt = GetGameTimer() + math.max(1, tonumber(data.expires_in) or 300) * 1000,
        }
        TriggerClientEvent('platenet:openTablet', src, payload)
        watchForPairing(src)
    end)
end

local tabletPending = {}

local function openTabletFor(src, isRetry)
    if tabletPending[src] then return end
    local session = PlateNetGetSession(src)
    if not session then return end

    local expectedLicense = session.license
    local expectedToken = session.token
    tabletPending[src] = {license = expectedLicense, token = expectedToken}

    PlateNetRequest('session', {}, expectedToken, function(ok, data, status)

        local pending = tabletPending[src]
        if not pending or pending.license ~= expectedLicense or pending.token ~= expectedToken then
            return
        end
        tabletPending[src] = nil

        if PlateNetIdentifier(src) ~= expectedLicense then return end
        local current = PlateNetGetSession(src)
        if not current or current.token ~= expectedToken then return end

        if not ok then
            if PlateNetNeedsRepair(data, status) then
                PlateNetClearSession(src)
                if not isRetry then

                    PlateNetAttemptResume(src, function(resumed, resumeData, resumeStatus)
                        if resumed then
                            openTabletFor(src, true)
                        elseif resumeStatus ~= 401 and type(resumeData) == 'table' and type(resumeData.error) == 'string' then
                            TriggerClientEvent('platenet:notify', src, 'PlateNet: unable to connect. Try again.')
                        else
                            beginPairing(src)
                        end
                    end)
                    return
                end
            end
            TriggerClientEvent('platenet:notify', src, 'PlateNet: unable to connect. Try again.')
            return
        end
        if type(data.tablet_ticket) ~= 'string' or data.tablet_ticket == '' then
            TriggerClientEvent('platenet:notify', src, 'PlateNet: update required. Contact an administrator.')
            return
        end
        local payload = {
            url = ('%s/tablet?c=%s#t=%s'):format(
                Config.GameUrl:gsub('/+$', ''),
                tostring(data.community_id or ''),
                token_urlencode(data.tablet_ticket)
            ),
            callsign = data.callsign,
        }
        TriggerClientEvent('platenet:openTablet', src, payload)
    end)
end

RegisterNetEvent('platenet:requestTablet', function()
    local src = source
    if not allowClientAction(src, 'tablet', 2000) then return end
    if not PlateNetAllowPlayer(src) then return end

    local session = PlateNetGetSession(src)
    if session then
        openTabletFor(src, false)
        return
    end
    PlateNetAttemptResume(src, function(ok, resumeData, resumeStatus)
        if ok then
            openTabletFor(src, false)
        elseif resumeStatus ~= 401 and type(resumeData) == 'table' and type(resumeData.error) == 'string' then
            TriggerClientEvent('platenet:notify', src, 'PlateNet: unable to connect. Try again.')
        else
            beginPairing(src)
        end
    end)
end)

function token_urlencode(value)
    return (tostring(value):gsub('[^%w%-%._~]', function(c)
        return ('%%%02X'):format(string.byte(c))
    end))
end

local plateWindows = {}
local PLATE_LOOKUPS_PER_MIN = 25
local FLAGGED_REFRESH_MS = 30000
local FLAGGED_BOLO_MIN = 4
local flagged = nil
local flaggedWarned = false

local function compactPlate(plate)
    return (tostring(plate or ''):upper():gsub('%s', ''))
end

local function plateFlagged(plate)
    if not flagged then return false end
    local compact = compactPlate(plate)
    if compact == '' then return false end
    if flagged.plates[compact] then return true end
    if #compact >= FLAGGED_BOLO_MIN then
        for _, text in ipairs(flagged.bolos) do
            if text:find(compact, 1, true) then return true end
        end
    end
    return false
end

local function refreshFlagged()
    PlateNetRequest('flagged_plates', {}, nil, function(ok, data)
        if not ok or type(data) ~= 'table' or type(data.plates) ~= 'table' then
            if not flaggedWarned then
                flaggedWarned = true
                print('^3[PlateNet CAD] Plate reader alerts are waiting for PlateNet. Check the PlateNet connection.^7')
            end
            return
        end
        local plates = {}
        for _, plate in ipairs(data.plates) do
            if type(plate) == 'string' and plate ~= '' then plates[compactPlate(plate)] = true end
        end
        local bolos = {}
        if type(data.bolos) == 'table' then
            for _, text in ipairs(data.bolos) do
                if type(text) == 'string' and text ~= '' then bolos[#bolos + 1] = compactPlate(text) end
            end
        end
        flagged = {plates = plates, bolos = bolos}
        flaggedWarned = false
    end)
end

CreateThread(function()
    Wait(2000)
    while true do
        if PlateNetCadEnabled() then refreshFlagged() end
        Wait(FLAGGED_REFRESH_MS)
    end
end)
local deniedExportWarnings = {}
local DEFAULT_RADIO = 'platenet-radio'
local DEFAULT_TRUST = {
    PlayerAccess = {[DEFAULT_RADIO] = true},
}

local function invokingResourceAllowed(bucket)
    local caller = GetInvokingResource()
    if type(caller) ~= 'string' or caller == '' then
        return false, caller
    end
    local security = type(PlateNetSecurity) == 'table' and PlateNetSecurity or {}
    local allowed = type(security[bucket]) == 'table' and security[bucket] or {}
    if allowed[caller] ~= nil then
        return allowed[caller] == true, caller
    end
    local defaults = DEFAULT_TRUST[bucket] or {}
    return defaults[caller] == true, caller
end

local function warnDeniedExport(caller, capability)
    local key = tostring(caller or '<unknown>') .. ':' .. capability
    local now = GetGameTimer()
    if now >= (deniedExportWarnings[key] or 0) then
        deniedExportWarnings[key] = now + 60000
        print(('^3[PlateNet CAD] Blocked %s from %s.^7'):format(capability, tostring(caller or '<unknown>')))
    end
end

local function allowPlateLookup(src, caller)
    local now = GetGameTimer()
    local key = tostring(caller or '<unknown>') .. ':' .. tostring(src)
    local w = plateWindows[key]
    if not w or now - w.started >= 60000 then
        w = {started = now, count = 0}
        plateWindows[key] = w
    end
    if w.count >= PLATE_LOOKUPS_PER_MIN then
        return false
    end
    w.count = w.count + 1
    return true
end

local function plateRequest(action, src, plate, cb, caller)

    local respond = function(data)
        if cb then cb(data) end
    end

    if type(src) ~= 'number' or src <= 0 then
        respond({success = false, error = 'Invalid player.'})
        return true
    end

    if type(plate) ~= 'string' then
        respond({success = false, error = 'Invalid plate.'})
        return true
    end

    plate = plate:upper():gsub('^%s+', ''):gsub('%s+$', '')
    if plate == '' or #plate > 20 then
        respond({success = false, error = 'Invalid plate.'})
        return true
    end

    local function dispatch()
        local session = PlateNetGetSession(src)

        if not session then
            respond({success = false, error = 'Player is not paired.', unpaired = true})
            return
        end

        if not plateFlagged(plate) then
            if action == 'plate_alert' then
                respond({success = true, alert = false})
            else
                respond({success = true, accepted = true})
            end
            return
        end

        if not allowPlateLookup(src, caller) then
            respond({success = false, error = 'Rate limit reached.'})
            return
        end

        local expectedToken = session.token

        PlateNetRequest(action, {plate = plate, source_resource = caller or ''}, expectedToken, function(ok, data, status)

            if not ok and PlateNetNeedsRepair(data, status) then
                local current = PlateNetGetSession(src)
                if current and current.token == expectedToken then
                    PlateNetClearSession(src)
                end
                data.unpaired = true
            end

            if data.success == nil then data.success = ok end
            if not data.success then
                data.error = data.unpaired and 'Player is not paired.' or 'PlateNet request failed.'
            end

            respond(data)
        end)
    end

    if PlateNetGetSession(src) then
        dispatch()
        return true
    end
    PlateNetAttemptResume(src, function(resumed)
        if not resumed then
            respond({
                success = false,
                error = 'Player is not paired.',
                unpaired = true,
            })
            return
        end

        dispatch()
    end)

    return true
end

exports('IsPlateAlerted', function(src, plate, cb)
    local allowed, caller = invokingResourceAllowed('AlertChecks')
    if not allowed then
        warnDeniedExport(caller, 'IsPlateAlerted')
        if cb then cb({success = false, error = 'Access denied.'}) end
        return true
    end
    return plateRequest('plate_alert', src, plate, cb, caller)
end)

exports('ScanPlate', function(src, plate, cb)
    local allowed, caller = invokingResourceAllowed('PlateScanners')
    if not allowed then
        warnDeniedExport(caller, 'ScanPlate')
        if cb then
            cb({success = false, error = 'Access denied.'})
        end
        return true
    end
    return plateRequest('scan_plate', src, plate, cb, caller)
end)

local playerAccessWindows = {}
local radioSyncWindows = {}
local PLAYER_ACCESS_PER_MIN = 20
local RADIO_SYNCS_PER_MIN = 10

local function allowWindow(windows, src, limit)
    local now = GetGameTimer()
    local w = windows[src]
    if not w or now - w.started >= 60000 then
        w = {started = now, count = 0}
        windows[src] = w
    end
    if w.count >= limit then
        return false
    end
    w.count = w.count + 1
    return true
end

local function accessRequest(src, radioId, respond)
    local session = PlateNetGetSession(src)
    if not session then
        respond({success = false, error = 'Player is not paired.', unpaired = true})
        return
    end

    local expectedToken = session.token

    PlateNetRequest('radio_profile', {radio_id = radioId}, expectedToken, function(ok, data, status)
        if type(data) ~= 'table' then data = {} end

        if not ok and PlateNetNeedsRepair(data, status) then
            local current = PlateNetGetSession(src)
            if current and current.token == expectedToken then
                PlateNetClearSession(src)
            end
            respond({success = false, error = 'Player is not paired.', unpaired = true})
            return
        end

        if not ok or data.success == false then
            respond({success = false, error = 'PlateNet request failed.'})
            return
        end

        local unit = data.unit == true
        local dispatch = data.dispatch == true
        local supervisor = data.supervisor == true
        respond({
            success = true,
            callsign = type(data.callsign) == 'string' and data.callsign or '',
            unit = unit,
            dispatch = dispatch,
            supervisor = supervisor,
            civilian = not unit and not dispatch and not supervisor,
            departments = type(data.departments) == 'table' and data.departments or {},
        })
    end)
end

exports('GetPlayerAccess', function(src, cb)
    local respond = function(data)
        if cb then cb(data) end
    end

    local allowed, caller = invokingResourceAllowed('PlayerAccess')
    if not allowed then
        warnDeniedExport(caller, 'GetPlayerAccess')
        respond({success = false, error = 'Access denied.'})
        return true
    end

    if type(src) ~= 'number' or src <= 0 or GetPlayerName(src) == nil then
        respond({success = false, error = 'Invalid player.'})
        return true
    end

    local function dispatch()
        if not allowWindow(playerAccessWindows, src, PLAYER_ACCESS_PER_MIN) then
            respond({success = false, error = 'Rate limit reached.'})
            return
        end
        accessRequest(src, '', respond)
    end

    if PlateNetGetSession(src) then
        dispatch()
        return true
    end
    PlateNetAttemptResume(src, function(resumed)
        if not resumed then
            respond({success = false, error = 'Player is not paired.', unpaired = true})
            return
        end
        dispatch()
    end)

    return true
end)

local function linkedRadioName()
    local security = type(PlateNetSecurity) == 'table' and PlateNetSecurity or {}
    if type(security.LinkedRadio) == 'string' and security.LinkedRadio ~= '' then
        return security.LinkedRadio
    end
    return DEFAULT_RADIO
end

local function linkedRadio()
    local name = linkedRadioName()
    if name == '' or GetResourceState(name) ~= 'started' then return nil end
    return name
end

RegisterNetEvent('platenet:linkedRadio:request', function()
    local src = source
    if not allowClientAction(src, 'linkedRadio', 5000) then return end
    TriggerClientEvent('platenet:linkedRadio', src, linkedRadioName())
end)

function PlateNetSyncRadioId(src)
    local radio = linkedRadio()
    if not radio or not PlateNetGetSession(src) then return end

    local ok, value = pcall(function()
        return exports[radio]:GetPlayerRadioId(src)
    end)
    if not ok then return end

    local radioId = tostring(value or ''):gsub('%D', '')
    if radioId == '' or #radioId > 8 then return end
    if not allowWindow(radioSyncWindows, src, RADIO_SYNCS_PER_MIN) then return end

    accessRequest(src, radioId, function() end)
end

AddEventHandler('platenet:radio:changed', function(src)
    local radio = linkedRadio()
    if not radio or GetInvokingResource() ~= radio then return end
    if type(src) ~= 'number' or GetPlayerName(src) == nil then return end
    PlateNetSyncRadioId(src)
end)

local SERVICES = {LEO = true, FIRE = true, EMS = true}

local function cleanText(value, limit)
    if type(value) ~= 'string' then return '' end
    value = value:gsub('%c', ' '):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    if #value > limit then value = value:sub(1, limit) end
    return value
end

local function playerPoint(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil, nil end
    local coords = GetEntityCoords(ped)
    if coords.x == 0.0 and coords.y == 0.0 then return nil, nil end
    return coords.x, coords.y
end

RegisterNetEvent('platenet:emergency', function(service, description, location)
    local src = source
    local cooldown = tonumber(Config.EmergencyCooldownSeconds) or 60
    if cooldown < 5 then cooldown = 5 end
    if not allowClientAction(src, 'emergency', cooldown * 1000) then
        TriggerClientEvent('platenet:notify', src, 'PlateNet: you have already reported an emergency. Wait a moment.')
        return
    end

    description = cleanText(description, 300)
    if description == '' then
        TriggerClientEvent('platenet:notify', src, 'PlateNet: say what is happening.')
        return
    end

    service = cleanText(service, 8):upper()
    if not SERVICES[service] then
        TriggerClientEvent('platenet:notify', src, 'PlateNet: choose leo, fire or ems.')
        return
    end

    local x, y = playerPoint(src)
    PlateNetRequest('emergency', {
        description = description,
        service = service,
        call_type = '911 CALL',
        location = cleanText(location, 96),
        x = x,
        y = y,
        caller_name = cleanText(GetPlayerName(src) or '', 32),
        player_identifier = PlateNetIdentifier(src) or '',
    }, nil, function(ok)
        if ok then
            TriggerClientEvent('platenet:notify', src, 'PlateNet: your call has been passed to dispatch.')
        else
            TriggerClientEvent('platenet:notify', src, 'PlateNet: your call could not be sent. Try again.')
        end
    end)
end)

RegisterNetEvent('platenet:panic', function(location)
    local src = source
    local session = PlateNetGetSession(src)
    if not session then
        TriggerClientEvent('platenet:notify', src, 'PlateNet: pair your tablet before using a panic.')
        return
    end

    local cooldown = tonumber(Config.PanicCooldownSeconds) or 30
    if cooldown < 5 then cooldown = 5 end
    if not allowClientAction(src, 'panic', cooldown * 1000) then
        TriggerClientEvent('platenet:notify', src, 'PlateNet: a panic is already out for you.')
        return
    end

    local x, y = playerPoint(src)
    PlateNetRequest('panic', {
        callsign = session.callsign or '',
        location = cleanText(location, 96),
        x = x,
        y = y,
        player_name = GetPlayerName(src) or '',
        game_identifier = PlateNetIdentifier(src) or '',
    }, session.token, function(ok, data, status)
        if ok then
            TriggerClientEvent('platenet:notify', src, 'PlateNet: SIGNAL 100 SENT.')
            return
        end
        if status == 403 then
            TriggerClientEvent('platenet:notify', src, 'PlateNet: this command is not available.')
            return
        end
        TriggerClientEvent('platenet:notify', src, 'PlateNet: the panic could not be sent. Try again.')
    end)
end)

AddEventHandler('playerJoining', function()
    local src = source
    CreateThread(function()
        Wait(2000)
        if GetPlayerName(src) ~= nil and not PlateNetGetSession(src) then
            PlateNetAttemptResume(src, nil)
        end
    end)
end)

AddEventHandler('playerDropped', function()
    local src = source
    pairWatch[src] = nil
    resumePending[src] = nil
    resumeNextAllowed[src] = nil
    resumeLastRefusal[src] = nil
    pairPending[src] = nil
    pairNextAllowed[src] = nil
    pairLaunch[src] = nil
    tabletPending[src] = nil
    playerAccessWindows[src] = nil
    radioSyncWindows[src] = nil
    local plateSuffix = ':' .. tostring(src)
    for key in pairs(plateWindows) do
        if key:sub(-#plateSuffix) == plateSuffix then
            plateWindows[key] = nil
        end
    end

    local session = PlateNetTakeSession(src)
    if not session then return end
    if not Config.AutoOffDutyOnDisconnect then return end
    PlateNetRequest('logoff', {}, session.token, nil)
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    CreateThread(function()
        Wait(5000)
        for _, id in ipairs(GetPlayers()) do
            local src = tonumber(id)
            if src and GetPlayerName(src) ~= nil and not PlateNetGetSession(src) then
                PlateNetAttemptResume(src, nil)
                Wait(250)
            end
        end
    end)
end)
