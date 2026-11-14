-- PlateNet CAD/MDT | https://platenet.app | Copyright (c) 2026 scentral and PlateNet. All rights reserved. See license.md.

local VERSION_URL = 'https://raw.githubusercontent.com/scentral/platenet/refs/heads/main/VERSION.txt'
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

local function updateKind(current, latest)
    local ca, cb, cc = versionParts(current)
    local la, lb, lc = versionParts(latest)
    if not ca or not la then return nil end
    if la > ca or (la == ca and lb > cb) then return 'required' end
    if la == ca and lb == cb and lc > cc then return 'available' end
    return nil
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
        print('^1[PlateNet CAD] Invalid resource version. PlateNet CAD stopped.^7')
        finishVersionCheck(false, nil)
        return
    end

    if VERSION_URL == '' then
        print(('[PlateNet CAD] v%s'):format(current))
        finishVersionCheck(true, current)
        return
    end

    local completed = false

    SetTimeout(15000, function()
        if not completed and updateState == 'checking' then
            completed = true
            print(('^3[PlateNet CAD] v%s - unable to check for updates.^7'):format(current))
            finishVersionCheck(true, current)
        end
    end)

    PerformHttpRequest(VERSION_URL, function(status, body)
        if completed or updateState ~= 'checking' then return end
        completed = true

        local latest = status == 200 and cleanVersion(body) or nil
        if not latest then
            print(('^3[PlateNet CAD] v%s - unable to check for updates.^7'):format(current))
            finishVersionCheck(true, current)
            return
        end

        local kind = updateKind(current, latest)
        if kind == 'required' then
            print(('^1[PlateNet CAD] Update required: v%s. This server has v%s. PlateNet CAD stopped.^7'):format(latest, current))
            finishVersionCheck(false, latest)
            return
        end
        if kind == 'available' then
            print(('^3[PlateNet CAD] Update available: v%s. This server has v%s.^7'):format(latest, current))
            finishVersionCheck(true, latest)
            return
        end

        print(('^2[PlateNet CAD] v%s is up to date.^7'):format(current))
        finishVersionCheck(true, latest)
    end, 'GET', '', {
        ['Accept'] = 'text/plain',
        ['Cache-Control'] = 'no-cache',
    })
end)
