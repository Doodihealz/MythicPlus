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
  [1]=true, [2]=true, [3]=true, [4]=true, [6]=true, [14]=true, [31]=true, [35]=true,
  [114]=true, [115]=true, [116]=true, [188]=true, [190]=true, [1610]=true, [1629]=true,
  [1683]=true, [1718]=true, [1770]=true
}

local WEEKLY_AFFIX_POOL = {
  { spell=8599, name="Enrage" }, { spell={48441,61301}, name="Rejuvenating" }, { spell=871, name="Turtling" },
  { spell={57662,57621,58738,8515}, name="Shamanism" }, { spell={43015,43008,43046,57531,12043}, name="Magus" },
  { spell={48161,48066,6346,48168,15286}, name="Priest Empowered" }, { spell={47893,50589}, name="Demonism" },
  { spell=53201, name="Falling Stars" }
}

local ALL_AFFIX_SPELL_IDS = {}
for _, affix in ipairs(WEEKLY_AFFIX_POOL) do
    local spells = type(affix.spell) == "table" and affix.spell or { affix.spell }
    for _, id in ipairs(spells) do ALL_AFFIX_SPELL_IDS[id] = true end
end

local AFFIX_COLOR_MAP = {
    ["Enrage"]="|cffff0000", ["Rejuvenating"]="|cff00ff00", ["Turtling"]="|cffffff00",
    ["Shamanism"]="|cffa335ee", ["Magus"]="|cff3399ff", ["Priest Empowered"]="|cffcccccc",
    ["Demonism"]="|cff8b0000", ["Falling Stars"]="|cff66ccff"
}

local WEEKLY_AFFIXES = {}
local function RollWeeklyAffixes()
    math.randomseed(os.time())
    local valid = false
    while not valid do
        local shuffled = { table.unpack(WEEKLY_AFFIX_POOL) }
        for i = #shuffled, 2, -1 do
            local j = math.random(i)
            shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
        end
        if not (shuffled[1].name == "Falling Stars" or shuffled[2].name == "Falling Stars") then
            WEEKLY_AFFIXES = { shuffled[1], shuffled[2], shuffled[3] }
            valid = true
        end
    end
end
RollWeeklyAffixes()

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
        local guid, faction = creature:GetGUIDLow(), creature:GetFaction()
        if not seen[guid] and creature:IsAlive() and creature:IsInWorld() and not creature:IsPlayer()
        and (not FRIENDLY_FACTIONS[faction] or creature:GetEntry() == 26861 or creature:GetName() == "King Ymiron") then
            seen[guid] = true
            for _, spellId in ipairs(affixes) do
                if not creature:HasAura(spellId) then
                    if not creature:CastSpell(creature, spellId, true) then
                        creature:AddAura(spellId, creature)
                    end
                end
            end
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
    local g,n=p:GetGUIDLow(),os.time()
    local g1,g2=TIER_RATING_GAIN[t],(TIER_RATING_LOSS[t]or 0)*(d or 0)
    local r=CharDBQuery("SELECT total_points,claimed_tier1,claimed_tier2,claimed_tier3 FROM character_mythic_rating WHERE guid="..g)
    local pv=r and r:GetUInt32(0)or 0
    local rw,pd=math.max(math.min(pv+g1-g2,2000),0),pv
    local c1,c2,c3=r and r:GetUInt32(1)or 0,r and r:GetUInt32(2)or 0,r and r:GetUInt32(3)or 0
    if t==1 then c1=c1+1 elseif t==2 then c2=c2+1 elseif t==3 then c3=c3+1 end
    CharDBExecute(string.format("INSERT INTO character_mythic_rating (guid,total_runs,total_points,claimed_tier1,claimed_tier2,claimed_tier3,last_updated) VALUES(%d,1,%d,%d,%d,%d,FROM_UNIXTIME(%d)) ON DUPLICATE KEY UPDATE total_runs=total_runs+1,total_points=%d,claimed_tier1=%d,claimed_tier2=%d,claimed_tier3=%d,last_updated=FROM_UNIXTIME(%d);",g,rw,c1,c2,c3,n,rw,c1,c2,c3,n))
    local rc="|cff1eff00";if rw>=1800 then rc="|cffff8000" elseif rw>=1000 then rc="|cffa335ee" elseif rw>=500 then rc="|cff0070dd" end
    local msg=rw==pd and "|cffffcc00No rating added because you are rating capped!|r" or string.format("|cff00ff00+%d rating|r%s",rw-pd+g2,(d>0 and string.format(" |cffff0000(-%d from deaths)|r",g2)or""))
    p:SendBroadcastMessage(string.format("|cffffff00Tier %d key completed.|r\n%s\nNew Rating: %s%d|r",t,msg,rc,rw))
    local i,c=45624,1;if rw>1800 then i,c=49426,2 elseif rw>1000 then i=49426 elseif rw>500 then i=47241 end
    p:AddItem(i,c)
    p:SendBroadcastMessage(string.format("|cffffff00[Mythic]|r Reward: |cffaaff00%s x%d|r\nYour final rating: %s%d|r",GetItemLink(i),c,rc,rw))
    if t==1 then p:AddItem(KEY_IDS[2],1)p:SendBroadcastMessage("|cffffff00[Mythic]|r Tier 2 Keystone granted!") end
    if t==2 then p:AddItem(KEY_IDS[3],1)p:SendBroadcastMessage("|cffffff00[Mythic]|r Tier 3 Keystone granted!") end
end

local function PenalizeMythicPoints(player, tier)
    local guid = player:GetGUIDLow()
    local loss = TIER_RATING_LOSS[tier]
    local result = CharDBQuery("SELECT total_points FROM character_mythic_rating WHERE guid = " .. guid)
    local previous = result and result:GetUInt32(0) or 0
    local updated = math.max(previous - loss, 0)
    CharDBExecute(string.format("INSERT INTO character_mythic_rating (guid, total_runs, total_points) VALUES (%d, 0, %d) ON DUPLICATE KEY UPDATE total_points = %d;", guid, updated, updated))
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
            local affix = WEEKLY_AFFIXES[i]; if affix then
                local color = AFFIX_COLOR_MAP[affix.name] or "|cffffffff"
                line = line..color..affix.name.."|r"..(i < tier and "|cff000000, |r" or "")
            end
        end
        header = header.."\n"..line
    end
    player:GossipMenuAddItem(0, header, 0, 0)
    if MYTHIC_FLAG_TABLE[instanceId] then
        player:GossipMenuAddItem(0, "|cffff0000You've already used a keystone.|r", 0, 999)
    else
        for tier = 1, 3 do
            player:GossipMenuAddItem(10, string.format("|cff000000Tier %d|r", tier), 0, 100 + tier, false, "", 0, ICONS[tier])
        end
    end
    player:GossipSendMenu(1, creature)
end

function ScheduleMythicTimeout(player, instanceId, tier)
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
        if MYTHIC_KILL_LOCK[instanceId] then player:SendBroadcastMessage("|cffff0000[Mythic]|r A creature has already been killed. Reset the dungeon to activate Mythic mode.") player:GossipComplete() return end
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

RegisterPlayerEvent(7, function(_, killer, victim)
    if not killer or not killer:IsPlayer() or not victim or victim:GetObjectType() ~= "Creature" then return end
    local map = killer:GetMap(); if not map then return end
    local mapId, instanceId = map:GetMapId(), map:GetInstanceId()

    if MYTHIC_FLAG_TABLE[instanceId] or MYTHIC_MODE_ENDED[instanceId] then return end

    local finalData = MYTHIC_FINAL_BOSSES[mapId]
    if finalData and victim:GetEntry() == finalData.final then return end

    local faction = victim:GetFaction()
    if not MYTHIC_HOSTILE_FACTIONS[faction] then return end

    MYTHIC_KILL_LOCK[instanceId] = true
    killer:SendBroadcastMessage("|cffff0000[Mythic]|r You have slain a hostile enemy. Mythic mode is now locked for this dungeon run.")
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
