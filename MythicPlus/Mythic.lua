--[[
===========================================================
 Mythic+ System for WotLK (Eluna) — AzerothCore
 Author: Doodihealz
 Notes:
  • Affixes auto re-roll every 6 hours (active runs are snapshotted).
  • Mid-run protection: affix list persisted per character+instance.
  • Gossip shows rating, weekly affixes, reroll ETA, and best times.
===========================================================
]]

print("[Mythic] Mythic script loaded successfully! Enjoy!")
dofile("C:/Build/bin/RelWithDebInfo/lua_scripts/MythicPlus/MythicBosses.lua")

--==========================================================
-- Config & Constants
--==========================================================
local PEDESTAL_NPC_ENTRY           = 900001
local MYTHIC_SCAN_RADIUS           = 500
local RATING_CAP                   = 2000
local AURA_LOOP_INTERVAL           = 6000       -- ms; affix aura re-apply cadence
local COMMAND_COOLDOWN             = 300        -- seconds; .mythicrating cooldown
local TIMER_COMMAND_COOLDOWN       = 300        -- seconds; .mythictimer cooldown
local RESET_CONFIRM_TIMEOUT        = 30         -- seconds; GM rating reset confirm window
local INSTANCE_STATE_TIMEOUT       = 7200       -- seconds; resume window after DC/relog
local AFFIX_REROLL_INTERVAL_MS     = 6 * 60 * 60 * 1000 -- 6h

-- Map IDs used in timer overrides
local FORGE_OF_SOULS_MAP_ID        = 632
local CULLING_OF_STRATHOLME_MAP_ID = 595
local AHN_KAHET_MAP_ID             = 619
local VIOLET_HOLD_MAP_ID           = 608

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
local MYTHIC_COMPLETION_STATE    = MYTHIC_COMPLETION_STATE    or {} -- "active" | "completed" | "failed"
local __MYTHIC_RATING_COOLDOWN__ = __MYTHIC_RATING_COOLDOWN__ or {}
local __MYTHIC_RESET_PENDING__   = __MYTHIC_RESET_PENDING__   or {}
local __MYTHIC_TIMER_COOLDOWN__  = __MYTHIC_TIMER_COOLDOWN__  or {}

-- Forward decls
local CleanupMythicInstance
local SpawnMythicRewardChest
local AutoRerollAffixes
local NEXT_AFFIX_REROLL_AT = os.time() + (AFFIX_REROLL_INTERVAL_MS / 1000)
local AUTO_REROLL_EVENT_ID = nil

--==========================================================
-- DB Helpers & Formatting
--==========================================================
local function SafeDBQuery(q, ...)   return CharDBQuery(string.format(q, ...)) end
local function SafeDBExecute(q, ...) return CharDBExecute(string.format(q, ...)) end
local function Colorize(s, c)        return string.format("%s%s|r", c or "|cffffffff", s) end

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

-- mm:ss (or hh:mm:ss if long) – compact race timer style
local function FormatRaceTime(sec)
  if sec < 0 then sec = 0 end
  local h = math.floor(sec / 3600); sec = sec % 3600
  local m = math.floor(sec / 60);   local s = sec % 60
  if h > 0 then return string.format("%d:%02d:%02d", h, m, s) end
  return string.format("%d:%02d", m, s)
end

local function GetAffixRerollETA()
  return math.max(0, (NEXT_AFFIX_REROLL_AT or 0) - os.time())
end

--==========================================================
-- Per-map Timer Overrides
--==========================================================
local TIMER_OVERRIDES = {
  [AHN_KAHET_MAP_ID]              = { fixed = 30 }, -- Always 30 minutes
  [FORGE_OF_SOULS_MAP_ID]         = { fixed = 15 }, -- Always 15 minutes
  [CULLING_OF_STRATHOLME_MAP_ID]  = { fixed = 30 }, -- Always 30 minutes
  [VIOLET_HOLD_MAP_ID]            = { per_tier = { [1]=15, [2]=30, [3]=30 } }, -- VH: T1=15, T2/T3=30
}

local function ComputeTierMinutes(mapId, tier)
  local minutes = (tier and tier >= 1 and tier <= 3) and ({15,30,30})[tier] or 15
  local ov = TIMER_OVERRIDES[mapId]
  if ov then
    if ov.fixed then minutes = ov.fixed
    elseif ov.per_tier and ov.per_tier[tier] then minutes = ov.per_tier[tier] end
  end
  return minutes
end

--==========================================================
-- Tier Settings / Rewards
--==========================================================
local TIER_CONFIG = {
  [1] = { rating_gain = 20, rating_loss = 3, timeout_penalty = 10, duration = 15, aura = 26013, color = "|cff0070dd" },
  [2] = { rating_gain = 40, rating_loss = 6, timeout_penalty = 20, duration = 30, aura = 71041, color = "|cffa335ee" },
  [3] = { rating_gain = 60, rating_loss = 9, timeout_penalty = 30, duration = 30, aura = 71041, color = "|cffff8000" }
}
local KEY_IDS       = { [1] = 900100, [2] = 900101, [3] = 900102 }
local CHEST_ENTRIES = { [1] = 900010, [2] = 900011, [3] = 900012 }
local ICONS = {
  [1] = "Interface\\Icons\\INV_Enchant_AbyssCrystal",
  [2] = "Interface\\Icons\\INV_Enchant_VoidCrystal",
  [3] = "Interface\\Icons\\INV_Enchant_NexusCrystal"
}

--==========================================================
-- Kill/Target Filters
--==========================================================
local MYTHIC_HOSTILE_FACTIONS = { [16]=true, [21]=true, [1885]=true }
local FRIENDLY_FACTIONS = {
  [1]=true,[2]=true,[3]=true,[4]=true,[5]=true,[6]=true,[14]=true,[31]=true,[35]=true,
  [114]=true,[115]=true,[116]=true,[188]=true,[190]=true,[1610]=true,[1629]=true,[1683]=true,[1718]=true,[1770]=true
}
local IGNORE_BUFF_ENTRIES = {
  [30172]=true,[30173]=true,[29630]=true,[28351]=true,[24137]=true,[37596]=true,[26499]=true,[27745]=true,[28922]=true,
  [36772]=true,[36661]=true
}

--==========================================================
-- Affix Pools / Colors
--==========================================================
local WEEKLY_AFFIX_POOL = {
  [1] = {
    { spell = { 48441, 61301 },                  name = "Rejuvenating"   },
    { spell = { 47893, 50589 },                  name = "Demonism"       },
    { spell = { 43010, 43024, 43012 },           name = "Resistant"      },
  },
  [2] = {
    { spell = 871,                                name = "Turtling"       },
    { spell = { 48161, 48066, 6346, 48168, 15286 }, name = "Priest Empowered" },
    { spell = 53201,                              name = "Falling Stars"  },
  },
  [3] = {
    { spell = 8599,                               name = "Enrage"         },
    { spell = { 47436, 53138, 57623 },            name = "Rallying"       },
    { spell = { 53385, 48819 },                   name = "Consecrated"    },
  }
}

local AFFIX_COLOR_MAP = {
  Enrage="|cffff0000", Turtling="|cffffff00", Rejuvenating="|cff00ff00",
  ["Falling Stars"]="|cff66ccff", ["Priest Empowered"]="|cffcccccc",
  Demonism="|cff8b0000", Consecrated="|cffffcc00", Resistant="|cffb0c4de", Rallying="|cffff8800"
}

-- Build a quick lookup of all affix spell IDs (if needed later)
local ALL_AFFIX_SPELL_IDS = {}
for _, tier in pairs(WEEKLY_AFFIX_POOL) do
  for _, affix in ipairs(tier) do
    local spells = type(affix.spell) == "table" and affix.spell or { affix.spell }
    for _, id in ipairs(spells) do ALL_AFFIX_SPELL_IDS[id] = true end
  end
end

--==========================================================
-- Weekly Affixes (randomized on load)
--==========================================================
local WEEKLY_AFFIXES = {}
math.randomseed(os.time()); math.random(); math.random(); math.random()
for i = 1, 3 do
  local pool = WEEKLY_AFFIX_POOL[i]
  if #pool > 0 then table.insert(WEEKLY_AFFIXES, pool[math.random(#pool)]) end
end

local function GetAffixSet(tier)
  local list = {}
  for i = 1, tier do
    local affix = WEEKLY_AFFIXES[i]
    if affix then
      local spells = type(affix.spell) == "table" and affix.spell or { affix.spell }
      for _, spellId in ipairs(spells) do table.insert(list, spellId) end
    end
  end
  return list
end

local function GetAffixNamesString(maxTier)
  local parts = {}
  for t = 1, (maxTier or 3) do
    local aff = WEEKLY_AFFIXES[t]
    local color = aff and (AFFIX_COLOR_MAP[aff.name] or "|cffffffff") or "|cffffffff"
    table.insert(parts, string.format("|cffffff00T%d|r: %s%s|r", t, color, aff and aff.name or "None"))
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

--==========================================================
-- Reroll Scheduler (global) – does NOT affect active runs
--==========================================================
local function ResetAffixCountdown()
  NEXT_AFFIX_REROLL_AT = os.time() + (AFFIX_REROLL_INTERVAL_MS / 1000)
  if AUTO_REROLL_EVENT_ID then RemoveEventById(AUTO_REROLL_EVENT_ID) end
  AUTO_REROLL_EVENT_ID = CreateLuaEvent(AutoRerollAffixes, AFFIX_REROLL_INTERVAL_MS, 0)
end

AutoRerollAffixes = function()
  local old = {
    WEEKLY_AFFIXES[1] and WEEKLY_AFFIXES[1].name or "None",
    WEEKLY_AFFIXES[2] and WEEKLY_AFFIXES[2].name or "None",
    WEEKLY_AFFIXES[3] and WEEKLY_AFFIXES[3].name or "None"
  }
  for t = 1, 3 do RerollTierAffix(t) end
  NEXT_AFFIX_REROLL_AT = os.time() + (AFFIX_REROLL_INTERVAL_MS / 1000)
  SendWorldMessage(string.format(
    "|cffffcc00[Mythic]|r Affixes have rotated (auto): T1 %s -> %s, T2 %s -> %s, T3 %s -> %s. Next in ~%s.",
    old[1], WEEKLY_AFFIXES[1].name, old[2], WEEKLY_AFFIXES[2].name, old[3], WEEKLY_AFFIXES[3].name, FormatDurationShort(GetAffixRerollETA())
  ))
end

AUTO_REROLL_EVENT_ID = CreateLuaEvent(AutoRerollAffixes, AFFIX_REROLL_INTERVAL_MS, 0)

--==========================================================
-- Best-time storage (per character and realm)
--==========================================================
local function EnsureBestTimeTables()
  SafeDBExecute([[
    CREATE TABLE IF NOT EXISTS character_mythic_best (
      guid INT UNSIGNED NOT NULL,
      map_id INT UNSIGNED NOT NULL,
      best_seconds INT UNSIGNED NOT NULL,
      best_tier TINYINT UNSIGNED NOT NULL DEFAULT 1,
      best_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (guid, map_id)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8;
  ]])
  SafeDBExecute([[
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
  local my = SafeDBQuery("SELECT best_seconds, best_tier FROM character_mythic_best WHERE guid=%d AND map_id=%d", guid, mapId)
  local realm = SafeDBQuery("SELECT best_seconds, best_tier, holder_name FROM mythic_realm_best WHERE map_id=%d", mapId)
  local myBest    = my    and { sec = my:GetUInt32(0),    tier = my:GetUInt32(1) } or nil
  local realmBest = realm and { sec = realm:GetUInt32(0), tier = realm:GetUInt32(1), name = realm:GetString(2) } or nil
  return myBest, realmBest
end

local function RecordBestTime(mapId, tier, player, elapsedSec)
  local guid = player:GetGUIDLow()
  local name = player:GetName()

  SafeDBExecute([[
    INSERT INTO character_mythic_best (guid,map_id,best_seconds,best_tier,best_at)
    VALUES (%d,%d,%d,%d,NOW())
    ON DUPLICATE KEY UPDATE
      best_seconds = LEAST(best_seconds, VALUES(best_seconds)),
      best_tier    = IF(VALUES(best_seconds) < best_seconds, VALUES(best_tier), best_tier),
      best_at      = IF(VALUES(best_seconds) < best_seconds, NOW(), best_at)
  ]], guid, mapId, elapsedSec, tier)

  SafeDBExecute([[
    INSERT INTO mythic_realm_best (map_id,best_seconds,best_tier,holder_guid,holder_name,best_at)
    VALUES (%d,%d,%d,%d,'%s',NOW())
    ON DUPLICATE KEY UPDATE
      holder_guid = IF(VALUES(best_seconds) < best_seconds, VALUES(holder_guid), holder_guid),
      holder_name = IF(VALUES(best_seconds) < best_seconds, VALUES(holder_name), holder_name),
      best_tier   = IF(VALUES(best_seconds) < best_seconds, VALUES(best_tier), best_tier),
      best_seconds= LEAST(best_seconds, VALUES(best_seconds)),
      best_at     = IF(VALUES(best_seconds) < best_seconds, NOW(), best_at)
  ]], mapId, elapsedSec, tier, guid, name:gsub("'", "''"))
end

--==========================================================
-- Affix Aura Application Loop (buffs enemies around players)
--==========================================================
local function ApplyAuraToNearbyCreatures(player, affixes)
  local map = player:GetMap(); if not map then return end
  local seen = {}
  for _, creature in pairs(player:GetCreaturesInRange(MYTHIC_SCAN_RADIUS)) do
    local guid = creature:GetGUIDLow()
    local faction, entry = creature:GetFaction(), creature:GetEntry()
    if not seen[guid] and creature:IsAlive() and creature:IsInWorld() and not creature:IsPlayer() then
      if not IGNORE_BUFF_ENTRIES[entry] and (not FRIENDLY_FACTIONS[faction] or entry == 26861 or creature:GetName() == "King Ymiron") then
        seen[guid] = true
        for _, spellId in ipairs(affixes) do
          if not creature:HasAura(spellId) then creature:CastSpell(creature, spellId, true) end
        end
      end
    end
  end
end

local function RemoveAffixAurasFromAllCreatures(instanceId, map)
  if not map then return end
  local affixes = MYTHIC_AFFIXES_TABLE[instanceId]; if not affixes then return end
  for _, creature in pairs(map:GetCreatures()) do
    if creature:IsAlive() and creature:IsInWorld() and not creature:IsPlayer() then
      for _, spellId in ipairs(affixes) do
        if creature:HasAura(spellId) then creature:RemoveAura(spellId) end
      end
    end
  end
end

local function StartAuraLoop(player, instanceId, mapId, affixes)
  local guid = player:GetGUIDLow()
  if MYTHIC_LOOP_HANDLERS[instanceId] then RemoveEventById(MYTHIC_LOOP_HANDLERS[instanceId]) end
  local eventId = CreateLuaEvent(function()
    local p = GetPlayerByGUID(guid)
    if p and p:GetMapId() == mapId and MYTHIC_FLAG_TABLE[instanceId] then
      ApplyAuraToNearbyCreatures(p, affixes)
    end
  end, AURA_LOOP_INTERVAL, 0)
  MYTHIC_LOOP_HANDLERS[instanceId] = eventId
end

--==========================================================
-- Rating & Rewards
--==========================================================
local function UpdatePlayerRating(player, tier, deathCount, isSuccess)
  if not player then return end
  local guid, cfg = player:GetGUIDLow(), TIER_CONFIG[tier]; if not cfg then return end
  local q = SafeDBQuery("SELECT total_points FROM character_mythic_rating WHERE guid = %d", guid)
  local current = q and q:GetUInt32(0) or 0
  local new
  if isSuccess then
    local gain, loss = cfg.rating_gain, cfg.rating_loss * (deathCount or 0)
    new = math.min(current + gain - loss, RATING_CAP)
  else
    local timeoutPenalty, deathPenalty = cfg.timeout_penalty, cfg.rating_loss * (deathCount or 0)
    new = math.max(current - timeoutPenalty - deathPenalty, 0)
  end
  local claims = {0,0,0}; if isSuccess then claims[tier] = 1 end
  SafeDBExecute([[
    INSERT INTO character_mythic_rating (guid,total_runs,total_points,claimed_tier1,claimed_tier2,claimed_tier3,last_updated)
    VALUES (%d,1,%d,%d,%d,%d,FROM_UNIXTIME(%d))
    ON DUPLICATE KEY UPDATE total_runs=total_runs+1,total_points=%d,
      claimed_tier1=claimed_tier1+%d, claimed_tier2=claimed_tier2+%d, claimed_tier3=claimed_tier3+%d,
      last_updated=FROM_UNIXTIME(%d)
  ]], guid, new, claims[1], claims[2], claims[3], os.time(), new, claims[1], claims[2], claims[3], os.time())
  return new, current
end

local function AwardMythicPoints(player, tier, deathCount)
  if not player then return end
  local newRating, prev = UpdatePlayerRating(player, tier, deathCount, true); if not newRating then return end
  local cfg = TIER_CONFIG[tier]
  local deaths = deathCount or 0
  local deathPenalty = cfg.rating_loss * deaths
  local actualGain = newRating - prev + deathPenalty

  local deathBlurb = (deaths > 0)
    and string.format(" (|cffff5555%d deaths|r |cffff0000(-%d from deaths)|r)", deaths, deathPenalty) or ""

  local msg = (actualGain == 0)
    and "|cffffcc00No rating added because you are rating capped|r"
    or string.format("|cff00ff00Gained +%d rating|r%s", actualGain, deathBlurb)

  player:SendBroadcastMessage(string.format(
    "%sTier %d completed!|r Mythic+ mode has been ended for this dungeon run.\n%s\nNew Rating: %s%d|r",
    cfg.color, tier, msg, GetRatingColor(newRating), newRating))

  -- Simple reward tiering by rating
  local itemId, count = 45624, 1
  if newRating > 1800 then itemId, count = 49426, 2
  elseif newRating > 1000 then itemId = 49426
  elseif newRating > 500 then itemId = 47241 end
  player:AddItem(itemId, count)
  player:SendBroadcastMessage(string.format("|cffffff00[Mythic]|r Reward: |cffaaff00%s x%d|r", GetItemLink(itemId), count))

  -- Grant next key up to T2/T3
  if tier < 3 then
    local nextKey = KEY_IDS[tier + 1]; player:AddItem(nextKey, 1)
    player:SendBroadcastMessage(string.format("|cffffff00[Mythic]|r Tier %d Keystone granted!", tier + 1))
  end

  local map = player:GetMap(); if map then MYTHIC_COMPLETION_STATE[map:GetInstanceId()] = "completed" end
end

local function PenalizeMythicFailure(player, tier, deathCount)
  if not player then return end
  local newRating, prev = UpdatePlayerRating(player, tier, deathCount, false); if not newRating then return end
  player:SendBroadcastMessage(string.format(
    "|cffffff00Mythic failed:|r |cffff0000-%d rating|r (|cffff5555%d deaths|r)\nNew Rating: %s%d|r",
    prev - newRating, deathCount or 0, GetRatingColor(newRating), newRating))
  local cfg = TIER_CONFIG[tier]; if cfg and player:HasAura(cfg.aura) then player:RemoveAura(cfg.aura) end
  local map = player:GetMap(); if map then MYTHIC_COMPLETION_STATE[map:GetInstanceId()] = "failed" end
end

--==========================================================
-- Timer (timeout aura + expiry handler)
--==========================================================
local function ScheduleMythicTimeout(player, instanceId, tier)
  if not player then return end
  local cfg = TIER_CONFIG[tier]; if not cfg then return end

  local auraId   = cfg.aura
  local guid     = player:GetGUIDLow()
  local map      = player:GetMap()
  local minutes  = ComputeTierMinutes(map and map:GetMapId() or 0, tier)
  local duration = minutes * 60000

  player:AddAura(auraId, player)

  -- forward-declare so both closures can cancel safely
  local keepAuraEventId
  local expireEventId

  keepAuraEventId = CreateLuaEvent(function()
    local p = GetPlayerByGUID(guid)
    if not p or not MYTHIC_FLAG_TABLE[instanceId] or MYTHIC_TIMER_EXPIRED[instanceId] then return end

    -- Tamper: aura missing -> fail immediately
    if not p:HasAura(auraId) then
      MYTHIC_TIMER_EXPIRED[instanceId] = true
      MYTHIC_MODE_ENDED[instanceId]    = true
      p:SendBroadcastMessage("|cffff0000[Mythic]|r Timer aura removed; run failed.")
      MYTHIC_COMPLETION_STATE[instanceId] = "failed"

      local mapNow = p:GetMap()
      if mapNow then
        for _, pl in pairs(mapNow:GetPlayers() or {}) do
          local g = pl:GetGUIDLow()
          local deaths = (MYTHIC_DEATHS[instanceId] and MYTHIC_DEATHS[instanceId][g]) or 0
          PenalizeMythicFailure(pl, tier, deaths)
        end
        RemoveAffixAurasFromAllCreatures(instanceId, mapNow)
      end

      if keepAuraEventId then RemoveEventById(keepAuraEventId) end
      if expireEventId   then RemoveEventById(expireEventId)   end
      CleanupMythicInstance(instanceId)
    end
  end, 5000, 0)

  expireEventId = CreateLuaEvent(function()
    local p = GetPlayerByGUID(guid)
    if p and MYTHIC_FLAG_TABLE[instanceId] and not MYTHIC_TIMER_EXPIRED[instanceId] then
      MYTHIC_TIMER_EXPIRED[instanceId]   = true
      MYTHIC_MODE_ENDED[instanceId]      = true
      MYTHIC_COMPLETION_STATE[instanceId] = "failed"
      p:SendBroadcastMessage("|cffff0000[Mythic]|r Time limit exceeded. You are no longer eligible for rewards.")
      if p:HasAura(auraId) then p:RemoveAura(auraId) end

      local mapNow = p:GetMap()
      if mapNow then
        for _, pl in pairs(mapNow:GetPlayers() or {}) do
          local g = pl:GetGUIDLow()
          local deaths = (MYTHIC_DEATHS[instanceId] and MYTHIC_DEATHS[instanceId][g]) or 0
          PenalizeMythicFailure(pl, tier, deaths)
        end
        RemoveAffixAurasFromAllCreatures(instanceId, mapNow)
      end

      CleanupMythicInstance(instanceId)
    end
    if keepAuraEventId then RemoveEventById(keepAuraEventId) end
  end, duration, 1)
end

--==========================================================
-- Gossip UI (Pedestal/NPC)
--==========================================================
local function GetPlayerRatingLine(player)
  local guid = player:GetGUIDLow()
  local q = SafeDBQuery("SELECT total_points, total_runs FROM character_mythic_rating WHERE guid = %d", guid)
  if not q then return "|cff66ccff[Mythic]|r Rating: |cffffcc000|r (no runs yet)" end
  local rating, runs = q:GetUInt32(0), q:GetUInt32(1)
  return string.format("|cff66ccff[Mythic]|r Rating: %s%d|r  (|cffffcc00%d runs|r)", GetRatingColor(rating), rating, runs)
end

local function Gossip_ShowAffixTierMenu(player, creature, tier)
  player:GossipClearMenu()
  local current     = WEEKLY_AFFIXES[tier]
  local currentName = current and current.name or "None"
  local header      = string.format("|cffffff00Tier %d Affix|r\nCurrent: %s", tier, Colorize(currentName, AFFIX_COLOR_MAP[currentName]))
  player:GossipMenuAddItem(0, header, 0, 999)
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
  player:GossipMenuAddItem(0, "|cffff6600Change Mythic affixes|r", 0, 999)
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

  player:GossipClearMenu()
  player:GossipMenuAddItem(0, GetPlayerRatingLine(player), 0, 999)

  -- Best-times panel (character + realm) for this map
  do
    local myBest, realmBest = GetBestTimesForMap(map:GetMapId(), player:GetGUIDLow())
    local myLine = myBest
      and string.format("|cff66ccffYour best:|r %s (T%d)", FormatRaceTime(myBest.sec), myBest.tier)
      or  "|cff66ccffYour best:|r —"
    local realmLine = realmBest
      and string.format("|cffffff00Realm best:|r %s (T%d) by %s", FormatRaceTime(realmBest.sec), realmBest.tier, realmBest.name)
      or  "|cffffff00Realm best:|r —"
    player:GossipMenuAddItem(0, myLine .. "   " .. realmLine, 0, 999)
  end

  local completionState = MYTHIC_COMPLETION_STATE[instanceId]
  if completionState == "completed" then
    player:GossipMenuAddItem(0, "|cff00ff00Good job, Mythic Champion! You've conquered this challenge!|r", 0, 999)
  elseif completionState == "failed" then
    player:GossipMenuAddItem(0, "|cffff0000You've failed, but try again in a different dungeon!|r", 0, 999)
  elseif MYTHIC_FLAG_TABLE[instanceId] then
    player:GossipMenuAddItem(0, "|cff000000You're already in Mythic mode! Hurry! Go fight!|r", 0, 999)
  else
    -- Weekly affixes + ETA
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
    player:GossipMenuAddItem(0, header, 0, 0)

    if MYTHIC_KILL_LOCK[instanceId] then
      local lockMsg = "|cffff0000[Mythic]|r Mythic+ is locked. Reset the dungeon to enable keystone use."
      player:GossipMenuAddItem(0, lockMsg, 0, 999)
      player:SendBroadcastMessage(lockMsg)
    else
      for tier = 1, 3 do
        local cfg = TIER_CONFIG[tier]
        player:GossipMenuAddItem(10, string.format("%sTier %d|r", cfg.color, tier), 0, 100 + tier, false, "", 0, ICONS[tier])
      end
    end
  end

  if player:IsGM() then player:GossipMenuAddItem(0, "|cffff6600Change Mythic affixes|r", 0, 200) end
  player:GossipSendMenu(1, creature)
end

function Pedestal_OnGossipSelect(_, player, creature, _, intid)
  if intid == 999 then
    local map = player:GetMap()
    if map then
      local state = MYTHIC_COMPLETION_STATE[map:GetInstanceId()]
      if     state == "completed" then player:SendBroadcastMessage("|cff00ff00[Mythic]|r Congratulations! Reset the dungeon to attempt a higher tier or try other dungeons!")
      elseif state == "failed"    then player:SendBroadcastMessage("|cffff0000[Mythic]|r Don't give up! Reset this dungeon or try a different one with a fresh keystone!") end
    end
    player:GossipComplete(); return
  end

  if intid == 200 then
    if not player:IsGM() then player:SendBroadcastMessage("|cffff0000[Mythic]|r You do not have permission to change affixes."); player:GossipComplete(); return end
    Gossip_ShowAffixRootMenu(player, creature); return
  end

  if intid == 290 then Pedestal_OnGossipHello(nil, player, creature); return end

  if intid == 211 or intid == 212 or intid == 213 then
    if not player:IsGM() then player:SendBroadcastMessage("|cffff0000[Mythic]|r You do not have permission to change affixes."); player:GossipComplete(); return end
    Gossip_ShowAffixTierMenu(player, creature, (intid == 211 and 1) or (intid == 212 and 2) or 3); return
  end

  if intid >= 300 then
    if not player:IsGM() then player:SendBroadcastMessage("|cffff0000[Mythic]|r You do not have permission to change affixes."); player:GossipComplete(); return end
    local code = intid - 300; local tier, idx = math.floor(code/10), code%10
    if tier < 1 or tier > 3 then player:GossipComplete(); return end
    local chosen = (WEEKLY_AFFIX_POOL[tier] or {})[idx]
    if not chosen then player:SendBroadcastMessage("|cffff0000[Mythic]|r Invalid affix selection."); player:GossipComplete(); return end

    local before = WEEKLY_AFFIXES[tier] and WEEKLY_AFFIXES[tier].name or "None"
    WEEKLY_AFFIXES[tier] = chosen
    ResetAffixCountdown()

    SendWorldMessage(string.format("|cffffcc00[Mythic]|r Tier %d affix set: %s -> %s", tier, before, chosen.name))
    player:SendBroadcastMessage("|cff66ccff[Mythic]|r New affixes: " .. GetAffixNamesString(3))
    Gossip_ShowAffixTierMenu(player, creature, tier); return
  end

  if intid >= 101 and intid <= 103 then
    local map = player:GetMap(); if not map then player:SendBroadcastMessage("Error: No map context."); player:GossipComplete(); return end
    local instanceId, tier = map:GetInstanceId(), intid - 100
    local keyId = KEY_IDS[tier]

    -- Pre-flight checks
    if MYTHIC_KILL_LOCK[instanceId] then player:SendBroadcastMessage("|cffff0000[Mythic]|r A creature was already killed. Reset the dungeon to use a keystone."); player:GossipComplete(); return end
    if MYTHIC_FLAG_TABLE[instanceId] then player:SendBroadcastMessage("|cffff0000Mythic mode has already been activated in this instance.|r"); player:GossipComplete(); return end
    if not player:HasItem(keyId) then player:SendBroadcastMessage("You do not have the required Tier " .. tier .. " Keystone."); player:GossipComplete(); return end
    if map:GetDifficulty() == 0 then player:SendBroadcastMessage("|cffff0000Mythic keys cannot be used in Normal mode dungeons.|r"); player:GossipComplete(); return end

    -- Activate run
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

    ScheduleMythicTimeout(player, instanceId, tier)

    local q = SafeDBQuery("SELECT total_points FROM character_mythic_rating WHERE guid = %d", guid)
    local cur = q and q:GetUInt32(0) or 0
    player:SendBroadcastMessage(string.format("%sTier %d Keystone|r inserted.\nAffixes: %s\nCurrent Rating: %s%d|r",
      cfg.color, tier, table.concat(names, ", "), GetRatingColor(cur), cur))

    -- Rating-based greeting
    creature:SendUnitSay((function(r)
      if r >= 1800 then return "I can think of none better for this trial. Show them no mercy, Mythic Champion!"
      elseif r >= 1000 then return "You will surely triumph in this challenge!"
      elseif r >= 500  then return "You may yet prevail in the trials ahead."
      else return "Good luck... you'll need it." end
    end)(cur), 0)

    player:RemoveItem(keyId, 1)

    ApplyAuraToNearbyCreatures(player, affixes)
    StartAuraLoop(player, instanceId, map:GetMapId(), affixes)

    local affix_str = SerializeAffixes(affixes)
    SafeDBExecute([[
      INSERT INTO character_mythic_instance_state (guid, instance_id, map_id, tier, affix_spells, created_at)
      VALUES (%d, %d, %d, %d, '%s', FROM_UNIXTIME(%d))
      ON DUPLICATE KEY UPDATE tier=VALUES(tier), affix_spells=VALUES(affix_spells), created_at=VALUES(created_at)
    ]], guid, instanceId, map:GetMapId(), tier, affix_str, os.time())

    player:GossipComplete()
  end
end

RegisterCreatureGossipEvent(PEDESTAL_NPC_ENTRY, 1, Pedestal_OnGossipHello)
RegisterCreatureGossipEvent(PEDESTAL_NPC_ENTRY, 2, Pedestal_OnGossipSelect)

--==========================================================
-- Player Death Tracking
--==========================================================
RegisterPlayerEvent(8, function(_, killer, victim)
  if not victim or not victim:IsPlayer() then return end
  local map = victim:GetMap(); if not map or map:GetDifficulty() == 0 then return end
  local instanceId = map:GetInstanceId(); if not MYTHIC_FLAG_TABLE[instanceId] then return end
  local guid = victim:GetGUIDLow()
  MYTHIC_DEATHS[instanceId] = MYTHIC_DEATHS[instanceId] or {}
  MYTHIC_DEATHS[instanceId][guid] = (MYTHIC_DEATHS[instanceId][guid] or 0) + 1
end)

--==========================================================
-- Kill-Lock (prevent post-kill key insert)
--==========================================================
RegisterPlayerEvent(7, function(_, killer, victim)
  if not killer or not killer:IsPlayer() or not victim or victim:GetObjectType() ~= "Creature" then return end
  local map = killer:GetMap(); if not map or not map:IsDungeon() or map:GetDifficulty() < 1 then return end
  local instanceId, mapId = map:GetInstanceId(), map:GetMapId()
  if killer:GetLevel() < 80 then return end
  if MYTHIC_FLAG_TABLE[instanceId] or MYTHIC_MODE_ENDED[instanceId] or MYTHIC_KILL_LOCK[instanceId] then return end
  local finalBoss = MYTHIC_FINAL_BOSSES[mapId] and MYTHIC_FINAL_BOSSES[mapId].final
  if finalBoss and victim:GetEntry() == finalBoss then return end
  if not MYTHIC_HOSTILE_FACTIONS[victim:GetFaction()] then return end
  MYTHIC_KILL_LOCK[instanceId] = true
  local msg = "|cffff0000[Mythic]|r Mythic+ is now locked because a hostile enemy was slain. Reset the dungeon to enable keystone use."
  for _, p in pairs(map:GetPlayers() or {}) do p:SendBroadcastMessage(msg) end
end)

--==========================================================
-- Resume Logic (on login/relog inside instance)
--==========================================================
RegisterPlayerEvent(28, function(_, player)
  local map = player:GetMap(); if not map then return end
  local instanceId, mapId, guid = map:GetInstanceId(), map:GetMapId(), player:GetGUIDLow()
  if MYTHIC_COMPLETION_STATE[instanceId] == "failed" or MYTHIC_COMPLETION_STATE[instanceId] == "completed" then return end

  local res = SafeDBQuery("SELECT tier, UNIX_TIMESTAMP(created_at), affix_spells FROM character_mythic_instance_state WHERE guid = %d AND instance_id = %d AND map_id = %d",
    guid, instanceId, mapId)
  if not res then return end

  local tier, created = res:GetUInt32(0), res:GetUInt32(1)
  if os.time() - created > INSTANCE_STATE_TIMEOUT then
    MYTHIC_MODE_ENDED[instanceId] = nil
    SafeDBExecute("DELETE FROM character_mythic_instance_state WHERE guid = %d AND instance_id = %d AND map_id = %d", guid, instanceId, mapId)
    return
  end

  local saved_affixes = res:GetString(2)
  local affixes = (#saved_affixes > 0) and ParseAffixes(saved_affixes) or GetAffixSet(tier)

  MYTHIC_FLAG_TABLE[instanceId]          = true
  MYTHIC_AFFIXES_TABLE[instanceId]       = affixes
  MYTHIC_REWARD_CHANCE_TABLE[instanceId] = (tier == 1 and 1.5) or (tier == 2 and 2.0) or 5.0
  MYTHIC_TIER_TABLE[instanceId]          = tier
  MYTHIC_COMPLETION_STATE[instanceId]    = "active"

  player:SendBroadcastMessage("|cffffff00[Mythic]|r Resuming active Mythic+ affixes.")
  ApplyAuraToNearbyCreatures(player, affixes)
  if not MYTHIC_LOOP_HANDLERS[instanceId] then StartAuraLoop(player, instanceId, mapId, affixes) end

  -- Rebuild remaining timer window
  local totalMin  = ComputeTierMinutes(mapId, tier)
  local elapsed   = os.time() - created
  local remaining = math.max(0, totalMin * 60 - elapsed)
  local auraId    = TIER_CONFIG[tier] and TIER_CONFIG[tier].aura or 0

  if remaining == 0 then
    MYTHIC_TIMER_EXPIRED[instanceId]   = true
    MYTHIC_COMPLETION_STATE[instanceId] = "failed"
    player:SendBroadcastMessage("|cffff0000[Mythic]|r Time limit exceeded while you were away.")
    if auraId ~= 0 and player:HasAura(auraId) then player:RemoveAura(auraId) end

    local mapNow = player:GetMap()
    if mapNow then
      for _, pl in pairs(mapNow:GetPlayers() or {}) do
        local g = pl:GetGUIDLow()
        local deaths = (MYTHIC_DEATHS[instanceId] and MYTHIC_DEATHS[instanceId][g]) or 0
        PenalizeMythicFailure(pl, tier, deaths)
      end
    end
    CleanupMythicInstance(instanceId)
    return
  end

  if auraId ~= 0 and not player:HasAura(auraId) then player:AddAura(auraId, player) end

  -- forward-declare so both closures can cancel safely
  local keepAuraEventId
  local expireEventId

  keepAuraEventId = CreateLuaEvent(function()
    local p = GetPlayerByGUID(guid)
    if not p or not MYTHIC_FLAG_TABLE[instanceId] or MYTHIC_TIMER_EXPIRED[instanceId] then return end

    -- Tamper on resume
    if auraId ~= 0 and not p:HasAura(auraId) then
      MYTHIC_TIMER_EXPIRED[instanceId]   = true
      MYTHIC_MODE_ENDED[instanceId]      = true
      MYTHIC_COMPLETION_STATE[instanceId] = "failed"
      p:SendBroadcastMessage("|cffff0000[Mythic]|r Timer aura removed; run failed.")

      local mapNow = p:GetMap()
      if mapNow then
        for _, pl in pairs(mapNow:GetPlayers() or {}) do
          local g = pl:GetGUIDLow()
          local deaths = (MYTHIC_DEATHS[instanceId] and MYTHIC_DEATHS[instanceId][g]) or 0
          PenalizeMythicFailure(pl, tier, deaths)
        end
        RemoveAffixAurasFromAllCreatures(instanceId, mapNow)
      end

      if keepAuraEventId then RemoveEventById(keepAuraEventId) end
      if expireEventId   then RemoveEventById(expireEventId)   end
      CleanupMythicInstance(instanceId)
    end
  end, 5000, 0)

  expireEventId = CreateLuaEvent(function()
    local p = GetPlayerByGUID(guid)
    if p and MYTHIC_FLAG_TABLE[instanceId] and not MYTHIC_TIMER_EXPIRED[instanceId] then
      MYTHIC_TIMER_EXPIRED[instanceId]   = true
      MYTHIC_MODE_ENDED[instanceId]      = true
      MYTHIC_COMPLETION_STATE[instanceId] = "failed"
      p:SendBroadcastMessage("|cffff0000[Mythic]|r Time limit exceeded. You are no longer eligible for rewards.")
      if auraId ~= 0 and p:HasAura(auraId) then p:RemoveAura(auraId) end

      local mapNow = p:GetMap()
      if mapNow then
        for _, pl in pairs(mapNow:GetPlayers() or {}) do
          local g = pl:GetGUIDLow()
          local deaths = (MYTHIC_DEATHS[instanceId] and MYTHIC_DEATHS[instanceId][g]) or 0
          PenalizeMythicFailure(pl, tier, deaths)
        end
        RemoveAffixAurasFromAllCreatures(instanceId, mapNow)
      end

      CleanupMythicInstance(instanceId)
    end
    if keepAuraEventId then RemoveEventById(keepAuraEventId) end
  end, remaining * 1000, 1)
end)

--==========================================================
-- Login Blurb (affixes + ETA)
--==========================================================
RegisterPlayerEvent(3, function(_, player)
  local parts = {}
  for _, aff in ipairs(WEEKLY_AFFIXES) do table.insert(parts, (AFFIX_COLOR_MAP[aff.name] or "|cffffffff") .. aff.name .. "|r") end
  local eta = GetAffixRerollETA()
  player:SendBroadcastMessage("|cffffcc00[Mythic]|r This week's affixes: " .. table.concat(parts, ", ")
    .. "  |  Next reroll in: " .. ((eta > 0) and FormatDurationShort(eta) or "soon"))
end)

--==========================================================
-- Command Handler (.simclean, .sim, .mythicroll, etc.)
--==========================================================
RegisterPlayerEvent(42, function(_, player, command)
  if not player then return false end
  local cmd = command:lower():gsub("[#./]", "")
  local guid, now = player:GetGUIDLow(), os.time()

  -- GM: remove nearby sim-spawned chests
  if cmd:sub(1,8) == "simclean" then
    if not player:IsGM() then player:SendBroadcastMessage("|cffff0000[Mythic]|r You do not have permission to use this command."); return false end
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
    player:SendBroadcastMessage(string.format("|cffffcc00[Mythic]|r simclean: removed %d chest(s) within %d yards.", removed, radius))
    return false
  end

  -- Affix display + countdown (rate-limited per player)
  if cmd == "mythictimer" then
    local last = __MYTHIC_TIMER_COOLDOWN__[guid] or 0
    if now - last < TIMER_COMMAND_COOLDOWN then
      local remain = TIMER_COMMAND_COOLDOWN - (now - last)
      player:SendBroadcastMessage("|cffffcc00[Mythic]|r You can use |cffffff00.mythictimer|r again in " .. FormatDurationShort(remain) .. ".")
      return false
    end
    __MYTHIC_TIMER_COOLDOWN__[guid] = now

    local eta  = GetAffixRerollETA()
    player:SendBroadcastMessage("|cff66ccff[Mythic]|r Current affixes: " .. GetAffixNamesString(3))
    player:SendBroadcastMessage("|cffffff00Next reroll in:|r " .. ((eta > 0) and FormatDurationShort(eta) or "soon"))
    return false
  end

  -- GM: simulate chest (no rating/flags)
  if cmd:sub(1,3) == "sim" or cmd:sub(1,8) == "simulate" then
    if not player:IsGM() then player:SendBroadcastMessage("|cffff0000[Mythic]|r You do not have permission to use this command."); return false end
    local tokens = {}; for w in cmd:gmatch("%S+") do table.insert(tokens, w) end
    local tier
    if tonumber(tokens[2]) then tier = tonumber(tokens[2])
    elseif tokens[2] == "tier" and tonumber(tokens[3]) then tier = tonumber(tokens[3]) end
    if not tier or tier < 1 or tier > 3 then player:SendBroadcastMessage("|cffff0000[Mythic]|r Usage: .sim <1-3>  or  .sim tier <1-3>"); return false end

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
      local guidLow = chest:GetGUIDLow()
      CreateLuaEvent(function()
        local go = GetGameObjectByGUID(guidLow)
        if go then
          if go.Despawn then go:Despawn() end
          go:RemoveFromWorld()
        end
      end, 60000, 1)
    end

    player:SendBroadcastMessage(string.format("|cffffcc00[Mythic]|r Simulated chest spawned (Tier %d). Auto-despawns in 60s. No rating or tokens granted.", tier))
    return false
  end

  -- GM: roll/set affixes
  if cmd == "mythicroll" or cmd:find("^mythicroll%s") then
    if not player:IsGM() then player:SendBroadcastMessage("|cffff0000[Mythic]|r You do not have permission to use this command."); return false end

    local tokens = {}; for w in cmd:gmatch("%S+") do table.insert(tokens, w) end

    -- ".mythicroll" or ".mythicroll all" → reroll all
    if tokens[2] == nil or (tokens[2] == "all" and tokens[3] == nil) then
      local old = {
        WEEKLY_AFFIXES[1] and WEEKLY_AFFIXES[1].name or "None",
        WEEKLY_AFFIXES[2] and WEEKLY_AFFIXES[2].name or "None",
        WEEKLY_AFFIXES[3] and WEEKLY_AFFIXES[3].name or "None"
      }
      for t = 1, 3 do RerollTierAffix(t) end
      ResetAffixCountdown()
      SendWorldMessage(string.format("|cffffcc00[Mythic]|r Affixes re-rolled: T1 %s -> %s, T2 %s -> %s, T3 %s -> %s",
        old[1], WEEKLY_AFFIXES[1].name, old[2], WEEKLY_AFFIXES[2].name, old[3], WEEKLY_AFFIXES[3].name))
      return false
    end

    -- ".mythicroll tier <n> [affix...]"
    if tokens[2] ~= "tier" or not tonumber(tokens[3]) then
      player:SendBroadcastMessage("|cffff0000[Mythic]|r Usage: .mythicroll  |  .mythicroll all  |  .mythicroll tier <1-3>  |  .mythicroll tier <1-3> <affix>")
      return false
    end

    local tier = tonumber(tokens[3])
    if tier < 1 or tier > 3 then player:SendBroadcastMessage("|cffff0000[Mythic]|r Tier must be 1, 2, or 3."); return false end

    if #tokens == 3 then
      local before = WEEKLY_AFFIXES[tier] and WEEKLY_AFFIXES[tier].name or "None"
      local after  = RerollTierAffix(tier)
      if after then
        ResetAffixCountdown()
        SendWorldMessage(string.format("|cffffcc00[Mythic]|r Tier %d affix re-rolled: %s -> %s", tier, before, after.name))
        player:SendBroadcastMessage("|cff66ccff[Mythic]|r New affixes: " .. GetAffixNamesString(3))
      end
      return false
    end

    local desired = table.concat(tokens, " ", 4):gsub("^%s+", ""):gsub("%s+$", ""):lower()
    if desired == "" then player:SendBroadcastMessage("|cffff0000[Mythic]|r Missing affix name. Example: .mythicroll tier 1 resistant"); return false end
    local aff = FindAffixByNameInTier(tier, desired)
    if not aff then
      local names = {}; for _, a in ipairs(WEEKLY_AFFIX_POOL[tier] or {}) do table.insert(names, a.name:lower()) end
      player:SendBroadcastMessage("|cffff0000[Mythic]|r Invalid affix for Tier " .. tier .. ". Valid: " .. table.concat(names, ", "))
      return false
    end

    local before = WEEKLY_AFFIXES[tier] and WEEKLY_AFFIXES[tier].name or "None"
    WEEKLY_AFFIXES[tier] = aff
    ResetAffixCountdown()
    SendWorldMessage(string.format("|cffffcc00[Mythic]|r Tier %d affix set: %s -> %s", tier, before, aff.name))
    player:SendBroadcastMessage("|cff66ccff[Mythic]|r New affixes: " .. GetAffixNamesString(3))
    return false
  end

  -- Player: rating snapshot (rate-limited) and GM: set rating
  if cmd:sub(1,12) == "mythicrating" then
    local tokens = {}; for w in cmd:gmatch("%S+") do table.insert(tokens, w) end

    -- GM: .mythicrating set <value>
    if tokens[2] == "set" then
      if not player:IsGM() then
        player:SendBroadcastMessage("|cffff0000[Mythic]|r You do not have permission to set ratings.")
        return false
      end
      local newVal = tonumber(tokens[3])
      if not newVal then
        player:SendBroadcastMessage("|cffff0000[Mythic]|r Usage: .mythicrating set <number>")
        return false
      end
      if newVal < 0 then newVal = 0 end
      if newVal > RATING_CAP then newVal = RATING_CAP end

      local pguid = player:GetGUIDLow()
      SafeDBExecute([[
        INSERT INTO character_mythic_rating (guid,total_runs,total_points,claimed_tier1,claimed_tier2,claimed_tier3,last_updated)
        VALUES (%d,0,%d,0,0,0,NOW())
        ON DUPLICATE KEY UPDATE total_points=%d,last_updated=NOW()
      ]], pguid, newVal, newVal)

      player:SendBroadcastMessage(string.format("|cff66ccff[Mythic]|r Your rating has been set to %s%d|r", GetRatingColor(newVal), newVal))
      return false
    end

    -- Normal .mythicrating (rate-limited for players)
    local last = __MYTHIC_RATING_COOLDOWN__[guid] or 0
    if now - last < COMMAND_COOLDOWN then
      player:SendBroadcastMessage("|cffffcc00[Mythic]|r You can only use this command once every 5 minutes.")
      return false
    end
    __MYTHIC_RATING_COOLDOWN__[guid] = now

    local q = SafeDBQuery("SELECT total_points, total_runs FROM character_mythic_rating WHERE guid = %d", guid)
    if q then
      local rating, runs = q:GetUInt32(0), q:GetUInt32(1)
      player:SendBroadcastMessage(string.format("|cff66ccff[Mythic]|r Rating: %s%d|r (|cffffcc00%d runs completed|r)", GetRatingColor(rating), rating, runs))
    else
      player:SendBroadcastMessage("|cffff0000[Mythic]|r No rating found. Complete a Mythic+ dungeon to begin tracking.")
    end
    return false
  end

  -- GM: instant leaderboard wipe (best-times only, no confirmation)
  if cmd == "mythicleaderboardreset" or cmd == "mythiclbreset" then
    if not player:IsGM() then
      player:SendBroadcastMessage("|cffff0000[Mythic]|r You do not have permission to use this command.")
      return false
    end
    CharDBExecute("TRUNCATE TABLE character_mythic_best")
    CharDBExecute("TRUNCATE TABLE mythic_realm_best")
    player:SendBroadcastMessage("|cff00ff00[Mythic]|r Leaderboards wiped (character & realm best times).")
    SendWorldMessage("|cffffcc00[Mythic]|r A Game Master has reset the Mythic+ leaderboards.")
    return false
  end

  -- Help / GM help
  if cmd == "mythichelp" then
    player:SendBroadcastMessage("|cff66ccff[Mythic]|r Available commands:")
    player:SendBroadcastMessage("|cffffff00.mythicrating|r - View your Mythic+ rating and runs.")
    player:SendBroadcastMessage("|cffffff00.mythictimer|r - Current affixes & next reroll ETA (5 min cooldown).")
    player:SendBroadcastMessage("|cffffff00.mythichelp|r - Show this help menu.")
    if player:IsGM() then
      player:SendBroadcastMessage("|cffff6600GM note:|r You can also modify affixes by talking to the Mythic Pedestal NPC while GM mode is enabled.")
      player:SendBroadcastMessage("|cffff6600.mythicroll all|r - GM: Reroll all affixes.")
      player:SendBroadcastMessage("|cffff6600.mythicroll tier <1-3>|r - GM: Reroll a specific tier.")
      player:SendBroadcastMessage("|cffff6600.mythicroll tier <1-3> <affix>|r - GM: Set a specific affix (e.g., resistant).")
      player:SendBroadcastMessage("|cffff6600.sim tier <1-3>|r - GM: Spawn a Tier chest without awarding rating or tokens.")
      player:SendBroadcastMessage("|cffff6600.mythicreset|r - GM: Start full server rating reset.")
      player:SendBroadcastMessage("|cffff6600.mythicreset confirm|r - GM: Confirm the reset within 30 seconds.")
      player:SendBroadcastMessage("|cffff6600.simclean [radius]|r - GM: Remove nearby sim-spawned chests (default radius 80).")
      player:SendBroadcastMessage("|cffff6600.mythiclbreset|r - GM: Reset best-time leaderboards instantly.")
      player:SendBroadcastMessage("|cffff6600.mythicrating set <n>|r - GM: Force-set your rating.")
    else
      player:SendBroadcastMessage("|cffaaaaaa(More settings are available with GM mode enabled.)|r")
    end
    return false
  end

  -- GM: global rating reset (two-step confirm)
  if cmd == "mythicreset" then
    if not player:IsGM() then
      player:SendBroadcastMessage("|cffff0000[Mythic]|r You do not have permission to use this command.")
    else
      __MYTHIC_RESET_PENDING__[guid] = now
      player:SendBroadcastMessage("|cffffff00[Mythic]|r Type |cff00ff00.mythicreset confirm|r within 30 seconds to confirm full reset.")
    end
    return false
  end

  if cmd == "mythicresetconfirm" or cmd:match("^mythicreset%s+confirm$") then
    local pendingTime = __MYTHIC_RESET_PENDING__[guid]
    if not pendingTime or now - pendingTime > RESET_CONFIRM_TIMEOUT then
      player:SendBroadcastMessage("|cffff0000[Mythic]|r No reset pending or confirmation expired. Use |cff00ff00.mythicreset|r first.")
    else
      __MYTHIC_RESET_PENDING__[guid] = nil
      CharDBExecute([[
        UPDATE character_mythic_rating
        SET total_points=0, total_runs=0,
            claimed_tier1=0, claimed_tier2=0, claimed_tier3=0,
            last_updated=NOW()
      ]])
      player:SendBroadcastMessage("|cff00ff00[Mythic]|r All player ratings and run counts have been reset.")
      SendWorldMessage("|cffffcc00[Mythic]|r A Game Master has reset all Mythic+ player ratings.")
    end
    return false
  end
end)

--==========================================================
-- Final Boss Kill Hook → Score/Reward/Chest/Cleanup
--==========================================================
for mapId, data in pairs(MYTHIC_FINAL_BOSSES) do
  local bossId = data.final
  if bossId then
    RegisterCreatureEvent(bossId, 4, function(_, creature)
      local map = creature:GetMap(); if not map then return end
      local instanceId = map:GetInstanceId()
      MYTHIC_MODE_ENDED[instanceId] = true
      if not MYTHIC_FLAG_TABLE[instanceId] then return end

      local expired = MYTHIC_TIMER_EXPIRED[instanceId]
      local tier    = MYTHIC_TIER_TABLE[instanceId] or 1

      -- Snapshot deaths per player for rating calc
      local playerDeaths = {}
      for _, p in pairs(map:GetPlayers() or {}) do
        local g = p:GetGUIDLow()
        playerDeaths[g] = MYTHIC_DEATHS[instanceId] and MYTHIC_DEATHS[instanceId][g] or 0
      end

      -- Award or fail per player + record run time if success
      for _, p in pairs(map:GetPlayers() or {}) do
        if p:IsAlive() and p:IsInWorld() then
          if expired then
            p:SendBroadcastMessage("|cffff0000[Mythic]|r Time expired. No rewards granted.")
            MYTHIC_COMPLETION_STATE[instanceId] = "failed"
          else
            AwardMythicPoints(p, tier, playerDeaths[p:GetGUIDLow()] or 0)

            local startRow = SafeDBQuery(
              "SELECT UNIX_TIMESTAMP(created_at) FROM character_mythic_instance_state WHERE guid=%d AND instance_id=%d AND map_id=%d",
              p:GetGUIDLow(), instanceId, map:GetMapId())
            if startRow then
              local startedAt = startRow:GetUInt32(0)
              local elapsed = math.max(0, os.time() - startedAt)
              RecordBestTime(map:GetMapId(), tier, p, elapsed)
              p:SendBroadcastMessage(string.format("|cffaaff00[Mythic]|r Time this run: %s", FormatRaceTime(elapsed)))
            end

            local cfg = TIER_CONFIG[tier]; if cfg and p:HasAura(cfg.aura) then p:RemoveAura(cfg.aura) end
          end
        end
      end

      -- Spawn chest behind boss if not expired
      if not expired then
        local x,y,z,o = creature:GetX(), creature:GetY(), creature:GetZ(), creature:GetO()
        x, y = x - math.cos(o) * 2, y - math.sin(o) * 2
        SpawnMythicRewardChest(x, y, z, o, map, instanceId, tier)
      end

      RemoveAffixAurasFromAllCreatures(instanceId, map)
      CleanupMythicInstance(instanceId)
    end)
  end
end

--==========================================================
-- Chest Spawn (real run) — one per instance; faction swap on T2
--==========================================================
function SpawnMythicRewardChest(x, y, z, o, map, instanceId, tier)
  if MYTHIC_CHEST_SPAWNED[instanceId] then return end
  local chestEntry
  if tier == 2 then
    local team
    for _, p in pairs(map:GetPlayers() or {}) do if p:IsAlive() then team = p:GetTeam(); break end end
    chestEntry = (team == 1) and 900013 or 900011
  else
    chestEntry = CHEST_ENTRIES[tier] or CHEST_ENTRIES[1]
  end
  PerformIngameSpawn(2, chestEntry, map:GetMapId(), instanceId, x, y, z, o)
  MYTHIC_CHEST_SPAWNED[instanceId] = true
end

--==========================================================
-- Cleanup (stop loops, clear flags, forget resume token)
--==========================================================
function CleanupMythicInstance(instanceId)
  if MYTHIC_LOOP_HANDLERS[instanceId] then
    RemoveEventById(MYTHIC_LOOP_HANDLERS[instanceId])
    MYTHIC_LOOP_HANDLERS[instanceId] = nil
  end
  MYTHIC_FLAG_TABLE[instanceId]          = nil
  MYTHIC_AFFIXES_TABLE[instanceId]       = nil
  MYTHIC_REWARD_CHANCE_TABLE[instanceId] = nil
  MYTHIC_TIER_TABLE[instanceId]          = nil
  MYTHIC_DEATHS[instanceId]              = nil
  MYTHIC_TIMER_EXPIRED[instanceId]       = nil
  MYTHIC_KILL_LOCK[instanceId]           = nil
  SafeDBExecute("DELETE FROM character_mythic_instance_state WHERE instance_id = %d", instanceId)
end
