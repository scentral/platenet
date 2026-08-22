local sessions = {}

function PlateNetIdentifier(src)
    for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
        if id:sub(1, 8) == 'license:' then
            return id
        end
    end
    return nil
end

function PlateNetGetSession(src)
    local session = sessions[src]
    if not session then return nil end
    if not session.license or PlateNetIdentifier(src) ~= session.license then
        sessions[src] = nil
        return nil
    end
    return session
end

function PlateNetSetSession(src, token, callsign)
    sessions[src] = {
        token = token,
        callsign = callsign or '',
        license = PlateNetIdentifier(src),
    }
end

function PlateNetClearSession(src)
    sessions[src] = nil
end

function PlateNetTakeSession(src)
    local session = sessions[src]
    sessions[src] = nil
    return session
end

function PlateNetEachSession(fn)
    local sources = {}
    for src in pairs(sessions) do
        sources[#sources + 1] = src
    end
    for _, src in ipairs(sources) do
        local session = PlateNetGetSession(src)
        if session then
            fn(src, session)
        end
    end
end
