local STREET_INTERVAL_MS = 10000

local lastStreet = nil

local function streetFor(coords)
    local street, crossing = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local name = GetStreetNameFromHashKey(street)
    if crossing and crossing ~= 0 then
        local cross = GetStreetNameFromHashKey(crossing)
        if cross and cross ~= '' and cross ~= name then
            return ('%s / %s'):format(name, cross)
        end
    end
    return name or ''
end

CreateThread(function()
    while true do
        Wait(STREET_INTERVAL_MS)
        if PlateNet.paired then
            local coords = GetEntityCoords(PlayerPedId())
            local street = streetFor(coords)
            if street ~= '' and street ~= lastStreet then
                lastStreet = street
                TriggerServerEvent('platenet:street', street)
            end
        end
    end
end)
