if GetCurrentResourceName() ~= 'platenet' then
    error('Rename this resource folder to "platenet".')
end

CreateThread(function()
    PlateNetRequireCurrentVersion(function(versionOk)
        if not versionOk then return end

        local ready = true

        if not PlateNetBootstrapKeyConfigured() then
            print('^1[platenet] Setup required: add platenet_api_key to server.cfg.^7')
            ready = false
        end
        if not Config.CommunitySlug or Config.CommunitySlug == '' or Config.CommunitySlug == 'your-community' then
            print('^1[platenet] Setup required: set Config.CommunitySlug in config.lua.^7')
            ready = false
        end
        if not Config.GameUrl or Config.GameUrl == '' then
            print('^1[platenet] Setup required: set Config.GameUrl in config.lua.^7')
            ready = false
        elseif not PlateNetGameUrlTrusted(Config.GameUrl) then
            print('^1[platenet] Setup required: Config.GameUrl must use HTTPS.^7')
            ready = false
        end

        if ready then
            PlateNetWarmServerAuth(function(ok)
                if ok then
                    print('^2[platenet] Connected.^7')
                else
                    print('^1[platenet] Connection failed. Check the PlateNet setup.^7')
                end
            end)
        end
    end)
end)

local eventCooldowns = {}

local function allowClientAction(src, action, cooldownMs)
    local now = GetGameTimer()
    eventCooldowns[src] = eventCooldowns[src] or {}
    if now < (eventCooldowns[src][action] or 0) then
        return false
    end
    eventCooldowns[src][action] = now + cooldownMs
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

local lastTablet = {}
local TABLET_CACHE_MS = 10000

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
                lastTablet[src] = nil
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
        lastTablet[src] = {
            payload = payload,
            at = GetGameTimer(),
            license = expectedLicense,
            token = expectedToken,
        }
        TriggerClientEvent('platenet:openTablet', src, payload)
    end)
end

RegisterNetEvent('platenet:requestTablet', function()
    local src = source
    if not allowClientAction(src, 'tablet', 2000) then return end

    local session = PlateNetGetSession(src)
    local cached = lastTablet[src]
    if cached then
        if session and cached.license == session.license and cached.token == session.token
            and (GetGameTimer() - cached.at) < TABLET_CACHE_MS then
            TriggerClientEvent('platenet:openTablet', src, cached.payload)
            return
        end

        lastTablet[src] = nil
    end

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
local PLATE_LOOKUPS_PER_MIN = 60
local deniedExportWarnings = {}

local function invokingResourceAllowed(bucket)
    local caller = GetInvokingResource()
    if type(caller) ~= 'string' or caller == '' then
        return false, caller
    end
    local security = type(PlateNetSecurity) == 'table' and PlateNetSecurity or {}
    local allowed = type(security[bucket]) == 'table' and security[bucket] or {}
    return allowed[caller] == true, caller
end

local function warnDeniedExport(caller, capability)
    local key = tostring(caller or '<unknown>') .. ':' .. capability
    local now = GetGameTimer()
    if now >= (deniedExportWarnings[key] or 0) then
        deniedExportWarnings[key] = now + 60000
        print(('^3[platenet] Blocked %s from %s.^7'):format(capability, tostring(caller or '<unknown>')))
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
    eventCooldowns[src] = nil
    resumePending[src] = nil
    resumeNextAllowed[src] = nil
    resumeLastRefusal[src] = nil
    pairPending[src] = nil
    pairNextAllowed[src] = nil
    pairLaunch[src] = nil
    lastTablet[src] = nil
    tabletPending[src] = nil
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

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    PlateNetEachSession(function(_src, session)
        PlateNetRequest('logoff', {}, session.token, nil)
    end)
end)
