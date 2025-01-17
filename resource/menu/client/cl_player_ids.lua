-- Prevent running if menu is disabled
if not TX_MENU_ENABLED then return end

-- =============================================
--  This file contains all overhead player ID logic
-- =============================================

-- Variables
local isPlayerIdsEnabled = false
local playerGamerTags = {}
local distanceToCheck = GetConvarInt('txAdmin-menuPlayerIdDistance', 150)

-- Game consts
local fivemGamerTagCompsEnum = {
    GamerName = 0,
    CrewTag = 1,
    HealthArmour = 2,
    BigText = 3,
    AudioIcon = 4,
    UsingMenu = 5,
    PassiveMode = 6,
    WantedStars = 7,
    Driver = 8,
    CoDriver = 9,
    Tagged = 12,
    GamerNameNearby = 13,
    Arrow = 14,
    Packages = 15,
    InvIfPedIsFollowing = 16,
    RankText = 17,
    Typing = 18
}

local redmGamerTagCompsEnum = {
    none = 0,
    icon = 1,
    simple = 2,
    complex = 3
}
local redmSpeakerIconHash = GetHashKey('SPEAKER')
local redmColorYellowHash = GetHashKey('COLOR_YELLOWSTRONG')

--- Removes all cached tags
local function cleanAllGamerTags()
    debugPrint('Cleaning up gamer tags table')
    for _, v in pairs(playerGamerTags) do
        if IsMpGamerTagActive(v.gamerTag) then
            if IS_FIVEM then
                RemoveMpGamerTag(v.gamerTag)
            else
                Citizen.InvokeNative(0x839BFD7D7E49FE09, Citizen.PointerValueIntInitialized(v.gamerTag));
            end
        end
    end
    playerGamerTags = {}
end


--- Draws a single gamer tag (fivem)
local function setGamerTagFivem(targetTag, pid)
    -- Setup name
    SetMpGamerTagVisibility(targetTag, fivemGamerTagCompsEnum.GamerName, 1)

    -- Setup Health
    SetMpGamerTagHealthBarColor(targetTag, 129)
    SetMpGamerTagAlpha(targetTag, fivemGamerTagCompsEnum.HealthArmour, 255)
    SetMpGamerTagVisibility(targetTag, fivemGamerTagCompsEnum.HealthArmour, 1)

    -- Setup AudioIcon
    SetMpGamerTagAlpha(targetTag, fivemGamerTagCompsEnum.AudioIcon, 255)
    if NetworkIsPlayerTalking(pid) then
        SetMpGamerTagVisibility(targetTag, fivemGamerTagCompsEnum.AudioIcon, true)
        SetMpGamerTagColour(targetTag, fivemGamerTagCompsEnum.AudioIcon, 12) --HUD_COLOUR_YELLOW
        SetMpGamerTagColour(targetTag, fivemGamerTagCompsEnum.GamerName, 12) --HUD_COLOUR_YELLOW
    else
        SetMpGamerTagVisibility(targetTag, fivemGamerTagCompsEnum.AudioIcon, false)
        SetMpGamerTagColour(targetTag, fivemGamerTagCompsEnum.AudioIcon, 0)
        SetMpGamerTagColour(targetTag, fivemGamerTagCompsEnum.GamerName, 0)
    end
end

--- Clears a single gamer tag (fivem)
local function clearGamerTagFivem(targetTag)
    -- Cleanup name
    SetMpGamerTagVisibility(targetTag, fivemGamerTagCompsEnum.GamerName, 0)
    -- Cleanup Health
    SetMpGamerTagVisibility(targetTag, fivemGamerTagCompsEnum.HealthArmour, 0)
    -- Cleanup AudioIcon
    SetMpGamerTagVisibility(targetTag, fivemGamerTagCompsEnum.AudioIcon, 0)
end


--- Draws a single gamer tag (redm)
local function setGamerTagRedm(targetTag, pid)
    Citizen.InvokeNative(0x93171DDDAB274EB8, targetTag, redmGamerTagCompsEnum.complex) --SetMpGamerTagVisibility
    if MumbleIsPlayerTalking(pid) then
        Citizen.InvokeNative(0x95384C6CE1526EFF, targetTag, redmSpeakerIconHash) --SetMpGamerTagSecondaryIcon
        Citizen.InvokeNative(0x84BD27DDF9575816, targetTag, redmColorYellowHash) --SetMpGamerTagColour
    else
        Citizen.InvokeNative(0x95384C6CE1526EFF, targetTag, nil) --SetMpGamerTagSecondaryIcon
        Citizen.InvokeNative(0x84BD27DDF9575816, targetTag, 0) --SetMpGamerTagColour
    end
end

--- Clears a single gamer tag (redm)
local function clearGamerTagRedm(targetTag)
    Citizen.InvokeNative(0x93171DDDAB274EB8, targetTag, redmGamerTagCompsEnum.none) --SetMpGamerTagVisibility
end


--- Setting game-specific functions
local setGamerTagFunc = IS_FIVEM and setGamerTagFivem or setGamerTagRedm
local clearGamerTagFunc = IS_FIVEM and clearGamerTagFivem or clearGamerTagRedm


--- Loops through every player, checks distance and draws or hides the tag
local function showGamerTags()
    local curCoords = GetEntityCoords(PlayerPedId())
    -- Per infinity this will only return players within 300m
    local allActivePlayers = GetActivePlayers()

    for _, pid in ipairs(allActivePlayers) do
        -- Resolving player
        local targetPed = GetPlayerPed(pid)

        -- If we have not yet indexed this player or their tag has somehow dissapeared (pause, etc)
        if not playerGamerTags[pid] or not IsMpGamerTagActive(playerGamerTags[pid].gamerTag) then
            local playerName = string.sub(GetPlayerName(pid) or "unknown", 1, 75)
            local playerStr = '[' .. GetPlayerServerId(pid) .. ']' .. ' ' .. playerName
            playerGamerTags[pid] = {
                gamerTag = CreateFakeMpGamerTag(targetPed, playerStr, false, false, 0),
                ped = targetPed
            }
        end
        local targetTag = playerGamerTags[pid].gamerTag

        -- Distance Check
        local targetPedCoords = GetEntityCoords(targetPed)
        if #(targetPedCoords - curCoords) <= distanceToCheck then
            setGamerTagFunc(targetTag, pid)
        else
            clearGamerTagFunc(targetTag)
        end
    end
end

--- Starts the gamer tag thread
--- Increasing/decreasing the delay realistically only reflects on the
--- delay for the VOIP indicator icon, 250 is fine
local function createGamerTagThread()
    debugPrint('Starting gamer tag thread')
    CreateThread(function()
        while isPlayerIdsEnabled do
            showGamerTags()
            Wait(250)
        end

        isPlayerIDActive = enabled
        if not isPlayerIDActive then
            sendSnackbarMessage('info', 'nui_menu.page_main.player_ids.above_head.alert_hide', true)
            -- Remove all gamer tags and clear out active table
            cleanAllGamerTags()
        else
            sendSnackbarMessage('info', 'nui_menu.page_main.player_ids.above_head.alert_show', true)
        end

        debugPrint('Show Player IDs Status: ' .. tostring(isPlayerIDActive))
    end)
end


--- Function to enable or disable the player ids
function toggleShowPlayerIDs(enabled, showNotification)
    if not menuIsAccessible then return end

    isPlayerIdsEnabled = enabled
    local snackMessage
    if isPlayerIdsEnabled then
        snackMessage = 'nui_menu.page_main.player_ids.alert_show'
        createGamerTagThread()
    else
        snackMessage = 'nui_menu.page_main.player_ids.alert_hide'
    end

    if showNotification then
        sendSnackbarMessage('info', snackMessage, true)
    end
    debugPrint('Show Player IDs Status: ' .. tostring(isPlayerIdsEnabled))
end


--- Receives the return from the server and toggles player ids on/off
RegisterNetEvent('txcl:showPlayerIDs', function(enabled)
    debugPrint('Received showPlayerIDs event')
    toggleShowPlayerIDs(enabled, true)
end)

--- Sends perms request to the server to enable player ids
local function togglePlayerIDsHandler()
    TriggerServerEvent('txsv:req:showPlayerIDs', not isPlayerIdsEnabled)
end

RegisterNUICallback('togglePlayerIDs', function(_, cb)
    togglePlayerIDsHandler()
    cb({})
end)

RegisterCommand('txAdmin:menu:togglePlayerIDs', togglePlayerIDsHandler)

local playersBlips = {}
---Refreshes blips on client
---@param blipsData {[string]: {coords: {x:number,y:number,z:number,h:number}, name:string}}
local function refreshPlayerBlips(blipsData)
    for k, v in pairs(playersBlips) do
        RemoveBlip(v)
      end
      playersBlips = {}
      for playerId, v in pairs(blipsData) do
        local blip = AddBlipForCoord(v.coords.x+0.01, v.coords.y+0.01, v.coords.z+0.01)
        playersBlips[playerId] = blip
        SetBlipShrink(blip, true)
        SetBlipCategory(blip, 7)
        SetBlipSprite(blip, 1)
        SetBlipDisplay(blip, 4)
        SetBlipScale(blip, 0.87)
        SetBlipColour(blip, 2)
        SetBlipFlashes(blip, false)
        SetBlipRotation(blip, math.ceil(v.coords.h))
        ShowNumberOnBlip(blip, tonumber(playerId % 100)) -- If blip number is above 100 it won't show anything
        ShowHeadingIndicatorOnBlip(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(('%s [%s]'):format(v.name, playerId))
        EndTextCommandSetBlipName(blip)
      end
end

RegisterNetEvent('txAdmin:menu:refreshPlayerBlips', function(blipsData, enabled)
    debugPrint('Received refreshPlayerBlips event')
    refreshPlayerBlips(blipsData)
    if enabled == nil then return end
    if enabled then
        sendSnackbarMessage('info', 'nui_menu.page_main.player_ids.map_blips.alert_show', true)
    else
        sendSnackbarMessage('info', 'nui_menu.page_main.player_ids.map_blips.alert_hide', true)
    end
end)

local function togglePlayerMapBlipsHandler()
    TriggerServerEvent('txAdmin:menu:showPlayerMapBlips', not isPlayerIDActive)
end

RegisterNUICallback('togglePlayerMapBlips', function(_, cb)
    togglePlayerMapBlipsHandler()
    cb({})
end)

RegisterCommand('txAdmin:menu:togglePlayerMapBlips', togglePlayerMapBlipsHandler)

CreateThread(function()
    local sleep = 150
    while true do
        if isPlayerIDActive then
            showGamerTags()
            sleep = 50
        else
            sleep = 500
        end
        Wait(sleep)
    end
end)
