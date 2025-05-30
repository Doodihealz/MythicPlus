print("[Mythic] Mythic.lua loaded successfully.")

dofile("C:/Build/bin/RelWithDebInfo/lua_scripts/Generic/MythicPlus/MythicBosses.lua")

local PEDESTAL_NPC_ENTRY = 900001

local WEEKLY_AFFIX_POOL = {
    { spell = 8599, name = "Enrage" },
    { spell = {48441, 61301}, name = "Rejuvenating" },
    { spell = 871, name = "Turtling" },
    { spell = {57662, 57621, 58738, 8515}, name = "Shamanism" },
    { spell = {43015, 43008, 43046, 57531, 12043}, name = "Magus" },
    { spell = {48161, 48066, 6346, 48168, 15286}, name = "Priest Empowered" },
    { spell = {47241, 47893, 50589}, name = "Demonism" },
    { spell = 53201, name = "Falling Stars" }
}

local AFFIX_COLOR_MAP = {
    ["Enrage"] = "|cffff0000",
    ["Rejuvenating"] = "|cff00ff00",
    ["Turtling"] = "|cffffff00",
    ["Shamanism"] = "|cffa335ee",
    ["Magus"] = "|cff3399ff",
    ["Priest Empowered"] = "|cffcccccc",
    ["Demonism"] = "|cff8b0000",
    ["Falling Stars"] = "|cff66ccff"
}

local SHAMANISM_SPELLS = {
    [57662] = true,
    [57621] = true,
    [58738] = true,
    [8515]  = true
}

local MAGUS_SPELLS = {
    [43015] = true,
    [43008] = true,
    [43046] = true,
    [57531] = true,
    [12043] = true
}

local PRIEST_EMPOWERED_SPELLS = {
    [48161] = true,
    [48066] = true,
    [6346]  = true,
    [48168] = true,
    [15286] = true
}

local WEEKLY_AFFIXES = {}

local function RollWeeklyAffixes()
    math.randomseed(os.time())
    local valid = false
    while not valid do
        local shuffled = {}
        for i = 1, #WEEKLY_AFFIX_POOL do shuffled[i] = WEEKLY_AFFIX_POOL[i] end
        for i = #shuffled, 2, -1 do
            local j = math.random(i)
            shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
        end
        
        local hasFS = false
        for i = 1, 2 do
            if shuffled[i].name == "Falling Stars" then
                hasFS = true
                break
            end
        end
        if not hasFS then
            WEEKLY_AFFIXES = { shuffled[1], shuffled[2], shuffled[3] }
            valid = true
        end
    end
end
RollWeeklyAffixes()

local KEY_IDS = {
    [1] = 900100,
    [2] = 900101,
    [3] = 900102
}

local ICONS = {
    [1] = "Interface\\Icons\\INV_Enchant_AbyssCrystal",
    [2] = "Interface\\Icons\\INV_Enchant_VoidCrystal",
    [3] = "Interface\\Icons\\INV_Enchant_NexusCrystal"
}

local MYSTERY_REWARD_ID = 50274
local MYTHIC_SCAN_RADIUS = 240
local MYTHIC_ENTRY_RANGE = { start = 1, stop = 60000 }

local RATING_THRESHOLDS = {
    [1] = { threshold = 500, item = 45624, message = "|cffccaa00[Mythic]|r Tier 1 reward unlocked!" },
    [2] = { threshold = 1000, item = 47421, message = "|cffaaff00[Mythic]|r Tier 2 reward unlocked!" },
    [3] = { threshold = 1800, item = 49426, message = "|cff00ffff[Mythic]|r Tier 3 reward unlocked!" }
}

local TIER_RATING_GAIN = { [1] = 20, [2] = 40, [3] = 60 }
local TIER_RATING_LOSS = { [1] = 3, [2] = 6, [3] = 9 }
local RATING_CAP = 2000

if MYTHIC_FLAG_TABLE == nil then MYTHIC_FLAG_TABLE = {} end
if MYTHIC_AFFIXES_TABLE == nil then MYTHIC_AFFIXES_TABLE = {} end
if MYTHIC_LOOP_HANDLERS == nil then MYTHIC_LOOP_HANDLERS = {} end
if MYTHIC_REWARD_CHANCE_TABLE == nil then MYTHIC_REWARD_CHANCE_TABLE = {} end

local function GetAffixSet(tier)
    local list = {}
    for i = 1, tier do
        local affix = WEEKLY_AFFIXES[i]
        if affix then
            if type(affix.spell) == "table" then
                for _, s in ipairs(affix.spell) do
                    table.insert(list, s)
                end
            else
                table.insert(list, affix.spell)
            end
        end
    end
    return list
end

local function GetAffixNameSet(tier)
    local names = {}
    for i = 1, tier do
        local affix = WEEKLY_AFFIXES[i]
        if affix then
            table.insert(names, affix.name)
        end
    end
    return table.concat(names, ", ")
end

local function HasShamanism()
    for _, affix in ipairs(WEEKLY_AFFIXES) do
        if affix.name == "Shamanism" then
            return true
        end
    end
    return false
end

local function ApplyAuraToNearbyCreatures(player, affixes)
    local seen = {}
    local map = player:GetMap()
    if not map then return end

    for entry = MYTHIC_ENTRY_RANGE.start, MYTHIC_ENTRY_RANGE.stop do
        local creature = player:GetNearestCreature(MYTHIC_SCAN_RADIUS, entry)
        if creature then
            local guid = creature:GetGUIDLow()
            local faction = creature:GetFaction()

            if not seen[guid]
                and creature:IsAlive()
                and creature:IsInWorld()
                and faction ~= 2 and faction ~= 3 and faction ~= 4 and faction ~= 14 and faction ~= 31 and faction ~= 35 and faction ~= 188 and faction ~= 1629 and faction ~= 114 and faction ~= 35 and faction ~= 115 and faction ~= 1 then

                seen[guid] = true
                for _, spellId in ipairs(affixes) do
                    if SHAMANISM_SPELLS[spellId] then
                        if not creature:HasAura(spellId) then
                            creature:CastSpell(creature, spellId, true)
                        end
                    else
                        creature:CastSpell(creature, spellId, true)
                    end
                end
            end
        end
    end
end

local function StartAuraLoop(player, instanceId, mapId, affixes, interval)
    local guid = player:GetGUIDLow()
    if MYTHIC_LOOP_HANDLERS[instanceId] then
        RemoveEventById(MYTHIC_LOOP_HANDLERS[instanceId])
    end
    local eventId = CreateLuaEvent(function()
        local p = GetPlayerByGUID(guid)
        if not p then return end
        if not MYTHIC_FLAG_TABLE[instanceId] then return end
        if p:GetMapId() ~= mapId then
            p:SendBroadcastMessage("|cff8b0000Map change detected. Stopping buff.|r")
            MYTHIC_FLAG_TABLE[instanceId] = nil
            MYTHIC_AFFIXES_TABLE[instanceId] = nil
            MYTHIC_LOOP_HANDLERS[instanceId] = nil
            MYTHIC_REWARD_CHANCE_TABLE[instanceId] = nil
            return
        end
        ApplyAuraToNearbyCreatures(p, affixes)
    end, interval, 0)
    MYTHIC_LOOP_HANDLERS[instanceId] = eventId
end

local function AwardMythicPoints(player, tier)
    local guid = player:GetGUIDLow()
    local gain = TIER_RATING_GAIN[tier]
    local now = os.time()

    local result = CharDBQuery("SELECT total_points, claimed_tier1, claimed_tier2, claimed_tier3 FROM character_mythic_rating WHERE guid = " .. guid)
    local previous = result and result:GetUInt32(0) or 0
    local updated = math.min(previous + gain, RATING_CAP)

    local claimed1 = result and result:GetUInt32(1) or 0
    local claimed2 = result and result:GetUInt32(2) or 0
    local claimed3 = result and result:GetUInt32(3) or 0

    if tier == 1 then claimed1 = claimed1 + 1
    elseif tier == 2 then claimed2 = claimed2 + 1
    elseif tier == 3 then claimed3 = claimed3 + 1 end

    CharDBExecute(string.format([[
        INSERT INTO character_mythic_rating (guid, total_runs, total_points, claimed_tier1, claimed_tier2, claimed_tier3, last_updated)
        VALUES (%d, 1, %d, %d, %d, %d, FROM_UNIXTIME(%d))
        ON DUPLICATE KEY UPDATE 
            total_runs = total_runs + 1,
            total_points = %d,
            claimed_tier1 = %d,
            claimed_tier2 = %d,
            claimed_tier3 = %d,
            last_updated = FROM_UNIXTIME(%d);
    ]], guid, updated, claimed1, claimed2, claimed3, now, updated, claimed1, claimed2, claimed3, now))

    player:SendBroadcastMessage(string.format("Tier %d key completed.\nNew Rating: %d (|cff00ff00+%d|r)", tier, updated, updated - previous))

    local reward = RATING_THRESHOLDS[tier]
    if reward then
        player:SendBroadcastMessage(reward.message)
        player:AddItem(reward.item, 1)
        print(string.format("[Mythic] Player %d awarded Tier %d reward and emblem. Rating: %d", guid, tier, updated))
    end

    if tier == 1 then
        player:AddItem(KEY_IDS[2], 1)
        player:SendBroadcastMessage("|cffffff00[Mythic]|r Tier 2 Keystone granted!")
    elseif tier == 2 then
        player:AddItem(KEY_IDS[3], 1)
        player:SendBroadcastMessage("|cffffff00[Mythic]|r Tier 3 Keystone granted!")
    end
end

local function PenalizeMythicPoints(player, tier)
    local guid = player:GetGUIDLow()
    local loss = TIER_RATING_LOSS[tier]
    local result = CharDBQuery("SELECT total_points FROM character_mythic_rating WHERE guid = " .. guid)
    local previous = result and result:GetUInt32(0) or 0
    local updated = math.max(previous - loss, 0)
    CharDBExecute(string.format([[
        INSERT INTO character_mythic_rating (guid, total_runs, total_points)
        VALUES (%d, 0, %d)
        ON DUPLICATE KEY UPDATE total_points = %d;
    ]], guid, updated, updated))
    player:SendBroadcastMessage(string.format("|cffffff00Tier %d death:|r |cffff0000-%d|r", tier, loss))
end

function Pedestal_OnGossipHello(_, player, creature)
    local map = player:GetMap()
    if not map then return end
    local instanceId = map:GetInstanceId()
    player:GossipClearMenu()

    local header = "|cff000000This Week's Mythic Affixes:|r"
    for tier = 1, 3 do
        local line = "|cff000000T" .. tier .. ":|r "
        for i = 1, tier do
            local affix = WEEKLY_AFFIXES[i]
            if affix then
                local color = AFFIX_COLOR_MAP[affix.name] or "|cffffffff"
                line = line .. color .. affix.name .. "|r"
                if i < tier then
                    line = line .. "|cff000000, |r"
                end
            end
        end
        header = header .. "\n" .. line
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

function Pedestal_OnGossipSelect(_, player, _, _, intid)
    if intid == 999 then 
        player:GossipComplete()
        return 
    end

    if intid >= 100 and intid <= 103 then
        local tier = intid - 100
        local keyId = KEY_IDS[tier]

        if not player:HasItem(keyId) then
            player:SendBroadcastMessage("You do not have the required Tier " .. tier .. " Keystone.")
            player:GossipComplete()
            return
        end

        local map = player:GetMap()
        if not map or map:GetDifficulty() == 0 then
            player:SendBroadcastMessage("|cffff0000Mythic keys cannot be used in Normal mode dungeons.|r")
            player:GossipComplete()
            return
        end

        local guid = player:GetGUIDLow()
        local now = os.time()

        -- Ensure character_mythic_rating entry exists and record the claimed tier
        CharDBExecute(string.format([[
            INSERT INTO character_mythic_rating (guid, total_runs, total_points, claimed_tier1, claimed_tier2, claimed_tier3, last_updated)
            VALUES (%d, 0, 0, %d, %d, %d, FROM_UNIXTIME(%d))
            ON DUPLICATE KEY UPDATE 
                last_updated = FROM_UNIXTIME(%d);
        ]], guid,
            tier == 1 and 1 or 0,
            tier == 2 and 1 or 0,
            tier == 3 and 1 or 0,
            now, now))

        local instanceId = map:GetInstanceId()
        local mapId = player:GetMapId()
        local affixes = GetAffixSet(tier)
        local affixNames = GetAffixNameSet(tier)

        MYTHIC_FLAG_TABLE[instanceId] = true
        MYTHIC_AFFIXES_TABLE[instanceId] = affixes
        MYTHIC_REWARD_CHANCE_TABLE[instanceId] = tier == 1 and 1.5 or tier == 2 and 2.0 or 5.0

        local ratingQuery = CharDBQuery("SELECT total_points FROM character_mythic_rating WHERE guid = " .. guid)
        local currentRating = ratingQuery and ratingQuery:GetUInt32(0) or 0

        player:SendBroadcastMessage(string.format("Tier %d Keystone inserted.\nAffixes: %s\nCurrent Rating: %d", tier, affixNames, currentRating))
        player:RemoveItem(keyId, 1)

        ApplyAuraToNearbyCreatures(player, affixes)
        StartAuraLoop(player, instanceId, mapId, affixes, 6000)

        player:GossipComplete()
    end
end

RegisterCreatureGossipEvent(PEDESTAL_NPC_ENTRY, 1, Pedestal_OnGossipHello)
RegisterCreatureGossipEvent(PEDESTAL_NPC_ENTRY, 2, Pedestal_OnGossipSelect)

RegisterPlayerEvent(6, function(_, player)
    local map = player:GetMap()
    if not map or map:GetDifficulty() == 0 then return end
    local instanceId = map:GetInstanceId()
    if not MYTHIC_FLAG_TABLE[instanceId] then return end
    local affixCount = MYTHIC_AFFIXES_TABLE[instanceId] and #MYTHIC_AFFIXES_TABLE[instanceId] or 1
    local tier = affixCount >= 4 and 3 or affixCount == 3 and 2 or 1
    PenalizeMythicPoints(player, tier)
end)

local ANNOUNCE_AFFIXES_ON_LOGIN = true

RegisterPlayerEvent(3, function(_, player)
    if not ANNOUNCE_AFFIXES_ON_LOGIN then return end
    local affixNames = {}
    for _, affix in ipairs(WEEKLY_AFFIXES) do
        local color = AFFIX_COLOR_MAP[affix.name] or "|cffffffff"
        table.insert(affixNames, color .. affix.name .. "|r")
    end
    SendWorldMessage("|cffffcc00[Mythic]|r This week's affixes: " .. table.concat(affixNames, ", "))
end)
