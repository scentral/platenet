-- PlateNet CAD/MDT | https://platenet.app | Copyright (c) 2026 scentral and PlateNet. All rights reserved. See license.md.

local MPS_TO_MPH = 2.23694
local MPS_TO_KMH = 3.6

local POSITION_INTERVAL_MS = 5000
local POSITION_MIN_DELTA = 12.0
local STALE_AFTER_TICKS = 6
local BATCH_LIMIT = 100
local FEED_CHECK_MS = 10000
local FEED_STUCK_MS = 30000

local lastSent = {}
local streets = {}
local streetAt = {}

local alertAccess = {}
local feedCursor = nil
local feedSupported = false
local feedInFlightAt = nil
local lastFeedAt = 0
local overdueSeen = {}
local respondedAt = {}
local respondCooldown = {}
local RESPOND_COOLDOWN_MS = 1500
local SELF_RESPOND_QUIET_MS = 60000

local function callAlertsOn()
    return Config.CallAlerts ~= false
end

local function canSeeCall(access, call)
    if not access or (access.unit ~= true and access.dispatch ~= true) then return false end
    if access.status ~= nil then
        if access.status == 'OFFDT' then return false end
        if tonumber(call.priority) ~= 0 and access.status ~= '10-8' then return false end
    end
    if access.dispatch == true then return true end
    if tonumber(call.priority) == 0 then return true end
    if call.service == 'LEO' then return access.leo == true end
    if call.service == 'FIRE' or call.service == 'EMS' then return access.fire == true end
    return true
end

local function textOf(value)
    return type(value) == 'string' and value or ''
end

local function sendCard(src, kind, call)
    TriggerClientEvent('platenet:callAlert', src, {
        kind = kind,
        call_id = tonumber(call.id),
        case_number = textOf(call.case_number),
        priority = tonumber(call.priority) or 2,
        service = textOf(call.service) ~= '' and call.service or 'OTHER',
        call_type = textOf(call.call_type),
        location = textOf(call.location),
        postal = textOf(call.postal),
        department = textOf(call.department),
        age = tonumber(call.age) or 0,
        need = tonumber(call.need) or 0,
        units = type(call.units) == 'table' and call.units or {},
        x = tonumber(call.x),
        y = tonumber(call.y),
    })
end

local function eachAlertPlayer(fn)
    PlateNetEachSession(function(src, session)
        local access = alertAccess[src]
        if access and access.token == session.token then
            fn(src, access)
        end
    end)
end

local function idSet(list)
    local set = {}
    if type(list) == 'table' then
        for _, value in ipairs(list) do
            local id = tonumber(value)
            if id then set[id] = true end
        end
    end
    return set
end

local function offerCall(kind, call, skip)
    if type(call) ~= 'table' or not tonumber(call.id) then return end
    local creator = tonumber(call.created_by) or 0
    eachAlertPlayer(function(src, access)
        if creator > 0 and access.user_id == creator then return end
        if skip and skip[access.user_id] then return end
        if canSeeCall(access, call) then
            sendCard(src, kind, call)
        end
    end)
end

local function sendAssigned(call, users)
    if type(call) ~= 'table' or not tonumber(call.id) then return end
    local callId = tonumber(call.id)
    local creator = tonumber(call.created_by) or 0
    local now = GetGameTimer()
    eachAlertPlayer(function(src, access)
        if not users[access.user_id] or access.user_id == creator then return end
        local responded = respondedAt[src] and respondedAt[src][callId]
        if responded and (now - responded) < SELF_RESPOND_QUIET_MS then return end
        sendCard(src, 'assigned', call)
    end)
end

local function handleFeed(feed)
    feedSupported = true
    local seeded = feedCursor ~= nil
    feedCursor = {call = tonumber(feed.call) or 0, unit = tonumber(feed.unit) or 0}

    local overdueNow = {}
    local overdueNew = {}
    if type(feed.overdue) == 'table' then
        for _, call in ipairs(feed.overdue) do
            local id = tonumber(type(call) == 'table' and call.id)
            if id then
                overdueNow[id] = true
                if not overdueSeen[id] then overdueNew[#overdueNew + 1] = call end
            end
        end
    end
    overdueSeen = overdueNow

    if not seeded or feed.enabled ~= true then return end

    local dispatcher = feed.dispatcher_active == true
    if type(feed.calls) == 'table' then
        for _, call in ipairs(feed.calls) do
            local onCall = idSet(call.unit_ids)
            sendAssigned(call, onCall)
            if tonumber(call.priority) == 0 then
                offerCall('call', call, onCall)
            elseif not dispatcher and call.self ~= true and (tonumber(call.need) or 0) > 0 then
                offerCall('call', call, onCall)
            end
        end
    end
    for _, call in ipairs(overdueNew) do
        if tonumber(call.priority) ~= 0 then
            offerCall('overdue', call)
        end
    end
    if type(feed.assigned) == 'table' then
        for _, call in ipairs(feed.assigned) do
            sendAssigned(call, idSet(call.new_units))
        end
    end
end

local function feedReady(now)
    if not callAlertsOn() then return false end
    if feedInFlightAt and (now - feedInFlightAt) < FEED_STUCK_MS then return false end
    return true
end

RegisterNetEvent('platenet:respond', function(callId)
    local src = source
    callId = tonumber(callId)
    if not callId then return end
    local now = GetGameTimer()
    if respondCooldown[src] and now < respondCooldown[src] then return end
    respondCooldown[src] = now + RESPOND_COOLDOWN_MS
    if not PlateNetAllowPlayer(src) then return end

    local session = PlateNetGetSession(src)
    if not session then
        TriggerClientEvent('platenet:respondResult', src, {call_id = callId, code = 'unpaired'})
        return
    end
    respondedAt[src] = respondedAt[src] or {}
    respondedAt[src][callId] = now

    PlateNetRequest('respond', {call_id = callId}, session.token, function(ok, data, status)
        if type(data) ~= 'table' then data = {} end
        local code = textOf(data.code)
        if code == '' then
            if not ok and PlateNetNeedsRepair(data, status) then
                code = 'unpaired'
            else
                code = ok and 'attached' or 'error'
            end
        end
        TriggerClientEvent('platenet:respondResult', src, {
            call_id = callId,
            code = code,
            error = textOf(data.error),
            x = tonumber(data.x),
            y = tonumber(data.y),
            units = type(data.units) == 'table' and data.units or {},
        })
    end)
end)

local onesyncOff = false

CreateThread(function()
    local mode = GetConvar('onesync', '')
    if mode == '' then
        mode = (GetConvar('onesync_enabled', 'false') == 'true') and 'on' or 'off'
    end
    if mode == 'off' then
        onesyncOff = true
        print('^1[PlateNet CAD] Live positions are unavailable. Enable OneSync.^7')
    end
end)

RegisterNetEvent('platenet:street', function(street)
    local src = source
    if type(street) ~= 'string' then return end
    local session = PlateNetGetSession(src)
    if not session then return end
    local now = GetGameTimer()
    local previous = streetAt[src]
    if previous
        and previous.license == session.license
        and previous.token == session.token
        and (now - previous.at) < 5000
    then
        return
    end
    streetAt[src] = {at = now, license = session.license, token = session.token}
    streets[src] = {
        value = (street:sub(1, 96):gsub('%c', '')),
        license = session.license,
        token = session.token,
    }
end)

local function speedFor(ped)
    local entity = ped
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle and vehicle ~= 0 then
        entity = vehicle
    end
    local v = GetEntityVelocity(entity)
    local mps = math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
    if Config.SpeedUnit == 'kmh' then
        return mps * MPS_TO_KMH
    end
    return mps * MPS_TO_MPH
end

local function sampleFor(src, session, now)
    local last = lastSent[src]
    if last and (last.license ~= session.license or last.token ~= session.token) then
        lastSent[src] = nil
        last = nil
    end

    local streetEntry = streets[src]
    if streetEntry and (streetEntry.license ~= session.license or streetEntry.token ~= session.token) then
        streets[src] = nil
        streetEntry = nil
    end

    local stale = not last or (now - last.at) > (POSITION_INTERVAL_MS * STALE_AFTER_TICKS)

    local ped = not onesyncOff and GetPlayerPed(src) or 0
    if not ped or ped == 0 then
        if not stale then return nil end
        lastSent[src] = {at = now, license = session.license, token = session.token}
        return {token = session.token}
    end

    local coords = GetEntityCoords(ped)
    local speed = speedFor(ped)

    if last and last.coords and not stale then
        local moved = #(coords - last.coords)
        if moved < POSITION_MIN_DELTA and speed < 1.0 then
            return nil
        end
    end
    lastSent[src] = {coords = coords, at = now, license = session.license, token = session.token}

    return {
        token = session.token,
        x = coords.x,
        y = coords.y,
        z = coords.z,
        heading = GetEntityHeading(ped),
        speed = speed,
        street = streetEntry and streetEntry.value or nil,
    }
end

local function repairFor(entry)
    if not entry then return end
    local src = entry.src
    if GetPlayerName(src) == nil then return end
    if PlateNetIdentifier(src) ~= entry.license then return end
    local current = PlateNetGetSession(src)
    if not current or current.token ~= entry.token then return end

    PlateNetClearSession(src)
    PlateNetAttemptResume(src, function(resumed)
        if not resumed then
            TriggerClientEvent('platenet:unpaired', src)
        end
    end)
end

local function sendBatch(samples, entries, withFeed)
    local payload = {samples = samples}
    local laneReport = PlateNetTakeLaneReport()
    if laneReport then payload.lane_full = laneReport end
    if withFeed then
        payload.feed = feedCursor or {}
        feedInFlightAt = GetGameTimer()
        lastFeedAt = feedInFlightAt
    end
    PlateNetRequest('positions', payload, nil, function(ok, data, status)
        if withFeed then feedInFlightAt = nil end
        if ok then
            if type(data.results) == 'table' then
                for i, result in ipairs(data.results) do
                    if type(result) == 'table' and result.repair then
                        repairFor(entries[i])
                    end
                    local entry = entries[i]
                    if entry and type(result) == 'table' and type(result.alerts) == 'table' then
                        alertAccess[entry.src] = {
                            token = entry.token,
                            user_id = tonumber(result.alerts.user_id) or 0,
                            unit = result.alerts.unit == true,
                            dispatch = result.alerts.dispatch == true,
                            status = type(result.alerts.status) == 'string' and result.alerts.status or nil,
                            leo = result.alerts.leo == true,
                            fire = result.alerts.fire == true,
                        }
                    end
                end
            end
            if withFeed and type(data.feed) == 'table' then
                handleFeed(data.feed)
            end
            return
        end
    end)
end

CreateThread(function()
    while true do
        Wait(POSITION_INTERVAL_MS)
        local now = GetGameTimer()
        local samples, entries = {}, {}

        PlateNetEachSession(function(src, session)
            local sample = sampleFor(src, session, now)
            if sample then
                samples[#samples + 1] = sample
                entries[#entries + 1] = {src = src, license = session.license, token = session.token}
            end
        end)

        local withFeed = feedReady(now)
        local i = 1
        while i <= #samples do
            local chunk, chunkEntries = {}, {}
            for j = i, math.min(i + BATCH_LIMIT - 1, #samples) do
                chunk[#chunk + 1] = samples[j]
                chunkEntries[#chunkEntries + 1] = entries[j]
            end
            sendBatch(chunk, chunkEntries, withFeed)
            withFeed = false
            i = i + BATCH_LIMIT
        end

        if withFeed and feedSupported and #samples == 0 and (now - lastFeedAt) >= FEED_CHECK_MS then
            local anySession = false
            PlateNetEachSession(function() anySession = true end)
            if anySession then
                sendBatch({}, {}, true)
            end
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    lastSent[src] = nil
    streets[src] = nil
    streetAt[src] = nil
    alertAccess[src] = nil
    respondedAt[src] = nil
    respondCooldown[src] = nil
end)
