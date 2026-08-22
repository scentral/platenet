local openSettingsOnLaunch = false
local currentTabletUrl = ''

local function setTablet(open, url)
    PlateNet.tabletOpen = open and true or false
    if PlateNet.tabletOpen and type(url) == 'string' and url ~= '' then
        currentTabletUrl = url
    end
    SetNuiFocus(PlateNet.tabletOpen, PlateNet.tabletOpen)
    SendNUIMessage({
        action = PlateNet.tabletOpen and 'open' or 'close',
        url = url or '',
    })
end

RegisterNUICallback('ready', function(_data, cb)
    if PlateNet.tabletOpen and currentTabletUrl ~= '' then
        SendNUIMessage({
            action = 'open',
            url = currentTabletUrl,
        })
    end
    cb({ok = true})
end)

local function tabletUrlAllowed(url)
    if type(url) ~= 'string' or url == '' then return false end
    local origin = tostring(Config.GameUrl or ''):gsub('/+$', ''):lower()
    if origin == '' then return false end
    local candidate = url:lower()
    if candidate == origin then return true end
    if candidate:sub(1, #origin) ~= origin then return false end
    local boundary = candidate:sub(#origin + 1, #origin + 1)
    return boundary == '/' or boundary == '?' or boundary == '#'
end

RegisterNetEvent('platenet:openTablet', function(payload)
    if type(payload) ~= 'table' or type(payload.url) ~= 'string' then return end
    if not tabletUrlAllowed(payload.url) then return end
    setTablet(true, payload.url)
    if openSettingsOnLaunch then
        openSettingsOnLaunch = false
        SendNUIMessage({
            action = 'settings',
            open = true,
        })
    end
end)

RegisterNUICallback('close', function(_data, cb)
    setTablet(false)
    cb({ok = true})
end)

CreateThread(function()
    while true do
        if PlateNet.tabletOpen then
            Wait(0)
            if IsControlJustReleased(0, 322) then
                setTablet(false)
            end
        else
            Wait(300)
        end
    end
end)

function PlateNetToggleTablet()
    if PlateNet.tabletOpen then
        setTablet(false)
        return
    end

    TriggerServerEvent('platenet:requestTablet')
end

function PlateNetOpenSettings()
    if PlateNet.tabletOpen then
        SendNUIMessage({
            action = 'settings',
            open = true,
        })
        return
    end

    openSettingsOnLaunch = true
    TriggerServerEvent('platenet:requestTablet')
end

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() and PlateNet.tabletOpen then
        SetNuiFocus(false, false)
    end
end)
