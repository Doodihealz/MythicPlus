
--===========================================================
-- Mythic+ System for WotLK (Eluna) - AzerothCore
-- Author: Doodihealz
--===========================================================

MYTHIC_FINAL_BOSSES = {
  [206] = { -- Utgarde Keep (zone/custom alias)
    bosses = { 30748, 31679, 31656, 23954 }, final = 23954, finalNames = { "Ingvar the Plunderer" },
  },
  [491] = { -- Utgarde Keep (legacy/custom alias)
    bosses = { 30748, 31679, 31656, 23954 }, final = 23954, finalNames = { "Ingvar the Plunderer" },
  },
  [574] = { -- Utgarde Keep (map ID)
    bosses = { 30748, 31679, 31656, 23954 }, final = 23954, finalNames = { "Ingvar the Plunderer" },
  },
  [575] = { -- Utgarde Pinnacle
    bosses = { 30809, 30774, 30807, 30788, 26861 }, final = 26861, finalNames = { "King Ymiron" },
  },
  [576] = { -- The Nexus
    bosses = { 30510, 30529, 30532, 30540 }, final = 30540, finalNames = { "Keristrasza" },
  },
  [578] = { -- The Oculus
    bosses = { 31558, 31559, 31560, 31561 }, final = { 31561, 27656 }, finalNames = { "Ley-Guardian Eregos" },
  },
  [595] = { -- The Culling of Stratholme
    bosses = { 31211, 31212, 31215, 32313 }, final = 32313, finalNames = { "Mal'Ganis" },
  },
  [599] = { -- Halls of Stone
    bosses = { 31381, 31384, 28234, 31386, 27978 }, final = { 31386, 27978 }, finalNames = { "Brann Bronzebeard", "Sjonnir the Ironshaper" },
  },
  [600] = { -- Drak'Tharon Keep
    bosses = { 31362, 31350, 31349, 31360, 26632 }, final = { 31360, 26632 }, finalNames = { "The Prophet Tharon'ja" },
  },
  [601] = { -- Azjol-Nerub
    bosses = { 31612, 31611, 31610 }, final = { 31610, 29120 }, finalNames = { "Anub'arak" },
  },
  [602] = { -- Halls of Lightning
    bosses = { 31533, 31536, 31537, 31538 }, final = 31538, finalNames = { "Loken" },
  },
  [604] = { -- Gundrak
    bosses = { 31370, 31365, 30530, 31368, 29306 }, final = 31368, finalNames = { "Gal'darah" },
  },
  [608] = { -- The Violet Hold
    bosses = { 31507, 31510, 31508, 31511, 31509, 31512, 31506, 31134 }, final = { 31506, 31134 }, finalNames = { "Cyanigosa" },
  },
  [619] = { -- Ahn'kahet: The Old Kingdom
    bosses = { 31456, 31469, 31465, 31464 }, final = 31464, finalNames = { "Herald Volazj" },
  },
  [632] = { -- Forge of Souls
    bosses = { 36498, 37677 }, final = 37677, finalNames = { "Devourer of Souls" },
  },
  [650] = { -- Trial of the Champion
    bosses = { 36088, 36082, 36083, 36086, 36087, 36089, 36085, 36090, 36091, 35568, 35518, 35517, 35490, 35451 }, final = 35490, finalNames = { "The Black Knight" },
  },
  [658] = { -- Pit of Saron
    bosses = { 37613, 37627, 37629, 36938 }, final = 36938, finalNames = { "Scourgelord Tyrannus" },
  },
  [668] = { -- Halls of Reflection
    bosses = { 38599, 38603 }, final = 38603, finalNames = { "The Lich King" },
  },
}

local function MythicLog(message)
  if not message then return end
  print(string.format("[Mythic] %s", message))
end

local function MythicSendPlayerMessage(player, message)
  if player and message and player.SendBroadcastMessage then
    player:SendBroadcastMessage(message)
  end
end

local function MythicSendWorldMessage(message)
  if message then
    SendWorldMessage(message)
  end
end

_G.__MYTHIC_CLASS_COLOR_BY_ID__ = _G.__MYTHIC_CLASS_COLOR_BY_ID__ or {
  [1]  = "|cffc79c6e", -- Warrior
  [2]  = "|cfff58cba", -- Paladin
  [3]  = "|cffabd473", -- Hunter
  [4]  = "|cfffff569", -- Rogue
  [5]  = "|cffffffff", -- Priest
  [6]  = "|cffc41f3b", -- Death Knight
  [7]  = "|cff0070de", -- Shaman
  [8]  = "|cff69ccf0", -- Mage
  [9]  = "|cff9482c9", -- Warlock
  [11] = "|cffff7d0a", -- Druid
}

function MythicColorizePlayerName(player)
  if not player or not player.GetName then
    return "Unknown"
  end

  local name = player:GetName() or "Unknown"
  local classId = nil
  if player.GetClass then
    local okClass, id = pcall(player.GetClass, player)
    if okClass and id then
      classId = tonumber(id)
    end
  end

  local color = (_G.__MYTHIC_CLASS_COLOR_BY_ID__ or {})[classId] or "|cffffffff"
  return color .. name .. "|r"
end

local ITEM_LINK_CACHE = ITEM_LINK_CACHE or {}

local function SafeGetItemLink(entry)
  if entry and ITEM_LINK_CACHE[entry] then
    return ITEM_LINK_CACHE[entry]
  end

  if entry and GetItemLink then
    local ok, link = pcall(GetItemLink, entry)
    if ok and link then
      ITEM_LINK_CACHE[entry] = link
      return link
    end
  end
  if entry and GetItemTemplate then
    local tpl = GetItemTemplate(entry)
    if tpl and tpl.GetName then
      local ok, name = pcall(tpl.GetName, tpl)
      if ok and name and name ~= "" then
        local link = string.format("|cffffffff[%s]|r", name)
        ITEM_LINK_CACHE[entry] = link
        return link
      end
    end
  end
  local fallback = string.format("|cffffffff[Item %d]|r", entry or 0)
  if entry then
    ITEM_LINK_CACHE[entry] = fallback
  end
  return fallback
end

local function GetItemLinkFromAddResult(entry, addResult)
  if addResult and (type(addResult) == "userdata" or type(addResult) == "table") then
    if addResult.GetItemLink then
      local ok, link = pcall(addResult.GetItemLink, addResult)
      if ok and link then return link end
    end
    if addResult.GetName then
      local ok, name = pcall(addResult.GetName, addResult)
      if ok and name then return string.format("|cffffffff[%s]|r", name) end
    end
  end
  return SafeGetItemLink(entry)
end

local function TryGiveItem(player, entry, count)
  if not player or not entry or entry <= 0 then return false, nil, "Invalid item." end
  count = count or 1
  if player.CanStoreItem and type(player.CanStoreItem) == "function" then
    local ok, result = pcall(function() return player:CanStoreItem(255, 255, entry, count) end)
    if ok and result and result ~= 0 then
      return false, nil, "You need at least 1 free bag slot."
    end
  end
  if not player.AddItem then return false, nil, "Unable to add items." end
  local ok, res = pcall(player.AddItem, player, entry, count)
  if ok and res then
    return true, res, nil
  end
  return false, nil, "Not enough bag space."
end

local function EscapeSQLValue(value)
  if value == nil then
    return "NULL"
  end
  local valueType = type(value)
  if valueType == "number" then
    return tostring(value)
  end
  if valueType == "boolean" then
    return value and "1" or "0"
  end
  local str = tostring(value)
  str = str:gsub("\\", "\\\\")
  str = str:gsub("'", "''")
  return string.format("'%s'", str)
end

local function PrepareSQL(query, ...)
  local args = { ... }
  local index = 0
  local prepared = query:gsub("%?", function()
    index = index + 1
    return EscapeSQLValue(args[index])
  end)
  return prepared
end

local function DBQuery(query, ...)
  return CharDBQuery(PrepareSQL(query, ...))
end

local function DBExecute(query, ...)
  return CharDBExecute(PrepareSQL(query, ...))
end

--==========================================================
-- Config & Constants
--==========================================================
local PEDESTAL_NPC_ENTRY           = 900001
local PEDESTAL_FALLBACK_NAMES      = { ["mythic keystone master"] = true }
local PEDESTAL_DETECTION_RADIUS    = 120
local MYTHIC_SCAN_RADIUS           = 500
local RATING_CAP                   = 2000
local AURA_LOOP_INTERVAL           = 2000
local COMMAND_COOLDOWN             = 300
local TIMER_COMMAND_COOLDOWN       = 300
local RESET_CONFIRM_TIMEOUT        = 30
local INSTANCE_STATE_TIMEOUT       = 7200
local AFFIX_REROLL_INTERVAL_MS     = 6 * 60 * 60 * 1000
local DEATH_FLUSH_INTERVAL_MS      = 5000
local AFFIX_SYSTEM_DEFAULT_ENABLED = true
if _G.__MYTHIC_ENEMY_FORCES_LOCKED__ == nil then
  _G.__MYTHIC_ENEMY_FORCES_LOCKED__ = true
end

-- Map IDs used in timer overrides
local FORGE_OF_SOULS_MAP_ID        = 632
local CULLING_OF_STRATHOLME_MAP_ID = 595
local AHN_KAHET_MAP_ID             = 619
local VIOLET_HOLD_MAP_ID           = 608
local HALLS_OF_REFLECTION_MAP_ID   = 668
local HOR_FAILSAFE_SCAN_INTERVAL_MS = 3000
local HOR_FAILSAFE_SCAN_RADIUS      = 500
local HOR_COMPLETION_STAIRS = { [201709] = true, [202211] = true }
local HOR_COMPLETION_LEADERS = { [36955] = true, [37554] = true }

--==========================================================
-- Runtime State (per-instance / persistent helpers)
--==========================================================
local MYTHIC_TIMER_EXPIRED       = MYTHIC_TIMER_EXPIRED       or {}
local MYTHIC_KILL_LOCK           = MYTHIC_KILL_LOCK           or {}
local MYTHIC_DEATHS              = MYTHIC_DEATHS              or {}
local MYTHIC_FLAG_TABLE          = MYTHIC_FLAG_TABLE          or {}
local MYTHIC_AFFIXES_TABLE       = MYTHIC_AFFIXES_TABLE       or {}
local MYTHIC_REWARD_CHANCE_TABLE = MYTHIC_REWARD_CHANCE_TABLE or {}
local MYTHIC_CHEST_SPAWNED       = MYTHIC_CHEST_SPAWNED       or {}
local MYTHIC_FINAL_BOSSES        = MYTHIC_FINAL_BOSSES        or {}
local MYTHIC_MODE_ENDED          = MYTHIC_MODE_ENDED          or {}
local MYTHIC_LOOP_HANDLERS       = MYTHIC_LOOP_HANDLERS       or {}
local MYTHIC_TIER_TABLE          = MYTHIC_TIER_TABLE          or {}
local MYTHIC_COMPLETION_STATE    = MYTHIC_COMPLETION_STATE    or {}
local MYTHIC_KILL_LOCK_META      = MYTHIC_KILL_LOCK_META      or {}
local __MYTHIC_RATING_COOLDOWN__ = __MYTHIC_RATING_COOLDOWN__ or {}
local __MYTHIC_RESET_PENDING__   = __MYTHIC_RESET_PENDING__   or {}
local __MYTHIC_TIMER_COOLDOWN__  = __MYTHIC_TIMER_COOLDOWN__  or {}
local MYTHIC_TIMEOUT_EVENTS      = MYTHIC_TIMEOUT_EVENTS      or {}
local __MYTHIC_AFFIX_COOLDOWN__  = __MYTHIC_AFFIX_COOLDOWN__  or {}
local MYTHIC_PENDING_DEATH_WRITES = MYTHIC_PENDING_DEATH_WRITES or {}
local MYTHIC_REGISTERED_PEDESTAL_ENTRIES = MYTHIC_REGISTERED_PEDESTAL_ENTRIES or {}
local MYTHIC_HOR_FAILSAFE_EVENTS   = MYTHIC_HOR_FAILSAFE_EVENTS   or {}
local MYTHIC_NON_BOSS_KILLS      = MYTHIC_NON_BOSS_KILLS      or {}
local MYTHIC_FORCES_WARN_TS      = MYTHIC_FORCES_WARN_TS      or {}
local MYTHIC_FORCES_PERSIST_CACHE = MYTHIC_FORCES_PERSIST_CACHE or {}
local GLOBAL_LOOP_HANDLERS_TABLE_KEY = "__MYTHIC_LOOP_HANDLERS__"
local GLOBAL_TIMEOUT_EVENTS_TABLE_KEY = "__MYTHIC_TIMEOUT_EVENTS__"
local GLOBAL_HOR_FAILSAFE_EVENTS_TABLE_KEY = "__MYTHIC_HOR_FAILSAFE_EVENTS__"
_G[GLOBAL_LOOP_HANDLERS_TABLE_KEY] = _G[GLOBAL_LOOP_HANDLERS_TABLE_KEY] or MYTHIC_LOOP_HANDLERS
_G[GLOBAL_TIMEOUT_EVENTS_TABLE_KEY] = _G[GLOBAL_TIMEOUT_EVENTS_TABLE_KEY] or MYTHIC_TIMEOUT_EVENTS
_G[GLOBAL_HOR_FAILSAFE_EVENTS_TABLE_KEY] = _G[GLOBAL_HOR_FAILSAFE_EVENTS_TABLE_KEY] or MYTHIC_HOR_FAILSAFE_EVENTS
MYTHIC_LOOP_HANDLERS = _G[GLOBAL_LOOP_HANDLERS_TABLE_KEY]
MYTHIC_TIMEOUT_EVENTS = _G[GLOBAL_TIMEOUT_EVENTS_TABLE_KEY]
MYTHIC_HOR_FAILSAFE_EVENTS = _G[GLOBAL_HOR_FAILSAFE_EVENTS_TABLE_KEY]
local AFFIX_SYSTEM_ENABLED_KEY    = "__MYTHIC_AFFIX_SYSTEM_ENABLED__"
if _G[AFFIX_SYSTEM_ENABLED_KEY] == nil then
  _G[AFFIX_SYSTEM_ENABLED_KEY] = AFFIX_SYSTEM_DEFAULT_ENABLED
end
local AFFIX_SYSTEM_ENABLED = _G[AFFIX_SYSTEM_ENABLED_KEY]
if _G.__MYTHIC_ENEMY_FORCES_LOCKED__ == true then
  _G.__MYTHIC_ENEMY_FORCES_ENABLED__ = true
elseif _G.__MYTHIC_ENEMY_FORCES_ENABLED__ == nil then
  _G.__MYTHIC_ENEMY_FORCES_ENABLED__ = false
end
if _G.__MYTHIC_ENEMY_FORCES_PERCENT__ == nil
   or tonumber(_G.__MYTHIC_ENEMY_FORCES_PERCENT__) == 90 then
  _G.__MYTHIC_ENEMY_FORCES_PERCENT__ = 80
end
if _G.__MYTHIC_ALLOW_SELF_CAST_FALLBACK__ == nil then
  _G.__MYTHIC_ALLOW_SELF_CAST_FALLBACK__ = false
end
if _G.__MYTHIC_DISABLE_NPC_PLAYER_AFFIX_CAST__ == nil then
  _G.__MYTHIC_DISABLE_NPC_PLAYER_AFFIX_CAST__ = true
end
_G.__MYTHIC_ENEMY_FORCES_REQUIRED__ = _G.__MYTHIC_ENEMY_FORCES_REQUIRED__ or {}
_G.__MYTHIC_ENEMY_FORCES_TRACKED_KEYS__ = _G.__MYTHIC_ENEMY_FORCES_TRACKED_KEYS__ or {}
_G.__MYTHIC_ENEMY_FORCES_KILLED_KEYS__ = _G.__MYTHIC_ENEMY_FORCES_KILLED_KEYS__ or {}
_G.__MYTHIC_ENEMY_FORCES_TRACKED_TOTAL__ = _G.__MYTHIC_ENEMY_FORCES_TRACKED_TOTAL__ or {}
_G.__MYTHIC_ENEMY_FORCES_REQ_STABLE__ = _G.__MYTHIC_ENEMY_FORCES_REQ_STABLE__ or {}
_G.__MYTHIC_ENEMY_FORCES_ELIGIBLE_KEYS__ = _G.__MYTHIC_ENEMY_FORCES_ELIGIBLE_KEYS__ or {}

-- Forward decls
local CleanupMythicInstance
local SpawnMythicRewardChest
local AutoRerollAffixes
local FinalizeMythicRun
local FlushPendingDeathWrites
local PersistEnemyForcesProgress
local NEXT_AFFIX_REROLL_AT = tonumber(_G.__MYTHIC_NEXT_AFFIX_REROLL_AT__ or 0) or 0
if NEXT_AFFIX_REROLL_AT <= 0 then
  NEXT_AFFIX_REROLL_AT = os.time() + (AFFIX_REROLL_INTERVAL_MS / 1000)
  _G.__MYTHIC_NEXT_AFFIX_REROLL_AT__ = NEXT_AFFIX_REROLL_AT
end
local AUTO_REROLL_EVENT_ID = nil
local GLOBAL_AFFIX_EVENT_KEY = "__MYTHIC_AFFIX_REROLL_EVENT_ID__"
if _G[GLOBAL_AFFIX_EVENT_KEY] then
  RemoveEventById(_G[GLOBAL_AFFIX_EVENT_KEY])
  _G[GLOBAL_AFFIX_EVENT_KEY] = nil
end
local DEATH_FLUSH_EVENT_ID = nil
local GLOBAL_DEATH_FLUSH_EVENT_KEY = "__MYTHIC_DEATH_FLUSH_EVENT_ID__"
if _G[GLOBAL_DEATH_FLUSH_EVENT_KEY] then
  RemoveEventById(_G[GLOBAL_DEATH_FLUSH_EVENT_KEY])
  _G[GLOBAL_DEATH_FLUSH_EVENT_KEY] = nil
end
local KILL_LOCK_SWEEP_EVENT_ID = nil
local GLOBAL_KILL_LOCK_SWEEP_EVENT_KEY = "__MYTHIC_KILL_LOCK_SWEEP_EVENT_ID__"
if _G[GLOBAL_KILL_LOCK_SWEEP_EVENT_KEY] then
  RemoveEventById(_G[GLOBAL_KILL_LOCK_SWEEP_EVENT_KEY])
  _G[GLOBAL_KILL_LOCK_SWEEP_EVENT_KEY] = nil
end
local RESTORE_ON_LOAD_EVENT_ID = nil
local GLOBAL_RESTORE_ON_LOAD_EVENT_KEY = "__MYTHIC_RESTORE_ON_LOAD_EVENT_ID__"
if _G[GLOBAL_RESTORE_ON_LOAD_EVENT_KEY] then
  RemoveEventById(_G[GLOBAL_RESTORE_ON_LOAD_EVENT_KEY])
  _G[GLOBAL_RESTORE_ON_LOAD_EVENT_KEY] = nil
end

for instanceId, eventId in pairs(MYTHIC_LOOP_HANDLERS) do
  if eventId then
    RemoveEventById(eventId)
  end
  MYTHIC_LOOP_HANDLERS[instanceId] = nil
end

for instanceId, timeoutEvents in pairs(MYTHIC_TIMEOUT_EVENTS) do
  if timeoutEvents then
    if timeoutEvents.keep then
      RemoveEventById(timeoutEvents.keep)
    end
    if timeoutEvents.expire then
      RemoveEventById(timeoutEvents.expire)
    end
  end
  MYTHIC_TIMEOUT_EVENTS[instanceId] = nil
end

for instanceId, eventId in pairs(MYTHIC_HOR_FAILSAFE_EVENTS) do
  if eventId then
    RemoveEventById(eventId)
  end
  MYTHIC_HOR_FAILSAFE_EVENTS[instanceId] = nil
end

--==========================================================
-- DB Helpers & Formatting
--==========================================================
local AFFIX_COLOR_MAP
local function Colorize(s, c)        return string.format("%s%s|r", c or "|cffffffff", s) end
local function ColorAffixName(name)
  local n = (name and name ~= "") and name or "None"
  return Colorize(n, AFFIX_COLOR_MAP[n] or "|cffffffff")
end

local function GetRatingColor(r)
  if r >= 1800 then return "|cffff8000"
  elseif r >= 1000 then return "|cffa335ee"
  elseif r >= 500  then return "|cff0070dd"
  else return "|cff1eff00" end
end

local function SerializeAffixes(spellList)
  if not spellList or #spellList == 0 then return "" end
  local t = {}
  for _, id in ipairs(spellList) do t[#t+1] = tostring(id) end
  return table.concat(t, ",")
end

local function ParseAffixes(str)
  local out = {}
  if not str or str == "" then return out end
  for num in string.gmatch(str, "([^,%s]+)") do
    local n = tonumber(num); if n then out[#out+1] = n end
  end
  return out
end

local function FormatDurationShort(sec)
  if sec < 0 then sec = 0 end
  local d = math.floor(sec / 86400); sec = sec % 86400
  local h = math.floor(sec / 3600);  sec = sec % 3600
  local m = math.floor(sec / 60);    sec = sec % 60
  if d > 0 then return string.format("%dd %dh %dm", d, h, m)
  elseif h > 0 then return string.format("%dh %dm %ds", h, m, sec)
  elseif m > 0 then return string.format("%dm %ds", m, sec)
  else return string.format("%ds", sec) end
end

local function FormatRaceTime(sec)
  if sec < 0 then sec = 0 end
  local h = math.floor(sec / 3600); sec = sec % 3600
  local m = math.floor(sec / 60);   local s = math.floor(sec % 60)
  if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
  return string.format("%d:%02d", m, s)
end

local function GetOnlinePlayerByGuid(fullGuid, guidLow)
  if fullGuid then
    local ok, p = pcall(GetPlayerByGUID, fullGuid)
    if ok and p then
      return p
    end
  end

  if guidLow and GetPlayersInWorld then
    for _, p in pairs(GetPlayersInWorld() or {}) do
      if p and p.GetGUIDLow and p:GetGUIDLow() == guidLow then
        return p
      end
    end
  end

  return nil
end

local function GetAffixRerollETA()
  return math.max(0, (NEXT_AFFIX_REROLL_AT or 0) - os.time())
end

local function IsAffixSystemEnabled()
  return AFFIX_SYSTEM_ENABLED == true
end

local function SetAffixSystemEnabled(enabled)
  AFFIX_SYSTEM_ENABLED = enabled == true
  _G[AFFIX_SYSTEM_ENABLED_KEY] = AFFIX_SYSTEM_ENABLED
end

function MythicGetEnemyForcesPercent()
  local pct = tonumber(_G.__MYTHIC_ENEMY_FORCES_PERCENT__ or 80) or 80
  if pct < 1 then pct = 1 end
  if pct > 100 then pct = 100 end
  return math.floor(pct)
end

function MythicGetEnemyForcesRequired(instanceId, mapId)
  local requiredByMap = _G.__MYTHIC_ENEMY_FORCES_REQUIRED__ or {}
  local staticRequired = tonumber(requiredByMap[mapId] or 0) or 0
  if staticRequired > 0 then
    return math.floor(staticRequired), false, 0, 0
  end

  local trackedTotal = ((_G.__MYTHIC_ENEMY_FORCES_TRACKED_TOTAL__ or {})[instanceId] or 0)
  if trackedTotal <= 0 then
    return 0, true, 0, MythicGetEnemyForcesPercent()
  end

  local pct = MythicGetEnemyForcesPercent()
  local required = math.ceil(trackedTotal * pct / 100)
  if required < 1 then required = 1 end
  return required, true, trackedTotal, pct
end

function MythicGetEnemyForcesProgress(instanceId, mapId)
  local kills = tonumber(MYTHIC_NON_BOSS_KILLS[instanceId] or 0) or 0
  if kills < 0 then kills = 0 end
  kills = math.floor(kills)

  local required = tonumber(MythicGetEnemyForcesRequired(instanceId, mapId) or 0) or 0
  if required < 0 then required = 0 end
  required = math.floor(required)

  local stableReqByInstance = _G.__MYTHIC_ENEMY_FORCES_REQ_STABLE__ or {}
  local stableReq = tonumber(stableReqByInstance[instanceId] or 0) or 0
  if required > stableReq then
    stableReq = required
  end
  if stableReq > 0 and required < stableReq then
    required = stableReq
  end
  stableReqByInstance[instanceId] = math.max(stableReq, required)
  _G.__MYTHIC_ENEMY_FORCES_REQ_STABLE__ = stableReqByInstance

  if PersistEnemyForcesProgress and instanceId and instanceId ~= 0 then
    PersistEnemyForcesProgress(instanceId, mapId)
  end

  return kills, required
end

function MythicEnemyForcesCanComplete(map, instanceId, mapId)
  if (_G.__MYTHIC_ENEMY_FORCES_LOCKED__ ~= true) and _G.__MYTHIC_ENEMY_FORCES_ENABLED__ ~= true then
    return true
  end

  local currentKills, requiredKills = MythicGetEnemyForcesProgress(instanceId, mapId)
  if requiredKills <= 0 and map and PrimeEnemyForcesTracking then
    pcall(PrimeEnemyForcesTracking, map, instanceId, mapId)
    currentKills, requiredKills = MythicGetEnemyForcesProgress(instanceId, mapId)
  end
  if requiredKills <= 0 then
    return false
  end

  if currentKills >= requiredKills then
    return true
  end

  return false
end

local KILL_LOCK_TTL_SECONDS = math.max(INSTANCE_STATE_TIMEOUT, 24 * 60 * 60)
local KILL_LOCK_MARKER_GUID = 0
local KILL_LOCK_MARKER_TIER = 255
local KILL_LOCK_MARKER_AFFIX = "__MYTHIC_KILL_LOCK__"

local function PersistKillLock(instanceId, mapId, setAt)
  if not instanceId or instanceId == 0 then
    return
  end
  DBExecute([[
    INSERT INTO character_mythic_instance_state (guid, instance_id, map_id, tier, affix_spells, created_at)
    VALUES (?, ?, ?, ?, ?, FROM_UNIXTIME(?))
    ON DUPLICATE KEY UPDATE map_id=VALUES(map_id), tier=VALUES(tier), affix_spells=VALUES(affix_spells), created_at=VALUES(created_at)
  ]], KILL_LOCK_MARKER_GUID, instanceId, mapId or 0, KILL_LOCK_MARKER_TIER, KILL_LOCK_MARKER_AFFIX, setAt or os.time())
end

local function DeletePersistedKillLock(instanceId)
  if not instanceId or instanceId == 0 then
    return
  end
  DBExecute([[
    DELETE FROM character_mythic_instance_state
    WHERE guid = ? AND instance_id = ? AND tier = ? AND affix_spells = ?
  ]], KILL_LOCK_MARKER_GUID, instanceId, KILL_LOCK_MARKER_TIER, KILL_LOCK_MARKER_AFFIX)
end

local function SetKillLock(instanceId, mapId)
  if not instanceId or instanceId == 0 then
    return
  end
  local setAt = os.time()
  MYTHIC_KILL_LOCK[instanceId] = true
  MYTHIC_KILL_LOCK_META[instanceId] = {
    mapId = mapId or 0,
    setAt = setAt,
  }
  PersistKillLock(instanceId, mapId or 0, setAt)
end

local function ClearKillLock(instanceId)
  if not instanceId or instanceId == 0 then
    return
  end
  MYTHIC_KILL_LOCK[instanceId] = nil
  MYTHIC_KILL_LOCK_META[instanceId] = nil
  DeletePersistedKillLock(instanceId)
end

local function IsKillLockActive(instanceId, mapId)
  if not instanceId or instanceId == 0 or not MYTHIC_KILL_LOCK[instanceId] then
    return false
  end

  local meta = MYTHIC_KILL_LOCK_META[instanceId]
  if not meta then
    -- Backfill metadata for legacy lock entries created by older script versions.
    local setAt = os.time()
    MYTHIC_KILL_LOCK_META[instanceId] = { mapId = mapId or 0, setAt = setAt }
    PersistKillLock(instanceId, mapId or 0, setAt)
    return true
  end

  if mapId and mapId ~= 0 and meta.mapId and meta.mapId ~= 0 and mapId ~= meta.mapId then
    ClearKillLock(instanceId)
    return false
  end

  if meta.setAt and (os.time() - meta.setAt) > KILL_LOCK_TTL_SECONDS then
    ClearKillLock(instanceId)
    return false
  end

  return true
end

--==========================================================
-- Per-map Timer Overrides
--==========================================================
local DEFAULT_TIER_MINUTES = {
  [1] = 15,
  [2] = 30,
  [3] = 30,
}

local TIMER_OVERRIDES = {
  [AHN_KAHET_MAP_ID] = { fixed = 30 },
  [FORGE_OF_SOULS_MAP_ID] = { fixed = 15 },
  [CULLING_OF_STRATHOLME_MAP_ID] = { per_tier = { [1] = 20, [2] = 25, [3] = 30 } },
  [VIOLET_HOLD_MAP_ID] = { per_tier = { [1] = 15, [2] = 30, [3] = 30 } },
  [206] = { fixed = 20 }, -- Utgarde Keep (zone/custom alias)
  [491] = { fixed = 20 }, -- Utgarde Keep (legacy/custom alias)
  [574] = { fixed = 20 }, -- Utgarde Keep (map ID)
  [575] = { per_tier = { [1] = 15, [2] = 30, [3] = 30 } }, -- Utgarde Pinnacle
  [576] = { fixed = 20 }, -- Nexus
  [578] = { per_tier = { [1] = 20, [2] = 35, [3] = 35 } }, -- Oculus (complex)
  [599] = { per_tier = { [1] = 20, [2] = 25, [3] = 25 } }, -- Halls of Stone
  [600] = { per_tier = { [1] = 13, [2] = 15, [3] = 16 } }, -- Drak'Tharon Keep
  [601] = { fixed = 15 }, -- Azjol-Nerub (short)
  [602] = { per_tier = { [1] = 15, [2] = 25, [3] = 25 } }, -- Halls of Lightning
  [604] = { fixed = 23 }, -- Gundrak
  [650] = { fixed = 20 }, -- Trial of the Champion
  [658] = { per_tier = { [1] = 15, [2] = 25, [3] = 25 } }, -- Pit of Saron
  [668] = { per_tier = { [1] = 20, [2] = 20, [3] = 30 } }, -- Halls of Reflection
}

local function ComputeTierMinutes(mapId, tier)
  local minutes = (tier and DEFAULT_TIER_MINUTES[tier]) or DEFAULT_TIER_MINUTES[1]
  local override = TIMER_OVERRIDES[mapId]
  if override then
    if override.fixed then
      minutes = override.fixed
    elseif override.per_tier and override.per_tier[tier] then
      minutes = override.per_tier[tier]
    end
  end
  return minutes
end

--==========================================================
-- Tier Settings / Rewards
--==========================================================
local TIER_CONFIG = {
  [1] = { rating_gain = 20, rating_loss = 3, timeout_penalty = 10, duration = 15, aura = 26013, color = "|cff0070dd" },
  [2] = { rating_gain = 40, rating_loss = 6, timeout_penalty = 20, duration = 30, aura = 26013, color = "|cffa335ee" },
  [3] = { rating_gain = 60, rating_loss = 9, timeout_penalty = 30, duration = 30, aura = 26013, color = "|cffff8000" },
}

-- Timer persistence is driven by server events + persisted `created_at`.
-- This aura is now cosmetic and can be disabled safely.
if _G.__MYTHIC_SHOW_TIMER_DEBUFF_AURA__ == nil then
  _G.__MYTHIC_SHOW_TIMER_DEBUFF_AURA__ = false
end
_G.__MYTHIC_TIMER_ADDON_LAST_SEEN_BY_GUID__ = _G.__MYTHIC_TIMER_ADDON_LAST_SEEN_BY_GUID__ or {}
if _G.__MYTHIC_TIMER_ADDON_HEARTBEAT_TTL__ == nil then
  _G.__MYTHIC_TIMER_ADDON_HEARTBEAT_TTL__ = 60
end

function MythicMarkTimerAddonAvailable(player)
  if not player or not player.GetGUIDLow then
    return
  end
  local byGuid = _G.__MYTHIC_TIMER_ADDON_LAST_SEEN_BY_GUID__
  if type(byGuid) ~= "table" then
    byGuid = {}
    _G.__MYTHIC_TIMER_ADDON_LAST_SEEN_BY_GUID__ = byGuid
  end
  byGuid[player:GetGUIDLow()] = os.time()
end

function MythicClearTimerAddonAvailable(player)
  if not player or not player.GetGUIDLow then
    return
  end
  local byGuid = _G.__MYTHIC_TIMER_ADDON_LAST_SEEN_BY_GUID__
  if type(byGuid) ~= "table" then
    return
  end
  byGuid[player:GetGUIDLow()] = nil
end

function MythicPlayerHasLiveTimerAddon(player)
  if not player or not player.GetGUIDLow then
    return false
  end
  local guid = player:GetGUIDLow()
  local seenAt = (_G.__MYTHIC_TIMER_ADDON_LAST_SEEN_BY_GUID__ or {})[guid]
  if type(seenAt) ~= "number" then
    return false
  end

  local ttl = tonumber(_G.__MYTHIC_TIMER_ADDON_HEARTBEAT_TTL__ or 60) or 60
  if ttl < 10 then
    ttl = 10
  end

  if (os.time() - seenAt) > ttl then
    (_G.__MYTHIC_TIMER_ADDON_LAST_SEEN_BY_GUID__ or {})[guid] = nil
    return false
  end
  return true
end

function MythicShouldUseTimerAuraForPlayer(player)
  if _G.__MYTHIC_SHOW_TIMER_DEBUFF_AURA__ then
    return true
  end
  return not MythicPlayerHasLiveTimerAddon(player)
end

function MythicGetTierConfiguredTimerAuraId(tier)
  local cfg = TIER_CONFIG[tier]
  if not cfg then
    return 0
  end
  local auraId = tonumber(cfg.aura or 0) or 0
  if auraId < 0 then
    auraId = 0
  end
  return math.floor(auraId)
end

function MythicGetTierActiveTimerAuraId(tier, player)
  if not MythicShouldUseTimerAuraForPlayer(player) then
    return 0
  end
  return MythicGetTierConfiguredTimerAuraId(tier)
end

function MythicClearTierTimerAura(player, tier, forceConfiguredAura)
  if not player then
    return
  end
  local auraId = forceConfiguredAura and MythicGetTierConfiguredTimerAuraId(tier) or MythicGetTierActiveTimerAuraId(tier)
  if auraId ~= 0 and player:HasAura(auraId) then
    player:RemoveAura(auraId)
  end
end

local KEY_IDS       = { [1] = 900100, [2] = 900101, [3] = 900102 }
local CHEST_ENTRIES = { [1] = 900010, [2] = 900011, [3] = 900012 }
local ICONS = {
  [1] = "Interface\\Icons\\INV_Enchant_AbyssCrystal",
  [2] = "Interface\\Icons\\INV_Enchant_VoidCrystal",
  [3] = "Interface\\Icons\\INV_Enchant_NexusCrystal",
}

--==========================================================
-- Kill/Target Filters
--==========================================================
local MYTHIC_HOSTILE_FACTIONS = { [14] = true, [16] = true, [21] = true, [1885] = true }
local FRIENDLY_FACTIONS = {
  [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true, [31] = true, [35] = true,
  [114] = true, [115] = true, [116] = true, [188] = true, [190] = true,
  [1610] = true, [1629] = true, [1683] = true, [1718] = true, [1770] = true,
}
local IGNORE_BUFF_ENTRIES = {
  [24137] = true,
  [26499] = true,
  [26667] = true, -- Explicitly exclude this entry from Mythic affix targeting/buffing.
  [26793] = true, -- Crystalline Frayer (The Nexus): fully ignored for Mythic targeting/counting.
  [27745] = true,
  [27747] = true,
  [28070] = true,
  [28130] = true, -- Explicitly exclude this entry from Mythic affix targeting/buffing.
  [28351] = true,
  [28922] = true,
  [29630] = true,
  [29682] = true, -- Explicitly exclude this entry from Mythic affix targeting/buffing.
  [30172] = true,
  [30173] = true,
  [36661] = true,
  [36770] = true,
  [36771] = true,
  [36772] = true,
  [37225] = true,
  [37596] = true,
}

--==========================================================
-- Affix Pools / Colors
--==========================================================
local WEEKLY_AFFIX_POOL = {
  [1] = {
    { spell = { 48441, 61301 }, name = "Rejuvenating" },
    { spell = { 47893, 50589 }, name = "Demonism" },
    { spell = { 43010, 43024, 43012 }, name = "Resistant" },
    { spell = { 48266, 49039 }, name = "Death Empowered" },
    { spell = {48011, 24259 }, name = "Devouring" },
  },
  [2] = {
    { spell = { 871, 30823 }, name = "Turtling" },
    { spell = { 48161, 48066, 6346, 48168, 15286 }, name = "Priest Empowered" },
    { spell = { 53201, 48463 }, name = "Falling Stars" },
    { spell = { 42921, 42873, 49233, 60043 }, name = "Burst" },
    { spell = { 47864, 47813, 30108, 47811 }, name = "Rot" },
  },
  [3] = {
    { spell = { 8599, 71188 }, name = "Enrage" },
    { spell = { 47436, 53138, 57623 }, name = "Rallying" },
    { spell = { 53385, 48819 }, name = "Consecrated" },
    { spell = { 14177, 13877, 14278, 51723 }, name = "Assassinate" },
    { spell = { 48465, 48300, 48127, 48135 }, name = "Annihilation" },
  }
}

AFFIX_COLOR_MAP = {
  Enrage="|cffff0000", Turtling="|cffffff00", Rejuvenating="|cff00ff00",
  ["Falling Stars"]="|cff66ccff", ["Priest Empowered"]="|cffcccccc",
  Demonism="|cff8b0000", Consecrated="|cffffcc00", Resistant="|cffb0c4de",
  Rallying="|cffff8800", ["Death Empowered"]="|cff800080", Devouring="|cffff99cc",
  Burst="|cffcc3300", Rot="|cff339900", Assassinate="|cffffff33", Annihilation="|cffcc0066"
}

local ALL_AFFIX_SPELL_IDS = {}
for _, tier in pairs(WEEKLY_AFFIX_POOL) do
  for _, affix in ipairs(tier) do
    local spells = type(affix.spell) == "table" and affix.spell or { affix.spell }
    for _, id in ipairs(spells) do ALL_AFFIX_SPELL_IDS[id] = true end
  end
end

--==========================================================
-- AIO Client Integration Helper
-- Resolves affix spell IDs for an instance into a name/color
-- list suitable for pushing to the MythicPlus client addon.
--==========================================================
local function MythicPlusGetAffixNamesForAIO(instanceId)
  local affixIds = MYTHIC_AFFIXES_TABLE[instanceId] or {}
  local idSet = {}
  for _, spellId in ipairs(affixIds) do idSet[spellId] = true end
  local result = {}
  local seen = {}
  for t = 1, 3 do
    for _, aff in ipairs(WEEKLY_AFFIX_POOL[t] or {}) do
      local spells = type(aff.spell) == "table" and aff.spell or { aff.spell }
      for _, spellId in ipairs(spells) do
        if idSet[spellId] and not seen[aff.name] then
          seen[aff.name] = true
          table.insert(result, {
            name = aff.name,
            color = AFFIX_COLOR_MAP[aff.name] or "|cffffffff",
            tier = t,
          })
          break
        end
      end
    end
  end
  return result
end

function MythicPlusGetCurrentWeeklyAffixesForAIO()
  local result = {}
  local weekly = _G.__MYTHIC_WEEKLY_AFFIXES__ or {}
  for t = 1, 3 do
    local aff = weekly[t]
    if type(aff) == "table" and aff.name then
      table.insert(result, {
        name = aff.name,
        color = AFFIX_COLOR_MAP[aff.name] or "|cffffffff",
        tier = t,
      })
    end
  end
  return result
end

function MythicBroadcastCurrentWeeklyAffixesToPlayers()
  if not AIO or not GetPlayersInWorld then
    return 0
  end
  local payload = MythicPlusGetCurrentWeeklyAffixesForAIO()
  if not payload or #payload == 0 then
    return 0
  end
  local sent = 0
  for _, pl in pairs(GetPlayersInWorld() or {}) do
    if pl and pl.IsInWorld and pl:IsInWorld() then
      local map = pl.GetMap and pl:GetMap() or nil
      local instanceId = map and map.GetInstanceId and map:GetInstanceId() or 0
      if instanceId == 0 or (not MYTHIC_FLAG_TABLE[instanceId]) or MYTHIC_MODE_ENDED[instanceId] then
        local ok = pcall(AIO.Handle, pl, "MythicPlus", "SetAffixes", payload)
        if ok then
          sent = sent + 1
        end
      end
    end
  end
  return sent
end

function MythicPushCurrentAffixesToPlayer(player)
  if not player or not AIO then
    return false
  end
  local map = player.GetMap and player:GetMap() or nil
  local instanceId = map and map.GetInstanceId and map:GetInstanceId() or 0
  if instanceId > 0 and MYTHIC_FLAG_TABLE[instanceId] and not MYTHIC_MODE_ENDED[instanceId] then
    local runPayload = MythicPlusGetAffixNamesForAIO(instanceId)
    if runPayload and #runPayload > 0 then
      return pcall(AIO.Handle, player, "MythicPlus", "SetAffixes", runPayload)
    end
  end
  return pcall(AIO.Handle, player, "MythicPlus", "SetAffixes", MythicPlusGetCurrentWeeklyAffixesForAIO())
end

function MythicGetWeeklyAffixState()
  local weekly = _G.__MYTHIC_WEEKLY_AFFIXES__
  if type(weekly) ~= "table" then
    weekly = {}
    _G.__MYTHIC_WEEKLY_AFFIXES__ = weekly
  end
  return weekly
end

function MythicFindAffixInTierByName(tier, affixName)
  local pool = WEEKLY_AFFIX_POOL[tier] or {}
  local desired = tostring(affixName or ""):gsub("^%s+", ""):gsub("%s+$", ""):lower()
  if desired == "" then
    return nil
  end
  for _, aff in ipairs(pool) do
    if tostring(aff.name or ""):lower() == desired then
      return aff
    end
  end
  return nil
end

function MythicBuildGmAffixEditorPayload(player)
  local canEdit = player and player.IsGM and player:IsGM()
  local payload = {
    canEdit = canEdit and true or false,
    nextRerollAt = tonumber(_G.__MYTHIC_NEXT_AFFIX_REROLL_AT__ or 0) or 0,
    tiers = {},
  }

  if not canEdit then
    return payload
  end

  local weekly = MythicGetWeeklyAffixState()
  for tier = 1, 3 do
    local current = weekly[tier]
    local tierPayload = {
      tier = tier,
      current = (type(current) == "table" and current.name) or "",
      options = {},
    }
    for _, aff in ipairs(WEEKLY_AFFIX_POOL[tier] or {}) do
      table.insert(tierPayload.options, {
        name = aff.name,
        color = AFFIX_COLOR_MAP[aff.name] or "|cffffffff",
      })
    end
    table.insert(payload.tiers, tierPayload)
  end

  return payload
end

function MythicPushGmAffixEditorData(player)
  if not player or not AIO then
    return false
  end
  return pcall(AIO.Handle, player, "MythicPlus", "SetGmAffixEditorData", MythicBuildGmAffixEditorPayload(player))
end

function MythicEnsureTimerAddonAIOHandlers()
  local handlers = _G.__MYTHICPLUS_SERVER_AIO_HANDLERS__
  if type(handlers) ~= "table" then
    if not AIO or not AIO.AddHandlers then
      return false
    end
    local ok, added = pcall(AIO.AddHandlers, "MythicPlusServer", {})
    if not ok or type(added) ~= "table" then
      return false
    end
    handlers = added
    _G.__MYTHICPLUS_SERVER_AIO_HANDLERS__ = handlers
  end

  handlers.TimerAddonReady = function(player, addonVersion)
    if not player then
      return
    end
    MythicMarkTimerAddonAvailable(player)

    -- Strip any fallback timer aura immediately once addon capability is confirmed.
    for tierId, _ in pairs(TIER_CONFIG) do
      MythicClearTierTimerAura(player, tierId, true)
    end

    MythicPushCurrentAffixesToPlayer(player)
    MythicPushGmAffixEditorData(player)
  end

  handlers.TimerAddonGone = function(player, addonVersion)
    if not player then
      return
    end
    MythicClearTimerAddonAvailable(player)
  end

  handlers.RequestGmAffixEditorData = function(player)
    if not player then
      return
    end
    MythicPushGmAffixEditorData(player)
  end

  handlers.SetWeeklyAffixTier = function(player, tier, affixName)
    if not player or not player.IsGM or not player:IsGM() then
      if player then
        MythicSendPlayerMessage(player, "|cffff0000[Mythic]|r You do not have permission to change affixes.")
      end
      MythicPushGmAffixEditorData(player)
      return
    end

    local tierNum = tonumber(tier)
    if not tierNum then
      MythicSendPlayerMessage(player, "|cffff0000[Mythic]|r Invalid tier.")
      MythicPushGmAffixEditorData(player)
      return
    end
    tierNum = math.floor(tierNum)
    if tierNum < 1 or tierNum > 3 then
      MythicSendPlayerMessage(player, "|cffff0000[Mythic]|r Tier must be 1, 2, or 3.")
      MythicPushGmAffixEditorData(player)
      return
    end

    local chosen = MythicFindAffixInTierByName(tierNum, affixName)
    if not chosen then
      MythicSendPlayerMessage(player, "|cffff0000[Mythic]|r Invalid affix for Tier " .. tierNum .. ".")
      MythicPushGmAffixEditorData(player)
      return
    end

    local weekly = MythicGetWeeklyAffixState()
    weekly[tierNum] = chosen
    _G.__MYTHIC_WEEKLY_AFFIXES__ = weekly

    if type(ResetAffixCountdown) == "function" then
      ResetAffixCountdown()
    else
      _G.__MYTHIC_NEXT_AFFIX_REROLL_AT__ = os.time() + (AFFIX_REROLL_INTERVAL_MS / 1000)
    end

    MythicBroadcastCurrentWeeklyAffixesToPlayers()
    MythicPushGmAffixEditorData(player)
    MythicSendWorldMessage(string.format("|cffffcc00[Mythic]|r GM has set the Tier %d affix to %s.", tierNum, ColorAffixName(chosen.name)))
  end
  return true
end
MythicEnsureTimerAddonAIOHandlers()

if _G.__MYTHIC_TIMER_AIO_BOOTSTRAP_EVENT_ID__ then
  RemoveEventById(_G.__MYTHIC_TIMER_AIO_BOOTSTRAP_EVENT_ID__)
  _G.__MYTHIC_TIMER_AIO_BOOTSTRAP_EVENT_ID__ = nil
end
_G.__MYTHIC_TIMER_AIO_BOOTSTRAP_EVENT_ID__ = CreateLuaEvent(function()
  if not MythicEnsureTimerAddonAIOHandlers() then
    return
  end
  MythicBroadcastCurrentWeeklyAffixesToPlayers()
  if _G.__MYTHIC_TIMER_AIO_BOOTSTRAP_EVENT_ID__ then
    RemoveEventById(_G.__MYTHIC_TIMER_AIO_BOOTSTRAP_EVENT_ID__)
    _G.__MYTHIC_TIMER_AIO_BOOTSTRAP_EVENT_ID__ = nil
  end
end, 5000, 0)

local AFFIX_PLAYER_CAST_RADIUS = 40
local DEVOURING_AFFIX_SPELL_IDS = {
  [48011] = true,
  [24259] = true,
}
local AFFIX_CAST_ON_PLAYERS = {
  [30108] = true,
  [42921] = true,
  [42873] = true,
  [47811] = true,
  [47813] = true,
  [47864] = true,
  [48011] = true,
  [24259] = true,
  [49233] = true,
  [60043] = true,
}
local AFFIX_PLAYER_ONLY = {
  [30108] = true,
  [42921] = true,
  [42873] = true,
  [47811] = true,
  [47813] = true,
  [47864] = true,
  [49233] = true,
  [60043] = true,
  [48011] = true,
  [24259] = true,
}
local VIOLET_HOLD_PRISON_BOSS_ENTRIES = {
  [29266] = true, [29312] = true, [29313] = true, [29314] = true, [29315] = true, [29316] = true,
  [31507] = true, [31508] = true, [31509] = true, [31510] = true, [31511] = true, [31512] = true,
}
local VIOLET_HOLD_PRISON_DOOR_ENTRIES = {
  [191556] = true, [191562] = true, [191563] = true, [191564] = true,
  [191565] = true, [191566] = true, [191606] = true, [191722] = true,
}
local VIOLET_HOLD_FINAL_BOSS_ENTRIES = {
  [31506] = true, [31134] = true, -- Cyanigosa variants.
}
local VIOLET_HOLD_FORCE_AFFIX_ENTRIES = {
  [30660] = true, -- Explicitly allow affix targeting for this Violet Hold wave entry.
  [30666] = true, -- Explicitly allow affix targeting for this Violet Hold wave entry.
  [30667] = true, -- Explicitly allow affix targeting for this Violet Hold wave entry.
  [31134] = true, -- Explicitly force-affix Cyanigosa variant in Violet Hold.
}
local VIOLET_HOLD_DOOR_RADIUS = 25
local DISABLE_AFFIXES_ON_SCRIPTED_BOSSES = false
local AFFIX_PROTECTED_BOSS_ENTRIES = {}
local DISABLE_AFFIX_NPC_CAST_ON_SCRIPTED_ENTRIES = true
local ALLOW_AFFIX_NPC_CAST_ON_PROTECTED_BOSSES = false
local DISABLE_AFFIXES_ON_SCRIPTED_BOSSES_IN_MAP = {
  [CULLING_OF_STRATHOLME_MAP_ID] = true, -- Culling of Stratholme scripted RP/combat sequence is sensitive.
}
local COS_SCRIPTED_BOSS_ENTRIES = {
  [26499] = true, -- Arthas
  [26533] = true, [31217] = true, [32313] = true, -- Mal'Ganis variants.
}
local SCRIPTED_CREATURE_ENTRY_CACHE = _G.__MYTHIC_SCRIPTED_CREATURE_ENTRY_CACHE__ or {}
_G.__MYTHIC_SCRIPTED_CREATURE_ENTRY_CACHE__ = SCRIPTED_CREATURE_ENTRY_CACHE

local function BuildProtectedBossEntrySet()
  for _, data in pairs(MYTHIC_FINAL_BOSSES or {}) do
    local bosses = data and data.bosses
    if type(bosses) == "table" then
      for _, id in ipairs(bosses) do
        if id then AFFIX_PROTECTED_BOSS_ENTRIES[id] = true end
      end
    end
    local finalEntry = data and data.final
    if type(finalEntry) == "table" then
      for _, id in ipairs(finalEntry) do
        if id then AFFIX_PROTECTED_BOSS_ENTRIES[id] = true end
      end
    elseif finalEntry then
      AFFIX_PROTECTED_BOSS_ENTRIES[finalEntry] = true
    end
  end
end
BuildProtectedBossEntrySet()

local function IsCreatureEntryScripted(entry)
  if not entry or entry <= 0 then
    return true
  end

  local cached = SCRIPTED_CREATURE_ENTRY_CACHE[entry]
  if cached ~= nil then
    return cached
  end

  -- Never query world DB from runtime aura loops; safest default is scripted.
  SCRIPTED_CREATURE_ENTRY_CACHE[entry] = true
  return true
end

--==========================================================
-- Weekly Affixes (persisted across script reloads)
--==========================================================
local WEEKLY_AFFIXES = _G.__MYTHIC_WEEKLY_AFFIXES__
if type(WEEKLY_AFFIXES) ~= "table" then
  WEEKLY_AFFIXES = {}
end
_G.__MYTHIC_WEEKLY_AFFIXES__ = WEEKLY_AFFIXES
math.randomseed(os.time()); math.random(); math.random(); math.random()
for i = 1, 3 do
  if NEXT_AFFIX_REROLL_AT <= os.time() then
    WEEKLY_AFFIXES[i] = nil
  end
  local pool = WEEKLY_AFFIX_POOL[i]
  if #pool > 0 and not WEEKLY_AFFIXES[i] then
    WEEKLY_AFFIXES[i] = pool[math.random(#pool)]
  end
end
if NEXT_AFFIX_REROLL_AT <= os.time() then
  NEXT_AFFIX_REROLL_AT = os.time() + (AFFIX_REROLL_INTERVAL_MS / 1000)
end
_G.__MYTHIC_NEXT_AFFIX_REROLL_AT__ = NEXT_AFFIX_REROLL_AT

local function EnsureWeeklyAffixesInitialized()
  for i = 1, 3 do
    if not WEEKLY_AFFIXES[i] then
      local pool = WEEKLY_AFFIX_POOL[i] or {}
      if #pool > 0 then
        WEEKLY_AFFIXES[i] = pool[math.random(#pool)]
      end
    end
  end
end

local function GetAffixSet(tier)
  if not IsAffixSystemEnabled() then
    return {}
  end

  EnsureWeeklyAffixesInitialized()

  local list = {}
  local maxTier = math.min(tier or 1, 3)
  for i = 1, maxTier do
    local affix = WEEKLY_AFFIXES[i]
    if affix then
      local spells = type(affix.spell) == "table" and affix.spell or { affix.spell }
      for _, spellId in ipairs(spells) do table.insert(list, spellId) end
    end
  end
  return list
end

local function GetAffixNamesString(maxTier)
  if not IsAffixSystemEnabled() then
    return "|cffff5555Disabled (no affixes applied)|r"
  end

  local parts = {}
  for t = 1, (maxTier or 3) do
    local aff = WEEKLY_AFFIXES[t]
    table.insert(parts, string.format("|cffffff00T%d|r: %s", t, ColorAffixName(aff and aff.name or "None")))
  end
  return table.concat(parts, "  ")
end

local function FindAffixByNameInTier(tier, nameLower)
  local pool = WEEKLY_AFFIX_POOL[tier]; if not pool then return nil end
  for _, aff in ipairs(pool) do if aff.name:lower() == nameLower then return aff end end
  return nil
end

local function RerollTierAffix(tier)
  local pool = WEEKLY_AFFIX_POOL[tier]; if not pool or #pool == 0 then return nil end
  local choice = pool[math.random(#pool)]
  WEEKLY_AFFIXES[tier] = choice
  return choice
end

ResetAffixCountdown = function(keepExistingDeadline)
  if not keepExistingDeadline then
    NEXT_AFFIX_REROLL_AT = os.time() + (AFFIX_REROLL_INTERVAL_MS / 1000)
  elseif NEXT_AFFIX_REROLL_AT <= os.time() then
    NEXT_AFFIX_REROLL_AT = os.time() + (AFFIX_REROLL_INTERVAL_MS / 1000)
  end
  _G.__MYTHIC_NEXT_AFFIX_REROLL_AT__ = NEXT_AFFIX_REROLL_AT
  _G.__MYTHIC_WEEKLY_AFFIXES__ = WEEKLY_AFFIXES
  if AUTO_REROLL_EVENT_ID then
    RemoveEventById(AUTO_REROLL_EVENT_ID)
    AUTO_REROLL_EVENT_ID = nil
  end
  if _G[GLOBAL_AFFIX_EVENT_KEY] then
    RemoveEventById(_G[GLOBAL_AFFIX_EVENT_KEY])
    _G[GLOBAL_AFFIX_EVENT_KEY] = nil
  end
  AUTO_REROLL_EVENT_ID = CreateLuaEvent(
    AutoRerollAffixes,
    math.max(1000, math.floor((NEXT_AFFIX_REROLL_AT - os.time()) * 1000)),
    1
  )
  _G[GLOBAL_AFFIX_EVENT_KEY] = AUTO_REROLL_EVENT_ID
end

AutoRerollAffixes = function()
  local old = {
    WEEKLY_AFFIXES[1] and WEEKLY_AFFIXES[1].name or "None",
    WEEKLY_AFFIXES[2] and WEEKLY_AFFIXES[2].name or "None",
    WEEKLY_AFFIXES[3] and WEEKLY_AFFIXES[3].name or "None"
  }
  for t = 1, 3 do RerollTierAffix(t) end
  NEXT_AFFIX_REROLL_AT = os.time() + (AFFIX_REROLL_INTERVAL_MS / 1000)
  MythicSendWorldMessage(string.format(
    "|cffffcc00[Mythic]|r Affixes have rotated (auto): T1 %s -> %s, T2 %s -> %s, T3 %s -> %s. Next in ~%s.",
    ColorAffixName(old[1]), ColorAffixName(WEEKLY_AFFIXES[1] and WEEKLY_AFFIXES[1].name or "None"),
    ColorAffixName(old[2]), ColorAffixName(WEEKLY_AFFIXES[2] and WEEKLY_AFFIXES[2].name or "None"),
    ColorAffixName(old[3]), ColorAffixName(WEEKLY_AFFIXES[3] and WEEKLY_AFFIXES[3].name or "None"),
    FormatDurationShort(GetAffixRerollETA())
  ))
  ResetAffixCountdown()
  MythicBroadcastCurrentWeeklyAffixesToPlayers()
end

ResetAffixCountdown(true)
MythicBroadcastCurrentWeeklyAffixesToPlayers()

--==========================================================
-- Core storage (rating, instance state, deaths)
--==========================================================
local function EnsureCoreTables()
  DBExecute([[
    CREATE TABLE IF NOT EXISTS character_mythic_rating (
      guid INT UNSIGNED NOT NULL PRIMARY KEY,
      total_runs INT UNSIGNED NOT NULL DEFAULT 0,
      total_points INT UNSIGNED NOT NULL DEFAULT 0,
      claimed_tier1 INT UNSIGNED NOT NULL DEFAULT 0,
      claimed_tier2 INT UNSIGNED NOT NULL DEFAULT 0,
      claimed_tier3 INT UNSIGNED NOT NULL DEFAULT 0,
      last_updated TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
  ]])
  DBExecute([[
    CREATE TABLE IF NOT EXISTS character_mythic_instance_state (
      guid INT UNSIGNED NOT NULL,
      instance_id INT UNSIGNED NOT NULL,
      map_id INT UNSIGNED NOT NULL,
      tier TINYINT UNSIGNED NOT NULL,
      affix_spells TEXT NOT NULL,
      created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (guid, instance_id, map_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
  ]])
  DBExecute([[
    CREATE TABLE IF NOT EXISTS character_mythic_instance_deaths (
      instance_id INT UNSIGNED NOT NULL,
      map_id INT UNSIGNED NOT NULL,
      guid INT UNSIGNED NOT NULL,
      death_count INT UNSIGNED NOT NULL DEFAULT 0,
      updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (instance_id, map_id, guid)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
  ]])
  DBExecute([[
    CREATE TABLE IF NOT EXISTS character_mythic_instance_progress (
      instance_id INT UNSIGNED NOT NULL,
      map_id INT UNSIGNED NOT NULL,
      non_boss_kills INT UNSIGNED NOT NULL DEFAULT 0,
      required_kills INT UNSIGNED NOT NULL DEFAULT 0,
      updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (instance_id, map_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
  ]])
end
EnsureCoreTables()

local function LoadPersistedKillLocks()
  local now = os.time()
  local rows = DBQuery([[
    SELECT instance_id, map_id, UNIX_TIMESTAMP(created_at)
    FROM character_mythic_instance_state
    WHERE guid = ? AND tier = ? AND affix_spells = ?
  ]], KILL_LOCK_MARKER_GUID, KILL_LOCK_MARKER_TIER, KILL_LOCK_MARKER_AFFIX)
  if not rows then
    return
  end

  repeat
    local instanceId = rows:GetUInt32(0)
    local mapId = rows:GetUInt32(1)
    local setAt = rows:GetUInt32(2)
    if not setAt or setAt == 0 then
      setAt = now
    end

    if (now - setAt) > KILL_LOCK_TTL_SECONDS then
      DeletePersistedKillLock(instanceId)
    else
      MYTHIC_KILL_LOCK[instanceId] = true
      MYTHIC_KILL_LOCK_META[instanceId] = { mapId = mapId or 0, setAt = setAt }
    end
  until not rows:NextRow()
end
LoadPersistedKillLocks()

local function PersistInstanceStateForPlayer(guid, instanceId, mapId, tier, affixStr, created)
  if not guid or guid <= 0 or not instanceId or instanceId <= 0 or not mapId or mapId <= 0 or not tier or tier <= 0 then
    return
  end
  DBExecute([[
    INSERT INTO character_mythic_instance_state (guid, instance_id, map_id, tier, affix_spells, created_at)
    VALUES (?, ?, ?, ?, ?, FROM_UNIXTIME(?))
    ON DUPLICATE KEY UPDATE tier=VALUES(tier), affix_spells=VALUES(affix_spells), created_at=VALUES(created_at)
  ]], guid, instanceId, mapId, tier, affixStr or "", created or os.time())
end

PersistEnemyForcesProgress = function(instanceId, mapId)
  if not instanceId or instanceId == 0 then
    return
  end
  local kills = math.max(0, math.floor(tonumber(MYTHIC_NON_BOSS_KILLS[instanceId] or 0) or 0))
  local stableReqByInstance = _G.__MYTHIC_ENEMY_FORCES_REQ_STABLE__ or {}
  local required = math.max(0, math.floor(tonumber(stableReqByInstance[instanceId] or 0) or 0))
  local normalizedMapId = mapId or 0
  local cached = MYTHIC_FORCES_PERSIST_CACHE[instanceId]
  if cached
    and cached.mapId == normalizedMapId
    and cached.kills == kills
    and cached.required == required then
    return
  end
  DBExecute([[
    INSERT INTO character_mythic_instance_progress (instance_id, map_id, non_boss_kills, required_kills, updated_at)
    VALUES (?, ?, ?, ?, NOW())
    ON DUPLICATE KEY UPDATE non_boss_kills=VALUES(non_boss_kills), required_kills=VALUES(required_kills), updated_at=NOW()
  ]], instanceId, normalizedMapId, kills, required)
  MYTHIC_FORCES_PERSIST_CACHE[instanceId] = {
    mapId = normalizedMapId,
    kills = kills,
    required = required,
  }
end

local function LoadPersistedEnemyForcesProgress(instanceId, mapId)
  if not instanceId or instanceId == 0 then
    return
  end
  local row = DBQuery(
    "SELECT non_boss_kills, required_kills FROM character_mythic_instance_progress WHERE instance_id=? AND map_id=? LIMIT 1",
    instanceId, mapId or 0
  )
  if not row then
    return
  end

  local kills = math.max(0, math.floor(tonumber(row:GetUInt32(0) or 0) or 0))
  local required = math.max(0, math.floor(tonumber(row:GetUInt32(1) or 0) or 0))
  MYTHIC_NON_BOSS_KILLS[instanceId] = kills
  MYTHIC_FORCES_PERSIST_CACHE[instanceId] = {
    mapId = mapId or 0,
    kills = kills,
    required = required,
  }

  if required > 0 then
    local stableReqByInstance = _G.__MYTHIC_ENEMY_FORCES_REQ_STABLE__ or {}
    local oldStable = math.max(0, math.floor(tonumber(stableReqByInstance[instanceId] or 0) or 0))
    if required > oldStable then
      stableReqByInstance[instanceId] = required
      _G.__MYTHIC_ENEMY_FORCES_REQ_STABLE__ = stableReqByInstance
    end
  end
end

--==========================================================
-- Best-time storage (per character and realm)
--==========================================================
local function EnsureBestTimeTables()
  DBExecute([[
    CREATE TABLE IF NOT EXISTS character_mythic_best (
      guid INT UNSIGNED NOT NULL,
      map_id INT UNSIGNED NOT NULL,
      best_seconds INT UNSIGNED NOT NULL,
      best_tier TINYINT UNSIGNED NOT NULL DEFAULT 1,
      best_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (guid, map_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
  ]])
  DBExecute([[
    CREATE TABLE IF NOT EXISTS mythic_realm_best (
      map_id INT UNSIGNED NOT NULL PRIMARY KEY,
      best_seconds INT UNSIGNED NOT NULL,
      best_tier TINYINT UNSIGNED NOT NULL DEFAULT 1,
      holder_guid INT UNSIGNED NOT NULL,
      holder_name VARCHAR(24) NOT NULL,
      best_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
  ]])
end
EnsureBestTimeTables()

local function GetBestTimesForMap(mapId, guid)
  local my = DBQuery("SELECT best_seconds, best_tier FROM character_mythic_best WHERE guid=? AND map_id=?", guid, mapId)
  local realm = DBQuery("SELECT best_seconds, best_tier, holder_name FROM mythic_realm_best WHERE map_id=?", mapId)
  local myBest    = my    and { sec = my:GetUInt32(0),    tier = my:GetUInt32(1) } or nil
  local realmBest = realm and { sec = realm:GetUInt32(0), tier = realm:GetUInt32(1), name = realm:GetString(2) } or nil
  return myBest, realmBest
end

local function RecordBestTime(mapId, tier, player, elapsedSec)
  local guid = player:GetGUIDLow()
  local name = player:GetName()

  DBExecute([[
    INSERT INTO character_mythic_best (guid,map_id,best_seconds,best_tier,best_at)
    VALUES (?, ?, ?, ?, NOW())
    ON DUPLICATE KEY UPDATE
      best_tier    = IF(VALUES(best_seconds) < best_seconds, VALUES(best_tier), best_tier),
      best_at      = IF(VALUES(best_seconds) < best_seconds, NOW(), best_at),
      best_seconds = LEAST(best_seconds, VALUES(best_seconds))
  ]], guid, mapId, elapsedSec, tier)

  DBExecute([[
    INSERT INTO mythic_realm_best (map_id,best_seconds,best_tier,holder_guid,holder_name,best_at)
    VALUES (?, ?, ?, ?, ?, NOW())
    ON DUPLICATE KEY UPDATE
      holder_guid = IF(VALUES(best_seconds) < best_seconds, VALUES(holder_guid), holder_guid),
      holder_name = IF(VALUES(best_seconds) < best_seconds, VALUES(holder_name), holder_name),
      best_tier   = IF(VALUES(best_seconds) < best_seconds, VALUES(best_tier), best_tier),
      best_at     = IF(VALUES(best_seconds) < best_seconds, NOW(), best_at),
      best_seconds= LEAST(best_seconds, VALUES(best_seconds))
  ]], mapId, elapsedSec, tier, guid, name)
end

local function TryTriggeredNpcCastWithoutCombatPollution(creature, target, spellId)
  if not creature or not target or not spellId then
    return false
  end

  local castOk = false
  if creature.CastSpell then
    local ok = pcall(creature.CastSpell, creature, target, spellId, true)
    castOk = ok and true or false
  end

  return castOk
end

local function RefreshOrApplyPlayerAffix(creature, player, spellId)
  if not player then return end
  local aura = player:GetAura(spellId)
  if aura then
    return
  end
  if DEVOURING_AFFIX_SPELL_IDS[spellId] then
    local playerGuid = player.GetGUIDLow and player:GetGUIDLow() or nil
    if playerGuid and playerGuid > 0 then
      local throttle = _G.__MYTHIC_PLAYER_AFFIX_CAST_THROTTLE__ or {}
      _G.__MYTHIC_PLAYER_AFFIX_CAST_THROTTLE__ = throttle
      local key = tostring(spellId) .. ":p:" .. tostring(playerGuid)
      local now = os.time()
      local nextAllowedAt = tonumber(throttle[key] or 0) or 0
      if nextAllowedAt > now then
        return
      end
      throttle[key] = now + 10
    end
  end

  local canNpcCast = (_G.__MYTHIC_DISABLE_NPC_PLAYER_AFFIX_CAST__ ~= true)
  if creature and creature.GetEntry then
    local entry = creature:GetEntry()
    local map = creature.GetMap and creature:GetMap() or nil
    local mapId = map and map.GetMapId and map:GetMapId() or 0
    local isProtectedBoss = AFFIX_PROTECTED_BOSS_ENTRIES[entry] == true
    if mapId == CULLING_OF_STRATHOLME_MAP_ID then
      canNpcCast = false
    elseif isProtectedBoss then
      canNpcCast = ALLOW_AFFIX_NPC_CAST_ON_PROTECTED_BOSSES
    elseif DISABLE_AFFIX_NPC_CAST_ON_SCRIPTED_ENTRIES and IsCreatureEntryScripted(entry) then
      canNpcCast = false
    end
  end

  if canNpcCast then
    TryTriggeredNpcCastWithoutCombatPollution(creature, player, spellId)
  end

  if not player:GetAura(spellId) and creature and creature.AddAura then
    -- Fallback keeps source as creature without driving a normal AI cast state.
    pcall(creature.AddAura, creature, spellId, player)
  end
end

local function IsVHPrisonBossReleased(creature)
  if not creature then return true end
  local map = creature:GetMap()
  local mapId = map and map:GetMapId() or 0
  if mapId ~= VIOLET_HOLD_MAP_ID then return true end
  if not VIOLET_HOLD_PRISON_BOSS_ENTRIES[creature:GetEntry()] then return true end

  local nearby = creature:GetGameObjectsInRange(VIOLET_HOLD_DOOR_RADIUS) or {}
  local nearest, nearestDist
  for _, go in pairs(nearby) do
    if go and VIOLET_HOLD_PRISON_DOOR_ENTRIES[go:GetEntry()] then
      local dist = creature:GetDistance(go)
      if not nearestDist or dist < nearestDist then
        nearestDist = dist
        nearest = go
      end
    end
  end

  if not nearest or not nearest.GetGoState then return true end
  local state = nearest:GetGoState()
  return state == 0 or state == 2
end

--==========================================================
-- Affix Aura Application Loop (buffs enemies around players)
--==========================================================
local function IsCreatureHostileToAnyPlayer(creature, players)
  if not creature or not creature.IsHostileTo then return false end
  for _, pl in pairs(players or {}) do
    if pl and pl.IsInWorld and pl:IsInWorld() and pl.IsAlive and pl:IsAlive() then
      local ok, hostile = pcall(creature.IsHostileTo, creature, pl)
      if ok and hostile then
        return true
      end
    end
  end
  return false
end

local function IsPlayerOwnedUnit(unit)
  if not unit or not unit.GetOwner then
    return false
  end

  local okOwner, owner = pcall(unit.GetOwner, unit)
  if not okOwner or not owner then
    return false
  end

  if owner.IsPlayer and owner:IsPlayer() then
    return true
  end

  if owner.GetOwner then
    local okTopOwner, topOwner = pcall(owner.GetOwner, owner)
    if okTopOwner and topOwner and topOwner.IsPlayer and topOwner:IsPlayer() then
      return true
    end
  end

  return false
end

local function IsUnitInCombat(unit)
  if not unit or not unit.IsInCombat then
    return false
  end
  local ok, state = pcall(unit.IsInCombat, unit)
  return ok and state and true or false
end

function SafeUnitBoolMethod(unit, methodName)
  if not unit or not methodName then
    return false
  end
  local method = unit[methodName]
  if type(method) ~= "function" then
    return false
  end
  local ok, result = pcall(method, unit)
  return ok and result and true or false
end

_G.__MYTHIC_ENEMY_FORCES_IGNORE_NAME_HINTS__ = _G.__MYTHIC_ENEMY_FORCES_IGNORE_NAME_HINTS__ or {
  "trigger", "target", "stalker", "controller", "invisible", "dummy"
}

function IsLikelyScriptHelperCreature(creature)
  if not creature then
    return true
  end

  if SafeUnitBoolMethod(creature, "IsTrigger")
    or SafeUnitBoolMethod(creature, "IsCritter")
    or SafeUnitBoolMethod(creature, "IsTotem")
    or SafeUnitBoolMethod(creature, "IsSpiritService")
    or SafeUnitBoolMethod(creature, "IsSpiritGuide") then
    return true
  end

  if creature.GetMaxHealth then
    local okMaxHealth, maxHealth = pcall(creature.GetMaxHealth, creature)
    if okMaxHealth and type(maxHealth) == "number" and maxHealth <= 1 then
      return true
    end
  end

  if creature.GetLevel then
    local okLevel, level = pcall(creature.GetLevel, creature)
    if okLevel and type(level) == "number" and level <= 0 then
      return true
    end
  end

  if creature.GetName then
    local okName, name = pcall(creature.GetName, creature)
    if okName and type(name) == "string" and name ~= "" then
      local lowered = name:lower()
      for _, hint in ipairs(_G.__MYTHIC_ENEMY_FORCES_IGNORE_NAME_HINTS__ or {}) do
        if lowered:find(hint, 1, true) then
          return true
        end
      end
    end
  end

  return false
end

local function IsCreatureAttackable(creature)
  if not creature then
    return false
  end

  if creature.IsTargetableForAttack then
    local okTargetable, targetable = pcall(creature.IsTargetableForAttack, creature, false)
    if okTargetable and targetable then
      return true
    end
  end

  if creature.CanAggro then
    local okAggro, canAggro = pcall(creature.CanAggro, creature)
    if okAggro and canAggro then
      return true
    end
  end

  return false
end

local function IsAffixTargetCreature(creature, mapId, players, faction, entry, fromHostileQuery)
  if not creature or not creature.IsAlive or not creature:IsAlive() then
    return false
  end
  if not creature.IsInWorld or not creature:IsInWorld() then
    return false
  end
  if creature.IsPlayer and creature:IsPlayer() then
    return false
  end
  if IsPlayerOwnedUnit(creature) then
    return false
  end
  if mapId == VIOLET_HOLD_MAP_ID and not IsVHPrisonBossReleased(creature) then
    return false
  end
  if IGNORE_BUFF_ENTRIES[entry] or (mapId == FORGE_OF_SOULS_MAP_ID and entry == 36967) then
    return false
  end
  if creature.HasAura then
    local okFrozen, hasFrozenAura = pcall(creature.HasAura, creature, 47854)
    if okFrozen and hasFrozenAura then
      -- Keristrasza frozen phase: do not target/apply/count until she is released.
      return false
    end
  end
  if mapId == CULLING_OF_STRATHOLME_MAP_ID and COS_SCRIPTED_BOSS_ENTRIES[entry] then
    return false
  end
  local forceVioletHoldAffixEntry = (mapId == VIOLET_HOLD_MAP_ID and VIOLET_HOLD_FORCE_AFFIX_ENTRIES[entry] == true)

  if AFFIX_PROTECTED_BOSS_ENTRIES[entry] and DISABLE_AFFIXES_ON_SCRIPTED_BOSSES_IN_MAP[mapId] and not forceVioletHoldAffixEntry then
    return false
  end
  if DISABLE_AFFIXES_ON_SCRIPTED_BOSSES and AFFIX_PROTECTED_BOSS_ENTRIES[entry] and not forceVioletHoldAffixEntry then
    return false
  end

  local attackableNow = IsCreatureAttackable(creature)
  local inCombatNow = IsUnitInCombat(creature)
  local likelyHelper = IsLikelyScriptHelperCreature(creature)
  if not attackableNow and not inCombatNow and likelyHelper then
    return false
  end

  local hostileToPlayers = IsCreatureHostileToAnyPlayer(creature, players)

  if forceVioletHoldAffixEntry then
    -- Some Violet Hold wave mobs can report non-standard faction flags.
    -- Keep explicitly allowed entries (including Cyanigosa variant 31134) eligible while active.
    if attackableNow or inCombatNow or hostileToPlayers then
      return true
    end
  end

  if FRIENDLY_FACTIONS[faction] then
    return false
  end

  if mapId == VIOLET_HOLD_MAP_ID then
    -- Violet Hold waves can present inconsistent hostility/faction flags while scripting.
    -- Treat any active combat-capable enemy as valid, while helper/friendly filters above still apply.
    if attackableNow or inCombatNow or hostileToPlayers then
      return true
    end
  end

  local hostileByFaction = MYTHIC_HOSTILE_FACTIONS[faction] == true
  if not hostileByFaction and not hostileToPlayers then
    -- Some cores report IsHostileTo=false for valid dungeon enemies until they engage.
    -- Keep clearly attackable/in-combat units eligible.
    if not attackableNow and not inCombatNow then
      return false
    end
  end

  if attackableNow or inCombatNow then
    return true
  end

  if entry == 26861 or creature:GetName() == "King Ymiron" then
    return true
  end
  return false
end

local function ApplySelfAffixToCreature(creature, spellId)
  local aura = creature:GetAura(spellId)
  if aura then
    -- Do not force-refresh active auras; let them expire naturally.
    return
  end

  local entry = creature.GetEntry and creature:GetEntry() or 0
  local isBossLike =
    (AFFIX_PROTECTED_BOSS_ENTRIES[entry] == true)
    or SafeUnitBoolMethod(creature, "IsBoss")
    or SafeUnitBoolMethod(creature, "IsDungeonBoss")
    or SafeUnitBoolMethod(creature, "IsWorldBoss")
  if isBossLike and not IsUnitInCombat(creature) then
    -- Avoid pre-pull boss aura interactions that can create long-range aggro.
    return
  end

  if creature.AddAura then
    pcall(creature.AddAura, creature, spellId, creature)
  end

  -- ALE fallback: some spells do not stick via AddAura on NPCs.
  -- Use triggered self-cast for non-protected enemies only.
  if creature:GetAura(spellId) then
    return
  end
  local attackableOrInCombat = IsCreatureAttackable(creature) or IsUnitInCombat(creature)
  -- Always allow fallback for active combat targets; keep GM toggle for passive units.
  if _G.__MYTHIC_ALLOW_SELF_CAST_FALLBACK__ ~= true and not attackableOrInCombat then
    return
  end
  local map = creature.GetMap and creature:GetMap() or nil
  local mapId = map and map.GetMapId and map:GetMapId() or 0
  local allowVioletHoldFinalFallback = (mapId == VIOLET_HOLD_MAP_ID) and (VIOLET_HOLD_FINAL_BOSS_ENTRIES[entry] == true)
  if AFFIX_PROTECTED_BOSS_ENTRIES[entry] and not allowVioletHoldFinalFallback then
    return
  end
  if DISABLE_AFFIX_NPC_CAST_ON_SCRIPTED_ENTRIES and IsCreatureEntryScripted(entry) and not attackableOrInCombat then
    return
  end
  if (SafeUnitBoolMethod(creature, "IsBoss")
    or SafeUnitBoolMethod(creature, "IsDungeonBoss")
    or SafeUnitBoolMethod(creature, "IsWorldBoss")) and not allowVioletHoldFinalFallback then
    return
  end
  if mapId == CULLING_OF_STRATHOLME_MAP_ID and COS_SCRIPTED_BOSS_ENTRIES[entry] then
    return
  end
  if creature.CastSpell then
    pcall(creature.CastSpell, creature, creature, spellId, true)
  end
end

function CollectionHasAny(collection)
  if not collection then
    return false
  end
  if type(collection) == "table" then
    return next(collection) ~= nil
  end

  local okPairs, hasPairs = pcall(function()
    for _, _ in pairs(collection) do
      return true
    end
    return false
  end)
  if okPairs and hasPairs then
    return true
  end

  local okIpairs, hasIpairs = pcall(function()
    for _, _ in ipairs(collection) do
      return true
    end
    return false
  end)
  if okIpairs and hasIpairs then
    return true
  end

  local okLen, len = pcall(function() return #collection end)
  return okLen and type(len) == "number" and len > 0
end

function CollectionForEach(collection, callback, maxVisits)
  if not collection or not callback then
    return 0
  end
  local visited = 0

  local function Visit(value)
    if not value then
      return false
    end
    visited = visited + 1
    if callback(value, visited) then
      return true
    end
    if maxVisits and visited >= maxVisits then
      return true
    end
    return false
  end

  local okPairs = pcall(function()
    for _, value in pairs(collection) do
      if Visit(value) then
        break
      end
    end
  end)
  if okPairs and visited > 0 then
    return visited
  end

  visited = 0
  local okIpairs = pcall(function()
    for _, value in ipairs(collection) do
      if Visit(value) then
        break
      end
    end
  end)
  if okIpairs and visited > 0 then
    return visited
  end

  visited = 0
  local okLen, len = pcall(function() return #collection end)
  if okLen and type(len) == "number" and len > 0 then
    for i = 1, len do
      local okValue, value = pcall(function() return collection[i] end)
      if okValue and value then
        if Visit(value) then
          break
        end
      end
    end
  end
  return visited
end

local function GetCreaturesNearPlayer(player, map, radius)
  local maxCreatures = 260

  local function BuildDungeonFallbackList()
    if not map or not map.IsDungeon or not map:IsDungeon() or not map.GetCreatures then
      return nil
    end
    local out = {}
    CollectionForEach(map:GetCreatures() or {}, function(creature)
      if creature and creature.IsInWorld and creature:IsInWorld()
        and creature.IsAlive and creature:IsAlive()
        and not (creature.IsPlayer and creature:IsPlayer())
        and not IsPlayerOwnedUnit(creature)
        and player.GetDistance and player:GetDistance(creature) <= radius then
        out[#out + 1] = creature
        if #out >= maxCreatures then
          return true
        end
      end
      return false
    end)
    return out
  end

  local nearby = nil
  local fromHostileQuery = false
  if player and player.GetCreaturesInRange then
    local okHostile, hostileRes = pcall(player.GetCreaturesInRange, player, radius, 0, 1, 1)
    if okHostile and CollectionHasAny(hostileRes) then
      nearby = hostileRes
      fromHostileQuery = true
    end
  end

  if not nearby and player and player.GetUnfriendlyUnitsInRange then
    local okUnfriendly, unfriendlyUnits = pcall(player.GetUnfriendlyUnitsInRange, player, radius)
    if okUnfriendly and CollectionHasAny(unfriendlyUnits) then
      local hostileCreatures = {}
      CollectionForEach(unfriendlyUnits, function(unit)
        if unit and unit.IsInWorld and unit:IsInWorld()
          and unit.IsAlive and unit:IsAlive()
          and not (unit.IsPlayer and unit:IsPlayer())
          and unit.GetEntry
          and not IsPlayerOwnedUnit(unit) then
          hostileCreatures[#hostileCreatures + 1] = unit
          if #hostileCreatures >= maxCreatures then
            return true
          end
        end
        return false
      end)
      if #hostileCreatures > 0 then
        nearby = hostileCreatures
        fromHostileQuery = true
      end
    end
  end

  if not nearby and player and player.GetCreaturesInRange then
    local ok, res = pcall(player.GetCreaturesInRange, player, radius)
    if ok and CollectionHasAny(res) then
      local genericCreatures = {}
      CollectionForEach(res, function(creature)
        if creature and creature.IsInWorld and creature:IsInWorld()
          and creature.IsAlive and creature:IsAlive()
          and not (creature.IsPlayer and creature:IsPlayer())
          and not IsPlayerOwnedUnit(creature) then
          genericCreatures[#genericCreatures + 1] = creature
          if #genericCreatures >= maxCreatures then
            return true
          end
        end
        return false
      end)
      if #genericCreatures > 0 then
        nearby = genericCreatures
      end
    end
  end
  if nearby then
    return nearby, fromHostileQuery
  end

  -- ALE compatibility fallback: dungeon-local scan with a strict cap.
  local fallback = BuildDungeonFallbackList()
  if fallback and CollectionHasAny(fallback) then
    return fallback, false
  end

  return {}, false
end

local function GetCreatureDedupeKey(creature)
  if not creature then return nil end
  if creature.GetGUIDLow then
    local okGuid, low = pcall(creature.GetGUIDLow, creature)
    if okGuid and type(low) == "number" and low > 0 then
      return low
    end
  end
  if creature.GetGUID then
    local okFull, full = pcall(creature.GetGUID, creature)
    if okFull and full then
      local key = tostring(full)
      if key ~= "" and key ~= "0" then
        return key
      end
    end
  end
  return tostring(creature)
end

local function ApplyAffixesToCreature(creature, mapId, players, affixes, seenCreatures, fromHostileQuery, caster)
  if not creature or not creature.GetFaction or not creature.GetEntry then
    return false
  end

  local key = GetCreatureDedupeKey(creature)
  if key and seenCreatures and seenCreatures[key] then
    return false
  end
  if key and seenCreatures then
    seenCreatures[key] = true
  end

  local faction, entry = creature:GetFaction(), creature:GetEntry()
  if not IsAffixTargetCreature(creature, mapId, players, faction, entry, fromHostileQuery) then
    return false
  end

  local map = creature.GetMap and creature:GetMap() or nil
  local instanceId = map and map.GetInstanceId and map:GetInstanceId() or 0
  local effectiveMapId = map and map.GetMapId and map:GetMapId() or mapId
  local staticRequired = tonumber(((_G.__MYTHIC_ENEMY_FORCES_REQUIRED__ or {})[effectiveMapId] or 0)) or 0
  if instanceId and instanceId > 0 and not AFFIX_PROTECTED_BOSS_ENTRIES[entry] then
    local keyToTrack = key or GetCreatureDedupeKey(creature)
    if keyToTrack ~= nil then
      local eligibleByInstance = _G.__MYTHIC_ENEMY_FORCES_ELIGIBLE_KEYS__ or {}
      local eligibleBucket = eligibleByInstance[instanceId]
      if not eligibleBucket then
        eligibleBucket = {}
        eligibleByInstance[instanceId] = eligibleBucket
        _G.__MYTHIC_ENEMY_FORCES_ELIGIBLE_KEYS__ = eligibleByInstance
      end
      eligibleBucket[keyToTrack] = true

      if staticRequired <= 0 then
        local trackedByInstance = _G.__MYTHIC_ENEMY_FORCES_TRACKED_KEYS__ or {}
        local bucket = trackedByInstance[instanceId]
        if not bucket then
          bucket = {}
          trackedByInstance[instanceId] = bucket
          _G.__MYTHIC_ENEMY_FORCES_TRACKED_KEYS__ = trackedByInstance
        end
        if not bucket[keyToTrack] then
          bucket[keyToTrack] = true
          local totals = _G.__MYTHIC_ENEMY_FORCES_TRACKED_TOTAL__ or {}
          totals[instanceId] = math.max(0, math.floor(tonumber(totals[instanceId] or 0) or 0)) + 1
          _G.__MYTHIC_ENEMY_FORCES_TRACKED_TOTAL__ = totals
        end
      end
    end
  end

  local creatureInCombat = IsUnitInCombat(creature)
  local nearbyActivePlayers = nil
  local function GetNearbyActivePlayers()
    if nearbyActivePlayers ~= nil then
      return nearbyActivePlayers
    end
    nearbyActivePlayers = {}
    for _, pl in pairs(players) do
      if pl and pl.IsAlive and pl:IsAlive() and pl.IsInWorld and pl:IsInWorld()
        and pl.GetDistance and pl:GetDistance(creature) <= AFFIX_PLAYER_CAST_RADIUS then
        nearbyActivePlayers[#nearbyActivePlayers + 1] = pl
      end
    end
    return nearbyActivePlayers
  end

  for _, spellId in ipairs(affixes) do
    local playerTargetedAffix = AFFIX_CAST_ON_PLAYERS[spellId] or AFFIX_PLAYER_ONLY[spellId]
    -- Player-targeted affixes should never remain on enemies.
    if playerTargetedAffix then
      if creature.HasAura and creature.RemoveAura and creature:HasAura(spellId) then
        creature:RemoveAura(spellId)
      end
    else
      ApplySelfAffixToCreature(creature, spellId)
    end
    if AFFIX_CAST_ON_PLAYERS[spellId] and creatureInCombat then
      for _, pl in ipairs(GetNearbyActivePlayers()) do
        RefreshOrApplyPlayerAffix(creature, pl, spellId)
      end
    end
  end
  return true
end

local function ApplyAuraToNearbyCreatures(player, affixes, seen, instancePlayers)
  if not player or not player.GetMap then return end
  local affixList = affixes or {}
  if #affixList > 0 and not IsAffixSystemEnabled() then return end
  local map = player:GetMap(); if not map then return end
  local mapId = map:GetMapId()
  local players = instancePlayers or map:GetPlayers() or {}
  local seenCreatures = seen or {}
  local nearbyCreatures, fromHostileQuery = GetCreaturesNearPlayer(player, map, MYTHIC_SCAN_RADIUS)
  CollectionForEach(nearbyCreatures, function(creature)
    ApplyAffixesToCreature(creature, mapId, players, affixList, seenCreatures, fromHostileQuery, player)
    return false
  end, 220)
end

PrimeEnemyForcesTracking = function(map, instanceId, mapId)
  if not map or not instanceId or instanceId == 0 then
    return
  end

  local players = map:GetPlayers() or {}
  local seen = {}
  local emptyAffixes = {}
  for _, pl in pairs(players) do
    if pl and pl.IsInWorld and pl:IsInWorld() and pl.GetMap then
      local plMap = pl:GetMap()
      if plMap and plMap:GetInstanceId() == instanceId then
        ApplyAuraToNearbyCreatures(pl, emptyAffixes, seen, players)
      end
    end
  end
end

local function RemoveAffixAurasFromAllCreatures(instanceId, map)
  if not map then return end
  local affixes = MYTHIC_AFFIXES_TABLE[instanceId]; if not affixes then return end
  CollectionForEach(map:GetCreatures() or {}, function(creature)
    if creature:IsAlive() and creature:IsInWorld() and not creature:IsPlayer() then
      for _, spellId in ipairs(affixes) do
        if creature:HasAura(spellId) then creature:RemoveAura(spellId) end
      end
    end
    return false
  end)
end

local function RemoveAffixAurasFromPlayers(instanceId, map)
  if not map then return end
  local affixes = MYTHIC_AFFIXES_TABLE[instanceId]; if not affixes then return end
  for _, player in pairs(map:GetPlayers() or {}) do
    if player:IsInWorld() then
      for _, spellId in ipairs(affixes) do
        if AFFIX_CAST_ON_PLAYERS[spellId] and player:HasAura(spellId) then
          player:RemoveAura(spellId)
        end
      end
    end
  end
end

local function GetPlayersInInstance(instanceId, mapId)
  local out = {}
  local players = GetPlayersInWorld and GetPlayersInWorld() or {}
  for _, pl in pairs(players) do
    if pl and pl:IsInWorld() then
      local m = pl:GetMap()
      if m and m:GetInstanceId() == instanceId and (not mapId or mapId == 0 or m:GetMapId() == mapId) then
        out[#out+1] = pl
      end
    end
  end
  return out
end

local function ApplyAuraToInstancePlayers(instanceId, mapId, affixes)
  if not IsAffixSystemEnabled() then return end
  if not affixes or #affixes == 0 then
    local tier = MYTHIC_TIER_TABLE[instanceId] or 1
    affixes = GetAffixSet(tier)
    MYTHIC_AFFIXES_TABLE[instanceId] = affixes
  end
  if not affixes or #affixes == 0 then return end
  local players = GetPlayersInInstance(instanceId, mapId)
  if not players or #players == 0 then return end

  local seen = {}
  for _, pl in pairs(players) do
    if pl and pl.IsInWorld and pl:IsInWorld() then
      ApplyAuraToNearbyCreatures(pl, affixes, seen, players)
    end
  end
end

local function StartAuraLoop(player, instanceId, mapId, affixes)
  if MYTHIC_LOOP_HANDLERS[instanceId] then RemoveEventById(MYTHIC_LOOP_HANDLERS[instanceId]) end
  local loopInterval = (mapId == CULLING_OF_STRATHOLME_MAP_ID) and 4000 or AURA_LOOP_INTERVAL
  local eventId = CreateLuaEvent(function()
    if not MYTHIC_FLAG_TABLE[instanceId] then return end
    if not IsAffixSystemEnabled() then return end
    if not affixes or #affixes == 0 then return end
    local ok, err = pcall(ApplyAuraToInstancePlayers, instanceId, mapId, affixes)
    if not ok then
      MythicLog("Affix loop error: " .. tostring(err))
    end

    -- Keep addon kill requirement/progress in sync even before first kill.
    if AIO then
      local currentKills, reqKills = MythicGetEnemyForcesProgress(instanceId, mapId)
      for _, pl in pairs(GetPlayersInInstance(instanceId, mapId)) do
        if pl and pl:IsInWorld() then
          AIO.Handle(pl, "MythicPlus", "SetKills", currentKills, reqKills)
        end
      end
    end
  end, loopInterval, 0)
  MYTHIC_LOOP_HANDLERS[instanceId] = eventId
end

local function StopHoRCompletionFailsafe(instanceId)
  local eventId = MYTHIC_HOR_FAILSAFE_EVENTS[instanceId]
  if eventId then
    RemoveEventById(eventId)
    MYTHIC_HOR_FAILSAFE_EVENTS[instanceId] = nil
  end
end

local function SafeCreatureBoolCall(creature, methodName)
  if not creature or not methodName then return false end
  local method = creature[methodName]
  if type(method) ~= "function" then return false end
  local ok, result = pcall(method, creature)
  return ok and result and true or false
end

local function IsHoRCompletionMarkerNearPlayer(player)
  if not player or not player:IsInWorld() then return false end
  local map = player:GetMap()
  if not map or map:GetMapId() ~= HALLS_OF_REFLECTION_MAP_ID then return false end

  if player.GetGameObjectsInRange then
    local gameObjects = player:GetGameObjectsInRange(HOR_FAILSAFE_SCAN_RADIUS) or {}
    for _, go in pairs(gameObjects) do
      if go and HOR_COMPLETION_STAIRS[go:GetEntry()] then
        return true, string.format("stairs gameobject %d", go:GetEntry())
      end
    end
  end

  if player.GetCreaturesInRange then
    local creatures = player:GetCreaturesInRange(HOR_FAILSAFE_SCAN_RADIUS) or {}
    for _, creature in pairs(creatures) do
      if creature and HOR_COMPLETION_LEADERS[creature:GetEntry()] and SafeCreatureBoolCall(creature, "IsQuestGiver") then
        return true, "leader questgiver detected"
      end
    end
  end

  return false
end

local function IsCoSCompletionMarkerNearPlayer(player, scanRadius)
  if not player or not player:IsInWorld() then return false end
  local map = player:GetMap()
  if not map or map:GetMapId() ~= CULLING_OF_STRATHOLME_MAP_ID then return false end

  if player.GetGameObjectsInRange then
    local gameObjects = player:GetGameObjectsInRange(scanRadius or 600) or {}
    local checked = 0
    for _, go in pairs(gameObjects) do
      checked = checked + 1
      if checked > 256 then break end
      if go then
        local entry = go:GetEntry()
        if entry == 190663 or entry == 193597 then
          return true, string.format("mal'ganis chest gameobject %d", entry)
        end
        if entry == 191788 and go.GetGoState then
          local ok, state = pcall(go.GetGoState, go)
          if ok and (state == 0 or state == 2) then
            return true, "exit gate opened"
          end
        end
      end
    end
  end

  return false
end

local function StartHoRCompletionFailsafe(instanceId, mapId)
  if not instanceId or instanceId == 0 then return end
  if mapId ~= HALLS_OF_REFLECTION_MAP_ID then return end

  StopHoRCompletionFailsafe(instanceId)
  local eventId = CreateLuaEvent(function()
    if not MYTHIC_FLAG_TABLE[instanceId] or MYTHIC_MODE_ENDED[instanceId] then
      StopHoRCompletionFailsafe(instanceId)
      return
    end

    local triggerPlayer = nil
    local triggerReason = nil
    for _, pl in pairs(GetPlayersInInstance(instanceId, mapId)) do
      if pl and pl:IsInWorld() then
        local complete, reason = IsHoRCompletionMarkerNearPlayer(pl)
        if complete then
          triggerPlayer = pl
          triggerReason = reason
          break
        end
      end
    end

    if not triggerPlayer then return end

    local map = triggerPlayer:GetMap()
    if not map or map:GetMapId() ~= mapId or map:GetInstanceId() ~= instanceId then return end
    if not MythicEnemyForcesCanComplete(map, instanceId, mapId) then return end

    local tier = MYTHIC_TIER_TABLE[instanceId] or 1
    local expired = MYTHIC_TIMER_EXPIRED[instanceId]
    local chestX, chestY, chestZ, chestO
    if not expired then
      chestX, chestY, chestZ, chestO = triggerPlayer:GetX(), triggerPlayer:GetY(), triggerPlayer:GetZ(), triggerPlayer:GetO()
      chestX = chestX - math.cos(chestO) * 2
      chestY = chestY - math.sin(chestO) * 2
    end

    MythicLog(string.format("HoR completion failsafe triggered for instance %d (%s)", instanceId, triggerReason or "completion marker"))
    FinalizeMythicRun(map, instanceId, tier, expired, chestX, chestY, chestZ, chestO)
    StopHoRCompletionFailsafe(instanceId)
  end, HOR_FAILSAFE_SCAN_INTERVAL_MS, 0)
  MYTHIC_HOR_FAILSAFE_EVENTS[instanceId] = eventId
end

local function StartCoSCompletionFailsafe(instanceId, mapId)
  if not instanceId or instanceId == 0 then return end
  if mapId ~= CULLING_OF_STRATHOLME_MAP_ID then return end

  StopHoRCompletionFailsafe(instanceId)
  local eventId = CreateLuaEvent(function()
    if not MYTHIC_FLAG_TABLE[instanceId] or MYTHIC_MODE_ENDED[instanceId] then
      StopHoRCompletionFailsafe(instanceId)
      return
    end

    local players = GetPlayersInInstance(instanceId, mapId)
    if not players or #players == 0 then return end
    local triggerPlayer = nil
    local triggerReason = nil

    local scannedPlayers = 0
    for _, pl in pairs(players) do
      if pl and pl:IsInWorld() then
        scannedPlayers = scannedPlayers + 1
        if scannedPlayers > 8 then break end
        local complete, reason = IsCoSCompletionMarkerNearPlayer(pl)
        if complete then
          triggerPlayer = pl
          triggerReason = reason
          break
        end
      end
    end

    if not triggerPlayer then return end

    local map = triggerPlayer:GetMap()
    if not map or map:GetMapId() ~= mapId or map:GetInstanceId() ~= instanceId then return end
    if not MythicEnemyForcesCanComplete(map, instanceId, mapId) then return end

    local tier = MYTHIC_TIER_TABLE[instanceId] or 1
    local expired = MYTHIC_TIMER_EXPIRED[instanceId]
    local chestX, chestY, chestZ, chestO
    if not expired then
      chestX, chestY, chestZ, chestO = triggerPlayer:GetX(), triggerPlayer:GetY(), triggerPlayer:GetZ(), triggerPlayer:GetO()
      chestX = chestX - math.cos(chestO) * 2
      chestY = chestY - math.sin(chestO) * 2
    end

    MythicLog(string.format("CoS completion failsafe triggered for instance %d (%s)", instanceId, triggerReason or "completion marker"))
    FinalizeMythicRun(map, instanceId, tier, expired, chestX, chestY, chestZ, chestO)
    StopHoRCompletionFailsafe(instanceId)
  end, 5000, 0)
  MYTHIC_HOR_FAILSAFE_EVENTS[instanceId] = eventId
end

--==========================================================
-- Rating & Rewards
--==========================================================
local function UpdatePlayerRating(player, tier, deathCount, isSuccess, timeBonus)
  if not player then return end
  local guid, cfg = player:GetGUIDLow(), TIER_CONFIG[tier]; if not cfg then return end
  local q = DBQuery("SELECT total_points FROM character_mythic_rating WHERE guid = ?", guid)
  local current = q and q:GetUInt32(0) or 0
  local new
  if isSuccess then
    local gain, loss = cfg.rating_gain, cfg.rating_loss * (deathCount or 0)
    local bonus = timeBonus or 0
    new = math.min(math.max(current + gain + bonus - loss, 0), RATING_CAP)
  else
    local timeoutPenalty, deathPenalty = cfg.timeout_penalty, cfg.rating_loss * (deathCount or 0)
    new = math.max(current - timeoutPenalty - deathPenalty, 0)
  end
  local claims = {0,0,0}; if isSuccess then claims[tier] = 1 end
  local now = os.time()
  DBExecute([[
    INSERT INTO character_mythic_rating (guid,total_runs,total_points,claimed_tier1,claimed_tier2,claimed_tier3,last_updated)
    VALUES (?, 1, ?, ?, ?, ?, FROM_UNIXTIME(?))
    ON DUPLICATE KEY UPDATE total_runs=total_runs+1,total_points=?,
      claimed_tier1=claimed_tier1+?, claimed_tier2=claimed_tier2+?, claimed_tier3=claimed_tier3+?,
      last_updated=FROM_UNIXTIME(?)
  ]], guid, new, claims[1], claims[2], claims[3], now, new, claims[1], claims[2], claims[3], now)
  return new, current
end

local function AwardMythicPoints(player, tier, deathCount, elapsedTime, maxTime)
  if not player then return end
  local cfg = TIER_CONFIG[tier]
  local deaths = deathCount or 0
  local timeBonus = 0
  local timeBonusText = ""
  
  -- Calculate time-based bonus
  if elapsedTime and maxTime and maxTime > 0 then
    local timePercent = (elapsedTime / maxTime) * 100
    if timePercent <= 70 then
      timeBonus = math.floor(cfg.rating_gain * 0.30)  -- 30% bonus
      timeBonusText = string.format(" |cff00ff00(+%d speed bonus)|r", timeBonus)
    elseif timePercent <= 80 then
      timeBonus = math.floor(cfg.rating_gain * 0.20)  -- 20% bonus
      timeBonusText = string.format(" |cff00ff00(+%d speed bonus)|r", timeBonus)
    elseif timePercent <= 90 then
      timeBonus = math.floor(cfg.rating_gain * 0.10)  -- 10% bonus
      timeBonusText = string.format(" |cff66ff66(+%d speed bonus)|r", timeBonus)
    end
  end
  
  local newRating, prev = UpdatePlayerRating(player, tier, deaths, true, timeBonus); if not newRating then return end
  local deathPenalty = cfg.rating_loss * deaths
  local netGain = newRating - prev

  local deathBlurb = (deaths > 0)
    and string.format(" (|cffff5555%d deaths|r |cffff0000(-%d from deaths)|r)", deaths, deathPenalty) or ""

  local msg
  if netGain > 0 then
    msg = string.format("|cff00ff00Gained +%d rating|r%s%s", netGain, timeBonusText, deathBlurb)
  elseif netGain == 0 then
    if prev >= RATING_CAP then
      msg = "|cffffcc00No rating added because you are rating capped|r"
    elseif deathPenalty > 0 then
      msg = "|cffffcc00No rating gained due to deaths|r" .. deathBlurb
    else
      msg = "|cffffcc00No rating change|r"
    end
  else
    msg = string.format("|cffff5555Lost %d rating due to deaths|r%s", math.abs(netGain), deathBlurb)
  end

  MythicSendPlayerMessage(player, string.format(
    "%sTier %d completed!|r Mythic+ mode has been ended for this dungeon run.\n%s\nNew Rating: %s%d|r",
    cfg.color, tier, msg, GetRatingColor(newRating), newRating))

  local itemId, count = 45624, 1
  if newRating > 1800 then itemId, count = 49426, 2
  elseif newRating > 1000 then itemId = 49426
  elseif newRating > 500 then itemId = 47241 end
  local okReward, rewardItem, rewardErr = TryGiveItem(player, itemId, count)
  if okReward then
    MythicSendPlayerMessage(player, string.format("|cffffff00[Mythic]|r Reward: |cffaaff00%s x%d|r", GetItemLinkFromAddResult(itemId, rewardItem), count))
  else
    MythicSendPlayerMessage(player, "|cffff0000[Mythic]|r Reward could not be added. " .. (rewardErr or "Check bag space."))
  end
  
  -- Rating-based extra loot chance (5% base + rating/100, capped at 25% at 2000 rating)
  local extraLootChance = math.min(5 + (newRating / 100), 25)
  if math.random(1, 100) <= extraLootChance then
    local bonusOk, bonusItem, bonusErr = TryGiveItem(player, itemId, 1)
    if bonusOk then
      MythicSendPlayerMessage(player, string.format("|cffff8800[Mythic]|r Bonus loot! |cffaaff00%s|r (%.1f%% chance)", GetItemLinkFromAddResult(itemId, bonusItem), extraLootChance))
    end
  end
  if tier < 3 then
    local grantedTier = tier + 1
    local speedJackpot = false
    local jackpotEligible = (tier == 1 and elapsedTime and maxTime and maxTime > 0 and elapsedTime <= (maxTime / 3))

    if jackpotEligible and math.random(1, 8) == 1 then
      grantedTier = 3
      speedJackpot = true
    end

    local nextKey = KEY_IDS[grantedTier]
    local okKey, _, keyErr = TryGiveItem(player, nextKey, 1)
    if okKey then
      if speedJackpot then
        MythicSendPlayerMessage(player, string.format(
          "|cffffff00[Mythic]|r |cffffd700Chrono Surge!|r You finished Tier 1 in |cff00ff00%s|r (needed |cff00ff00%s|r or faster). |cffff8000Tier 3 Keystone granted!|r",
          FormatRaceTime(elapsedTime),
          FormatRaceTime(math.floor(maxTime / 3))))
      else
        MythicSendPlayerMessage(player, string.format("|cffffff00[Mythic]|r Tier %d Keystone granted!", grantedTier))
      end
    else
      MythicSendPlayerMessage(player, "|cffff0000[Mythic]|r Keystone could not be added. " .. (keyErr or "Check bag space."))
    end
  end

  local map = player:GetMap(); if map then MYTHIC_COMPLETION_STATE[map:GetInstanceId()] = "completed" end
  return newRating, prev
end

local function PenalizeMythicFailure(player, tier, deathCount)
  if not player then return end
  local newRating, prev = UpdatePlayerRating(player, tier, deathCount, false); if not newRating then return end
  MythicSendPlayerMessage(player, string.format(
    "|cffffff00Mythic failed:|r |cffff0000-%d rating|r (|cffff5555%d deaths|r)\nNew Rating: %s%d|r",
    prev - newRating, deathCount or 0, GetRatingColor(newRating), newRating))
  MythicClearTierTimerAura(player, tier, true)
  local map = player:GetMap(); if map then MYTHIC_COMPLETION_STATE[map:GetInstanceId()] = "failed" end
end

--==========================================================
-- Timer (server timeout + optional visual aura)
--==========================================================
local function ClearTimeoutEvents(instanceId)
  local events = MYTHIC_TIMEOUT_EVENTS[instanceId]
  if not events then return end
  if events.keep then RemoveEventById(events.keep) end
  if events.expire then RemoveEventById(events.expire) end
  MYTHIC_TIMEOUT_EVENTS[instanceId] = nil
end

local function ComputeRemainingSecondsFromCreatedAt(instanceId, mapId, tier)
  if not instanceId or instanceId == 0 then
    return nil
  end
  if not mapId or mapId == 0 then
    return nil
  end
  if not tier or tier <= 0 then
    return nil
  end

  local row = DBQuery(
    "SELECT UNIX_TIMESTAMP(created_at) FROM character_mythic_instance_state WHERE instance_id=? AND map_id=? AND guid<>? ORDER BY created_at ASC LIMIT 1",
    instanceId, mapId, KILL_LOCK_MARKER_GUID)
  if not row then
    return nil
  end

  local createdAt = row:GetUInt32(0)
  if not createdAt or createdAt == 0 then
    return nil
  end

  local elapsed = math.max(0, os.time() - createdAt)
  local totalSeconds = ComputeTierMinutes(mapId, tier) * 60
  return math.max(0, totalSeconds - elapsed)
end

local function ScheduleMythicTimeout(player, instanceId, tier, remainingSeconds)
  if not player then return end
  local cfg = TIER_CONFIG[tier]; if not cfg then return end
  MythicEnsureTimerAddonAIOHandlers()

  local auraId  = MythicGetTierConfiguredTimerAuraId(tier)
  local map     = player:GetMap()
  local mapId   = map and map:GetMapId() or 0
  local playerGuidLow = player:GetGUIDLow()
  local durationMs
  local persistedRemaining = ComputeRemainingSecondsFromCreatedAt(instanceId, mapId, tier)

  if remainingSeconds and remainingSeconds > 0 then
    -- If timers were increased in config, keep existing runs aligned with the
    -- persisted run start instead of keeping the shorter previously scheduled end.
    if persistedRemaining and persistedRemaining > remainingSeconds then
      remainingSeconds = persistedRemaining
    end
    durationMs = math.floor(remainingSeconds * 1000)
  else
    if persistedRemaining and persistedRemaining > 0 then
      durationMs = math.floor(persistedRemaining * 1000)
    else
      local minutes = ComputeTierMinutes(mapId, tier)
      durationMs = minutes * 60000
    end
  end

  if not durationMs or durationMs <= 0 then
    return
  end

  local endAt = os.time() + math.ceil(durationMs / 1000)

  local function ApplyTimerAuraToPlayer(pl, remainingMs)
    if not pl then
      return
    end
    if auraId == 0 then
      return
    end
    if not MythicShouldUseTimerAuraForPlayer(pl) then
      MythicClearTierTimerAura(pl, tier, true)
      return
    end
    local aura = pl:GetAura(auraId) or pl:AddAura(auraId, pl)
    if aura then
      aura:SetMaxDuration(remainingMs)
      aura:SetDuration(remainingMs)
    end
  end

  if auraId ~= 0 then
    ApplyTimerAuraToPlayer(player, durationMs)
    for _, pl in pairs(GetPlayersInInstance(instanceId, mapId)) do
      if pl and pl:GetGUIDLow() ~= playerGuidLow then
        ApplyTimerAuraToPlayer(pl, durationMs)
      end
    end
  else
    MythicClearTierTimerAura(player, tier, true)
    for _, pl in pairs(GetPlayersInInstance(instanceId, mapId)) do
      if pl and pl:GetGUIDLow() ~= playerGuidLow then
        MythicClearTierTimerAura(pl, tier, true)
      end
    end
  end

  ClearTimeoutEvents(instanceId)

  local keepAuraEventId = nil
  if auraId ~= 0 then
    keepAuraEventId = CreateLuaEvent(function()
      if not MYTHIC_FLAG_TABLE[instanceId] or MYTHIC_TIMER_EXPIRED[instanceId] then return end
      if not auraId or auraId == 0 then return end

      local remainingMs = math.max(0, (endAt - os.time()) * 1000)
      if remainingMs <= 0 then return end

      for _, pl in pairs(GetPlayersInInstance(instanceId, mapId)) do
        if pl and pl:IsInWorld() then
          ApplyTimerAuraToPlayer(pl, remainingMs)
        end
      end
    end, 1000, 0)
  end

  local expireEventId = CreateLuaEvent(function()
    if not MYTHIC_FLAG_TABLE[instanceId] or MYTHIC_TIMER_EXPIRED[instanceId] then return end

    MYTHIC_TIMER_EXPIRED[instanceId]   = true
    -- Keep the run active after timeout so final-boss death can still finalize
    -- the run and publish the final rating payload to the addon.
    MYTHIC_COMPLETION_STATE[instanceId] = "active"
    SetKillLock(instanceId, mapId)

    local affectedPlayers = GetPlayersInInstance(instanceId, mapId)
    local mapNow = nil
    if #affectedPlayers > 0 then
      mapNow = affectedPlayers[1]:GetMap()
    elseif map and map:GetInstanceId() == instanceId then
      mapNow = map
    end

    if mapNow then
      for _, pl in pairs(affectedPlayers) do
        local g = pl:GetGUIDLow()
        local deaths = (MYTHIC_DEATHS[instanceId] and MYTHIC_DEATHS[instanceId][g]) or 0
        PenalizeMythicFailure(pl, tier, deaths)
        MythicSendPlayerMessage(pl, "|cffff0000[Mythic]|r Time limit exceeded. Finish the final boss to finalize this run.")
        MythicClearTierTimerAura(pl, tier, true)
      end
    end

    -- AIO: notify clients that timer expired
    if AIO then
      for _, pl in pairs(GetPlayersInInstance(instanceId, mapId)) do
        if pl and pl:IsInWorld() then
          local deaths = (MYTHIC_DEATHS[instanceId] and MYTHIC_DEATHS[instanceId][pl:GetGUIDLow()]) or 0
          local qRating = DBQuery("SELECT total_points FROM character_mythic_rating WHERE guid = ?", pl:GetGUIDLow())
          local rating = qRating and qRating:GetUInt32(0) or nil
          AIO.Handle(pl, "MythicPlus", "StopRun", {
            completed = false,
            expired = true,
            finalized = false,
            deaths = deaths,
            rating = rating,
          })
        end
      end
    end
  end, durationMs, 1)

  MYTHIC_TIMEOUT_EVENTS[instanceId] = {
    keep = keepAuraEventId,
    expire = expireEventId,
  }
end

--==========================================================
-- Gossip UI (Pedestal/NPC)
--==========================================================
local function GetPlayerRatingLine(player)
  local guid = player:GetGUIDLow()
  local q = DBQuery("SELECT total_points, total_runs FROM character_mythic_rating WHERE guid = ?", guid)
  if not q then return "|cff66ccff[Mythic]|r Rating: |cffffcc000|r (no runs yet)" end
  local rating, runs = q:GetUInt32(0), q:GetUInt32(1)
  return string.format("|cff66ccff[Mythic]|r Rating: %s%d|r  (|cffffcc00%d runs|r)", GetRatingColor(rating), rating, runs)
end

local GOSSIP_INTID_NOOP = 9000

local function IsMythicMapSupported(mapId)
  return MYTHIC_FINAL_BOSSES[mapId] ~= nil
end

local function Gossip_ShowAffixTierMenu(player, creature, tier)
  player:GossipClearMenu()
  local current     = WEEKLY_AFFIXES[tier]
  local currentName = current and current.name or "None"
  local header      = string.format("|cffffff00Tier %d Affix|r\nCurrent: %s", tier, Colorize(currentName, AFFIX_COLOR_MAP[currentName]))
  player:GossipMenuAddItem(0, header, 0, GOSSIP_INTID_NOOP)
  local pool = WEEKLY_AFFIX_POOL[tier] or {}
  for i, aff in ipairs(pool) do
    local name = aff.name
    if not current or name ~= current.name then
      player:GossipMenuAddItem(0, string.format("Set to: %s", Colorize(name, AFFIX_COLOR_MAP[name])), 0, (300 + tier * 10 + i))
    end
  end
  player:GossipMenuAddItem(0, "Go back", 0, 200)
  player:GossipSendMenu(1, creature)
end

local function Gossip_ShowAffixRootMenu(player, creature)
  player:GossipClearMenu()
  player:GossipMenuAddItem(0, "|cffff6600Change Mythic affixes|r", 0, GOSSIP_INTID_NOOP)
  for t = 1, 3 do
    local aff   = WEEKLY_AFFIXES[t]
    local name  = aff and aff.name or "None"
    local color = AFFIX_COLOR_MAP[name] or "|cffffffff"
    local tid   = (t == 1 and 211) or (t == 2 and 212) or 213
    player:GossipMenuAddItem(0, string.format("Tier %d (current: %s%s|r)", t, color, name), 0, tid)
  end
  player:GossipMenuAddItem(0, "Go back", 0, 290)
  player:GossipSendMenu(1, creature)
end

function Pedestal_OnGossipHello(_, player, creature)
  local map = player:GetMap(); if not map then return end
  local instanceId = map:GetInstanceId()
  local mapId = map:GetMapId()

  player:GossipClearMenu()
  player:GossipMenuAddItem(0, GetPlayerRatingLine(player), 0, GOSSIP_INTID_NOOP)

  do
    local myBest, realmBest = GetBestTimesForMap(map:GetMapId(), player:GetGUIDLow())
    local myLine = myBest
      and string.format("|cff66ccffYour best:|r %s (T%d)", FormatRaceTime(myBest.sec), myBest.tier)
      or  "|cff66ccffYour best:|r —"
    local realmLine = realmBest
      and string.format("|cffffff00Realm best:|r %s (T%d) by %s", FormatRaceTime(realmBest.sec), realmBest.tier, realmBest.name)
      or  "|cffffff00Realm best:|r —"
    player:GossipMenuAddItem(0, myLine .. "   " .. realmLine, 0, GOSSIP_INTID_NOOP)
  end

  local completionState = MYTHIC_COMPLETION_STATE[instanceId]
  if completionState == "completed" then
    player:GossipMenuAddItem(0, "|cff00ff00Good job, Mythic Champion! You've conquered this challenge!|r", 0, GOSSIP_INTID_NOOP)
  elseif completionState == "failed" then
    player:GossipMenuAddItem(0, "|cffff0000You've failed, but try again in a different dungeon!|r", 0, GOSSIP_INTID_NOOP)
  elseif MYTHIC_FLAG_TABLE[instanceId] then
    player:GossipMenuAddItem(0, "|cff000000You're already in Mythic mode! Hurry! Go fight!|r", 0, GOSSIP_INTID_NOOP)
  else
    if not IsMythicMapSupported(mapId) then
      player:GossipMenuAddItem(0, "|cffff8800This dungeon is not configured for Mythic+ yet.|r", 0, GOSSIP_INTID_NOOP)
    else
      local header = "|cff000000This Week's Mythic Affixes:|r"
      for tier = 1, 3 do
        local parts = {}
        for i = 1, tier do
          local aff = WEEKLY_AFFIXES[i]
          if aff then table.insert(parts, (AFFIX_COLOR_MAP[aff.name] or "|cffffffff") .. aff.name .. "|r") end
        end
        header = header .. "\n|cff000000T" .. tier .. ":|r " .. table.concat(parts, "|cff000000, |r")
      end
      local eta = GetAffixRerollETA()
      header = header .. "\n|cff000000Next reroll in:|r " .. ((eta > 0) and FormatDurationShort(eta) or "soon")
      player:GossipMenuAddItem(0, header, 0, GOSSIP_INTID_NOOP)

      if IsKillLockActive(instanceId, mapId) then
        local lockMsg = "|cffff0000[Mythic]|r Mythic+ is locked. Reset the dungeon to enable keystone use."
        player:GossipMenuAddItem(0, lockMsg, 0, GOSSIP_INTID_NOOP)
        MythicSendPlayerMessage(player, lockMsg)
      else
        for tier = 1, 3 do
          local cfg = TIER_CONFIG[tier]
          player:GossipMenuAddItem(10, string.format("%sTier %d|r", cfg.color, tier), 0, 100 + tier, false, "", 0, ICONS[tier])
        end
      end
    end
  end

  if player:IsGM() then player:GossipMenuAddItem(0, "|cffff6600Change Mythic affixes|r", 0, 200) end
  player:GossipSendMenu(1, creature)
end

function Pedestal_OnGossipSelect(_, player, creature, _, intid)
  if intid == GOSSIP_INTID_NOOP then return end

  if intid == 200 then
    if not player:IsGM() then MythicSendPlayerMessage(player, "|cffff0000[Mythic]|r You do not have permission to change affixes."); player:GossipComplete(); return end
    Gossip_ShowAffixRootMenu(player, creature); return
  end

  if intid == 290 then Pedestal_OnGossipHello(nil, player, creature); return end

  if intid == 211 or intid == 212 or intid == 213 then
    if not player:IsGM() then MythicSendPlayerMessage(player, "|cffff0000[Mythic]|r You do not have permission to change affixes."); player:GossipComplete(); return end
    Gossip_ShowAffixTierMenu(player, creature, (intid == 211 and 1) or (intid == 212 and 2) or 3); return
  end

  if intid >= 300 then
    if not player:IsGM() then MythicSendPlayerMessage(player, "|cffff0000[Mythic]|r You do not have permission to change affixes."); player:GossipComplete(); return end
    local code = intid - 300; local tier, idx = math.floor(code/10), code%10
    if tier < 1 or tier > 3 then player:GossipComplete(); return end
    local chosen = (WEEKLY_AFFIX_POOL[tier] or {})[idx]
    if not chosen then MythicSendPlayerMessage(player, "|cffff0000[Mythic]|r Invalid affix selection."); player:GossipComplete(); return end

    local before = WEEKLY_AFFIXES[tier] and WEEKLY_AFFIXES[tier].name or "None"
    WEEKLY_AFFIXES[tier] = chosen
    ResetAffixCountdown()

    MythicSendWorldMessage(string.format("|cffffcc00[Mythic]|r Tier %d affix set: %s -> %s", tier, ColorAffixName(before), ColorAffixName(chosen.name)))
    MythicSendPlayerMessage(player, "|cff66ccff[Mythic]|r New affixes: " .. GetAffixNamesString(3))
    Gossip_ShowAffixTierMenu(player, creature, tier); return
  end

  if intid >= 101 and intid <= 103 then
    local map = player:GetMap(); if not map then MythicSendPlayerMessage(player, "Error: No map context."); player:GossipComplete(); return end
    local instanceId, tier = map:GetInstanceId(), intid - 100
    local mapId = map:GetMapId()
    local keyId = KEY_IDS[tier]

    if not IsMythicMapSupported(mapId) then
      MythicSendPlayerMessage(player, "|cffff0000[Mythic]|r This dungeon is not configured for Mythic+ yet.")
      player:GossipComplete()
      return
    end
    if IsKillLockActive(instanceId, mapId) then MythicSendPlayerMessage(player, "|cffff0000[Mythic]|r A creature was already killed. Reset the dungeon to use a keystone."); player:GossipComplete(); return end
    if MYTHIC_FLAG_TABLE[instanceId] then MythicSendPlayerMessage(player, "|cffff0000Mythic mode has already been activated in this instance.|r"); player:GossipComplete(); return end
    if not player:HasItem(keyId) then MythicSendPlayerMessage(player, "You do not have the required Tier " .. tier .. " Keystone."); player:GossipComplete(); return end
    if map:GetDifficulty() == 0 then MythicSendPlayerMessage(player, "|cffff0000Mythic keys cannot be used in Normal mode dungeons.|r"); player:GossipComplete(); return end
    local guid    = player:GetGUIDLow()
    local affixes = GetAffixSet(tier)
    local cfg     = TIER_CONFIG[tier]

    local names = {}
    for i = 1, tier do local a = WEEKLY_AFFIXES[i]; if a then table.insert(names, (AFFIX_COLOR_MAP[a.name] or "|cffffffff") .. a.name .. "|r") end end

    MYTHIC_FLAG_TABLE[instanceId]          = true
    MYTHIC_AFFIXES_TABLE[instanceId]       = affixes
    MYTHIC_REWARD_CHANCE_TABLE[instanceId] = (tier == 1 and 1.5) or (tier == 2 and 2.0) or 5.0
    MYTHIC_TIER_TABLE[instanceId]          = tier
    MYTHIC_COMPLETION_STATE[instanceId]    = "active"
    MYTHIC_DEATHS[instanceId]              = {}
    MYTHIC_NON_BOSS_KILLS[instanceId]      = 0
    MYTHIC_FORCES_WARN_TS[instanceId]      = nil
    (_G.__MYTHIC_ENEMY_FORCES_TRACKED_KEYS__ or {})[instanceId] = {}
    (_G.__MYTHIC_ENEMY_FORCES_KILLED_KEYS__ or {})[instanceId] = {}
    (_G.__MYTHIC_ENEMY_FORCES_TRACKED_TOTAL__ or {})[instanceId] = 0
    (_G.__MYTHIC_ENEMY_FORCES_REQ_STABLE__ or {})[instanceId] = 0
    (_G.__MYTHIC_ENEMY_FORCES_ELIGIBLE_KEYS__ or {})[instanceId] = {}
    MYTHIC_FORCES_PERSIST_CACHE[instanceId] = nil
    MYTHIC_PENDING_DEATH_WRITES[instanceId] = nil
    DBExecute("DELETE FROM character_mythic_instance_deaths WHERE instance_id = ? AND map_id = ?", instanceId, mapId)
    DBExecute("DELETE FROM character_mythic_instance_progress WHERE instance_id = ? AND map_id = ?", instanceId, mapId)
    PersistEnemyForcesProgress(instanceId, mapId)

    ScheduleMythicTimeout(player, instanceId, tier)

    local q = DBQuery("SELECT total_points FROM character_mythic_rating WHERE guid = ?", guid)
    local cur = q and q:GetUInt32(0) or 0
    MythicSendPlayerMessage(player, string.format("%sTier %d Keystone|r inserted.\nAffixes: %s\nCurrent Rating: %s%d|r",
      cfg.color, tier, table.concat(names, ", "), GetRatingColor(cur), cur))
    if not IsAffixSystemEnabled() then
      MythicSendPlayerMessage(player, "|cffff8800[Mythic]|r Affix system is currently disabled by GM/config.")
    end

    creature:SendUnitSay((function(r)
      if r >= 1800 then return "I can think of none better for this trial. Show them no mercy, Mythic Champion!"
      elseif r >= 1000 then return "You will surely triumph in this challenge!"
      elseif r >= 500  then return "You may yet prevail in the trials ahead."
      else return "Good luck... you'll need it." end
    end)(cur), 0)

    player:RemoveItem(keyId, 1)

    local okApply, errApply = pcall(ApplyAuraToInstancePlayers, instanceId, mapId, affixes)
    if not okApply then
      MythicLog("Initial affix application failed: " .. tostring(errApply))
    end
    if IsAffixSystemEnabled() and #affixes > 0 then
      StartAuraLoop(player, instanceId, mapId, affixes)
    end
    if mapId == HALLS_OF_REFLECTION_MAP_ID then
      StartHoRCompletionFailsafe(instanceId, mapId)
    end
    if mapId == CULLING_OF_STRATHOLME_MAP_ID then
      StartCoSCompletionFailsafe(instanceId, mapId)
    end

    local affixStr = SerializeAffixes(affixes)
    local created = os.time()
    for _, member in pairs(map:GetPlayers() or {}) do
      if member and member:IsInWorld() then
        PersistInstanceStateForPlayer(member:GetGUIDLow(), instanceId, mapId, tier, affixStr, created)
      end
    end

    -- AIO: push MythicPlus run start to all instance players
    if AIO then
      local aioAffixes = MythicPlusGetAffixNamesForAIO(instanceId)
      local totalSec = ComputeTierMinutes(mapId, tier) * 60
      local currentKills, forceReq = MythicGetEnemyForcesProgress(instanceId, mapId)
      local forcePct = MythicGetEnemyForcesPercent()
      for _, member in pairs(map:GetPlayers() or {}) do
        if member and member:IsInWorld() then
          AIO.Handle(member, "MythicPlus", "Show")
          AIO.Handle(member, "MythicPlus", "StartRun", {
            tier = tier,
            timer = totalSec,
            timerMax = totalSec,
            forcePct = forcePct,
            affixes = aioAffixes,
            kills = { currentKills, forceReq },
            deaths = 0,
          })
        end
      end
    end

    player:GossipComplete()
  end
end

local function IsPedestalNameMatch(name)
  if type(name) ~= "string" or name == "" then return false end
  return PEDESTAL_FALLBACK_NAMES[name:lower()] == true
end

local function EnsurePedestalGossipRegistered(entry)
  if not entry or entry <= 0 then return false end
  if MYTHIC_REGISTERED_PEDESTAL_ENTRIES[entry] then return true end
  RegisterCreatureGossipEvent(entry, 1, Pedestal_OnGossipHello)
  RegisterCreatureGossipEvent(entry, 2, Pedestal_OnGossipSelect)
  MYTHIC_REGISTERED_PEDESTAL_ENTRIES[entry] = true
  return true
end

local function TryAutoRegisterPedestalForPlayer(player)
  if not player or not player.GetCreaturesInRange then return end
  local nearby = player:GetCreaturesInRange(PEDESTAL_DETECTION_RADIUS) or {}
  for _, creature in pairs(nearby) do
    if creature and IsPedestalNameMatch(creature:GetName()) then
      EnsurePedestalGossipRegistered(creature:GetEntry())
    end
  end
end

EnsurePedestalGossipRegistered(PEDESTAL_NPC_ENTRY)

--==========================================================
-- Player Death Tracking
--==========================================================
local function LoadPersistedDeaths(instanceId, mapId)
  if MYTHIC_DEATHS[instanceId] then return end
  MYTHIC_DEATHS[instanceId] = {}
  local rows = DBQuery("SELECT guid, death_count FROM character_mythic_instance_deaths WHERE instance_id=? AND map_id=?", instanceId, mapId)
  if rows then
    repeat
      local guid = rows:GetUInt32(0)
      local count = rows:GetUInt32(1)
      MYTHIC_DEATHS[instanceId][guid] = count
    until not rows:NextRow()
  end
end

local function PersistDeathCount(instanceId, mapId, guid, count)
  if not instanceId or instanceId <= 0 or not mapId or mapId <= 0 or not guid or guid <= 0 then
    return
  end
  MYTHIC_PENDING_DEATH_WRITES[instanceId] = MYTHIC_PENDING_DEATH_WRITES[instanceId] or { mapId = mapId, rows = {} }
  local bucket = MYTHIC_PENDING_DEATH_WRITES[instanceId]
  bucket.mapId = mapId
  bucket.rows[guid] = count
end

FlushPendingDeathWrites = function(instanceId)
  local function FlushBucket(id, bucket)
    if not bucket or not bucket.rows then return end
    local mapId = bucket.mapId or 0
    for guid, count in pairs(bucket.rows) do
      DBExecute([[
        INSERT INTO character_mythic_instance_deaths (instance_id, map_id, guid, death_count, updated_at)
        VALUES (?, ?, ?, ?, NOW())
        ON DUPLICATE KEY UPDATE death_count=?, updated_at=NOW()
      ]], id, mapId, guid, count, count)
    end
  end

  if instanceId then
    local bucket = MYTHIC_PENDING_DEATH_WRITES[instanceId]
    FlushBucket(instanceId, bucket)
    MYTHIC_PENDING_DEATH_WRITES[instanceId] = nil
    return
  end

  for id, bucket in pairs(MYTHIC_PENDING_DEATH_WRITES) do
    FlushBucket(id, bucket)
    MYTHIC_PENDING_DEATH_WRITES[id] = nil
  end
end

local function ClearAffixesFromActiveInstances()
  local seen = {}
  local players = GetPlayersInWorld and GetPlayersInWorld() or {}
  for _, pl in pairs(players) do
    if pl and pl:IsInWorld() then
      local map = pl:GetMap()
      if map then
        local instanceId = map:GetInstanceId()
        if instanceId and MYTHIC_FLAG_TABLE[instanceId] and not seen[instanceId] then
          seen[instanceId] = map
        end
      end
    end
  end

  for instanceId, map in pairs(seen) do
    RemoveAffixAurasFromPlayers(instanceId, map)
    RemoveAffixAurasFromAllCreatures(instanceId, map)
  end
end

local function ReapplyAffixesToActiveInstances()
  local seen = {}
  local players = GetPlayersInWorld and GetPlayersInWorld() or {}
  for _, pl in pairs(players) do
    if pl and pl:IsInWorld() then
      local map = pl:GetMap()
      if map then
        local instanceId = map:GetInstanceId()
        if instanceId and MYTHIC_FLAG_TABLE[instanceId] and not seen[instanceId] then
          seen[instanceId] = { map = map, player = pl }
        end
      end
    end
  end

  for instanceId, data in pairs(seen) do
    local tier = MYTHIC_TIER_TABLE[instanceId] or 1
    local affixes = MYTHIC_AFFIXES_TABLE[instanceId]
    if not affixes or #affixes == 0 then
      affixes = GetAffixSet(tier)
      MYTHIC_AFFIXES_TABLE[instanceId] = affixes
    end
    if affixes and #affixes > 0 then
      ApplyAuraToInstancePlayers(instanceId, data.map:GetMapId(), affixes)
      if not MYTHIC_LOOP_HANDLERS[instanceId] then
        StartAuraLoop(data.player, instanceId, data.map:GetMapId(), affixes)
      end
    end
  end
end

local function GetInstanceAnchorState(instanceId, mapId)
  local row = DBQuery(
    "SELECT tier, UNIX_TIMESTAMP(created_at), affix_spells FROM character_mythic_instance_state WHERE instance_id=? AND map_id=? AND guid<>? ORDER BY created_at ASC LIMIT 1",
    instanceId, mapId, KILL_LOCK_MARKER_GUID)
  if not row then
    return nil
  end
  return {
    tier = row:GetUInt32(0),
    created = row:GetUInt32(1),
    affixStr = row:GetString(2) or "",
  }
end

local function PushMythicAIOState(player, instanceId, mapId, tier, createdAt)
  if not player or not player:IsInWorld() or not AIO then
    return false
  end
  if not MYTHIC_FLAG_TABLE[instanceId] or MYTHIC_MODE_ENDED[instanceId] then
    return false
  end

  local elapsed = 0
  if createdAt and createdAt > 0 then
    elapsed = math.max(0, os.time() - createdAt)
  end
  local totalSec = ComputeTierMinutes(mapId, tier) * 60
  local remaining = math.max(0, totalSec - elapsed)
  local kills, forceReq = MythicGetEnemyForcesProgress(instanceId, mapId)
  local forcePct = MythicGetEnemyForcesPercent()
  local deaths = (MYTHIC_DEATHS[instanceId] and MYTHIC_DEATHS[instanceId][player:GetGUIDLow()]) or 0
  local payload = {
    tier = tier,
    timer = remaining,
    timerMax = totalSec,
    forcePct = forcePct,
    affixes = MythicPlusGetAffixNamesForAIO(instanceId),
    kills = { kills, forceReq },
    deaths = deaths,
    running = true,
  }

  local ok, err = pcall(function()
    AIO.Handle(player, "MythicPlus", "Show")
    AIO.Handle(player, "MythicPlus", "UpdateAll", payload)
  end)
  if not ok then
    MythicLog("AIO UpdateAll sync failed: " .. tostring(err))
    return false
  end

  pcall(function() AIO.Handle(player, "MythicPlus", "SetKills", kills, forceReq) end)
  pcall(function() AIO.Handle(player, "MythicPlus", "SetDeaths", deaths) end)
  return true
end

local function PushMythicAIOStateToInstance(instanceId, mapId, tier, createdAt)
  if not AIO then
    return 0
  end
  local sent = 0
  for _, pl in pairs(GetPlayersInInstance(instanceId, mapId)) do
    if PushMythicAIOState(pl, instanceId, mapId, tier, createdAt) then
      sent = sent + 1
    end
  end
  return sent
end

local function ScheduleMythicAIOResync(instanceId, mapId, createdAt)
  CreateLuaEvent(function()
    if not MYTHIC_FLAG_TABLE[instanceId] or MYTHIC_MODE_ENDED[instanceId] then
      return
    end
    local liveTier = MYTHIC_TIER_TABLE[instanceId] or 1
    PushMythicAIOStateToInstance(instanceId, mapId, liveTier, createdAt)
  end, 1500, 3)
end

local function RestoreActiveMythicInstancesAfterReload()
  local players = GetPlayersInWorld and GetPlayersInWorld() or {}
  local instances = {}
  local now = os.time()

  for _, pl in pairs(players) do
    if pl and pl:IsInWorld() then
      local map = pl:GetMap()
      if map and map:IsDungeon() and map:GetDifficulty() > 0 then
        local instanceId, mapId = map:GetInstanceId(), map:GetMapId()
        if instanceId and instanceId > 0 then
          local bucket = instances[instanceId]
          if not bucket then
            local state = GetInstanceAnchorState(instanceId, mapId)
            if state and TIER_CONFIG[state.tier] then
              bucket = {
                instanceId = instanceId,
                mapId = mapId,
                map = map,
                tier = state.tier,
                created = state.created,
                affixStr = state.affixStr,
                players = {},
              }
              instances[instanceId] = bucket
            end
          end
          if bucket then
            bucket.players[#bucket.players + 1] = pl
          end
        end
      end
    end
  end

  local restored = 0
  for instanceId, data in pairs(instances) do
    local map, mapId, tier = data.map, data.mapId, data.tier
    if map and map:GetInstanceId() == instanceId and map:GetMapId() == mapId then
      local elapsed = now - (data.created or now)
      if elapsed > INSTANCE_STATE_TIMEOUT then
        DBExecute("DELETE FROM character_mythic_instance_state WHERE instance_id = ? AND map_id = ?", instanceId, mapId)
        DBExecute("DELETE FROM character_mythic_instance_deaths WHERE instance_id = ? AND map_id = ?", instanceId, mapId)
        DBExecute("DELETE FROM character_mythic_instance_progress WHERE instance_id = ? AND map_id = ?", instanceId, mapId)
      else
        local affixes = (data.affixStr ~= "") and ParseAffixes(data.affixStr) or GetAffixSet(tier)
        if #affixes == 0 and IsAffixSystemEnabled() then
          affixes = GetAffixSet(tier)
        end

        MYTHIC_FLAG_TABLE[instanceId]          = true
        MYTHIC_AFFIXES_TABLE[instanceId]       = affixes
        MYTHIC_REWARD_CHANCE_TABLE[instanceId] = (tier == 1 and 1.5) or (tier == 2 and 2.0) or 5.0
        MYTHIC_TIER_TABLE[instanceId]          = tier
        MYTHIC_COMPLETION_STATE[instanceId]    = "active"
        MYTHIC_MODE_ENDED[instanceId]          = nil
        MYTHIC_TIMER_EXPIRED[instanceId]       = nil
        if MYTHIC_NON_BOSS_KILLS[instanceId] == nil then
          MYTHIC_NON_BOSS_KILLS[instanceId] = 0
        end
        MYTHIC_FORCES_WARN_TS[instanceId] = nil
        if (_G.__MYTHIC_ENEMY_FORCES_TRACKED_KEYS__ or {})[instanceId] == nil then
          (_G.__MYTHIC_ENEMY_FORCES_TRACKED_KEYS__ or {})[instanceId] = {}
        end
        if (_G.__MYTHIC_ENEMY_FORCES_KILLED_KEYS__ or {})[instanceId] == nil then
          (_G.__MYTHIC_ENEMY_FORCES_KILLED_KEYS__ or {})[instanceId] = {}
        end
        if (_G.__MYTHIC_ENEMY_FORCES_TRACKED_TOTAL__ or {})[instanceId] == nil then
          (_G.__MYTHIC_ENEMY_FORCES_TRACKED_TOTAL__ or {})[instanceId] = 0
        end
        if (_G.__MYTHIC_ENEMY_FORCES_REQ_STABLE__ or {})[instanceId] == nil then
          (_G.__MYTHIC_ENEMY_FORCES_REQ_STABLE__ or {})[instanceId] = 0
        end
        if (_G.__MYTHIC_ENEMY_FORCES_ELIGIBLE_KEYS__ or {})[instanceId] == nil then
          (_G.__MYTHIC_ENEMY_FORCES_ELIGIBLE_KEYS__ or {})[instanceId] = {}
        end
        LoadPersistedDeaths(instanceId, mapId)
        LoadPersistedEnemyForcesProgress(instanceId, mapId)

        local totalMin = ComputeTierMinutes(mapId, tier)
        local remaining = math.max(0, totalMin * 60 - elapsed)
        local anchorPlayer = data.players[1]
        if remaining == 0 then
          MYTHIC_TIMER_EXPIRED[instanceId]   = true
          MYTHIC_COMPLETION_STATE[instanceId] = "failed"
          SetKillLock(instanceId, mapId)

          for _, pl in pairs(GetPlayersInInstance(instanceId, mapId)) do
            if pl and pl:IsInWorld() then
              local g = pl:GetGUIDLow()
              local deaths = (MYTHIC_DEATHS[instanceId] and MYTHIC_DEATHS[instanceId][g]) or 0
              PenalizeMythicFailure(pl, tier, deaths)
              MythicSendPlayerMessage(pl, "|cffff0000[Mythic]|r Timer expired while scripts were reloading.")
              MythicClearTierTimerAura(pl, tier, true)
            end
          end
          RemoveAffixAurasFromPlayers(instanceId, map)
          RemoveAffixAurasFromAllCreatures(instanceId, map)
          CleanupMythicInstance(instanceId)
        else
          ApplyAuraToInstancePlayers(instanceId, mapId, affixes)
          if IsAffixSystemEnabled() and #affixes > 0 and anchorPlayer and not MYTHIC_LOOP_HANDLERS[instanceId] then
            StartAuraLoop(anchorPlayer, instanceId, mapId, affixes)
          end
          if mapId == HALLS_OF_REFLECTION_MAP_ID then
            StartHoRCompletionFailsafe(instanceId, mapId)
          end
          if mapId == CULLING_OF_STRATHOLME_MAP_ID then
            StartCoSCompletionFailsafe(instanceId, mapId)
          end
          if anchorPlayer then
            ScheduleMythicTimeout(anchorPlayer, instanceId, tier, remaining)
          end
          PushMythicAIOStateToInstance(instanceId, mapId, tier, data.created)
          ScheduleMythicAIOResync(instanceId, mapId, data.created)
          for _, pl in pairs(data.players) do
            MythicSendPlayerMessage(pl, "|cff66ccff[Mythic]|r Active Mythic+ state restored after script reload.")
          end
          restored = restored + 1
        end
      end
    end
  end

  if restored > 0 then
    MythicLog(string.format("Reload restore completed: %d active mythic instance(s) restored", restored))
  end
end

do
  local registerPlayerEvent = _G.RegisterPlayerEvent
  if type(registerPlayerEvent) ~= "function" then
    MythicLog("RegisterPlayerEvent is unavailable; skipped on-killed-by-creature handler (event 8).")
  elseif _G.__MYTHIC_PLAYER_EVENT8_REGISTERED__ then
    -- Already registered in this Lua state.
  else
    local ok, err = pcall(registerPlayerEvent, 8, function(_, killer, victim)
  if not victim or not victim:IsPlayer() then return end
  local map = victim:GetMap(); if not map or map:GetDifficulty() == 0 then return end
  local instanceId = map:GetInstanceId(); if not MYTHIC_FLAG_TABLE[instanceId] then return end
  local guid = victim:GetGUIDLow()
  MYTHIC_DEATHS[instanceId] = MYTHIC_DEATHS[instanceId] or {}
  MYTHIC_DEATHS[instanceId][guid] = (MYTHIC_DEATHS[instanceId][guid] or 0) + 1
  PersistDeathCount(instanceId, map:GetMapId(), guid, MYTHIC_DEATHS[instanceId][guid])

  -- AIO: push death count to the dead player
  if AIO then
    AIO.Handle(victim, "MythicPlus", "SetDeaths", MYTHIC_DEATHS[instanceId][guid])
  end
    end)
    if not ok then
      MythicLog("RegisterPlayerEvent(8) failed for on-killed-by-creature handler: " .. tostring(err))
    else
      _G.__MYTHIC_PLAYER_EVENT8_REGISTERED__ = true
    end
  end
end

DEATH_FLUSH_EVENT_ID = CreateLuaEvent(function()
  FlushPendingDeathWrites(nil)
end, DEATH_FLUSH_INTERVAL_MS, 0)
_G[GLOBAL_DEATH_FLUSH_EVENT_KEY] = DEATH_FLUSH_EVENT_ID

KILL_LOCK_SWEEP_EVENT_ID = CreateLuaEvent(function()
  local now = os.time()
  for instanceId, locked in pairs(MYTHIC_KILL_LOCK) do
    if not locked then
      MYTHIC_KILL_LOCK_META[instanceId] = nil
    else
      local meta = MYTHIC_KILL_LOCK_META[instanceId]
      if meta and meta.setAt and (now - meta.setAt) > KILL_LOCK_TTL_SECONDS then
        local mapId = meta.mapId or 0
        if not MYTHIC_FLAG_TABLE[instanceId] and #GetPlayersInInstance(instanceId, mapId) == 0 then
          ClearKillLock(instanceId)
        end
      end
    end
  end
end, 15 * 60 * 1000, 0)
_G[GLOBAL_KILL_LOCK_SWEEP_EVENT_KEY] = KILL_LOCK_SWEEP_EVENT_ID

RESTORE_ON_LOAD_EVENT_ID = CreateLuaEvent(function()
  RestoreActiveMythicInstancesAfterReload()
  _G[GLOBAL_RESTORE_ON_LOAD_EVENT_KEY] = nil
  RESTORE_ON_LOAD_EVENT_ID = nil
end, 2000, 1)
_G[GLOBAL_RESTORE_ON_LOAD_EVENT_KEY] = RESTORE_ON_LOAD_EVENT_ID

local function MythicCreatureMatchesName(creature, names)
  if not names then return false end
  local compareName = creature:GetName() and creature:GetName():lower() or ""
  if compareName == "" then return false end
  local list = (type(names) == "table") and names or { names }
  for _, name in ipairs(list) do
    if type(name) == "string" and compareName == name:lower() then
      return true
    end
  end
  return false
end

local function IsFinalBossCreature(creature)
  if not creature or creature:GetObjectType() ~= "Creature" then return false end
  local map = creature:GetMap(); if not map then return false end
  local data = MYTHIC_FINAL_BOSSES[map:GetMapId()]
  if not data then return false end

  local finalEntry = data.final
  if finalEntry then
    if type(finalEntry) == "table" then
      for _, bossId in ipairs(finalEntry) do
        if creature:GetEntry() == bossId then
          return true
        end
      end
    elseif creature:GetEntry() == finalEntry then
      return true
    end
  end

  if MythicCreatureMatchesName(creature, data.finalNames or data.final_names) then
    return true
  end

  return false
end

--==========================================================
-- Kill-Lock (prevent post-kill key insert)
--==========================================================
local function ProcessCreatureDeath(creature, killer)
  if not creature or creature:GetObjectType() ~= "Creature" then return end
  local map = creature:GetMap(); if not map or not map:IsDungeon() or map:GetDifficulty() < 1 then return end
  local instanceId, mapId = map:GetInstanceId(), map:GetMapId()

  -- Only react to maps that have Mythic+ metadata configured.
  if not MYTHIC_FINAL_BOSSES[mapId] then return end
  
  local completionState = MYTHIC_COMPLETION_STATE[instanceId]
  if completionState == "completed" or completionState == "failed" then return end

  if MYTHIC_FLAG_TABLE[instanceId] or MYTHIC_MODE_ENDED[instanceId] or IsKillLockActive(instanceId, mapId) then return end

  if IsFinalBossCreature(creature) then
    return
  end

  local entry = creature:GetEntry()
  local faction = creature:GetFaction()
  local forceVioletHoldAffixEntry = (mapId == VIOLET_HOLD_MAP_ID and VIOLET_HOLD_FORCE_AFFIX_ENTRIES[entry] == true)
  if not MYTHIC_HOSTILE_FACTIONS[faction] and not forceVioletHoldAffixEntry then
    return
  end

  local hasValidPlayer = false
  for _, p in pairs(map:GetPlayers() or {}) do
    if p and p:GetLevel() >= 80 then
      hasValidPlayer = true
      break
    end
  end
  if not hasValidPlayer then return end
  
  SetKillLock(instanceId, mapId)
  local killerInfo = ""
  if killer and killer:IsPlayer() then
    killerInfo = string.format(" (killed by %s)", MythicColorizePlayerName(killer))
  end
  local msg = string.format("|cffff0000[Mythic]|r Mythic+ is now locked because hostile NPC '%s' (ID: %d) was slain%s. Reset the dungeon to enable keystone use.", 
    creature:GetName() or "Unknown", creature:GetEntry(), killerInfo)
  for _, p in pairs(map:GetPlayers() or {}) do 
    if p then MythicSendPlayerMessage(p, msg) end 
  end
end

local function TryFinalizeRunOnDeath(creature)
  if not creature or creature:GetObjectType() ~= "Creature" then return end
  local map = creature:GetMap(); if not map then return end
  local instanceId = map:GetInstanceId()
  if not MYTHIC_FLAG_TABLE[instanceId] or MYTHIC_MODE_ENDED[instanceId] then return end
  if not IsFinalBossCreature(creature) then return end
  local mapId = map:GetMapId()
  if not MythicEnemyForcesCanComplete(map, instanceId, mapId) then return end

  local expired = MYTHIC_TIMER_EXPIRED[instanceId]
  local tier    = MYTHIC_TIER_TABLE[instanceId] or 1

  local chestX, chestY, chestZ, chestO
  if not expired then
    chestX, chestY, chestZ, chestO = creature:GetX(), creature:GetY(), creature:GetZ(), creature:GetO()
    chestX = chestX - math.cos(chestO) * 2
    chestY = chestY - math.sin(chestO) * 2
  end

  FinalizeMythicRun(map, instanceId, tier, expired, chestX, chestY, chestZ, chestO)
end

do
  local registerPlayerEvent = _G.RegisterPlayerEvent
  if type(registerPlayerEvent) ~= "function" then
    MythicLog("RegisterPlayerEvent is unavailable; skipped on-kill-creature handler (event 7).")
  elseif _G.__MYTHIC_PLAYER_EVENT7_REGISTERED__ then
    -- Already registered in this Lua state.
  else
    local ok, err = pcall(registerPlayerEvent, 7, function(_, killer, victim)
  if killer and killer:IsPlayer() then
    ProcessCreatureDeath(victim, killer)

    if victim and victim:GetObjectType() == "Creature" then
      local map = victim:GetMap()
      if map and map:IsDungeon() and map:GetDifficulty() > 0 then
        local instanceId = map:GetInstanceId()
        if MYTHIC_FLAG_TABLE[instanceId] and not MYTHIC_MODE_ENDED[instanceId] then
          local mapId = map:GetMapId()
          local staticRequired = tonumber(((_G.__MYTHIC_ENEMY_FORCES_REQUIRED__ or {})[mapId] or 0)) or 0
          local key = GetCreatureDedupeKey(victim)
          local shouldCount = false
          local trackedBucket = (_G.__MYTHIC_ENEMY_FORCES_TRACKED_KEYS__ or {})[instanceId]
          local eligibleBucket = (_G.__MYTHIC_ENEMY_FORCES_ELIGIBLE_KEYS__ or {})[instanceId]
          local entry = victim:GetEntry()
          local faction = victim:GetFaction()
          local ignoreForcesEntry = (IGNORE_BUFF_ENTRIES[entry] == true) or (mapId == FORGE_OF_SOULS_MAP_ID and entry == 36967)
          local baseHostileMob =
            (not IsFinalBossCreature(victim))
            and (not AFFIX_PROTECTED_BOSS_ENTRIES[entry])
            and MYTHIC_HOSTILE_FACTIONS[faction]
            and (not FRIENDLY_FACTIONS[faction])
            and (not ignoreForcesEntry)

          if (not ignoreForcesEntry) and key and ((trackedBucket and trackedBucket[key]) or (eligibleBucket and eligibleBucket[key])) then
            shouldCount = true
          elseif baseHostileMob then
            if staticRequired > 0 then
              shouldCount = not IsLikelyScriptHelperCreature(victim)
            else
              shouldCount = (IsUnitInCombat(victim) or IsCreatureAttackable(victim)) and (not IsLikelyScriptHelperCreature(victim))
            end
          end

          if shouldCount and key then
            if staticRequired <= 0 then
              local trackedByInstance = _G.__MYTHIC_ENEMY_FORCES_TRACKED_KEYS__ or {}
              local trackedBucket = trackedByInstance[instanceId]
              if not trackedBucket then
                trackedBucket = {}
                trackedByInstance[instanceId] = trackedBucket
                _G.__MYTHIC_ENEMY_FORCES_TRACKED_KEYS__ = trackedByInstance
              end
              local eligibleByInstance = _G.__MYTHIC_ENEMY_FORCES_ELIGIBLE_KEYS__ or {}
              local eligibleBucket = eligibleByInstance[instanceId]
              if not eligibleBucket then
                eligibleBucket = {}
                eligibleByInstance[instanceId] = eligibleBucket
                _G.__MYTHIC_ENEMY_FORCES_ELIGIBLE_KEYS__ = eligibleByInstance
              end
              eligibleBucket[key] = true
              if not trackedBucket[key] then
                trackedBucket[key] = true
                local totals = _G.__MYTHIC_ENEMY_FORCES_TRACKED_TOTAL__ or {}
                totals[instanceId] = math.max(0, math.floor(tonumber(totals[instanceId] or 0) or 0)) + 1
                _G.__MYTHIC_ENEMY_FORCES_TRACKED_TOTAL__ = totals
              end
            end

            local killedByInstance = _G.__MYTHIC_ENEMY_FORCES_KILLED_KEYS__ or {}
            local killedBucket = killedByInstance[instanceId]
            if not killedBucket then
              killedBucket = {}
              killedByInstance[instanceId] = killedBucket
              _G.__MYTHIC_ENEMY_FORCES_KILLED_KEYS__ = killedByInstance
            end

            if not killedBucket[key] then
              killedBucket[key] = true
              local currentKills = math.max(0, math.floor(tonumber(MYTHIC_NON_BOSS_KILLS[instanceId] or 0) or 0)) + 1
              MYTHIC_NON_BOSS_KILLS[instanceId] = currentKills
              PersistEnemyForcesProgress(instanceId, mapId)

              -- AIO: push kill count update to all instance players
              if AIO then
                local syncedKills, reqKills = MythicGetEnemyForcesProgress(instanceId, mapId)
                for _, p in pairs(map:GetPlayers() or {}) do
                  if p and p:IsInWorld() then
                    AIO.Handle(p, "MythicPlus", "SetKills", syncedKills, reqKills)
                  end
                end
              end

            end
          end
        end
      end
    end

    TryFinalizeRunOnDeath(victim)
  end
    end)
    if not ok then
      MythicLog("RegisterPlayerEvent(7) failed for on-kill-creature handler: " .. tostring(err))
    else
      _G.__MYTHIC_PLAYER_EVENT7_REGISTERED__ = true
    end
  end
end

--==========================================================
-- Resume Logic (on login/relog inside instance)
--==========================================================
do
  local registerPlayerEvent = _G.RegisterPlayerEvent
  if type(registerPlayerEvent) ~= "function" then
    MythicLog("RegisterPlayerEvent is unavailable; skipped on-map-change resume handler (event 28).")
  elseif _G.__MYTHIC_PLAYER_EVENT28_REGISTERED__ then
    -- Already registered in this Lua state.
  else
    local ok, err = pcall(registerPlayerEvent, 28, function(_, player)
  local map = player:GetMap(); if not map then return end
  TryAutoRegisterPedestalForPlayer(player)
  MythicEnsureTimerAddonAIOHandlers()
  MythicPushCurrentAffixesToPlayer(player)
  if not map:IsDungeon() or map:GetDifficulty() == 0 then
    return
  end
  local instanceId, mapId, guid = map:GetInstanceId(), map:GetMapId(), player:GetGUIDLow()
  if MYTHIC_COMPLETION_STATE[instanceId] == "failed" or MYTHIC_COMPLETION_STATE[instanceId] == "completed" then return end

  local selectStateQuery = "SELECT tier, UNIX_TIMESTAMP(created_at), affix_spells FROM character_mythic_instance_state WHERE guid = ? AND instance_id = ? AND map_id = ?"
  local res = DBQuery(selectStateQuery, guid, instanceId, mapId)
  if not res and MYTHIC_FLAG_TABLE[instanceId] and TIER_CONFIG[MYTHIC_TIER_TABLE[instanceId] or 0] then
    local liveTier = MYTHIC_TIER_TABLE[instanceId]
    local anchor = DBQuery(
      "SELECT UNIX_TIMESTAMP(created_at), affix_spells FROM character_mythic_instance_state WHERE instance_id=? AND map_id=? AND guid<>? ORDER BY created_at ASC LIMIT 1",
      instanceId, mapId, KILL_LOCK_MARKER_GUID)
    local createdAt = os.time()
    local affixStr = ""
    if anchor then
      createdAt = anchor:GetUInt32(0)
      affixStr = anchor:GetString(1) or ""
    else
      affixStr = SerializeAffixes(MYTHIC_AFFIXES_TABLE[instanceId] or GetAffixSet(liveTier))
    end
    PersistInstanceStateForPlayer(guid, instanceId, mapId, liveTier, affixStr, createdAt)
    res = DBQuery(selectStateQuery, guid, instanceId, mapId)
  end
  if not res then return end

  local tier, created = res:GetUInt32(0), res:GetUInt32(1)
  if not TIER_CONFIG[tier] then
    DBExecute("DELETE FROM character_mythic_instance_state WHERE guid = ? AND instance_id = ? AND map_id = ?", guid, instanceId, mapId)
    return
  end
  if os.time() - created > INSTANCE_STATE_TIMEOUT then
    MYTHIC_MODE_ENDED[instanceId] = nil
    DBExecute("DELETE FROM character_mythic_instance_state WHERE guid = ? AND instance_id = ? AND map_id = ?", guid, instanceId, mapId)
    MYTHIC_PENDING_DEATH_WRITES[instanceId] = nil
    DBExecute("DELETE FROM character_mythic_instance_deaths WHERE instance_id = ? AND map_id = ?", instanceId, mapId)
    DBExecute("DELETE FROM character_mythic_instance_progress WHERE instance_id = ? AND map_id = ?", instanceId, mapId)
    return
  end

  local saved_affixes = res:GetString(2) or ""
  local affixes = (saved_affixes ~= "") and ParseAffixes(saved_affixes) or GetAffixSet(tier)
  if #affixes == 0 and IsAffixSystemEnabled() then
    affixes = GetAffixSet(tier)
  end

  MYTHIC_FLAG_TABLE[instanceId]          = true
  MYTHIC_AFFIXES_TABLE[instanceId]       = affixes
  MYTHIC_REWARD_CHANCE_TABLE[instanceId] = (tier == 1 and 1.5) or (tier == 2 and 2.0) or 5.0
  MYTHIC_TIER_TABLE[instanceId]          = tier
  MYTHIC_COMPLETION_STATE[instanceId]    = "active"
  if MYTHIC_NON_BOSS_KILLS[instanceId] == nil then
    MYTHIC_NON_BOSS_KILLS[instanceId] = 0
  end
  MYTHIC_FORCES_WARN_TS[instanceId] = nil
  if (_G.__MYTHIC_ENEMY_FORCES_TRACKED_KEYS__ or {})[instanceId] == nil then
    (_G.__MYTHIC_ENEMY_FORCES_TRACKED_KEYS__ or {})[instanceId] = {}
  end
  if (_G.__MYTHIC_ENEMY_FORCES_KILLED_KEYS__ or {})[instanceId] == nil then
    (_G.__MYTHIC_ENEMY_FORCES_KILLED_KEYS__ or {})[instanceId] = {}
  end
  if (_G.__MYTHIC_ENEMY_FORCES_TRACKED_TOTAL__ or {})[instanceId] == nil then
    (_G.__MYTHIC_ENEMY_FORCES_TRACKED_TOTAL__ or {})[instanceId] = 0
  end
  if (_G.__MYTHIC_ENEMY_FORCES_REQ_STABLE__ or {})[instanceId] == nil then
    (_G.__MYTHIC_ENEMY_FORCES_REQ_STABLE__ or {})[instanceId] = 0
  end
  if (_G.__MYTHIC_ENEMY_FORCES_ELIGIBLE_KEYS__ or {})[instanceId] == nil then
    (_G.__MYTHIC_ENEMY_FORCES_ELIGIBLE_KEYS__ or {})[instanceId] = {}
  end
  LoadPersistedDeaths(instanceId, mapId)
  LoadPersistedEnemyForcesProgress(instanceId, mapId)

  MythicSendPlayerMessage(player, "|cffffff00[Mythic]|r Resuming active Mythic+ affixes.")
  ApplyAuraToInstancePlayers(instanceId, mapId, affixes)
  if IsAffixSystemEnabled() and #affixes > 0 and not MYTHIC_LOOP_HANDLERS[instanceId] then
    StartAuraLoop(player, instanceId, mapId, affixes)
  end
  if mapId == HALLS_OF_REFLECTION_MAP_ID and not MYTHIC_HOR_FAILSAFE_EVENTS[instanceId] then
    StartHoRCompletionFailsafe(instanceId, mapId)
  end
  if mapId == CULLING_OF_STRATHOLME_MAP_ID and not MYTHIC_HOR_FAILSAFE_EVENTS[instanceId] then
    StartCoSCompletionFailsafe(instanceId, mapId)
  end

  local totalMin  = ComputeTierMinutes(mapId, tier)
  local elapsed   = os.time() - created
  local remaining = math.max(0, totalMin * 60 - elapsed)

  if remaining == 0 then
    MYTHIC_TIMER_EXPIRED[instanceId]   = true
    MYTHIC_COMPLETION_STATE[instanceId] = "failed"
    SetKillLock(instanceId, mapId)
    MythicSendPlayerMessage(player, "|cffff0000[Mythic]|r Time limit exceeded while you were away.")
    MythicClearTierTimerAura(player, tier, true)

    local mapNow = player:GetMap()
    if mapNow then
      for _, pl in pairs(mapNow:GetPlayers() or {}) do
        local g = pl:GetGUIDLow()
        local deaths = (MYTHIC_DEATHS[instanceId] and MYTHIC_DEATHS[instanceId][g]) or 0
        PenalizeMythicFailure(pl, tier, deaths)
      end
      RemoveAffixAurasFromPlayers(instanceId, mapNow)
      RemoveAffixAurasFromAllCreatures(instanceId, mapNow)
    end

    -- AIO: notify client that the run expired while away
    if AIO then
      local playerDeaths = (MYTHIC_DEATHS[instanceId] and MYTHIC_DEATHS[instanceId][player:GetGUIDLow()]) or 0
      local qRating = DBQuery("SELECT total_points FROM character_mythic_rating WHERE guid = ?", player:GetGUIDLow())
      local rating = qRating and qRating:GetUInt32(0) or nil
      AIO.Handle(player, "MythicPlus", "StopRun", {
        completed = false,
        expired = true,
        finalized = true,
        deaths = playerDeaths,
        rating = rating,
      })
    end

    CleanupMythicInstance(instanceId)
    return
  end

  MYTHIC_TIMER_EXPIRED[instanceId] = nil
  MYTHIC_MODE_ENDED[instanceId]    = nil
  ScheduleMythicTimeout(player, instanceId, tier, remaining)

  PushMythicAIOState(player, instanceId, mapId, tier, created)
  ScheduleMythicAIOResync(instanceId, mapId, created)
    end)
    if not ok then
      MythicLog("RegisterPlayerEvent(28) failed for on-map-change resume handler: " .. tostring(err))
    else
      _G.__MYTHIC_PLAYER_EVENT28_REGISTERED__ = true
    end
  end
end

--==========================================================
-- Login Blurb (affixes + ETA)
--==========================================================
do
  local registerPlayerEvent = _G.RegisterPlayerEvent
  if type(registerPlayerEvent) ~= "function" then
    MythicLog("RegisterPlayerEvent is unavailable; skipped on-login affix blurb handler (event 3).")
  elseif _G.__MYTHIC_PLAYER_EVENT3_REGISTERED__ then
    -- Already registered in this Lua state.
  else
    local ok, err = pcall(registerPlayerEvent, 3, function(_, player)
  MythicEnsureTimerAddonAIOHandlers()
  MythicClearTimerAddonAvailable(player)
  TryAutoRegisterPedestalForPlayer(player)
  local parts = {}
  for tier = 1, 3 do
    local aff = WEEKLY_AFFIXES[tier]
    if aff and aff.name then
      table.insert(parts, (AFFIX_COLOR_MAP[aff.name] or "|cffffffff") .. aff.name .. "|r")
    end
  end
  if #parts == 0 then
    table.insert(parts, "|cffaaaaaaNone|r")
  end
  local eta = GetAffixRerollETA()
  MythicSendPlayerMessage(player, "|cffffcc00[Mythic]|r This week's affixes: " .. table.concat(parts, ", ")
    .. "  |  Next reroll in: " .. ((eta > 0) and FormatDurationShort(eta) or "soon"))
    end)
    if not ok then
      MythicLog("RegisterPlayerEvent(3) failed for on-login affix blurb handler: " .. tostring(err))
    else
      _G.__MYTHIC_PLAYER_EVENT3_REGISTERED__ = true
    end
  end
end

--==========================================================
-- Command Handler (.simclean, .sim, .mythicroll, etc.)
--==========================================================
do
  local registerPlayerEvent = _G.RegisterPlayerEvent
  if type(registerPlayerEvent) ~= "function" then
    MythicLog("RegisterPlayerEvent is unavailable; skipped on-command handler (event 42).")
  elseif _G.__MYTHIC_PLAYER_EVENT42_REGISTERED__ then
    -- Already registered in this Lua state.
  else
    local ok, err = pcall(registerPlayerEvent, 42, function(_, player, command)
  if not player then return true end
  if type(command) ~= "string" or command == "" then return true end
  local cmd = command:lower():gsub("[#./]", "")
  if cmd == "" then return true end
  local guid, now = player:GetGUIDLow(), os.time()


  if cmd:sub(1,8) == "simclean" then
    if not player:IsGM() then MythicSendPlayerMessage(player, "|cffff0000[Mythic]|r You do not have permission to use this command."); return false end
    local tokens = {}; for w in cmd:gmatch("%S+") do table.insert(tokens, w) end
    local radius = tonumber(tokens[2]) or 80
    local TARGET_CHEST = { [900010]=true, [900011]=true, [900012]=true, [900013]=true }
    local removed = 0
    local list = player:GetGameObjectsInRange(radius) or {}
    for _, go in pairs(list) do
      if go and go:IsInWorld() and TARGET_CHEST[go:GetEntry()] then
        if go.Despawn then go:Despawn() end
        go:RemoveFromWorld()
        removed = removed + 1
      end
    end
    MythicSendPlayerMessage(player, string.format("|cffffcc00[Mythic]|r simclean: removed %d chest(s) within %d yards.", removed, radius))
    return false
  end


  if cmd == "mythictimer" then
    local last = __MYTHIC_TIMER_COOLDOWN__[guid] or 0
    if now - last < TIMER_COMMAND_COOLDOWN then
      local remain = TIMER_COMMAND_COOLDOWN - (now - last)
      MythicSendPlayerMessage(player, "|cffffcc00[Mythic]|r You can use |cffffff00.mythictimer|r again in " .. FormatDurationShort(remain) .. ".")
      return false
    end
    __MYTHIC_TIMER_COOLDOWN__[guid] = now

    local eta  = GetAffixRerollETA()
    MythicSendPlayerMessage(player, "|cff66ccff[Mythic]|r Current affixes: " .. GetAffixNamesString(3))
    MythicSendPlayerMessage(player, "|cffffff00Next reroll in:|r " .. ((eta > 0) and FormatDurationShort(eta) or "soon"))
    return false
  end

  if cmd == "mythicinfo" then
    MythicSendPlayerMessage(player, GetPlayerRatingLine(player))
    MythicSendPlayerMessage(player, "|cff66ccff[Mythic]|r Affix system: " .. (IsAffixSystemEnabled() and "|cff00ff00enabled|r" or "|cffff0000disabled|r"))
    MythicSendPlayerMessage(player, "|cff66ccff[Mythic]|r Current affixes: " .. GetAffixNamesString(3))
    return false
  end

  if cmd == "mythicbest" then
    local map = player:GetMap()
    if not map then
      MythicSendPlayerMessage(player, "|cffff0000[Mythic]|r Unable to determine your current map.")
      return false
    end

    local myBest, realmBest = GetBestTimesForMap(map:GetMapId(), guid)
    local myLine = myBest
      and string.format("|cff66ccffYour best:|r %s (T%d)", FormatRaceTime(myBest.sec), myBest.tier)
      or "|cff66ccffYour best:|r |cffaaaaaaNo run recorded|r"
    local realmLine = realmBest
      and string.format("|cffffff00Realm best:|r %s (T%d) by %s", FormatRaceTime(realmBest.sec), realmBest.tier, realmBest.name)
      or "|cffffff00Realm best:|r |cffaaaaaaNo run recorded|r"

    MythicSendPlayerMessage(player, string.format("|cff66ccff[Mythic]|r %s  |  %s", myLine, realmLine))
    return false
  end

  if cmd == "mythictime" then
    local map = player:GetMap()
    if not map or not map:IsDungeon() then
      MythicSendPlayerMessage(player, "|cffffcc00[Mythic]|r .mythictime can only be used inside dungeon instances.")
      return false
    end

    local instanceId = map:GetInstanceId()
    local mapId = map:GetMapId()
    local tier = MYTHIC_TIER_TABLE[instanceId]
    local createdAt = nil
    local savedAffixStr = ""

    local row = DBQuery(
      "SELECT tier, UNIX_TIMESTAMP(created_at), affix_spells FROM character_mythic_instance_state WHERE guid=? AND instance_id=? AND map_id=?",
      guid, instanceId, mapId
    )
    if not row then
      row = DBQuery(
        "SELECT tier, UNIX_TIMESTAMP(created_at), affix_spells FROM character_mythic_instance_state WHERE instance_id=? AND map_id=? AND guid<>? ORDER BY created_at ASC LIMIT 1",
        instanceId, mapId, KILL_LOCK_MARKER_GUID
      )
    end
    if row then
      tier = tier or row:GetUInt32(0)
      createdAt = row:GetUInt32(1)
      savedAffixStr = row:GetString(2) or ""
    end

    if not tier or tier < 1 or tier > 3 then
      MythicSendPlayerMessage(player, "|cffffcc00[Mythic]|r No active Mythic+ run was found in this instance.")
      return false
    end

    local elapsed = createdAt and math.max(0, os.time() - createdAt) or 0
    local allowed = ComputeTierMinutes(mapId, tier) * 60
    local deaths = (MYTHIC_DEATHS[instanceId] and MYTHIC_DEATHS[instanceId][guid]) or 0
    if deaths == 0 then
      local deathRow = DBQuery(
        "SELECT death_count FROM character_mythic_instance_deaths WHERE instance_id=? AND map_id=? AND guid=?",
        instanceId, mapId, guid
      )
      if deathRow then
        deaths = deathRow:GetUInt32(0)
      end
    end

    local affixIds = MYTHIC_AFFIXES_TABLE[instanceId]
    if not affixIds or #affixIds == 0 then
      affixIds = (savedAffixStr ~= "") and ParseAffixes(savedAffixStr) or GetAffixSet(tier)
    end

    local idSet = {}
    for _, spellId in ipairs(affixIds or {}) do idSet[spellId] = true end

    local affixNames, seenAffixName = {}, {}
    for t = 1, 3 do
      for _, aff in ipairs(WEEKLY_AFFIX_POOL[t] or {}) do
        local spells = type(aff.spell) == "table" and aff.spell or { aff.spell }
        for _, spellId in ipairs(spells) do
          if idSet[spellId] and not seenAffixName[aff.name] then
            seenAffixName[aff.name] = true
            table.insert(affixNames, ColorAffixName(aff.name))
            break
          end
        end
      end
    end
    if #affixNames == 0 then
      table.insert(affixNames, "|cffaaaaaaNone|r")
    end

    local killProgress = ""
    if _G.__MYTHIC_ENEMY_FORCES_ENABLED__ == true then
      local currentKills, requiredKills = MythicGetEnemyForcesProgress(instanceId, mapId)
      local rawRequired, isDynamic, trackedTotal, percent = MythicGetEnemyForcesRequired(instanceId, mapId)
      if rawRequired > requiredKills then
        requiredKills = rawRequired
      end
      if requiredKills > 0 then
        killProgress = string.format(" / Kills: %d/%d", currentKills, requiredKills)
        if isDynamic and trackedTotal and trackedTotal > 0 then
          killProgress = killProgress .. string.format(" (%d%% of %d)", percent, trackedTotal)
        end
      end
    end

    MythicSendPlayerMessage(player, string.format(
      "|cff66ccff[Mythic]|r Elapsed: %s / Allowed: %s / Deaths: %d%s / Affixes: %s",
      FormatRaceTime(elapsed),
      FormatRaceTime(allowed),
      deaths,
      killProgress,
      table.concat(affixNames, ", ")
    ))
    return false
  end


  local isSimCommand = (cmd:sub(1,3) == "sim" or cmd:sub(1,8) == "simulate")
  if isSimCommand and not cmd:find("^simdrop") then
    if not player:IsGM() then MythicSendPlayerMessage(player, "|cffff0000[Mythic]|r You do not have permission to use this command."); return false end
    local tokens = {}; for w in cmd:gmatch("%S+") do table.insert(tokens, w) end
    local tier
    if tonumber(tokens[2]) then tier = tonumber(tokens[2])
    elseif tokens[2] == "tier" and tonumber(tokens[3]) then tier = tonumber(tokens[3]) end
    if not tier or tier < 1 or tier > 3 then MythicSendPlayerMessage(player, "|cffff0000[Mythic]|r Usage: .sim <1-3>  or  .sim tier <1-3>"); return false end

    local map, mapId, instanceId = player:GetMap(), 0, 0
    if map then mapId = map:GetMapId(); instanceId = map:GetInstanceId() end

    local chestEntry
    if tier == 2 then
      chestEntry = (player:GetTeam() == 1) and 900013 or 900011
    else
      chestEntry = CHEST_ENTRIES[tier] or CHEST_ENTRIES[1]
    end

    local x, y, z, o = player:GetX(), player:GetY(), player:GetZ(), player:GetO()
    local chest = PerformIngameSpawn(2, chestEntry, mapId, instanceId, x, y, z, o, false)
    if chest then
      local chestGuid = chest.GetGUID and chest:GetGUID() or nil
      CreateLuaEvent(function()
        local go = nil
        if chestGuid then
          local okGo, obj = pcall(GetGameObjectByGUID, chestGuid)
          if okGo then
            go = obj
          end
        end
        if not go and chest and chest.IsInWorld and chest:IsInWorld() then
          go = chest
        end
        if go then
          if go.Despawn then go:Despawn() end
          go:RemoveFromWorld()
        end
      end, 60000, 1)
    end

    MythicSendPlayerMessage(player, string.format("|cffffcc00[Mythic]|r Simulated chest spawned (Tier %d). Auto-despawns in 60s. No rating or tokens granted.", tier))
    return false
  end


  if cmd == "mythicroll" or cmd:find("^mythicroll%s") then
    if not player:IsGM() then MythicSendPlayerMessage(player, "|cffff0000[Mythic]|r You do not have permission to use this command."); return false end

    local tokens = {}; for w in cmd:gmatch("%S+") do table.insert(tokens, w) end


    if tokens[2] == nil or (tokens[2] == "all" and tokens[3] == nil) then
      local old = {
        WEEKLY_AFFIXES[1] and WEEKLY_AFFIXES[1].name or "None",
        WEEKLY_AFFIXES[2] and WEEKLY_AFFIXES[2].name or "None",
        WEEKLY_AFFIXES[3] and WEEKLY_AFFIXES[3].name or "None"
      }
      for t = 1, 3 do RerollTierAffix(t) end
      ResetAffixCountdown()
      MythicBroadcastCurrentWeeklyAffixesToPlayers()
      MythicSendWorldMessage(string.format("|cffffcc00[Mythic]|r Affixes re-rolled: T1 %s -> %s, T2 %s -> %s, T3 %s -> %s",
        ColorAffixName(old[1]), ColorAffixName(WEEKLY_AFFIXES[1] and WEEKLY_AFFIXES[1].name or "None"), 
        ColorAffixName(old[2]), ColorAffixName(WEEKLY_AFFIXES[2] and WEEKLY_AFFIXES[2].name or "None"), 
        ColorAffixName(old[3]), ColorAffixName(WEEKLY_AFFIXES[3] and WEEKLY_AFFIXES[3].name or "None")))
      return false
    end


    if tokens[2] ~= "tier" or not tonumber(tokens[3]) then
      MythicSendPlayerMessage(player, "|cffff0000[Mythic]|r Usage: .mythicroll  |  .mythicroll all  |  .mythicroll tier <1-3>  |  .mythicroll tier <1-3> <affix>")
      return false
    end

    local tier = tonumber(tokens[3])
    if tier < 1 or tier > 3 then MythicSendPlayerMessage(player, "|cffff0000[Mythic]|r Tier must be 1, 2, or 3."); return false end

    if #tokens == 3 then
      local before = WEEKLY_AFFIXES[tier] and WEEKLY_AFFIXES[tier].name or "None"
      local after  = RerollTierAffix(tier)
      if after then
        ResetAffixCountdown()
        MythicBroadcastCurrentWeeklyAffixesToPlayers()
        MythicSendWorldMessage(string.format("|cffffcc00[Mythic]|r Tier %d affix re-rolled: %s -> %s", tier, ColorAffixName(before), ColorAffixName(after.name)))
        MythicSendPlayerMessage(player, "|cff66ccff[Mythic]|r New affixes: " .. GetAffixNamesString(3))
      end
      return false
    end

    local desired = table.concat(tokens, " ", 4):gsub("^%s+", ""):gsub("%s+$", ""):lower()
    if desired == "" then MythicSendPlayerMessage(player, "|cffff0000[Mythic]|r Missing affix name. Example: .mythicroll tier 1 resistant"); return false end
    local aff = FindAffixByNameInTier(tier, desired)
    if not aff then
      local names = {}; for _, a in ipairs(WEEKLY_AFFIX_POOL[tier] or {}) do table.insert(names, a.name:lower()) end
      MythicSendPlayerMessage(player, "|cffff0000[Mythic]|r Invalid affix for Tier " .. tier .. ". Valid: " .. table.concat(names, ", "))
      return false
    end

    local before = WEEKLY_AFFIXES[tier] and WEEKLY_AFFIXES[tier].name or "None"
    WEEKLY_AFFIXES[tier] = aff
    ResetAffixCountdown()
    MythicBroadcastCurrentWeeklyAffixesToPlayers()
    MythicSendWorldMessage(string.format("|cffffcc00[Mythic]|r Tier %d affix set: %s -> %s", tier, ColorAffixName(before), ColorAffixName(aff.name)))
    MythicSendPlayerMessage(player, "|cff66ccff[Mythic]|r New affixes: " .. GetAffixNamesString(3))
    return false
  end


  if cmd:sub(1,12) == "mythicrating" then
    local tokens = {}; for w in cmd:gmatch("%S+") do table.insert(tokens, w) end


    if tokens[2] == "set" then
      if not player:IsGM() then
        MythicSendPlayerMessage(player, "|cffff0000[Mythic]|r You do not have permission to set ratings.")
        return false
      end

      local newVal = tonumber(tokens[3])
      if not newVal then
        MythicSendPlayerMessage(player, "|cffff0000[Mythic]|r Usage: .mythicrating set <number> [playerName]")
        return false
      end

      if newVal < 0 then newVal = 0 end
      if newVal > RATING_CAP then newVal = RATING_CAP end

      local targetGuid, targetPlayer, targetName

      if tokens[4] then
        local nameArg = tokens[4]

        targetPlayer = GetPlayerByName(nameArg)
        if targetPlayer then
          targetGuid = targetPlayer:GetGUIDLow()
          targetName = targetPlayer:GetName()
        else

          local row = DBQuery(
            "SELECT guid, name FROM characters WHERE LOWER(name)=LOWER(?) LIMIT 1",
            nameArg
          )
          if not row then
            MythicSendPlayerMessage(player, "|cffff0000[Mythic]|r Player not found: " .. nameArg)
            return false
          end
          targetGuid = row:GetUInt32(0)
          targetName = row:GetString(1)
        end
      else

        targetGuid = player:GetGUIDLow()
        targetName = player:GetName()
      end

      DBExecute([[
        INSERT INTO character_mythic_rating (guid,total_runs,total_points,claimed_tier1,claimed_tier2,claimed_tier3,last_updated)
        VALUES (?,0,?,0,0,0,NOW())
        ON DUPLICATE KEY UPDATE total_points=?,last_updated=NOW()
      ]], targetGuid, newVal, newVal)

      if targetPlayer then
        MythicSendPlayerMessage(targetPlayer, string.format(
          "|cff66ccff[Mythic]|r Your rating has been set to %s%d|r by a GM.",
          GetRatingColor(newVal), newVal
        ))
      end

      MythicSendPlayerMessage(player, string.format(
        "|cff66ccff[Mythic]|r Set %s's rating to %s%d|r.",
        targetName, GetRatingColor(newVal), newVal
      ))
      return false


    else
      local last = __MYTHIC_RATING_COOLDOWN__[guid] or 0
      if now - last < COMMAND_COOLDOWN then
        local remain = COMMAND_COOLDOWN - (now - last)
        MythicSendPlayerMessage(player, "|cffffcc00[Mythic]|r You can use |cffffff00.mythicrating|r again in " .. FormatDurationShort(remain) .. ".")
        return false
      end
      __MYTHIC_RATING_COOLDOWN__[guid] = now

      local row = DBQuery("SELECT total_points, total_runs, claimed_tier1, claimed_tier2, claimed_tier3 FROM character_mythic_rating WHERE guid=?", guid)
      if row then
        local pts  = row:GetUInt32(0)
        local runs = row:GetUInt32(1)
        local c1   = row:GetUInt32(2)
        local c2   = row:GetUInt32(3)
        local c3   = row:GetUInt32(4)
        MythicSendPlayerMessage(player, string.format(
          "|cff66ccff[Mythic]|r Rating: %s%d|r  (|cffffcc00%d runs|r) — Chests: T1 %d, T2 %d, T3 %d",
          GetRatingColor(pts), pts, runs, c1, c2, c3
        ))
      else
        MythicSendPlayerMessage(player, "|cff66ccff[Mythic]|r Rating: |cffffcc000|r (no runs yet)")
      end
      return false
    end
  end


  if cmd == "mythicleaderboardreset" or cmd == "mythiclbreset" then
    if not player:IsGM() then
      MythicSendPlayerMessage(player, "|cffff0000[Mythic]|r You do not have permission to use this command.")
      return false
    end
    DBExecute("TRUNCATE TABLE character_mythic_best")
    DBExecute("TRUNCATE TABLE mythic_realm_best")
    MythicSendPlayerMessage(player, "|cff00ff00[Mythic]|r Leaderboards wiped (character & realm best times).")
    MythicSendWorldMessage("|cffffcc00[Mythic]|r A Game Master has reset the Mythic+ leaderboards.")
    return false
  end


  if cmd == "mythicaffix" or cmd == "mythicaffixes" then
    local last = __MYTHIC_AFFIX_COOLDOWN__[guid] or 0
    if now - last < TIMER_COMMAND_COOLDOWN then
      local remain = TIMER_COMMAND_COOLDOWN - (now - last)
      MythicSendPlayerMessage(player, "|cffffcc00[Mythic]|r You can use |cffffff00.mythicaffix(es)|r again in " .. FormatDurationShort(remain) .. ".")
      return false
    end
    __MYTHIC_AFFIX_COOLDOWN__[guid] = now

    MythicSendPlayerMessage(player, "|cff66ccff[Mythic]|r Affix system: " .. (IsAffixSystemEnabled() and "|cff00ff00enabled|r" or "|cffff0000disabled|r"))
    local map = player:GetMap()
    local shownRunAffixes = false
    if map and map:IsDungeon() then
      local instanceId = map:GetInstanceId()
      local mapId = map:GetMapId()
      local tier = MYTHIC_TIER_TABLE[instanceId]
      local savedAffixStr = ""

      if (not tier or tier < 1 or tier > 3) and instanceId and instanceId > 0 then
        local row = DBQuery(
          "SELECT tier, affix_spells FROM character_mythic_instance_state WHERE guid=? AND instance_id=? AND map_id=?",
          guid, instanceId, mapId
        )
        if not row then
          row = DBQuery(
            "SELECT tier, affix_spells FROM character_mythic_instance_state WHERE instance_id=? AND map_id=? AND guid<>? ORDER BY created_at ASC LIMIT 1",
            instanceId, mapId, KILL_LOCK_MARKER_GUID
          )
        end
        if row then
          tier = row:GetUInt32(0)
          savedAffixStr = row:GetString(1) or ""
        end
      end

      if tier and tier >= 1 and tier <= 3 then
        local affixIds = MYTHIC_AFFIXES_TABLE[instanceId]
        if not affixIds or #affixIds == 0 then
          affixIds = (savedAffixStr ~= "") and ParseAffixes(savedAffixStr) or GetAffixSet(tier)
        end

        local idSet = {}
        for _, spellId in ipairs(affixIds or {}) do idSet[spellId] = true end

        local affixNames, seenAffixName = {}, {}
        for t = 1, 3 do
          for _, aff in ipairs(WEEKLY_AFFIX_POOL[t] or {}) do
            local spells = type(aff.spell) == "table" and aff.spell or { aff.spell }
            for _, spellId in ipairs(spells) do
              if idSet[spellId] and not seenAffixName[aff.name] then
                seenAffixName[aff.name] = true
                table.insert(affixNames, ColorAffixName(aff.name))
                break
              end
            end
          end
        end

        if #affixNames > 0 then
          MythicSendPlayerMessage(player, "|cff66ccff[Mythic]|r Active run affixes: " .. table.concat(affixNames, ", "))
          shownRunAffixes = true
        end
      end
    end

    if not shownRunAffixes then
      MythicSendPlayerMessage(player, "|cff66ccff[Mythic]|r Current affixes: " .. GetAffixNamesString(3))
    end
    return false
  end

  if cmd == "mythicaffixmode" or cmd:find("^mythicaffixmode%s") then
    if not player:IsGM() then
      MythicSendPlayerMessage(player, "|cffff0000[Mythic]|r You do not have permission to use this command.")
      return false
    end

    local tokens = {}; for w in cmd:gmatch("%S+") do table.insert(tokens, w) end
    local mode = tokens[2]

    if not mode or mode == "status" then
      MythicSendPlayerMessage(player, "|cff66ccff[Mythic]|r Affix system is currently " .. (IsAffixSystemEnabled() and "|cff00ff00enabled|r." or "|cffff0000disabled|r."))
      MythicSendPlayerMessage(player, "|cffaaaaaaUsage: .mythicaffixmode <on|off|status>|r")
      return false
    end

    if mode == "on" then
      SetAffixSystemEnabled(true)
      ReapplyAffixesToActiveInstances()
      MythicSendWorldMessage("|cffffcc00[Mythic]|r A GM has enabled the Mythic+ affix system.")
      return false
    end

    if mode == "off" then
      SetAffixSystemEnabled(false)
      ClearAffixesFromActiveInstances()
      MythicSendWorldMessage("|cffffcc00[Mythic]|r A GM has disabled the Mythic+ affix system.")
      return false
    end

    MythicSendPlayerMessage(player, "|cffff0000[Mythic]|r Usage: .mythicaffixmode <on|off|status>")
    return false
  end

  if cmd == "mythicforces" or cmd:find("^mythicforces%s") then
    local tokens = {}; for w in cmd:gmatch("%S+") do table.insert(tokens, w) end
    local sub = tokens[2] or "status"
    local enabled = (_G.__MYTHIC_ENEMY_FORCES_LOCKED__ == true) or (_G.__MYTHIC_ENEMY_FORCES_ENABLED__ == true)
    local requiredByMap = _G.__MYTHIC_ENEMY_FORCES_REQUIRED__ or {}
    local dynamicPercent = MythicGetEnemyForcesPercent()
    local usageUnlocked = ".mythicforces <status|on|off|percent <1-100>|sethere <kills>|set <mapId> <kills>|clear <mapId>>"
    local usageLocked = ".mythicforces <status|percent <1-100>|sethere <kills>|set <mapId> <kills>|clear <mapId>>"
    local usageText = (_G.__MYTHIC_ENEMY_FORCES_LOCKED__ == true) and usageLocked or usageUnlocked

    if sub == "status" then
      local statusText = (enabled and "|cff00ff00enabled|r" or "|cffff0000disabled|r")
      if _G.__MYTHIC_ENEMY_FORCES_LOCKED__ == true then
        statusText = statusText .. " |cffaaaaaa(locked)|r"
      end
      MythicSendPlayerMessage(player, "|cff66ccff[Mythic]|r Enemy forces requirement is " .. statusText .. ".")
      local map = player:GetMap()
      if map and map:IsDungeon() then
        local mapId = map:GetMapId()
        local instanceId = map:GetInstanceId()
        local currentKills, requiredKills = MythicGetEnemyForcesProgress(instanceId, mapId)
        local rawRequired, isDynamic, trackedTotal, percent = MythicGetEnemyForcesRequired(instanceId, mapId)
        if rawRequired > requiredKills then
          requiredKills = rawRequired
        end
        local staticRequired = tonumber(requiredByMap[mapId] or 0) or 0
        if requiredKills > 0 then
          if isDynamic then
            MythicSendPlayerMessage(player, string.format("|cff66ccff[Mythic]|r Map %d forces target: %d (dynamic %d%% of tracked %d, current: %d/%d)", mapId, requiredKills, percent, trackedTotal, currentKills, requiredKills))
          else
            MythicSendPlayerMessage(player, string.format("|cff66ccff[Mythic]|r Map %d forces target: %d (static, current: %d/%d)", mapId, requiredKills, currentKills, requiredKills))
          end
        else
          if staticRequired > 0 then
            MythicSendPlayerMessage(player, string.format("|cff66ccff[Mythic]|r Map %d forces target: %d (current: %d/%d)", mapId, staticRequired, currentKills, staticRequired))
          else
            MythicSendPlayerMessage(player, string.format("|cff66ccff[Mythic]|r Map %d forces target: pending dynamic discovery (%d%% mode).", mapId, dynamicPercent))
          end
        end
      else
        MythicSendPlayerMessage(player, "|cffaaaaaa[Mythic]|r Enter a dungeon to view current-map enemy-forces progress.")
      end
      if player:IsGM() then
        MythicSendPlayerMessage(player, "|cffaaaaaaUsage: " .. usageText .. "|r")
      end
      return false
    end

    if not player:IsGM() then
      MythicSendPlayerMessage(player, "|cffff0000[Mythic]|r You do not have permission to modify enemy forces settings.")
      return false
    end

    if sub == "on" then
      _G.__MYTHIC_ENEMY_FORCES_ENABLED__ = true
      MythicSendWorldMessage("|cffffcc00[Mythic]|r A GM has enabled enemy-forces completion requirements.")
      return false
    end

    if sub == "off" then
      if _G.__MYTHIC_ENEMY_FORCES_LOCKED__ == true then
        _G.__MYTHIC_ENEMY_FORCES_ENABLED__ = true
        MythicSendPlayerMessage(player, "|cffffcc00[Mythic]|r Enemy-forces completion is locked on by script configuration.")
        return false
      end
      _G.__MYTHIC_ENEMY_FORCES_ENABLED__ = false
      MythicSendWorldMessage("|cffffcc00[Mythic]|r A GM has disabled enemy-forces completion requirements.")
      return false
    end

    if sub == "percent" then
      local pct = tonumber(tokens[3] or "")
      if not pct or pct < 1 or pct > 100 then
        MythicSendPlayerMessage(player, "|cffff0000[Mythic]|r Usage: .mythicforces percent <1-100>")
        return false
      end
      _G.__MYTHIC_ENEMY_FORCES_PERCENT__ = math.floor(pct)
      MythicSendPlayerMessage(player, string.format("|cff00ff00[Mythic]|r Dynamic enemy-forces percent set to %d%%.", math.floor(pct)))
      return false
    end

    if sub == "sethere" then
      local map = player:GetMap()
      local kills = tonumber(tokens[3] or "")
      if not map or not map:IsDungeon() then
        MythicSendPlayerMessage(player, "|cffff0000[Mythic]|r .mythicforces sethere requires you to be inside a dungeon.")
        return false
      end
      if not kills or kills < 0 then
        MythicSendPlayerMessage(player, "|cffff0000[Mythic]|r Usage: .mythicforces sethere <kills>")
        return false
      end
      kills = math.floor(kills)
      requiredByMap[map:GetMapId()] = kills
      _G.__MYTHIC_ENEMY_FORCES_REQUIRED__ = requiredByMap
      MythicSendPlayerMessage(player, string.format("|cff00ff00[Mythic]|r Enemy forces target for map %d set to %d.", map:GetMapId(), kills))
      return false
    end

    if sub == "set" then
      local mapId = tonumber(tokens[3] or "")
      local kills = tonumber(tokens[4] or "")
      if not mapId or not kills or kills < 0 then
        MythicSendPlayerMessage(player, "|cffff0000[Mythic]|r Usage: .mythicforces set <mapId> <kills>")
        return false
      end
      mapId = math.floor(mapId)
      kills = math.floor(kills)
      requiredByMap[mapId] = kills
      _G.__MYTHIC_ENEMY_FORCES_REQUIRED__ = requiredByMap
      MythicSendPlayerMessage(player, string.format("|cff00ff00[Mythic]|r Enemy forces target for map %d set to %d.", mapId, kills))
      return false
    end

    if sub == "clear" then
      local mapId = tonumber(tokens[3] or "")
      if not mapId then
        MythicSendPlayerMessage(player, "|cffff0000[Mythic]|r Usage: .mythicforces clear <mapId>")
        return false
      end
      mapId = math.floor(mapId)
      requiredByMap[mapId] = nil
      _G.__MYTHIC_ENEMY_FORCES_REQUIRED__ = requiredByMap
      MythicSendPlayerMessage(player, string.format("|cff00ff00[Mythic]|r Cleared enemy forces target for map %d.", mapId))
      return false
    end

    MythicSendPlayerMessage(player, "|cffff0000[Mythic]|r Usage: " .. usageText)
    return false
  end


  if cmd == "mythichelp" then
    MythicSendPlayerMessage(player, "|cff66ccff[Mythic]|r Available commands:")
    MythicSendPlayerMessage(player, "|cffffff00.mythicinfo|r - View your Mythic+ rating and current affixes.")
    MythicSendPlayerMessage(player, "|cffffff00.mythicrating|r - View your Mythic+ rating and runs.")
    MythicSendPlayerMessage(player, "|cffffff00.mythictime|r - View elapsed time, allowed time, deaths, and current run affixes.")
    MythicSendPlayerMessage(player, "|cffffff00.mythicbest|r - View your best + realm best for your current map.")
    MythicSendPlayerMessage(player, "|cffffff00.mythictimer|r - Current affixes & next reroll ETA (5 min cooldown).")
    MythicSendPlayerMessage(player, "|cffffff00.mythichelp|r - Show this help menu.")
    MythicSendPlayerMessage(player, "|cffffff00.mythicaffixes|r - Show current Mythic+ affixes (5 min cooldown).")
    MythicSendPlayerMessage(player, "|cffffff00.mythicforces status|r - Show enemy-forces requirement status/progress.")
    if player:IsGM() then
      MythicSendPlayerMessage(player, "|cffff6600GM note:|r You can also modify affixes by talking to the Mythic Pedestal NPC while GM mode is enabled.")
      MythicSendPlayerMessage(player, "|cffff6600.mythicroll all|r - GM: Reroll all affixes.")
      MythicSendPlayerMessage(player, "|cffff6600.mythicroll tier <1-3>|r - GM: Reroll a specific tier.")
      MythicSendPlayerMessage(player, "|cffff6600.mythicroll tier <1-3> <affix>|r - GM: Set a specific affix (e.g., resistant).")
      MythicSendPlayerMessage(player, "|cffff6600.sim tier <1-3>|r - GM: Spawn a Tier chest without awarding rating or tokens.")
      MythicSendPlayerMessage(player, "|cffff6600.mythicreset|r - GM: Start full server rating reset.")
      MythicSendPlayerMessage(player, "|cffff6600.mythicreset confirm|r - GM: Confirm the reset within 30 seconds.")
      MythicSendPlayerMessage(player, "|cffff6600.simclean [radius]|r - GM: Remove nearby sim-spawned chests (default radius 80).")
      MythicSendPlayerMessage(player, "|cffff6600.mythiclbreset|r - GM: Reset best-time leaderboards instantly.")
      MythicSendPlayerMessage(player, "|cffff6600.mythicrating set <n> [player]|r - GM: Force-set rating (self or target).")
      MythicSendPlayerMessage(player, "|cffff6600.mythicaffixmode <on|off|status>|r - GM: Toggle affix system.")
      if _G.__MYTHIC_ENEMY_FORCES_LOCKED__ == true then
        MythicSendPlayerMessage(player, "|cffff6600.mythicforces <status|percent <1-100>|sethere <kills>|set <mapId> <kills>|clear <mapId>>|r - GM: Enemy-forces completion settings (locked on).")
      else
        MythicSendPlayerMessage(player, "|cffff6600.mythicforces <status|on|off|percent <1-100>|sethere <kills>|set <mapId> <kills>|clear <mapId>>|r - GM: Enemy-forces completion settings.")
      end
    else
      MythicSendPlayerMessage(player, "|cffaaaaaa(More settings are available with GM mode enabled.)|r")
    end
    return false
  end


  if cmd == "mythiccomplete" then
    if not player:IsGM() then
      MythicSendPlayerMessage(player, "|cffff0000[Mythic]|r You do not have permission to use this command.")
      return false
    end
    local map = player:GetMap()
    if not map then
      MythicSendPlayerMessage(player, "|cffff0000[Mythic]|r You must be inside an instance to use this command.")
      return false
    end
    local instanceId = map:GetInstanceId()
    if not instanceId or not MYTHIC_FLAG_TABLE[instanceId] then
      MythicSendPlayerMessage(player, "|cffff0000[Mythic]|r Mythic+ mode is not active in this instance.")
      return false
    end
    if MYTHIC_COMPLETION_STATE[instanceId] and MYTHIC_COMPLETION_STATE[instanceId] ~= "active" then
      MythicSendPlayerMessage(player, "|cffffcc00[Mythic]|r This Mythic+ run has already ended.")
      return false
    end
    local tier = MYTHIC_TIER_TABLE[instanceId]
    if not tier then
      MythicSendPlayerMessage(player, "|cffff0000[Mythic]|r Unable to determine current tier.")
      return false
    end
    local px, py, pz, po = player:GetX(), player:GetY(), player:GetZ(), player:GetO()
    local chestX = px + math.cos(po) * 2
    local chestY = py + math.sin(po) * 2
    FinalizeMythicRun(map, instanceId, tier, false, chestX, chestY, pz, po)
    MythicSendPlayerMessage(player, "|cff00ff00[Mythic]|r Mythic+ run forcibly completed and chest spawned.")
    return false
  end

  if cmd == "mythicreset" then
    if not player:IsGM() then
      MythicSendPlayerMessage(player, "|cffff0000[Mythic]|r You do not have permission to use this command.")
    else
      __MYTHIC_RESET_PENDING__[guid] = now
      MythicSendPlayerMessage(player, "|cffffff00[Mythic]|r Type |cff00ff00.mythicreset confirm|r within 30 seconds to confirm full reset.")
    end
    return false
  end

  if cmd == "mythicresetconfirm" or cmd:match("^mythicreset%s+confirm$") then
    local pendingTime = __MYTHIC_RESET_PENDING__[guid]
    if not pendingTime or now - pendingTime > RESET_CONFIRM_TIMEOUT then
      MythicSendPlayerMessage(player, "|cffff0000[Mythic]|r No reset pending or confirmation expired. Use |cff00ff00.mythicreset|r first.")
    else
      __MYTHIC_RESET_PENDING__[guid] = nil
      DBExecute([[
        UPDATE character_mythic_rating
        SET total_points=0, total_runs=0,
            claimed_tier1=0, claimed_tier2=0, claimed_tier3=0,
            last_updated=NOW()
      ]])
      MythicSendPlayerMessage(player, "|cff00ff00[Mythic]|r All player ratings and run counts have been reset.")
      MythicSendWorldMessage("|cffffcc00[Mythic]|r A Game Master has reset all Mythic+ player ratings.")
    end
    return false
  end
    end)
    if not ok then
      MythicLog("RegisterPlayerEvent(42) failed for on-command handler: " .. tostring(err))
    else
      _G.__MYTHIC_PLAYER_EVENT42_REGISTERED__ = true
    end
  end
end

--==========================================================
-- Final Boss Kill Hook → Score/Reward/Chest/Cleanup
--==========================================================
(function()
  if _G.__MYTHIC_CREATURE_FINAL_EVENTS_REGISTERED__ then
    return
  end

  for _, data in pairs(MYTHIC_FINAL_BOSSES) do
    local finalEntry = data.final
    if finalEntry then
      local bossIds = type(finalEntry) == "table" and finalEntry or { finalEntry }
      for _, bossId in ipairs(bossIds) do
        RegisterCreatureEvent(bossId, 4, function(_, creature)
          TryFinalizeRunOnDeath(creature)
        end)
      end
    end
  end

  --==========================================================
  -- Mal'Ganis Failsafe (Culling of Stratholme)
  -- Tertiary fallback: if RP markers are missed, complete at <=10% HP.
  --==========================================================
  local MALGANIS_ENTRY_IDS = { 26533, 31217, 32313 }
  for _, malganisEntryId in ipairs(MALGANIS_ENTRY_IDS) do
    RegisterCreatureEvent(malganisEntryId, 14, function(_, creature, _)
      if not creature then return end
      local map = creature:GetMap()
      if not map then return end
      if map:GetMapId() ~= CULLING_OF_STRATHOLME_MAP_ID then return end
      local instanceId = map:GetInstanceId()
      if not MYTHIC_FLAG_TABLE[instanceId] or MYTHIC_MODE_ENDED[instanceId] then return end

      if creature:GetHealthPct() > 10 then return end

      local expired = MYTHIC_TIMER_EXPIRED[instanceId]
      local tier = MYTHIC_TIER_TABLE[instanceId] or 1
      if not MythicEnemyForcesCanComplete(map, instanceId, map:GetMapId()) then return end

      local chestX, chestY, chestZ, chestO
      if not expired then
        chestX, chestY, chestZ, chestO = creature:GetX(), creature:GetY(), creature:GetZ(), creature:GetO()
        chestX = chestX - math.cos(chestO) * 2
        chestY = chestY - math.sin(chestO) * 2
      end

      FinalizeMythicRun(map, instanceId, tier, expired, chestX, chestY, chestZ, chestO)
      MythicLog("Mal'Ganis failsafe triggered at 10% health - completing mythic run")
    end, 10)
  end

  _G.__MYTHIC_CREATURE_FINAL_EVENTS_REGISTERED__ = true
end)()

--==========================================================
-- Chest Spawn (real run) — one per instance; faction swap on T2
--==========================================================
function SpawnMythicRewardChest(x, y, z, o, map, instanceId, tier)
  if MYTHIC_CHEST_SPAWNED[instanceId] then return end
  local chestEntry
  if tier == 2 then
    local team = 0
    for _, p in pairs(map:GetPlayers() or {}) do
      if p:IsAlive() then
        team = p:GetTeam()
        break
      end
    end
    if team == 0 then
      for _, p in pairs(map:GetPlayers() or {}) do
        if p:IsInWorld() then
          team = p:GetTeam()
          break
        end
      end
    end
    chestEntry = (team == 1) and 900013 or 900011
  else
    chestEntry = CHEST_ENTRIES[tier] or CHEST_ENTRIES[1]
  end
  PerformIngameSpawn(2, chestEntry, map:GetMapId(), instanceId, x, y, z, o, false)
  MYTHIC_CHEST_SPAWNED[instanceId] = true
end

--==========================================================
-- Cleanup (stop loops, clear flags, forget resume token)
--==========================================================
function CleanupMythicInstance(instanceId)
  if not instanceId or instanceId <= 0 then
    return
  end
  FlushPendingDeathWrites(instanceId)
  ClearTimeoutEvents(instanceId)
  StopHoRCompletionFailsafe(instanceId)
  if MYTHIC_LOOP_HANDLERS[instanceId] then
    RemoveEventById(MYTHIC_LOOP_HANDLERS[instanceId])
    MYTHIC_LOOP_HANDLERS[instanceId] = nil
  end
  MYTHIC_FLAG_TABLE[instanceId]          = nil
  MYTHIC_AFFIXES_TABLE[instanceId]       = nil
  MYTHIC_REWARD_CHANCE_TABLE[instanceId] = nil
  MYTHIC_TIER_TABLE[instanceId]          = nil
  MYTHIC_DEATHS[instanceId]              = nil
  MYTHIC_NON_BOSS_KILLS[instanceId]      = nil
  MYTHIC_FORCES_WARN_TS[instanceId]      = nil
  (_G.__MYTHIC_ENEMY_FORCES_TRACKED_KEYS__ or {})[instanceId] = nil
  (_G.__MYTHIC_ENEMY_FORCES_KILLED_KEYS__ or {})[instanceId] = nil
  (_G.__MYTHIC_ENEMY_FORCES_TRACKED_TOTAL__ or {})[instanceId] = nil
  (_G.__MYTHIC_ENEMY_FORCES_REQ_STABLE__ or {})[instanceId] = nil
  (_G.__MYTHIC_ENEMY_FORCES_ELIGIBLE_KEYS__ or {})[instanceId] = nil
  MYTHIC_FORCES_PERSIST_CACHE[instanceId] = nil
  MYTHIC_TIMER_EXPIRED[instanceId]       = nil
  MYTHIC_CHEST_SPAWNED[instanceId]       = nil
  MYTHIC_MODE_ENDED[instanceId]          = nil
  MYTHIC_COMPLETION_STATE[instanceId]    = nil
  -- Preserve kill-lock marker rows so lock state survives script reloads.
  DBExecute("DELETE FROM character_mythic_instance_state WHERE instance_id = ? AND guid <> ?", instanceId, KILL_LOCK_MARKER_GUID)
  DBExecute("DELETE FROM character_mythic_instance_deaths WHERE instance_id = ?", instanceId)
  DBExecute("DELETE FROM character_mythic_instance_progress WHERE instance_id = ?", instanceId)
end

function FinalizeMythicRun(map, instanceId, tier, expired, chestX, chestY, chestZ, chestO)
  if not map or not instanceId or instanceId <= 0 or not tier or tier <= 0 then
    return
  end
  MYTHIC_MODE_ENDED[instanceId] = true
  SetKillLock(instanceId, map:GetMapId())
  MYTHIC_COMPLETION_STATE[instanceId] = expired and "failed" or "completed"

  local playerDeaths = {}
  local aioSummaryByGuid = {}
  for _, player in pairs(map:GetPlayers() or {}) do
    local guid = player:GetGUIDLow()
    playerDeaths[guid] = MYTHIC_DEATHS[instanceId] and MYTHIC_DEATHS[instanceId][guid] or 0
  end

  for _, player in pairs(map:GetPlayers() or {}) do
    if player:IsInWorld() then
      local guid = player:GetGUIDLow()
      local deaths = playerDeaths[guid] or 0
      local elapsed, maxTime = nil, nil
      local startRow = DBQuery(
        "SELECT UNIX_TIMESTAMP(created_at) FROM character_mythic_instance_state WHERE guid=? AND instance_id=? AND map_id=?",
        guid, instanceId, map:GetMapId())
      if not startRow then
        startRow = DBQuery(
          "SELECT UNIX_TIMESTAMP(created_at) FROM character_mythic_instance_state WHERE instance_id=? AND map_id=? AND guid<>? ORDER BY created_at ASC LIMIT 1",
          instanceId, map:GetMapId(), KILL_LOCK_MARKER_GUID)
      end
      if startRow then
        local startedAt = startRow:GetUInt32(0)
        elapsed = math.max(0, os.time() - startedAt)
        maxTime = ComputeTierMinutes(map:GetMapId(), tier) * 60
      end

      local newRating = nil
      if expired then
        MythicSendPlayerMessage(player, "|cffff0000[Mythic]|r Time expired. No rewards granted.")
        MYTHIC_COMPLETION_STATE[instanceId] = "failed"
      else
        if elapsed then
          RecordBestTime(map:GetMapId(), tier, player, elapsed)
          MythicSendPlayerMessage(player, string.format("|cffaaff00[Mythic]|r Time this run: %s", FormatRaceTime(elapsed)))
        end
        newRating = select(1, AwardMythicPoints(player, tier, deaths, elapsed, maxTime))
        MythicClearTierTimerAura(player, tier, true)
      end

      if not newRating then
        local qRating = DBQuery("SELECT total_points FROM character_mythic_rating WHERE guid = ?", guid)
        newRating = qRating and qRating:GetUInt32(0) or nil
      end
      aioSummaryByGuid[guid] = {
        elapsed = elapsed,
        deaths = deaths,
        rating = newRating,
      }
    end
  end

  if not expired then
    if not (chestX and chestY and chestZ and chestO) then
      for _, player in pairs(map:GetPlayers() or {}) do
        if player:IsInWorld() then
          chestX, chestY, chestZ, chestO = player:GetX(), player:GetY(), player:GetZ(), player:GetO()
          chestX = chestX - math.cos(chestO) * 2
          chestY = chestY - math.sin(chestO) * 2
          break
        end
      end
    end
    if chestX and chestY and chestZ and chestO then
      SpawnMythicRewardChest(chestX, chestY, chestZ, chestO, map, instanceId, tier)
    end
  end

  -- AIO: notify clients that the run has ended
  if AIO then
    for _, player in pairs(map:GetPlayers() or {}) do
      if player and player:IsInWorld() then
        local summary = aioSummaryByGuid[player:GetGUIDLow()] or {}
        AIO.Handle(player, "MythicPlus", "StopRun", {
          completed = not expired,
          expired = expired and true or false,
          finalized = true,
          elapsed = summary.elapsed,
          deaths = summary.deaths,
          rating = summary.rating,
        })
      end
    end
  end

  RemoveAffixAurasFromPlayers(instanceId, map)
  RemoveAffixAurasFromAllCreatures(instanceId, map)
  CleanupMythicInstance(instanceId)
end
