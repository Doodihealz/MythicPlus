print("[Mythic] Mythic script loaded successfully! Enjoy!")
dofile("C:/Build/bin/RelWithDebInfo/lua_scripts/Generic/MythicPlus/MythicBosses.lua")

local PEDESTAL_NPC_ENTRY = 900001

MYTHIC_TIMER_EXPIRED = MYTHIC_TIMER_EXPIRED or {}
MYTHIC_KILL_LOCK = MYTHIC_KILL_LOCK or {}
MYTHIC_DEATHS = MYTHIC_DEATHS or {}
MYTHIC_FLAG_TABLE = MYTHIC_FLAG_TABLE or {}
MYTHIC_AFFIXES_TABLE = MYTHIC_AFFIXES_TABLE or {}
MYTHIC_REWARD_CHANCE_TABLE = MYTHIC_REWARD_CHANCE_TABLE or {}
MYTHIC_CHEST_SPAWNED = MYTHIC_CHEST_SPAWNED or {}
MYTHIC_FINAL_BOSSES = MYTHIC_FINAL_BOSSES or {}
MYTHIC_MODE_ENDED = MYTHIC_MODE_ENDED or {}

local MYTHIC_ENTRY_RANGE = { start = 1, stop = 60000 }
local MYTHIC_HOSTILE_FACTIONS = { [16] = true, [21] = true, [1885] = true }
local FRIENDLY_FACTIONS = {
  [1]=true, [2]=true, [3]=true, [4]=true, [5]=true, [6]=true, [14]=true, [31]=true, [35]=true,
  [114]=true, [115]=true, [116]=true, [188]=true, [190]=true, [1610]=true, [1629]=true,
  [1683]=true, [1718]=true, [1770]=true
}

local WEEKLY_AFFIX_POOL = {
    [1] = {
        {spell={48441,61301},name="Rejuvenating"},
        {spell={47893,50589},name="Demonism"},
        {spell={43010,43024,43012},name="Resistant"}
    },
    [2] = {
        {spell=871,name="Turtling"},
        {spell={48161,48066,6346,48168,15286},name="Priest Empowered"},
        {spell=53201,name="Falling Stars"}
    },
    [3] = {
        {spell=8599,name="Enrage"},
        {spell={47436,53138,57623},name="Rallying"},
        {spell={53385,48819},name="Consecrated"}
    }
}

local AFFIX_COLOR_MAP, ALL_AFFIX_SPELL_IDS = {}, {}
local colorMap = {
    Enrage="|cffff0000", Turtling="|cffffff00", Rejuvenating="|cff00ff00",
    Falling_Stars="|cff66ccff", ["Priest Empowered"]="|cffcccccc",
    Demonism="|cff8b0000", Consecrated="|cffffcc00",
    Resistant="|cffb0c4de", Rallying="|cffff8800"
}

for _, tier in pairs(WEEKLY_AFFIX_POOL) do
    for _, affix in ipairs(tier) do
        local spells = type(affix.spell) == "table" and affix.spell or {affix.spell}
        for _, id in ipairs(spells) do ALL_AFFIX_SPELL_IDS[id] = true end
        AFFIX_COLOR_MAP[affix.name] = colorMap[affix.name:gsub(" ", "_")] or "|cffffffff"
    end
end

local WEEKLY_AFFIXES = {}
math.randomseed(os.time())
for i = 1, 3 do
    local pool = WEEKLY_AFFIX_POOL[i]
    if #pool > 0 then table.insert(WEEKLY_AFFIXES, pool[math.random(#pool)]) end
end

local KEY_IDS = { [1]=900100, [2]=900101, [3]=900102 }
local ICONS = {
    [1]="Interface\\Icons\\INV_Enchant_AbyssCrystal",
    [2]="Interface\\Icons\\INV_Enchant_VoidCrystal",
    [3]="Interface\\Icons\\INV_Enchant_NexusCrystal"
}

local MYTHIC_SCAN_RADIUS = 500
local TIER_RATING_GAIN = { [1]=20, [2]=40, [3]=60 }
local TIER_RATING_LOSS = { [1]=3, [2]=6, [3]=9 }
local RATING_CAP = 2000

if not MYTHIC_FLAG_TABLE then MYTHIC_FLAG_TABLE = {} end
if not MYTHIC_AFFIXES_TABLE then MYTHIC_AFFIXES_TABLE = {} end
if not MYTHIC_LOOP_HANDLERS then MYTHIC_LOOP_HANDLERS = {} end
if not MYTHIC_REWARD_CHANCE_TABLE then MYTHIC_REWARD_CHANCE_TABLE = {} end

local function GetAffixSet(tier)
    local list = {}
    for i = 1, tier do
        local affix = WEEKLY_AFFIXES[i]
        if affix then
            local spells = type(affix.spell) == "table" and affix.spell or { affix.spell }
            for _, s in ipairs(spells) do table.insert(list, s) end
        end
    end
    return list
end

local function GetAffixNameSet(tier)
    local names = {}
    for i = 1, tier do
        local affix = WEEKLY_AFFIXES[i]
        if affix then table.insert(names, affix.name) end
    end
    return table.concat(names, ", ")
end

local function ApplyAuraToNearbyCreatures(player, affixes)
    local map = player:GetMap(); if not map then return end
    local seen = {}
    for _, creature in pairs(player:GetCreaturesInRange(MYTHIC_SCAN_RADIUS)) do
        local guid, f = creature:GetGUIDLow(), creature:GetFaction()
        if not seen[guid] and creature:IsAlive() and creature:IsInWorld() and not creature:IsPlayer()
        and (not FRIENDLY_FACTIONS[f] or creature:GetEntry() == 26861 or creature:GetName() == "King Ymiron") then
            seen[guid] = true
            for _, spellId in ipairs(affixes) do creature:CastSpell(creature, spellId, true) end
        end
    end
end

local CHEST_ENTRIES = { [1] = 900010, [2] = 900011, [3] = 900012 }

function SpawnMythicRewardChest(x, y, z, o, mapId, instanceId, tier)
    PerformIngameSpawn(2, CHEST_ENTRIES[tier] or CHEST_ENTRIES[1], mapId, instanceId, x, y, z, o)
end

local function RemoveAffixAurasFromAllCreatures(instanceId, map)
    if not map then return end
    local affixes = MYTHIC_AFFIXES_TABLE[instanceId]
    if not affixes then return end

    for _, creature in pairs(map:GetCreatures()) do
        if creature:IsAlive() and creature:IsInWorld() and not creature:IsPlayer() then
            for _, spellId in ipairs(affixes) do
                if creature:HasAura(spellId) then
                    creature:RemoveAura(spellId)
                end
            end
        end
    end
end

local function StartAuraLoop(player, instanceId, mapId, affixes, interval)
    local guid = player:GetGUIDLow()
    if MYTHIC_LOOP_HANDLERS[instanceId] then RemoveEventById(MYTHIC_LOOP_HANDLERS[instanceId]) end
    local eventId = CreateLuaEvent(function()
        local p = GetPlayerByGUID(guid)
        if not p or p:GetMapId() ~= mapId or not MYTHIC_FLAG_TABLE[instanceId] then
            MYTHIC_FLAG_TABLE[instanceId], MYTHIC_AFFIXES_TABLE[instanceId], MYTHIC_REWARD_CHANCE_TABLE[instanceId], MYTHIC_LOOP_HANDLERS[instanceId] = nil, nil, nil, nil
            return
        end
        ApplyAuraToNearbyCreatures(p, affixes)
    end, interval, 0)
    MYTHIC_LOOP_HANDLERS[instanceId] = eventId
end

local function AwardMythicPoints(p, t, d)
    if not p then
        print("[Mythic] AwardMythicPoints called without valid player — aborting.")
        return
    end
    local g, n = p:GetGUIDLow(), os.time()
    local g1, g2 = TIER_RATING_GAIN[t], (TIER_RATING_LOSS[t] or 0) * (d or 0)
    local r = CharDBQuery("SELECT total_points,claimed_tier1,claimed_tier2,claimed_tier3 FROM character_mythic_rating WHERE guid=" .. g)
    local pv = r and r:GetUInt32(0) or 0
    local rw, pd = math.max(math.min(pv + g1 - g2, 2000), 0), pv
    local c1 = r and r:GetUInt32(1) or 0
    local c2 = r and r:GetUInt32(2) or 0
    local c3 = r and r:GetUInt32(3) or 0
    if t == 1 then c1 = c1 + 1 elseif t == 2 then c2 = c2 + 1 elseif t == 3 then c3 = c3 + 1 end
    CharDBExecute(string.format(
        "INSERT INTO character_mythic_rating (guid,total_runs,total_points,claimed_tier1,claimed_tier2,claimed_tier3,last_updated) VALUES(%d,1,%d,%d,%d,%d,FROM_UNIXTIME(%d)) ON DUPLICATE KEY UPDATE total_runs=total_runs+1,total_points=%d,claimed_tier1=%d,claimed_tier2=%d,claimed_tier3=%d,last_updated=FROM_UNIXTIME(%d);",
        g, rw, c1, c2, c3, n, rw, c1, c2, c3, n
    ))
    local rc = "|cff1eff00"
    if rw >= 1800 then rc = "|cffff8000"
    elseif rw >= 1000 then rc = "|cffa335ee"
    elseif rw >= 500 then rc = "|cff0070dd" end
    local msg = rw == pd and "|cffffcc00No rating added because you are rating capped!|r"
        or string.format("|cff00ff00+%d rating|r%s", rw - pd + g2, (d > 0 and string.format(" |cffff0000(-%d from deaths)|r", g2) or ""))
    p:SendBroadcastMessage(string.format("|cffffff00Tier %d key completed.|r\n%s\nNew Rating: %s%d|r", t, msg, rc, rw))
    local i, c = 45624, 1
    if rw > 1800 then i, c = 49426, 2
    elseif rw > 1000 then i = 49426
    elseif rw > 500 then i = 47241 end
    p:AddItem(i, c)
    p:SendBroadcastMessage(string.format("|cffffff00[Mythic]|r Reward: |cffaaff00%s x%d|r\nYour final rating: %s%d|r", GetItemLink(i), c, rc, rw))
    if t == 1 then
        p:AddItem(KEY_IDS[2], 1)
        p:SendBroadcastMessage("|cffffff00[Mythic]|r Tier 2 Keystone granted!")
    end
    if t == 2 then
        p:AddItem(KEY_IDS[3], 1)
        p:SendBroadcastMessage("|cffffff00[Mythic]|r Tier 3 Keystone granted!")
    end
end

local function PenalizeMythicPoints(player, tier)
    if not player then
        print("[Mythic] PenalizeMythicPoints called without valid player — aborting.")
        return
    end
    local guid = player:GetGUIDLow()
    local loss = TIER_RATING_LOSS[tier]
    local result = CharDBQuery("SELECT total_points FROM character_mythic_rating WHERE guid = " .. guid)
    local previous = result and result:GetUInt32(0) or 0
    local updated = math.max(previous - loss, 0)
    CharDBExecute(string.format(
        "INSERT INTO character_mythic_rating (guid, total_runs, total_points) VALUES (%d, 0, %d) ON DUPLICATE KEY UPDATE total_points = %d;",
        guid, updated, updated
    ))
    player:SendBroadcastMessage(string.format("|cffffff00Tier %d death:|r |cffff0000-%d|r", tier, loss))
end

function Pedestal_OnGossipHello(_, player, creature)
    local map = player:GetMap(); if not map then return end
    local instanceId = map:GetInstanceId()
    player:GossipClearMenu()

    local header = "|cff000000This Week's Mythic Affixes:|r"
    for tier = 1, 3 do
        local line = "|cff000000T"..tier..":|r "
        for i = 1, tier do
            local affix = WEEKLY_AFFIXES[i]
            if affix then
                local color = AFFIX_COLOR_MAP[affix.name] or "|cffffffff"
                line = line..color..affix.name.."|r"..(i < tier and "|cff000000, |r" or "")
            end
        end
        header = header.."\n"..line
    end
    player:GossipMenuAddItem(0, header, 0, 0)

    if MYTHIC_FLAG_TABLE[instanceId] then
        player:GossipMenuAddItem(0, "|cffff0000You've already used a keystone.|r", 0, 999)
    elseif MYTHIC_KILL_LOCK[instanceId] then
        local lockMsg = "|cffff0000Mythic+ is locked. Reset the dungeon to enable keystone use.|r"
        player:GossipMenuAddItem(0, lockMsg, 0, 999)
        player:SendBroadcastMessage(lockMsg)
    else
        for tier = 1, 3 do
            player:GossipMenuAddItem(10, string.format("|cff000000Tier %d|r", tier), 0, 100 + tier, false, "", 0, ICONS[tier])
        end
    end

    player:GossipSendMenu(1, creature)
end

function ScheduleMythicTimeout(player, instanceId, tier)
    if not player then
        print("[Mythic] ScheduleMythicTimeout called without valid player — aborting.")
        return
    end
    local duration = (tier == 1 and 15 or 30) * 60000
    local auraId = (tier == 1) and 26013 or 71041
    local guid = player:GetGUIDLow()
    player:AddAura(auraId, player)

    local checkEvent = CreateLuaEvent(function()
        local p = GetPlayerByGUID(guid)
        if not p or not p:IsInWorld() or MYTHIC_TIMER_EXPIRED[instanceId] or not MYTHIC_FLAG_TABLE[instanceId] then return end
        if not p:HasAura(auraId) then
            local map = p:GetMap()
            MYTHIC_TIMER_EXPIRED[instanceId] = true
            p:SendBroadcastMessage("|cffff0000[Mythic]|r Time ran out. Mythic mode failed.")

            if MYTHIC_LOOP_HANDLERS[instanceId] then
                RemoveEventById(MYTHIC_LOOP_HANDLERS[instanceId])
                MYTHIC_LOOP_HANDLERS[instanceId] = nil
            end

            if map then RemoveAffixAurasFromAllCreatures(instanceId, map) end

            CharDBExecute(string.format(
                "DELETE FROM character_mythic_instance_state WHERE guid = %d AND instance_id = %d;",
                guid, instanceId
            ))
            DeductMythicRatingOnFailure(p, tier)
        end
    end, 5000, 0)

    local function DeductMythicRatingOnFailure(player, tier)
    if not player then
        print("[Mythic] DeductMythicRatingOnFailure called without valid player — aborting.")
        return
    end
    local guid = player:GetGUIDLow()
    local loss = TIER_RATING_LOSS[tier] or 0
    local result = CharDBQuery("SELECT total_points FROM character_mythic_rating WHERE guid = " .. guid)
    local previous = result and result:GetUInt32(0) or 0
    local updated = math.max(previous - loss, 0)
    CharDBExecute(string.format(
        "INSERT INTO character_mythic_rating (guid, total_runs, total_points) VALUES (%d, 0, %d) ON DUPLICATE KEY UPDATE total_points = %d;",
        guid, updated, updated
    ))
    player:SendBroadcastMessage(string.format("|cffffff00Mythic timeout:|r |cffff0000-%d rating|r", loss))
end

    CreateLuaEvent(function()
        local p = GetPlayerByGUID(guid)
        if p and p:IsInWorld() and MYTHIC_FLAG_TABLE[instanceId] and not MYTHIC_TIMER_EXPIRED[instanceId] then
            local map = p:GetMap()
            MYTHIC_TIMER_EXPIRED[instanceId] = true
            p:SendBroadcastMessage("|cffff0000[Mythic]|r Time limit exceeded. You are no longer eligible for rewards.")
            MYTHIC_MODE_ENDED[instanceId] = true

            if map then RemoveAffixAurasFromAllCreatures(instanceId, map) end

            if MYTHIC_LOOP_HANDLERS[instanceId] then
                RemoveEventById(MYTHIC_LOOP_HANDLERS[instanceId])
                MYTHIC_LOOP_HANDLERS[instanceId] = nil
            end
        end
        RemoveEventById(checkEvent)
    end, duration, 1)
end

function Pedestal_OnGossipSelect(_, player, _, _, intid)
    if intid == 999 then player:GossipComplete() return end
    if intid >= 100 and intid <= 103 then
        local map = player:GetMap(); if not map then player:SendBroadcastMessage("Error: No map context.") player:GossipComplete() return end
        local instanceId = map:GetInstanceId()
        if MYTHIC_KILL_LOCK[instanceId] then return player:SendBroadcastMessage("|cffff0000[Mythic]|r A creature was already killed. Reset the dungeon to use a keystone."), player:GossipComplete() end
        if MYTHIC_FLAG_TABLE[instanceId] then player:SendBroadcastMessage("|cffff0000Mythic mode has already been activated in this instance.|r") player:GossipComplete() return end
        local tier, keyId = intid - 100, KEY_IDS[intid - 100]
        if not player:HasItem(keyId) then player:SendBroadcastMessage("You do not have the required Tier "..tier.." Keystone.") player:GossipComplete() return end
        if map:GetDifficulty() == 0 then player:SendBroadcastMessage("|cffff0000Mythic keys cannot be used in Normal mode dungeons.|r") player:GossipComplete() return end
        local guid, now = player:GetGUIDLow(), os.time()
        CharDBExecute(string.format([[INSERT INTO character_mythic_rating (guid, total_runs, total_points, claimed_tier1, claimed_tier2, claimed_tier3, last_updated)
            VALUES (%d, 0, 0, %d, %d, %d, FROM_UNIXTIME(%d))
            ON DUPLICATE KEY UPDATE last_updated = FROM_UNIXTIME(%d);]], guid, tier==1 and 1 or 0, tier==2 and 1 or 0, tier==3 and 1 or 0, now, now))
        local affixes, affixNames = GetAffixSet(tier), GetAffixNameSet(tier)
        MYTHIC_FLAG_TABLE[instanceId], MYTHIC_AFFIXES_TABLE[instanceId], MYTHIC_REWARD_CHANCE_TABLE[instanceId] = true, affixes, tier==1 and 1.5 or tier==2 and 2.0 or 5.0
        ScheduleMythicTimeout(player, instanceId, tier)
        local ratingQuery = CharDBQuery("SELECT total_points FROM character_mythic_rating WHERE guid = " .. guid)
        local currentRating = ratingQuery and ratingQuery:GetUInt32(0) or 0
        local c = "|cff1eff00"
        if currentRating >= 1800 then c = "|cffff8000" elseif currentRating >= 1000 then c = "|cffa335ee" elseif currentRating >= 500 then c = "|cff0070dd" end
        player:SendBroadcastMessage(string.format("Tier %d Keystone inserted.\nAffixes: %s\nCurrent Rating: %s%d|r", tier, affixNames, c, currentRating))
        player:RemoveItem(keyId, 1)
        ApplyAuraToNearbyCreatures(player, affixes)
        StartAuraLoop(player, instanceId, map:GetMapId(), affixes, 6000)
        CharDBExecute(string.format("INSERT INTO character_mythic_instance_state (guid, instance_id, map_id, tier, created_at) VALUES (%d, %d, %d, %d, FROM_UNIXTIME(%d)) ON DUPLICATE KEY UPDATE tier = VALUES(tier), created_at = VALUES(created_at);", guid, instanceId, map:GetMapId(), tier, now))
        player:GossipComplete()
    end
end

RegisterCreatureGossipEvent(PEDESTAL_NPC_ENTRY, 1, Pedestal_OnGossipHello)
RegisterCreatureGossipEvent(PEDESTAL_NPC_ENTRY, 2, Pedestal_OnGossipSelect)

RegisterPlayerEvent(6, function(_, player)
    local map = player:GetMap(); if not map or map:GetDifficulty() == 0 then return end
    local instanceId = map:GetInstanceId()
    if not MYTHIC_FLAG_TABLE[instanceId] then return end
    local guid = player:GetGUIDLow()
    MYTHIC_DEATHS[instanceId] = MYTHIC_DEATHS[instanceId] or {}
    MYTHIC_DEATHS[instanceId][guid] = (MYTHIC_DEATHS[instanceId][guid] or 0) + 1
end)

RegisterPlayerEvent(3, function(_, player)
    if not ANNOUNCE_AFFIXES_ON_LOGIN then return end
    local affixNames = {}
    for _, affix in ipairs(WEEKLY_AFFIXES) do
        table.insert(affixNames, (AFFIX_COLOR_MAP[affix.name] or "|cffffffff")..affix.name.."|r")
    end
    player:SendBroadcastMessage("|cffffcc00[Mythic]|r This week's affixes: "..table.concat(affixNames, ", "))
end)

RegisterPlayerEvent(28, function(_, p)
    local m = p:GetMap(); if not m then return end
    local iid, mid, g = m:GetInstanceId(), m:GetMapId(), p:GetGUIDLow()
    local r = CharDBQuery("SELECT tier, UNIX_TIMESTAMP(created_at) FROM character_mythic_instance_state WHERE guid="..g.." AND instance_id="..iid.." AND map_id="..mid)
    if not r then return end
    local t, ts = r:GetUInt32(0), r:GetUInt32(1)

    if os.time() - ts > 7200 then
        MYTHIC_MODE_ENDED[iid] = nil
        CharDBExecute("DELETE FROM character_mythic_instance_state WHERE guid="..g.." AND instance_id="..iid.." AND map_id="..mid)
        return
    end

    local a = GetAffixSet(t)
    MYTHIC_FLAG_TABLE[iid], MYTHIC_AFFIXES_TABLE[iid], MYTHIC_REWARD_CHANCE_TABLE[iid] = true, a, t == 1 and 1.5 or t == 2 and 2.0 or 5.0
    p:SendBroadcastMessage("|cffffff00[Mythic]|r Resuming active Mythic+ affixes.")
    ApplyAuraToNearbyCreatures(p, a)
    if not MYTHIC_LOOP_HANDLERS[iid] then
        StartAuraLoop(p, iid, mid, a, 6000)
    end
end)

RegisterPlayerEvent(42, function(_, player, command)
    if command:lower():gsub("[#./]", "") ~= "mythicrating" then return end

    local guid, now = player:GetGUIDLow(), os.time()

    __MYTHIC_RATING_COOLDOWN__ = __MYTHIC_RATING_COOLDOWN__ or {}
    if now - (__MYTHIC_RATING_COOLDOWN__[guid] or 0) < 300 then
        player:SendBroadcastMessage("|cffffcc00[Mythic]|r You can only use this command once every 5 minutes.")
        return false
    end
    __MYTHIC_RATING_COOLDOWN__[guid] = now

    local result = CharDBQuery("SELECT total_points, total_runs FROM character_mythic_rating WHERE guid = "..guid)
    if result then
        local rating, runs = result:GetUInt32(0), result:GetUInt32(1)
        local color = rating <= 500 and "|cff1eff00" or rating <= 1000 and "|cff0070dd" or rating <= 1800 and "|cffa335ee" or "|cffff8000"
        player:SendBroadcastMessage(string.format("|cff66ccff[Mythic]|r Rating: %s%d|r (|cffffcc00%d runs completed|r)", color, rating, runs))
    else
        player:SendBroadcastMessage("|cffff0000[Mythic]|r No rating found. Complete a Mythic+ dungeon to begin tracking.")
    end
    return false
end)

RegisterPlayerEvent(7, function(_, k, v)
    if not k or not k:IsPlayer() or not v or v:GetObjectType() ~= "Creature" then return end
    local m = k:GetMap(); if not m or not m:IsDungeon() then return end
    local mid, iid = m:GetMapId(), m:GetInstanceId()
    if MYTHIC_FLAG_TABLE[iid] or MYTHIC_MODE_ENDED[iid] or MYTHIC_KILL_LOCK[iid] then return end
    local d = MYTHIC_FINAL_BOSSES[mid]; if d and v:GetEntry() == d.final then return end
    if not MYTHIC_HOSTILE_FACTIONS[v:GetFaction()] then return end
    MYTHIC_KILL_LOCK[iid] = true
    local msg = "|cffff0000[Mythic]|r Mythic+ is now locked because a hostile enemy was slain. Reset the dungeon to enable keystone use."
    for _, p in pairs(m:GetPlayers() or {}) do p:SendBroadcastMessage(msg) end
end)

if not MYTHIC_CHEST_SPAWNED then MYTHIC_CHEST_SPAWNED = {} end

for mapId, data in pairs(MYTHIC_FINAL_BOSSES) do
    local bossId = data.final
    if bossId then
        RegisterCreatureEvent(bossId, 4, function(_, creature)
    local map = creature:GetMap(); if not map then return end
    local instanceId = map:GetInstanceId()
    MYTHIC_MODE_ENDED[instanceId] = true 
            if not MYTHIC_FLAG_TABLE[instanceId] then return end

            local expired = MYTHIC_TIMER_EXPIRED[instanceId]
            local affixes = MYTHIC_AFFIXES_TABLE[instanceId] or {}
            local tier = (#affixes >= 4) and 3 or (#affixes == 3 and 2 or 1)

            for _, player in pairs(map:GetPlayers() or {}) do
                if player:IsAlive() and player:IsInWorld() then
                    if expired then
                        player:SendBroadcastMessage("|cffff0000[Mythic]|r Time expired. No rewards granted.")
                    else
                        local deaths = MYTHIC_DEATHS[instanceId] and MYTHIC_DEATHS[instanceId][player:GetGUIDLow()] or 0
                        AwardMythicPoints(player, tier, deaths)
                        local aura = tier == 1 and 26013 or 71041
                        if player:HasAura(aura) then player:RemoveAura(aura) end
                        player:SendBroadcastMessage("|cff00ff00Mythic+ dungeon complete! Rewards granted.")
                    end
                end
            end

            if not expired then
                local x, y, z, o = creature:GetX(), creature:GetY(), creature:GetZ(), creature:GetO()
                x, y = x - math.cos(o) * 2, y - math.sin(o) * 2
                SpawnMythicRewardChest(x, y, z, o, creature:GetMapId(), instanceId, tier)
            end

            RemoveAffixAurasFromAllCreatures(instanceId, map)

            if MYTHIC_LOOP_HANDLERS[instanceId] then RemoveEventById(MYTHIC_LOOP_HANDLERS[instanceId]) end
            MYTHIC_FLAG_TABLE[instanceId], MYTHIC_AFFIXES_TABLE[instanceId], MYTHIC_REWARD_CHANCE_TABLE[instanceId], MYTHIC_DEATHS[instanceId] = nil, nil, nil, nil
        end)
    end
end

local function ClearAffixBuffsFromNearbyEnemies(player)
    local map = player:GetMap(); if not map then return end
    local instanceId = map:GetInstanceId()
    local affixes = MYTHIC_AFFIXES_TABLE[instanceId] or {}

    for _, creature in pairs(map:GetCreatures()) do
        if creature:IsAlive() and creature:IsInWorld() and not creature:IsPlayer()
           and not FRIENDLY_FACTIONS[creature:GetFaction()] then
            for _, spellId in ipairs(affixes) do
                if creature:HasAura(spellId) then
                    creature:RemoveAura(spellId)
                end
            end
        end
    end
end

RegisterPlayerEvent(3, function(_, player)
    local affixNames = {}
    for i, affix in ipairs(WEEKLY_AFFIXES) do
        local color = AFFIX_COLOR_MAP[affix.name] or "|cffffffff"
        table.insert(affixNames, color .. affix.name .. "|r")
    end
    local msg = "|cffffcc00[Mythic]|r This week's affixes: " .. table.concat(affixNames, ", ")
    player:SendBroadcastMessage(msg)
end)

__MYTHIC_RATING_COOLDOWN__ = __MYTHIC_RATING_COOLDOWN__ or {}
__MYTHIC_RESET_PENDING__ = __MYTHIC_RESET_PENDING__ or {}

RegisterPlayerEvent(42, function(_, player, command)
    if not player then
        return false
    end

    local cmd = command:lower():gsub("[#./]", "")
    local guid, now = player:GetGUIDLow(), os.time()

    if cmd == "mythicrating" then
        local last = __MYTHIC_RATING_COOLDOWN__[guid] or 0
        if now - last < 300 then
            player:SendBroadcastMessage("|cffffcc00[Mythic]|r You can only use this command once every 5 minutes.")
            return false
        end
        __MYTHIC_RATING_COOLDOWN__[guid] = now

        local q = CharDBQuery("SELECT total_points, total_runs FROM character_mythic_rating WHERE guid = "..guid)
        if q then
            local rating, runs = q:GetUInt32(0), q:GetUInt32(1)
            local c = rating >= 1801 and "|cffff8000" or rating >= 1001 and "|cffa335ee" or rating >= 501 and "|cff0070dd" or "|cff1eff00"
            player:SendBroadcastMessage(string.format("|cff66ccff[Mythic]|r Rating: %s%d|r (|cffffcc00%d runs completed|r)", c, rating, runs))
        else
            player:SendBroadcastMessage("|cffff0000[Mythic]|r No rating found. Complete a Mythic+ dungeon to begin tracking.")
        end
        return false
    end

    if cmd == "mythichelp" then
        player:SendBroadcastMessage("|cff66ccff[Mythic]|r Available commands:")
        player:SendBroadcastMessage("|cffffff00.mythicrating|r - View your Mythic+ rating and runs.")
        player:SendBroadcastMessage("|cffffff00.mythichelp|r - Show this help menu.")
        if player:IsGM() then
            player:SendBroadcastMessage("|cffff6600.mythicreset|r - GM ONLY: Start full server rating reset.")
            player:SendBroadcastMessage("|cffff6600.mythicreset confirm|r - GM ONLY: Confirm the reset within 30 seconds.")
        end
        return false
    end

    if cmd == "mythicreset" then
        if not player:IsGM() then
            player:SendBroadcastMessage("|cffff0000[Mythic]|r You do not have permission to use this command.")
        else
            __MYTHIC_RESET_PENDING__[guid] = now
            player:SendBroadcastMessage("|cffffff00[Mythic]|r Type |cff00ff00.mythicreset confirm|r within 30 seconds to confirm full reset.")
        end
        return false
    end

    if cmd == "mythicresetconfirm" then
        local t = __MYTHIC_RESET_PENDING__[guid]
        if not t or now - t > 30 then
            player:SendBroadcastMessage("|cffff0000[Mythic]|r No reset pending or confirmation expired. Use |cff00ff00.mythicreset|r first.")
        else
            __MYTHIC_RESET_PENDING__[guid] = nil
            CharDBExecute([[
                UPDATE character_mythic_rating
                SET total_points = 0, total_runs = 0,
                    claimed_tier1 = 0, claimed_tier2 = 0, claimed_tier3 = 0,
                    last_updated = NOW();
            ]])
            player:SendBroadcastMessage("|cff00ff00[Mythic]|r All player ratings and run counts have been reset.")
            SendWorldMessage("|cffffcc00[Mythic]|r A Game Master has reset all Mythic+ player ratings.")
        end
        return false
    end
end)
