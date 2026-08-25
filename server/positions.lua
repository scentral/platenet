local MPS_TO_MPH = 2.23694
local MPS_TO_KMH = 3.6

local POSITION_INTERVAL_MS = 5000
local POSITION_MIN_DELTA = 12.0
local STALE_AFTER_TICKS = 6
local BATCH_LIMIT = 100

local lastSent = {}
local streets = {}
local streetAt = {}

local onesyncOff = false
local legacyCad = false

CreateThread(function()
    local mode = GetConvar('onesync', '')
    if mode == '' then
        mode = (GetConvar('onesync_enabled', 'false') == 'true') and 'on' or 'off'
    end
    if mode == 'off' then
        onesyncOff = true
        print('^1[platenet] Live positions are unavailable. Enable OneSync.^7')
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

local function sendLegacy(samples, entries)
    for i, sample in ipairs(samples) do
        if sample.x ~= nil then
            local entry = entries[i]
            sample.token = nil
            PlateNetRequest('position', sample, entry.token, function(ok, data, status)
                if not ok and PlateNetNeedsRepair(data, status) then
                    repairFor(entry)
                end
            end)
        end
    end
end

local function sendBatch(samples, entries)
    PlateNetRequest('positions', {samples = samples}, nil, function(ok, data, status)
        if ok then
            if type(data.results) == 'table' then
                for i, result in ipairs(data.results) do
                    if type(result) == 'table' and result.repair then
                        repairFor(entries[i])
                    end
                end
            end
            return
        end
        if status == 400 and not legacyCad then
            legacyCad = true
            print('^3[platenet] Update PlateNet to restore live positions.^7')
        end
        if legacyCad then
            sendLegacy(samples, entries)
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

        local i = 1
        while i <= #samples do
            local chunk, chunkEntries = {}, {}
            for j = i, math.min(i + BATCH_LIMIT - 1, #samples) do
                chunk[#chunk + 1] = samples[j]
                chunkEntries[#chunkEntries + 1] = entries[j]
            end
            sendBatch(chunk, chunkEntries)
            i = i + BATCH_LIMIT
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    lastSent[src] = nil
    streets[src] = nil
    streetAt[src] = nil
end)
