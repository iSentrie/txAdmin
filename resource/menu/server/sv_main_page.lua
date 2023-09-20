-- Prevent running in monitor mode
if not TX_SERVER_MODE then return end
-- Prevent running if menu is disabled
if not TX_MENU_ENABLED then return end

-- =============================================
--  This file is for server side handlers related to
--  actions defined on Menu's "Main Page"
-- =============================================

RegisterNetEvent('txsv:req:tpToWaypoint', function()
  local src = source
  local allow = PlayerHasTxPermission(src, 'players.teleport')
  if allow then
    TriggerClientEvent('txcl:tpToWaypoint', src)
    Wait(250)
    local coords = GetEntityCoords(GetPlayerPed(src))
    TriggerEvent('txsv:logger:menuEvent', src, 'teleportWaypoint', true,
        { x = coords[1], y = coords[2], z = coords[3] })
  else
    TriggerEvent('txsv:logger:menuEvent', src, 'teleportWaypoint', false)
  end
end)

RegisterNetEvent('txsv:req:sendAnnouncement', function(message)
  local src = source
  if type(message) ~= 'string' then
    return
  end
  local allow = PlayerHasTxPermission(src, 'players.message')
  TriggerEvent('txsv:logger:menuEvent', src, 'announcement', allow, message)
  if allow then
    PrintStructuredTrace(json.encode({
      type = 'txAdminCommandBridge',
      command = 'announcement',
      author = TX_ADMINS[tostring(src)].username,
      message = message,
    }))
  end
end)

RegisterNetEvent('txsv:req:clearArea', function(radius)
  local src = source
  local allow = PlayerHasTxPermission(src, 'menu.clear_area')
  TriggerEvent('txsv:logger:menuEvent', src, 'clearArea', allow, radius)
  if allow then
    TriggerClientEvent('txcl:clearArea', src, radius)
  end
end)

RegisterNetEvent('txsv:req:healEveryone', function()
  local src = source
  local allow = PlayerHasTxPermission(src, 'players.heal')
  TriggerEvent('txsv:logger:menuEvent', src, 'healAll', true)
  if allow then
    -- For use with third party resources that handle players
    -- 'revive state' standalone from health (esx-ambulancejob, qb-ambulancejob, etc)
    TriggerEvent('txAdmin:events:healedPlayer', {id = -1})
    TriggerClientEvent('txcl:heal', -1)
  end
end)

RegisterNetEvent('txsv:req:healMyself', function()
  local src = source
  local allow = PlayerHasTxPermission(src, 'players.heal')
  TriggerEvent('txsv:logger:menuEvent', src, 'healSelf', allow)
  if allow then
    -- For use with third party resources that handle players
    -- 'revive state' standalone from health (esx-ambulancejob, qb-ambulancejob, etc)
    TriggerEvent('txAdmin:events:healedPlayer', {id = src})
    TriggerClientEvent('txcl:heal', src)
  end
end)

RegisterNetEvent('txsv:req:healPlayer', function(id)
  local src = source
  if type(id) ~= 'string' and type(id) ~= 'number' then
    return
  end
  id = tonumber(id)
  local allow = PlayerHasTxPermission(src, 'players.heal')
  if allow then
    local ped = GetPlayerPed(id)
    if ped then
      -- For use with third party resources that handle players
      -- 'revive state' standalone from health (esx-ambulancejob, qb-ambulancejob, etc)
      -- TriggerEvent('txAdmin:healedPlayer', id)
      TriggerEvent('txAdmin:events:healedPlayer', {id = id})
      TriggerClientEvent('txcl:heal', id)
    end
  end
  TriggerEvent('txsv:logger:menuEvent', src, 'healPlayer', allow, id)
end)

RegisterNetEvent('txsv:req:showPlayerIDs', function(enabled)
  local src = source
  local allow = PlayerHasTxPermission(src, 'menu.viewids')
  TriggerEvent('txsv:logger:menuEvent', src, 'showPlayerIDs', allow, enabled)
  if allow then
    TriggerClientEvent('txcl:showPlayerIDs', src, enabled)
  end
end)

---Stores data needed for blips
---@type { [serverID]: {coords: {x:number,y:number,z:number,h:number}, name: string, blipsEnabled: boolean, foundLastCheck: boolean} }
local playerBlipsData = {}
local BLIPS_REFRESH_TIMEOUT = 2000
local intervalYieldLimit = 50

RegisterNetEvent('txAdmin:menu:showPlayerMapBlips', function(enabled)
  local src = source
  local allow = PlayerHasTxPermission(src, 'menu.viewids')
  if allow then
    if type(playerBlipsData[tostring(src)]) == 'table' then
      playerBlipsData[tostring(src)].blipsEnabled = not playerBlipsData[tostring(src)].blipsEnabled
    else
      playerBlipsData[tostring(src)] = {
        blipsEnabled = true
      }
    end
    TriggerEvent("txaLogger:menuEvent", src, "showPlayerMapBlips", allow, playerBlipsData[tostring(src)].blipsEnabled)
    TriggerClientEvent('txAdmin:menu:refreshPlayerBlips', src, {}, playerBlipsData[tostring(src)].blipsEnabled)
  end
end)

Citizen.CreateThread(function()
  while true do
    Citizen.Wait(BLIPS_REFRESH_TIMEOUT)
    for yieldCounter, serverID in ipairs(GetPlayers()) do
      local ping = GetPlayerPing(serverID)
      if serverID and ping ~= nil and type(ping) == 'number' and ping > 1 then
        local ped = GetPlayerPed(serverID)
        local coords = GetEntityCoords(ped)
        local h = GetEntityHeading(ped)
        if type(playerBlipsData[tostring(serverID)]) ~= 'table' then
          playerBlipsData[tostring(serverID)] = {}
        end
        playerBlipsData[tostring(serverID)].coords = {
          x = math.floor(coords.x),
          y = math.floor(coords.y),
          z = math.floor(coords.z),
          h = h
        }
        playerBlipsData[tostring(serverID)].name = GetPlayerName(serverID)
        playerBlipsData[tostring(serverID)].foundLastCheck = true
        if playerBlipsData[tostring(serverID)].blipsEnabled then
          TriggerClientEvent('txAdmin:menu:refreshPlayerBlips', serverID, playerBlipsData)
        end
      end
      -- Yield to prevent hitches
      if yieldCounter % intervalYieldLimit == 0 then
        Wait(0)
      end
    end
    
    for playerID, playerData in pairs(playerBlipsData) do
      if playerData.foundLastCheck == true then
          playerData.foundLastCheck = false
      else
        playerBlipsData[playerID] = nil
      end
    end
  end
end)

---@param x number|nil
---@param y number|nil
---@param z number|nil
RegisterNetEvent('txsv:req:tpToCoords', function(x, y, z)
  local src = source
  if type(x) ~= 'number' or type(y) ~= 'number' or type(z) ~= 'number' then
    return
  end

  local allow = PlayerHasTxPermission(src, 'players.teleport')
  TriggerEvent('txsv:logger:menuEvent', src, 'teleportCoords', true, { x = x, y = y, z = z })
  if allow then
    TriggerClientEvent('txcl:tpToCoords', src, x, y, z)
  end
end)
