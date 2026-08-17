local VERSION_URL = tostring(Config.UpdateUrl or ''):gsub('^%s+', ''):gsub('%s+$', '')
local updateState = 'checking'
local latestVersion = nil
local updateWaiters = {}

local function cleanVersion(value)
    value = tostring(value or ''):gsub('^%s+', ''):gsub('%s+$', ''):gsub('^[vV]', '')
    if not value:match('^%d+%.%d+%.%d+$') then return nil end
    return value
end

local function versionParts(value)
    local a, b, c = value:match('^(%d+)%.(%d+)%.(%d+)$')
    if not a then return nil end
    return tonumber(a), tonumber(b), tonumber(c)
end

local function versionOlder(current, latest)
    local ca, cb, cc = versionParts(current)
    local la, lb, lc = versionParts(latest)
    if not ca or not la then return true end
    if ca ~= la then return ca < la end
    if cb ~= lb then return cb < lb end
    return cc < lc
end

local function finishVersionCheck(ok, latest)
    if updateState ~= 'checking' then return end

    updateState = ok and 'ready' or 'blocked'
    latestVersion = latest

    local pending = updateWaiters
    updateWaiters = {}

    for _, cb in ipairs(pending) do
        cb(ok, latestVersion)
    end

    if not ok then
        SetTimeout(0, function()
            StopResource(GetCurrentResourceName())
        end)
    end
end

function PlateNetRequireCurrentVersion(cb)
    if updateState == 'ready' then
        cb(true, latestVersion)
        return
    end

    if updateState == 'blocked' then
        cb(false, latestVersion)
        return
    end

    updateWaiters[#updateWaiters + 1] = cb
end

CreateThread(function()
    local current = cleanVersion(GetResourceMetadata(GetCurrentResourceName(), 'version', 0))

    if not current then
        print('^1[platenet] Invalid resource version. PlateNet stopped.^7')
        finishVersionCheck(false, nil)
        return
    end

    if VERSION_URL == '' then
        finishVersionCheck(true, current)
        return
    end

    local completed = false

    SetTimeout(15000, function()
        if not completed and updateState == 'checking' then
            completed = true
            print('^1[platenet] Unable to check for updates. PlateNet stopped.^7')
            finishVersionCheck(false, nil)
        end
    end)

    PerformHttpRequest(VERSION_URL, function(status, body)
        if completed or updateState ~= 'checking' then return end
        completed = true

        if status ~= 200 then
            print('^1[platenet] Unable to check for updates. PlateNet stopped.^7')
            finishVersionCheck(false, nil)
            return
        end

        local latest = cleanVersion(body)
        if not latest then
            print('^1[platenet] Invalid update version. PlateNet stopped.^7')
            finishVersionCheck(false, nil)
            return
        end

        if versionOlder(current, latest) then
            print(('^1[platenet] Update required: %s. PlateNet stopped.^7'):format(latest))
            finishVersionCheck(false, latest)
            return
        end

        print(('^2[platenet] Version %s is current.^7'):format(current))
        finishVersionCheck(true, latest)
    end, 'GET', '', {
        ['Accept'] = 'text/plain',
        ['Cache-Control'] = 'no-cache',
    })
end)

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

local globalWindow = {started = 0, count = 0}
local GLOBAL_LIMIT_PER_MIN = 300

local function allowGlobalRequest()
    local now = GetGameTimer()
    if now - globalWindow.started >= 60000 then
        globalWindow.started = now
        globalWindow.count = 0
    end
    if globalWindow.count >= GLOBAL_LIMIT_PER_MIN then
        return false
    end
    globalWindow.count = globalWindow.count + 1
    return true
end

local function warnGlobalLimit()
    local now = GetGameTimer()
    if now - lastGlobalWarning > 60000 then
        lastGlobalWarning = now
        print('^3[platenet] Too many requests. Try again shortly.^7')
    end
end

local function transportReady(cb)
    local apiKey = getApiKey()
    if apiKey == '' then
        local now = GetGameTimer()
        if now - lastKeyWarning > 60000 then
            lastKeyWarning = now
            print('^1[platenet] Setup required: add platenet_api_key to server.cfg.^7')
        end
        if cb then cb(false, 'PlateNet setup is incomplete.') end
        return false, 'PlateNet setup is incomplete.'
    end

    if not PlateNetGameUrlTrusted(Config.GameUrl) then
        local now = GetGameTimer()
        if now - lastUrlWarning > 60000 then
            lastUrlWarning = now
            print('^1[platenet] Setup required: Config.GameUrl must use HTTPS.^7')
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

    if not allowGlobalRequest() then
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
    local body = json.encode({community_slug = Config.CommunitySlug})

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
    payload.community_slug = Config.CommunitySlug

    local function dispatch(retried)
        ensureServerAuthentication(function(authOk, authError)
            if not authOk then
                if cb then
                    cb(false, {success = false, error = 'PlateNet connection failed.', server_auth = true}, 0)
                end
                return
            end

            if not allowGlobalRequest() then
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
