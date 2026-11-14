-- PlateNet CAD/MDT | https://platenet.app | Copyright (c) 2026 scentral and PlateNet. All rights reserved. See license.md.

local openSettingsOnLaunch = false
local currentTabletUrl = ''

local TABLET_ANIM = {
    prop = 'prop_cs_tablet',
    bone = 60309,
    pos = vector3(0.0300, 0.0020, 0.0000),
    rot = vector3(10.0000, 160.0000, 0.0000),
    dict = 'amb@code_human_in_bus_passenger_idles@female@tablet@base',
    clip = 'base',
    flags = 49,
}
local ANIM_OFF_KEY = 'platenet_tablet_anim_off'
local animOff = GetResourceKvpInt(ANIM_OFF_KEY) == 1
local animRun = 0
local animProp = 0
local animPlaying = false

local function animAllowed()
    return Config.TabletAnimation ~= false
end

local function animOn()
    return animAllowed() and not animOff
end

local function stopTabletAnim()
    animRun = animRun + 1
    if animProp ~= 0 then
        if DoesEntityExist(animProp) then
            DetachEntity(animProp, true, false)
            DeleteEntity(animProp)
        end
        animProp = 0
    end
    if animPlaying then
        StopAnimTask(PlayerPedId(), TABLET_ANIM.dict, TABLET_ANIM.clip, 2.0)
        animPlaying = false
    end
end

local function startTabletAnim()
    stopTabletAnim()
    if not animOn() then return end
    local run = animRun
    CreateThread(function()
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) then return end
        local model = GetHashKey(TABLET_ANIM.prop)
        RequestModel(model)
        RequestAnimDict(TABLET_ANIM.dict)
        local deadline = GetGameTimer() + 3000
        while (not HasModelLoaded(model) or not HasAnimDictLoaded(TABLET_ANIM.dict)) and GetGameTimer() < deadline do
            Wait(0)
        end
        if run ~= animRun or not PlateNet.tabletOpen then return end
        if not HasModelLoaded(model) or not HasAnimDictLoaded(TABLET_ANIM.dict) then return end
        ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) then return end
        local coords = GetEntityCoords(ped)
        animProp = CreateObject(model, coords.x, coords.y, coords.z + 0.2, true, true, false)
        SetEntityCollision(animProp, false, false)
        AttachEntityToEntity(animProp, ped, GetPedBoneIndex(ped, TABLET_ANIM.bone),
            TABLET_ANIM.pos.x, TABLET_ANIM.pos.y, TABLET_ANIM.pos.z,
            TABLET_ANIM.rot.x, TABLET_ANIM.rot.y, TABLET_ANIM.rot.z,
            true, true, false, true, 1, true)
        SetModelAsNoLongerNeeded(model)
        TaskPlayAnim(ped, TABLET_ANIM.dict, TABLET_ANIM.clip, 3.0, 3.0, -1, TABLET_ANIM.flags, 0, false, false, false)
        animPlaying = true
    end)
end

local function settingsMessage()
    return {
        action = 'settings',
        open = true,
        animAllowed = animAllowed(),
        anim = animOn(),
    }
end

local function setTablet(open, url)
    local wasOpen = PlateNet.tabletOpen and true or false
    PlateNet.tabletOpen = open and true or false
    if PlateNet.tabletOpen and not wasOpen then
        startTabletAnim()
    elseif not PlateNet.tabletOpen then
        stopTabletAnim()
    end
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
        SendNUIMessage(settingsMessage())
    end
end)

RegisterNUICallback('close', function(_data, cb)
    setTablet(false)
    cb({ok = true})
end)

function PlateNetToggleTabletAnim()
    if not animAllowed() then
        PlateNetNotify('PlateNet: the tablet animation is turned off on this server.')
        return false
    end
    animOff = not animOff
    SetResourceKvpInt(ANIM_OFF_KEY, animOff and 1 or 0)
    if PlateNet.tabletOpen then
        if animOff then stopTabletAnim() else startTabletAnim() end
    end
    PlateNetNotify(animOff and 'PlateNet: tablet animation off.' or 'PlateNet: tablet animation on.')
    return true
end

RegisterNUICallback('tabletAnim', function(_data, cb)
    PlateNetToggleTabletAnim()
    cb({allowed = animAllowed(), on = animOn()})
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
        SendNUIMessage(settingsMessage())
        return
    end

    openSettingsOnLaunch = true
    TriggerServerEvent('platenet:requestTablet')
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    stopTabletAnim()
    if PlateNet.tabletOpen then
        SetNuiFocus(false, false)
    end
end)
