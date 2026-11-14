-- PlateNet CAD/MDT | https://platenet.app | Copyright (c) 2026 scentral and PlateNet. All rights reserved. See license.md.

local API_KEY_HEADER = 'X-PlateNet-Game-Key'
local SERVER_TOKEN_HEADER = 'X-PlateNet-Server-Token'
local SESSION_HEADER = 'X-PlateNet-Session'

local lastKeyWarning = 0
local lastUrlWarning = 0
local lastGlobalWarning = 0

local serverToken = nil
local serverTokenRefreshAt = 0
local authInFlight = false
local authWaiters = {}
local authGeneration = 0
local communitySlug = ''
local cadEnabled = true
local cadOffNoted = false

local CAD_OFF_ERROR = 'CAD is not turned on for this community.'

local function setCadEnabled(enabled)
    cadEnabled = enabled
    if enabled then
        cadOffNoted = false
    elseif not cadOffNoted then
        cadOffNoted = true
        print('^1[PlateNet CAD] CAD is not turned on for this community. Contact PlateNet.^7')
    end
end

function PlateNetCadEnabled()
    return cadEnabled
end

local bootstrapApiKey = GetConvar('platenet_api_key', '')

local function getApiKey()
    return bootstrapApiKey
end

function PlateNetBootstrapKeyConfigured()
    return bootstrapApiKey ~= ''
end

function PlateNetGameUrlTrusted(url)
    if type(url) ~= 'string' then return false end
    if url:match('^https://') then return true end
    if url:match('^http://127%.0%.0%.1[:/]') or url:match('^http://localhost[:/]') then return true end
    return false
end

local LANES = {
    priority = {limit = 150, started = 0, count = 0},
    general = {limit = 250, started = 0, count = 0},
    plates = {limit = 150, started = 0, count = 0},
}
local PRIORITY_ACTIONS = {panic = true, emergency = true, positions = true, logoff = true, flagged_plates = true}
local PLATE_ACTIONS = {scan_plate = true, plate_alert = true}
local PLAYER_LIMIT_PER_MIN = 13
local playerWindows = {}
local laneFull = {}

local function laneFor(action)
    if PRIORITY_ACTIONS[action] then return 'priority' end
    if PLATE_ACTIONS[action] then return 'plates' end
    return 'general'
end

local function allowGlobalRequest(laneName)
    local lane = LANES[laneName] or LANES.general
    local now = GetGameTimer()
    if now - lane.started >= 60000 then
        lane.started = now
        lane.count = 0
    end
    if lane.count >= lane.limit then
        laneFull[laneName] = (laneFull[laneName] or 0) + 1
        return false
    end
    lane.count = lane.count + 1
    return true
end

function PlateNetTakeLaneReport()
    if next(laneFull) == nil then return nil end
    local report = laneFull
    laneFull = {}
    return report
end

function PlateNetAllowPlayer(src)
    src = tonumber(src)
    if not src then return false end
    local now = GetGameTimer()
    local w = playerWindows[src]
    if not w or now - w.started >= 60000 then
        w = {started = now, count = 0}
        playerWindows[src] = w
    end
    if w.count >= PLAYER_LIMIT_PER_MIN then
        laneFull.player = (laneFull.player or 0) + 1
        return false
    end
    w.count = w.count + 1
    return true
end

AddEventHandler('playerDropped', function()
    playerWindows[tonumber(source)] = nil
end)

local function warnGlobalLimit()
    local now = GetGameTimer()
    if now - lastGlobalWarning > 60000 then
        lastGlobalWarning = now
        print('^3[PlateNet CAD] Too many requests. Try again shortly.^7')
    end
end

local function transportReady(cb)
    local apiKey = getApiKey()
    if apiKey == '' then
        local now = GetGameTimer()
        if now - lastKeyWarning > 60000 then
            lastKeyWarning = now
            print('^1[PlateNet CAD] Setup required: add platenet_api_key to server.cfg.^7')
        end
        if cb then cb(false, 'PlateNet setup is incomplete.') end
        return false, 'PlateNet setup is incomplete.'
    end

    if not PlateNetGameUrlTrusted(Config.GameUrl) then
        local now = GetGameTimer()
        if now - lastUrlWarning > 60000 then
            lastUrlWarning = now
            print('^1[PlateNet CAD] Setup required: Config.GameUrl must use HTTPS.^7')
        end
        if cb then cb(false, 'PlateNet setup is incomplete.') end
        return false, 'PlateNet setup is incomplete.'
    end

    return true, apiKey
end

local function finishAuthentication(ok, token, refreshAfter, errorText)
    authGeneration = authGeneration + 1
    if ok then
        serverToken = token
        local refreshSeconds = tonumber(refreshAfter) or 480
        if refreshSeconds < 30 then refreshSeconds = 30 end
        serverTokenRefreshAt = GetGameTimer() + math.floor(refreshSeconds * 1000)
    else
        serverToken = nil
        serverTokenRefreshAt = 0
    end

    authInFlight = false
    local waiters = authWaiters
    authWaiters = {}
    for _, waiter in ipairs(waiters) do
        waiter(ok, errorText)
    end
end

local function ensureServerAuthentication(cb, force)
    if not force and serverToken and serverToken ~= '' and GetGameTimer() < serverTokenRefreshAt then
        cb(true)
        return
    end

    authWaiters[#authWaiters + 1] = cb
    if authInFlight then return end
    authInFlight = true

    local watchdogGeneration = (authGeneration or 0) + 1
    authGeneration = watchdogGeneration
    SetTimeout(30000, function()
        if authInFlight and authGeneration == watchdogGeneration then
            finishAuthentication(false, nil, nil, 'PlateNet is unavailable. Try again.')
        end
    end)

    local ready, apiKeyOrError = transportReady(nil)
    if not ready then
        finishAuthentication(false, nil, nil, apiKeyOrError)
        return
    end
    local apiKey = apiKeyOrError

    if not allowGlobalRequest('priority') then
        warnGlobalLimit()
        finishAuthentication(false, nil, nil, 'PlateNet is busy. Try again.')
        return
    end

    local url = ('%s/api/game/authenticate'):format(Config.GameUrl:gsub('/+$', ''))
    local headers = {
        ['Content-Type'] = 'application/json',
        ['Accept'] = 'application/json',
        [API_KEY_HEADER] = apiKey,
    }
    local body = json.encode({community_slug = '', resource_version = GetResourceMetadata(GetCurrentResourceName(), 'version', 0) or ''})

    PerformHttpRequest(url, function(status, responseBody, _responseHeaders)
        if authGeneration ~= watchdogGeneration then return end
        local data = nil
        if responseBody and responseBody ~= '' then
            local ok, decoded = pcall(json.decode, responseBody)
            if ok and type(decoded) == 'table' then data = decoded end
        end
        data = data or {}

        if status ~= 200 or data.success == false or type(data.server_token) ~= 'string' or data.server_token == '' then
            finishAuthentication(false, nil, nil, 'PlateNet connection failed.')
            return
        end

        communitySlug = type(data.community_slug) == 'string' and data.community_slug or ''
        setCadEnabled(not (type(data.products) == 'table' and data.products.cad == false))
        finishAuthentication(true, data.server_token, data.refresh_after, nil)
    end, 'POST', body, headers)
end

function PlateNetWarmServerAuth(cb)
    PlateNetRequireCurrentVersion(function(versionOk)
        if not versionOk then
            if cb then cb(false, 'PlateNet update required.') end
            return
        end

        ensureServerAuthentication(function(ok, errorText)
            if cb then cb(ok, errorText) end
        end, false)
    end)
end

function PlateNetRequest(action, payload, sessionToken, cb)
    payload = payload or {}

    local function dispatch(retried)
        ensureServerAuthentication(function(authOk, authError)
            if not authOk then
                if cb then
                    cb(false, {success = false, error = 'PlateNet connection failed.', server_auth = true}, 0)
                end
                return
            end

            if not cadEnabled then
                if cb then
                    cb(false, {success = false, error = CAD_OFF_ERROR, product = 'cad'}, 403)
                end
                return
            end

            payload.community_slug = communitySlug

            if not allowGlobalRequest(laneFor(action)) then
                warnGlobalLimit()
                if cb then
                    cb(false, {success = false, error = 'PlateNet is busy. Try again.'}, 0)
                end
                return
            end

            local headers = {
                ['Content-Type'] = 'application/json',
                ['Accept'] = 'application/json',
                [SERVER_TOKEN_HEADER] = serverToken,
            }
            if sessionToken and sessionToken ~= '' then
                headers[SESSION_HEADER] = sessionToken
            end

            local url = ('%s/api/game/%s'):format(Config.GameUrl:gsub('/+$', ''), action)

            PerformHttpRequest(url, function(status, body, _responseHeaders)
                local data = nil
                if body and body ~= '' then
                    local ok, decoded = pcall(json.decode, body)
                    if ok and type(decoded) == 'table' then data = decoded end
                end
                data = data or {}

                if status == 401 and data.server_auth == true and not retried then
                    serverToken = nil
                    serverTokenRefreshAt = 0
                    dispatch(true)
                    return
                end

                if status == 403 and data.product == 'cad' then
                    setCadEnabled(false)
                end

                if status ~= 200 or data.success == false then
                    if cb then cb(false, data, status) end
                    return
                end
                if cb then cb(true, data, status) end
            end, 'POST', json.encode(payload), headers)
        end, false)
    end

    PlateNetRequireCurrentVersion(function(versionOk)
        if not versionOk then
            if cb then
                cb(false, {success = false, error = 'PlateNet update required.'}, 0)
            end
            return
        end

        dispatch(false)
    end)
end

function PlateNetNeedsRepair(data, status)
    return status == 401 and not (type(data) == 'table' and data.server_auth == true)
        or (type(data) == 'table' and data.repair == true)
end
