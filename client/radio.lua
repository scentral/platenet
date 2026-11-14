-- PlateNet CAD/MDT | https://platenet.app | Copyright (c) 2026 scentral and PlateNet. All rights reserved. See license.md.

local linkedRadioName = ''
local maxRadioAudio = 2000000

RegisterNetEvent('platenet:linkedRadio', function(name)
    linkedRadioName = type(name) == 'string' and name or ''
end)

local function linkedRadio()
    if linkedRadioName == '' or GetResourceState(linkedRadioName) ~= 'started' then return nil end
    return linkedRadioName
end

local function radioReady()
    local radio = linkedRadio()
    if not radio then return false end
    local ok, ready = pcall(function()
        return exports[radio]:IsReadbackReady()
    end)
    return ok and ready == true
end

RegisterNUICallback('radioStatus', function(_data, cb)
    cb({on = radioReady()})
end)

RegisterNUICallback('radioPlay', function(data, cb)
    local audio = type(data) == 'table' and data.audio or nil
    local radio = linkedRadio()
    if not radio or type(audio) ~= 'string' or audio == '' or #audio > maxRadioAudio then
        cb({ok = false})
        return
    end
    local ok, played = pcall(function()
        return exports[radio]:PlayReadback(audio)
    end)
    cb({ok = ok and played == true})
end)

CreateThread(function()
    TriggerServerEvent('platenet:linkedRadio:request')
end)
