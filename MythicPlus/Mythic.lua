print("[Mythic] Mythic script loaded successfully! Enjoy!")
dofile("C:/Build/bin/RelWithDebInfo/lua_scripts/Generic/MythicPlus/MythicBosses.lua")

local PEDESTAL_NPC_ENTRY = 900001
local MYTHIC_SCAN_RADIUS = 500
local SLOTS = 6
local RATING_CAP = 2000
local AURA_LOOP_INTERVAL = 6000
local COMMAND_COOLDOWN = 300
local RESET_CONFIRM_TIMEOUT = 30
local INSTANCE_STATE_TIMEOUT = 7200

local MYTHIC_TIMER_EXPIRED = MYTHIC_TIMER_EXPIRED or {}
local MYTHIC_KILL_LOCK = MYTHIC_KILL_LOCK or {}
local MYTHIC_DEATHS = MYTHIC_DEATHS or {}
local MYTHIC_FLAG_TABLE = MYTHIC_FLAG_TABLE or {}
local MYTHIC_AFFIXES_TABLE = MYTHIC_AFFIXES_TABLE or {}
local MYTHIC_REWARD_CHANCE_TABLE = MYTHIC_REWARD_CHANCE_TABLE or {}
local MYTHIC_CHEST_SPAWNED = MYTHIC_CHEST_SPAWNED or {}
local MYTHIC_FINAL_BOSSES = MYTHIC_FINAL_BOSSES or {}
local MYTHIC_MODE_ENDED = MYTHIC_MODE_ENDED or {}
local MYTHIC_LOOP_HANDLERS = MYTHIC_LOOP_HANDLERS or {}
local MYTHIC_TIER_TABLE = MYTHIC_TIER_TABLE or {}
local MYTHIC_COMPLETION_STATE = MYTHIC_COMPLETION_STATE or {}
local __MYTHIC_RATING_COOLDOWN__ = __MYTHIC_RATING_COOLDOWN__ or {}
local __MYTHIC_RESET_PENDING__ = __MYTHIC_RESET_PENDING__ or {}

local TIER_CONFIG = {
    [1] = { rating_gain = 20, rating_loss = 3, timeout_penalty = 10, duration = 15, aura = 26013, color = "|cff0070dd" },
    [2] = { rating_gain = 40, rating_loss = 6, timeout_penalty = 20, duration = 30, aura = 71041, color = "|cffa335ee" },
    [3] = { rating_gain = 60, rating_loss = 9, timeout_penalty = 30, duration = 30, aura = 71041, color = "|cffff8000" }
}

local KEY_IDS = { [1] = 900100, [2] = 900101, [3] = 900102 }
local CHEST_ENTRIES = { [1] = 900010, [2] = 900011, [3] = 900012 }
local ICONS = {
    [1] = "Interface\\Icons\\INV_Enchant_AbyssCrystal",
    [2] = "Interface\\Icons\\INV_Enchant_VoidCrystal",
    [3] = "Interface\\Icons\\INV_Enchant_NexusCrystal"
}

local MYTHIC_HOSTILE_FACTIONS = { [16] = true, [21] = true, [1885] = true }
local FRIENDLY_FACTIONS = {
    [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true, [14] = true, [31] = true, [35] = true,
    [114] = true, [115] = true, [116] = true, [188] = true, [190] = true, [1610] = true, [1629] = true,
    [1683] = true, [1718] = true, [1770] = true
}

local IGNORE_BUFF_ENTRIES = { [30172] = true, [30173] = true, [29630] = true, [28351] = true, [24137] = true,
[37596] = true
}

local WEEKLY_AFFIX_POOL = {
    [1] = {
        { spell = { 48441, 61301 }, name = "Rejuvenating" },
        { spell = { 47893, 50589 }, name = "Demonism" },
        { spell = { 43010, 43024, 43012 }, name = "Resistant" }
    },
    [2] = {
        { spell = 871, name = "Turtling" },
        { spell = { 48161, 48066, 6346, 48168, 15286 }, name = "Priest Empowered" },
        { spell = 53201, name = "Falling Stars" }
    },
    [3] = {
        { spell = 8599, name = "Enrage" },
        { spell = { 47436, 53138, 57623 }, name = "Rallying" },
        { spell = { 53385, 48819 }, name = "Consecrated" }
    }
}

local AFFIX_COLOR_MAP = {
    Enrage = "|cffff0000", Turtling = "|cffffff00", Rejuvenating = "|cff00ff00",
    ["Falling Stars"] = "|cff66ccff", ["Priest Empowered"] = "|cffcccccc",
    Demonism = "|cff8b0000", Consecrated = "|cffffcc00",
    Resistant = "|cffb0c4de", Rallying = "|cffff8800"
}

local ALL_AFFIX_SPELL_IDS = {}
for _, tier in pairs(WEEKLY_AFFIX_POOL) do
    for _, affix in ipairs(tier) do
        local spells = type(affix.spell) == "table" and affix.spell or { affix.spell }
        for _, id in ipairs(spells) do
            ALL_AFFIX_SPELL_IDS[id] = true
        end
    end
end

local WEEKLY_AFFIXES = {}
math.randomseed(os.time())
for i = 1, 3 do
    local pool = WEEKLY_AFFIX_POOL[i]
    if #pool > 0 then
        table.insert(WEEKLY_AFFIXES, pool[math.random(#pool)])
    end
end

local GOSSIP_CHANGE_AFFIXES = 200
local GOSSIP_TIER1_MENU = 211
local GOSSIP_TIER2_MENU = 212
local GOSSIP_TIER3_MENU = 213
local GOSSIP_BACK_MAIN = 290
local function EncodeAffixIntId(tier, idx) return 300 + tier * 10 + idx end
local function DecodeAffixIntId(intid) local code=intid-300 local tier=math.floor(code/10) local idx=code%10 return tier,idx end

local function SafeDBQuery(query, ...)
    local safeQuery = string.format(query, ...)
    return CharDBQuery(safeQuery)
end

local function SafeDBExecute(query, ...)
    local safeQuery = string.format(query, ...)
    return CharDBExecute(safeQuery)
end

local function GetRatingColor(rating)
    if rating >= 1800 then return "|cffff8000"
    elseif rating >= 1000 then return "|cffa335ee"
    elseif rating >= 500 then return "|cff0070dd"
    else return "|cff1eff00" end
end

local function GetAffixSet(tier)
    local list = {}
    for i = 1, tier do
        local affix = WEEKLY_AFFIXES[i]
        if affix then
            local spells = type(affix.spell) == "table" and affix.spell or { affix.spell }
            for _, spellId in ipairs(spells) do
                table.insert(list, spellId)
            end
        end
    end
    return list
end

local function ApplyAuraToNearbyCreatures(player, affixes)
    local map = player:GetMap()
    if not map then return end
    
    local seen = {}
    for _, creature in pairs(player:GetCreaturesInRange(MYTHIC_SCAN_RADIUS)) do
        local guid = creature:GetGUIDLow()
        local faction = creature:GetFaction()
        local entry = creature:GetEntry()
        
        if not seen[guid] and creature:IsAlive() and creature:IsInWorld() and not creature:IsPlayer() then
            if not IGNORE_BUFF_ENTRIES[entry] and (not FRIENDLY_FACTIONS[faction] or entry == 26861 or creature:GetName() == "King Ymiron") then
                seen[guid] = true
                for _, spellId in ipairs(affixes) do
                    if not creature:HasAura(spellId) then
                        creature:CastSpell(creature, spellId, true)
                    end
                end
            end
        end
    end
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

local function CleanupMythicInstance(instanceId)
    if MYTHIC_LOOP_HANDLERS[instanceId] then
        RemoveEventById(MYTHIC_LOOP_HANDLERS[instanceId])
        MYTHIC_LOOP_HANDLERS[instanceId] = nil
    end
    
    MYTHIC_FLAG_TABLE[instanceId] = nil
    MYTHIC_AFFIXES_TABLE[instanceId] = nil
    MYTHIC_REWARD_CHANCE_TABLE[instanceId] = nil
    MYTHIC_TIER_TABLE[instanceId] = nil
    MYTHIC_DEATHS[instanceId] = nil
    MYTHIC_TIMER_EXPIRED[instanceId] = nil
    MYTHIC_KILL_LOCK[instanceId] = nil
    
    SafeDBExecute("DELETE FROM character_mythic_instance_state WHERE instance_id = %d", instanceId)
end

local function StartAuraLoop(player, instanceId, mapId, affixes)
    local guid = player:GetGUIDLow()
    
    if MYTHIC_LOOP_HANDLERS[instanceId] then
        RemoveEventById(MYTHIC_LOOP_HANDLERS[instanceId])
    end
    
    local eventId = CreateLuaEvent(function()
        local p = GetPlayerByGUID(guid)
        if p and p:GetMapId() == mapId and MYTHIC_FLAG_TABLE[instanceId] then
            ApplyAuraToNearbyCreatures(p, affixes)
        end
    end, AURA_LOOP_INTERVAL, 0)
    
    MYTHIC_LOOP_HANDLERS[instanceId] = eventId
end

function SpawnMythicRewardChest(x, y, z, o, mapId, instanceId, tier)
    if MYTHIC_CHEST_SPAWNED[instanceId] then return end
    
    local chestEntry = CHEST_ENTRIES[tier] or CHEST_ENTRIES[1]
    PerformIngameSpawn(2, chestEntry, mapId, instanceId, x, y, z, o)
    MYTHIC_CHEST_SPAWNED[instanceId] = true
end

local function UpdatePlayerRating(player, tier, deathCount, isSuccess)
    if not player then return end
    
    local guid = player:GetGUIDLow()
    local config = TIER_CONFIG[tier]
    if not config then return end
    
    local ratingQuery = SafeDBQuery("SELECT total_points FROM character_mythic_rating WHERE guid = %d", guid)
    local currentRating = ratingQuery and ratingQuery:GetUInt32(0) or 0
    
    local newRating
    if isSuccess then
        local gain = config.rating_gain
        local loss = config.rating_loss * (deathCount or 0)
        newRating = math.min(currentRating + gain - loss, RATING_CAP)
    else
        local timeoutPenalty = config.timeout_penalty
        local deathPenalty = config.rating_loss * (deathCount or 0)
        newRating = math.max(currentRating - timeoutPenalty - deathPenalty, 0)
    end
    
    local tierClaims = { 0, 0, 0 }
    if isSuccess then
        tierClaims[tier] = 1
    end
    
    SafeDBExecute([[
        INSERT INTO character_mythic_rating 
        (guid, total_runs, total_points, claimed_tier1, claimed_tier2, claimed_tier3, last_updated) 
        VALUES (%d, 1, %d, %d, %d, %d, FROM_UNIXTIME(%d)) 
        ON DUPLICATE KEY UPDATE 
        total_runs = total_runs + 1, 
        total_points = %d, 
        claimed_tier1 = claimed_tier1 + %d, 
        claimed_tier2 = claimed_tier2 + %d, 
        claimed_tier3 = claimed_tier3 + %d, 
        last_updated = FROM_UNIXTIME(%d)
    ]], guid, newRating, tierClaims[1], tierClaims[2], tierClaims[3], os.time(), 
        newRating, tierClaims[1], tierClaims[2], tierClaims[3], os.time())
    
    return newRating, currentRating
end

local function AwardMythicPoints(player, tier, deathCount)
    if not player then return end
    
    local newRating, previousRating = UpdatePlayerRating(player, tier, deathCount, true)
    if not newRating then return end
    
    local config = TIER_CONFIG[tier]
    local deathPenalty = config.rating_loss * (deathCount or 0)
    local actualGain = newRating - previousRating + deathPenalty
    
    local ratingColor = GetRatingColor(newRating)
    local tierColor = config.color
    
    local msg = actualGain == 0 and "|cffffcc00No rating added because you are rating capped!|r"
        or string.format("|cff00ff00Gained +%d rating|r%s", actualGain, 
           (deathCount > 0 and string.format(" |cffff0000(-%d from deaths)|r", deathPenalty) or ""))
    
    player:SendBroadcastMessage(string.format(
        "%sTier %d completed!|r Mythic+ mode has been ended for this dungeon run.\n%s\nNew Rating: %s%d|r",
        tierColor, tier, msg, ratingColor, newRating
    ))
    
    local itemId, count = 45624, 1
    if newRating > 1800 then itemId, count = 49426, 2
    elseif newRating > 1000 then itemId = 49426
    elseif newRating > 500 then itemId = 47241 end
    
    player:AddItem(itemId, count)
    player:SendBroadcastMessage(string.format("|cffffff00[Mythic]|r Reward: |cffaaff00%s x%d|r", GetItemLink(itemId), count))
    
    if tier < 3 then
        local nextTierKey = KEY_IDS[tier + 1]
        player:AddItem(nextTierKey, 1)
        player:SendBroadcastMessage(string.format("|cffffff00[Mythic]|r Tier %d Keystone granted!", tier + 1))
    end
    
    local map = player:GetMap()
    if map then
        MYTHIC_COMPLETION_STATE[map:GetInstanceId()] = "completed"
    end
end

local function PenalizeMythicFailure(player, tier, deathCount)
    if not player then return end
    
    local newRating, previousRating = UpdatePlayerRating(player, tier, deathCount, false)
    if not newRating then return end
    
    local ratingColor = GetRatingColor(newRating)
    local penalty = previousRating - newRating
    
    player:SendBroadcastMessage(string.format(
        "|cffffff00Mythic failed:|r |cffff0000-%d rating|r (|cffff5555%d deaths|r)\nNew Rating: %s%d|r",
        penalty, deathCount or 0, ratingColor, newRating
    ))
    
    local config = TIER_CONFIG[tier]
    if config and player:HasAura(config.aura) then
        player:RemoveAura(config.aura)
    end
    
    local map = player:GetMap()
    if map then
        MYTHIC_COMPLETION_STATE[map:GetInstanceId()] = "failed"
    end
end

local function ScheduleMythicTimeout(player, instanceId, tier)
    if not player then return end
    
    local config = TIER_CONFIG[tier]
    if not config then return end
    
    local duration = config.duration * 60000
    local auraId = config.aura
    local guid = player:GetGUIDLow()
    
    player:AddAura(auraId, player)
    
    local keepAuraEvent = CreateLuaEvent(function()
        local p = GetPlayerByGUID(guid)
        if not p or not MYTHIC_FLAG_TABLE[instanceId] or MYTHIC_TIMER_EXPIRED[instanceId] then return end
        if not p:HasAura(auraId) then
            p:AddAura(auraId, p)
        end
    end, 5000, 0)
    
    CreateLuaEvent(function()
        local p = GetPlayerByGUID(guid)
        if p and MYTHIC_FLAG_TABLE[instanceId] and not MYTHIC_TIMER_EXPIRED[instanceId] then
            local map = p:GetMap()
            MYTHIC_TIMER_EXPIRED[instanceId] = true
            p:SendBroadcastMessage("|cffff0000[Mythic]|r Time limit exceeded. You are no longer eligible for rewards.")
            MYTHIC_MODE_ENDED[instanceId] = true
            
            if p:HasAura(auraId) then
                p:RemoveAura(auraId)
            end
            
            MYTHIC_COMPLETION_STATE[instanceId] = "failed"
            
            if map then RemoveAffixAurasFromAllCreatures(instanceId, map) end
            CleanupMythicInstance(instanceId)
        end
        RemoveEventById(keepAuraEvent)
    end, duration, 1)
end

local function Colorize(str, color) return string.format("%s%s|r", color or "|cffffffff", str) end

local function GetPlayerRatingLine(player)
    local guid = player:GetGUIDLow()
    local q = SafeDBQuery("SELECT total_points, total_runs FROM character_mythic_rating WHERE guid = %d", guid)
    if not q then
        return "|cff66ccff[Mythic]|r Rating: |cffffcc000|r (no runs yet)"
    end
    local rating, runs = q:GetUInt32(0), q:GetUInt32(1)
    local color = GetRatingColor(rating)
    return string.format("|cff66ccff[Mythic]|r Rating: %s%d|r  (|cffffcc00%d runs|r)", color, rating, runs)
end

local function Gossip_ShowAffixTierMenu(player, creature, tier)
    player:GossipClearMenu()
    local current = WEEKLY_AFFIXES[tier]
    local currentName = current and current.name or "None"
    local header = string.format("|cffffff00Tier %d Affix|r\nCurrent: %s", tier, Colorize(currentName, AFFIX_COLOR_MAP[currentName]))
    player:GossipMenuAddItem(0, header, 0, 999)
    local pool = WEEKLY_AFFIX_POOL[tier] or {}
    for i, aff in ipairs(pool) do
        local name = aff.name
        if not current or name ~= current.name then
            local label = string.format("Set to: %s", Colorize(name, AFFIX_COLOR_MAP[name]))
            player:GossipMenuAddItem(0, label, 0, EncodeAffixIntId(tier, i))
        end
    end
    player:GossipMenuAddItem(0, "Go back", 0, GOSSIP_CHANGE_AFFIXES)
    player:GossipSendMenu(1, creature)
end

local function Gossip_ShowAffixRootMenu(player, creature)
    player:GossipClearMenu()
    player:GossipMenuAddItem(0, "|cffff6600Change Mythic affixes|r", 0, 999)
    for t = 1, 3 do
        local aff = WEEKLY_AFFIXES[t]
        local name = aff and aff.name or "None"
        local color = AFFIX_COLOR_MAP[name] or "|cffffffff"
        local line = string.format("Tier %d (current: %s%s|r)", t, color, name)
        local tid = (t == 1 and GOSSIP_TIER1_MENU) or (t == 2 and GOSSIP_TIER2_MENU) or GOSSIP_TIER3_MENU
        player:GossipMenuAddItem(0, line, 0, tid)
    end
    player:GossipMenuAddItem(0, "Go back", 0, GOSSIP_BACK_MAIN)
    player:GossipSendMenu(1, creature)
end

function Pedestal_OnGossipHello(_, player, creature)
    local map = player:GetMap()
    if not map then return end
    
    local instanceId = map:GetInstanceId()
    player:GossipClearMenu()

    player:GossipMenuAddItem(0, GetPlayerRatingLine(player), 0, 999)

    local completionState = MYTHIC_COMPLETION_STATE[instanceId]
    
    if completionState == "completed" then
        player:GossipMenuAddItem(0, "|cff00ff00Good job, Mythic Champion! You've conquered this challenge!|r", 0, 999)
    elseif completionState == "failed" then
        player:GossipMenuAddItem(0, "|cffff0000You've failed, but try again in a different dungeon!|r", 0, 999)
    elseif MYTHIC_FLAG_TABLE[instanceId] then
        player:GossipMenuAddItem(0, "|cff000000You're already in Mythic mode! Hurry! Go fight!|r", 0, 999)
    else
        local header = "|cff000000This Week's Mythic Affixes:|r"
        for tier = 1, 3 do
            local line = "|cff000000T" .. tier .. ":|r "
            local affixParts = {}
            for i = 1, tier do
                local affix = WEEKLY_AFFIXES[i]
                if affix then
                    local color = AFFIX_COLOR_MAP[affix.name] or "|cffffffff"
                    table.insert(affixParts, color .. affix.name .. "|r")
                end
            end
            line = line .. table.concat(affixParts, "|cff000000, |r")
            header = header .. "\n" .. line
        end
        
        player:GossipMenuAddItem(0, header, 0, 0)
        
        if MYTHIC_KILL_LOCK[instanceId] then
            local lockMsg = "|cffff0000Mythic+ is locked. Reset the dungeon to enable keystone use.|r"
            player:GossipMenuAddItem(0, lockMsg, 0, 999)
            player:SendBroadcastMessage(lockMsg)
        else
            for tier = 1, 3 do
                local config = TIER_CONFIG[tier]
                player:GossipMenuAddItem(10, string.format("%sTier %d|r", config.color, tier), 0, 100 + tier, false, "", 0, ICONS[tier])
            end
        end
    end

    if player:IsGM() then
        player:GossipMenuAddItem(0, "|cffff6600Change Mythic affixes|r", 0, GOSSIP_CHANGE_AFFIXES)
    end

    player:GossipSendMenu(1, creature)
end

function Pedestal_OnGossipSelect(_, player, creature, _, intid)
    if intid == 999 then 
        local map = player:GetMap()
        if map then
            local instanceId = map:GetInstanceId()
            local completionState = MYTHIC_COMPLETION_STATE[instanceId]
            
            if completionState == "completed" then
                player:SendBroadcastMessage("|cff00ff00[Mythic]|r Congratulations! Reset the dungeon to attempt a higher tier or try other dungeons!")
            elseif completionState == "failed" then
                player:SendBroadcastMessage("|cffff0000[Mythic]|r Don't give up! Reset this dungeon or try a different one with a fresh keystone!")
            end
        end
        
        player:GossipComplete() 
        return 
    end

    if intid == GOSSIP_CHANGE_AFFIXES then
        if not player:IsGM() then
            player:SendBroadcastMessage("|cffff0000[Mythic]|r You do not have permission to change affixes.")
            player:GossipComplete()
            return
        end
        Gossip_ShowAffixRootMenu(player, creature)
        return
    end

    if intid == GOSSIP_BACK_MAIN then
        Pedestal_OnGossipHello(nil, player, creature)
        return
    end

    if intid == GOSSIP_TIER1_MENU or intid == GOSSIP_TIER2_MENU or intid == GOSSIP_TIER3_MENU then
        if not player:IsGM() then
            player:SendBroadcastMessage("|cffff0000[Mythic]|r You do not have permission to change affixes.")
            player:GossipComplete()
            return
        end
        local tier = (intid == GOSSIP_TIER1_MENU and 1) or (intid == GOSSIP_TIER2_MENU and 2) or 3
        Gossip_ShowAffixTierMenu(player, creature, tier)
        return
    end

    if intid >= 300 then
        if not player:IsGM() then
            player:SendBroadcastMessage("|cffff0000[Mythic]|r You do not have permission to change affixes.")
            player:GossipComplete()
            return
        end
        local tier, idx = DecodeAffixIntId(intid)
        if tier < 1 or tier > 3 then
            player:GossipComplete()
            return
        end
        local pool = WEEKLY_AFFIX_POOL[tier] or {}
        local chosen = pool[idx]
        if not chosen then
            player:SendBroadcastMessage("|cffff0000[Mythic]|r Invalid affix selection.")
            player:GossipComplete()
            return
        end
        local before = WEEKLY_AFFIXES[tier] and WEEKLY_AFFIXES[tier].name or "None"
        WEEKLY_AFFIXES[tier] = chosen
        SendWorldMessage(string.format("|cffffcc00[Mythic]|r Tier %d affix set: %s -> %s", tier, before, chosen.name))
        player:SendBroadcastMessage("|cff66ccff[Mythic]|r New affixes: " .. (function(maxTier) local parts = {} for t=1,(maxTier or 3) do local aff=WEEKLY_AFFIXES[t] local color=aff and (AFFIX_COLOR_MAP[aff.name] or "|cffffffff") or "|cffffffff" local name=aff and aff.name or "None" table.insert(parts, string.format("|cffffff00T%d|r: %s%s|r", t, color, name)) end return table.concat(parts, "  ") end)(3))
        Gossip_ShowAffixTierMenu(player, creature, tier)
        return
    end
    
    if intid >= 101 and intid <= 103 then
        local map = player:GetMap()
        if not map then 
            player:SendBroadcastMessage("Error: No map context.") 
            player:GossipComplete() 
            return 
        end
        
        local instanceId = map:GetInstanceId()
        local tier = intid - 100
        local keyId = KEY_IDS[tier]
        
        if MYTHIC_KILL_LOCK[instanceId] then 
            player:SendBroadcastMessage("|cffff0000[Mythic]|r A creature was already killed. Reset the dungeon to use a keystone.")
            player:GossipComplete() 
            return 
        end
        
        if MYTHIC_FLAG_TABLE[instanceId] then 
            player:SendBroadcastMessage("|cffff0000Mythic mode has already been activated in this instance.|r") 
            player:GossipComplete() 
            return 
        end
        
        if not player:HasItem(keyId) then 
            player:SendBroadcastMessage("You do not have the required Tier " .. tier .. " Keystone.") 
            player:GossipComplete() 
            return 
        end
        
        if map:GetDifficulty() == 0 then 
            player:SendBroadcastMessage("|cffff0000Mythic keys cannot be used in Normal mode dungeons.|r") 
            player:GossipComplete() 
            return 
        end
        
        local guid = player:GetGUIDLow()
        local affixes = GetAffixSet(tier)
        local config = TIER_CONFIG[tier]
        
        local affixNames = {}
        for i = 1, tier do
            local affix = WEEKLY_AFFIXES[i]
            if affix then
                local color = AFFIX_COLOR_MAP[affix.name] or "|cffffffff"
                table.insert(affixNames, color .. affix.name .. "|r")
            end
        end
        
        MYTHIC_FLAG_TABLE[instanceId] = true
        MYTHIC_AFFIXES_TABLE[instanceId] = affixes
        MYTHIC_REWARD_CHANCE_TABLE[instanceId] = tier == 1 and 1.5 or tier == 2 and 2.0 or 5.0
        MYTHIC_TIER_TABLE[instanceId] = tier
        MYTHIC_COMPLETION_STATE[instanceId] = "active"
        MYTHIC_DEATHS[instanceId] = {}
        
        ScheduleMythicTimeout(player, instanceId, tier)
        
        local ratingQuery = SafeDBQuery("SELECT total_points FROM character_mythic_rating WHERE guid = %d", guid)
        local currentRating = ratingQuery and ratingQuery:GetUInt32(0) or 0
        local ratingColor = GetRatingColor(currentRating)
        
        player:SendBroadcastMessage(string.format(
            "%sTier %d Keystone|r inserted.\nAffixes: %s\nCurrent Rating: %s%d|r",
            config.color, tier, table.concat(affixNames, ", "), ratingColor, currentRating
        ))
        
        creature:SendUnitSay("Good luck... You'll need it.", 0)
        player:RemoveItem(keyId, 1)
        
        ApplyAuraToNearbyCreatures(player, affixes)
        StartAuraLoop(player, instanceId, map:GetMapId(), affixes)
        
        SafeDBExecute([[
            INSERT INTO character_mythic_instance_state (guid, instance_id, map_id, tier, created_at) 
            VALUES (%d, %d, %d, %d, FROM_UNIXTIME(%d)) 
            ON DUPLICATE KEY UPDATE tier = VALUES(tier), created_at = VALUES(created_at)
        ]], guid, instanceId, map:GetMapId(), tier, os.time())
        
        player:GossipComplete()
    end
end

RegisterCreatureGossipEvent(PEDESTAL_NPC_ENTRY, 1, Pedestal_OnGossipHello)
RegisterCreatureGossipEvent(PEDESTAL_NPC_ENTRY, 2, Pedestal_OnGossipSelect)

RegisterPlayerEvent(8, function(event, killer, victim)
    if not victim or not victim:IsPlayer() then return end

    local map = victim:GetMap()
    if not map or map:GetDifficulty() == 0 then return end

    local instanceId = map:GetInstanceId()
    if not MYTHIC_FLAG_TABLE[instanceId] then return end

    local guid = victim:GetGUIDLow()
    MYTHIC_DEATHS[instanceId] = MYTHIC_DEATHS[instanceId] or {}
    MYTHIC_DEATHS[instanceId][guid] = (MYTHIC_DEATHS[instanceId][guid] or 0) + 1
end)

RegisterPlayerEvent(7, function(_, killer, victim)
    if not killer or not killer:IsPlayer() or not victim or victim:GetObjectType() ~= "Creature" then return end

    local map = killer:GetMap()
    if not map or not map:IsDungeon() or map:GetDifficulty() < 1 then return end

    local instanceId = map:GetInstanceId()
    local mapId = map:GetMapId()

    if killer:GetLevel() < 80 then return end
    if MYTHIC_FLAG_TABLE[instanceId] or MYTHIC_MODE_ENDED[instanceId] or MYTHIC_KILL_LOCK[instanceId] then return end

    local finalBoss = MYTHIC_FINAL_BOSSES[mapId] and MYTHIC_FINAL_BOSSES[mapId].final
    if finalBoss and victim:GetEntry() == finalBoss then return end

    if not MYTHIC_HOSTILE_FACTIONS[victim:GetFaction()] then return end

    MYTHIC_KILL_LOCK[instanceId] = true

    local msg = "|cffff0000[Mythic]|r Mythic+ is now locked because a hostile enemy was slain. Reset the dungeon to enable keystone use."
    for _, player in pairs(map:GetPlayers() or {}) do
        player:SendBroadcastMessage(msg)
    end
end)

RegisterPlayerEvent(28, function(_, player)
    local map = player:GetMap()
    if not map then return end
    
    local instanceId, mapId, guid = map:GetInstanceId(), map:GetMapId(), player:GetGUIDLow()
    
    if MYTHIC_COMPLETION_STATE[instanceId] == "failed" or MYTHIC_COMPLETION_STATE[instanceId] == "completed" then
        return
    end
    
    local result = SafeDBQuery(
        "SELECT tier, UNIX_TIMESTAMP(created_at) FROM character_mythic_instance_state WHERE guid = %d AND instance_id = %d AND map_id = %d",
        guid, instanceId, mapId
    )
    
    if not result then return end
    
    local tier, timestamp = result:GetUInt32(0), result:GetUInt32(1)
    
    if os.time() - timestamp > INSTANCE_STATE_TIMEOUT then
        MYTHIC_MODE_ENDED[instanceId] = nil
        SafeDBExecute(
            "DELETE FROM character_mythic_instance_state WHERE guid = %d AND instance_id = %d AND map_id = %d",
            guid, instanceId, mapId
        )
        return
    end

    local affixes = GetAffixSet(tier)
    MYTHIC_FLAG_TABLE[instanceId] = true
    MYTHIC_AFFIXES_TABLE[instanceId] = affixes
    MYTHIC_REWARD_CHANCE_TABLE[instanceId] = tier == 1 and 1.5 or tier == 2 and 2.0 or 5.0
    MYTHIC_TIER_TABLE[instanceId] = tier
    MYTHIC_COMPLETION_STATE[instanceId] = "active"
    
    player:SendBroadcastMessage("|cffffff00[Mythic]|r Resuming active Mythic+ affixes.")
    ApplyAuraToNearbyCreatures(player, affixes)
    
    if not MYTHIC_LOOP_HANDLERS[instanceId] then
        StartAuraLoop(player, instanceId, mapId, affixes)
    end

    local config = TIER_CONFIG[tier]
    if config and not player:HasAura(config.aura) then
        player:AddAura(config.aura, player)
    end
end)

RegisterPlayerEvent(3, function(_, player)
    local affixNames = {}
    for _, affix in ipairs(WEEKLY_AFFIXES) do
        local color = AFFIX_COLOR_MAP[affix.name] or "|cffffffff"
        table.insert(affixNames, color .. affix.name .. "|r")
    end
    local msg = "|cffffcc00[Mythic]|r This week's affixes: " .. table.concat(affixNames, ", ")
    player:SendBroadcastMessage(msg)
end)

local function GetAffixNamesString(maxTier)
    local parts = {}
    for t = 1, (maxTier or 3) do
        local aff = WEEKLY_AFFIXES[t]
        local color = aff and (AFFIX_COLOR_MAP[aff.name] or "|cffffffff") or "|cffffffff"
        local name = aff and aff.name or "None"
        table.insert(parts, string.format("|cffffff00T%d|r: %s%s|r", t, color, name))
    end
    return table.concat(parts, "  ")
end

local function FindAffixByNameInTier(tier, nameLower)
    local pool = WEEKLY_AFFIX_POOL[tier]
    if not pool then return nil end
    for _, aff in ipairs(pool) do
        if aff.name:lower() == nameLower then
            return aff
        end
    end
    return nil
end

local function RerollTierAffix(tier)
    local pool = WEEKLY_AFFIX_POOL[tier]
    if not pool or #pool == 0 then return nil end
    local choice = pool[math.random(#pool)]
    WEEKLY_AFFIXES[tier] = choice
    return choice
end

RegisterPlayerEvent(42, function(_, player, command)
    if not player then return false end

    local cmd = command:lower():gsub("[#./]", "")
    local guid = player:GetGUIDLow()
    local now = os.time()

    if cmd == "mythicaffix" then
        player:SendBroadcastMessage("|cff66ccff[Mythic]|r Current affixes: " .. GetAffixNamesString(3))
        return false
    end

    if cmd:sub(1, 10) == "mythicroll" then
        if not player:IsGM() then
            player:SendBroadcastMessage("|cffff0000[Mythic]|r You do not have permission to use this command.")
            return false
        end

        local tokens = {}
        for w in cmd:gmatch("%S+") do table.insert(tokens, w) end
        if #tokens == 1 then
            local old = { WEEKLY_AFFIXES[1] and WEEKLY_AFFIXES[1].name, WEEKLY_AFFIXES[2] and WEEKLY_AFFIXES[2].name, WEEKLY_AFFIXES[3] and WEEKLY_AFFIXES[3].name }
            for t = 1, 3 do RerollTierAffix(t) end
            SendWorldMessage(string.format("|cffffcc00[Mythic]|r Affixes re-rolled: T1 %s -> %s, T2 %s -> %s, T3 %s -> %s",
                old[1] or "None", WEEKLY_AFFIXES[1].name, old[2] or "None", WEEKLY_AFFIXES[2].name, old[3] or "None", WEEKLY_AFFIXES[3].name))
            return false
        end

        if tokens[2] ~= "tier" or not tonumber(tokens[3]) then
            player:SendBroadcastMessage("|cffff0000[Mythic]|r Usage: .mythicroll  |  .mythicroll tier <1-3>  |  .mythicroll tier <1-3> <affix name>")
            return false
        end

        local tier = tonumber(tokens[3])
        if tier < 1 or tier > 3 then
            player:SendBroadcastMessage("|cffff0000[Mythic]|r Tier must be 1, 2, or 3.")
            return false
        end

        if #tokens == 3 then
            local before = WEEKLY_AFFIXES[tier] and WEEKLY_AFFIXES[tier].name or "None"
            local after = RerollTierAffix(tier)
            if after then
                SendWorldMessage(string.format("|cffffcc00[Mythic]|r Tier %d affix re-rolled: %s -> %s", tier, before, after.name))
                player:SendBroadcastMessage("|cff66ccff[Mythic]|r New affixes: " .. GetAffixNamesString(3))
            end
            return false
        end

        local desired = table.concat(tokens, " ", 4):gsub("^%s+", ""):gsub("%s+$", "")
        if desired == "" then
            player:SendBroadcastMessage("|cffff0000[Mythic]|r Missing affix name. Example: .mythicroll tier 1 resistant")
            return false
        end

        local aff = FindAffixByNameInTier(tier, desired)
        if not aff then
            local names = {}
            for _, a in ipairs(WEEKLY_AFFIX_POOL[tier] or {}) do table.insert(names, a.name:lower()) end
            player:SendBroadcastMessage("|cffff0000[Mythic]|r Invalid affix for Tier " .. tier .. ". Valid: " .. table.concat(names, ", "))
            return false
        end

        local before = WEEKLY_AFFIXES[tier] and WEEKLY_AFFIXES[tier].name or "None"
        WEEKLY_AFFIXES[tier] = aff
        SendWorldMessage(string.format("|cffffcc00[Mythic]|r Tier %d affix set: %s -> %s", tier, before, aff.name))
        player:SendBroadcastMessage("|cff66ccff[Mythic]|r New affixes: " .. GetAffixNamesString(3))
        return false
    end

    if cmd == "mythicrating" then
        local last = __MYTHIC_RATING_COOLDOWN__[guid] or 0
        if now - last < COMMAND_COOLDOWN then
            player:SendBroadcastMessage("|cffffcc00[Mythic]|r You can only use this command once every 5 minutes.")
            return false
        end
        __MYTHIC_RATING_COOLDOWN__[guid] = now

        local query = SafeDBQuery("SELECT total_points, total_runs FROM character_mythic_rating WHERE guid = %d", guid)
        if query then
            local rating, runs = query:GetUInt32(0), query:GetUInt32(1)
            local color = GetRatingColor(rating)
            player:SendBroadcastMessage(string.format(
                "|cff66ccff[Mythic]|r Rating: %s%d|r (|cffffcc00%d runs completed|r)", 
                color, rating, runs
            ))
        else
            player:SendBroadcastMessage("|cffff0000[Mythic]|r No rating found. Complete a Mythic+ dungeon to begin tracking.")
        end
        return false
    end

    if cmd == "mythichelp" then
        player:SendBroadcastMessage("|cff66ccff[Mythic]|r Available commands:")
        player:SendBroadcastMessage("|cffffff00.mythicrating|r - View your Mythic+ rating and runs.")
        player:SendBroadcastMessage("|cffffff00.mythicaffix|r - View the current Mythic affixes.")
        player:SendBroadcastMessage("|cffffff00.mythichelp|r - Show this help menu.")
        if player:IsGM() then
            player:SendBroadcastMessage("|cffff6600.mythicroll|r - GM: Reroll all affixes.")
            player:SendBroadcastMessage("|cffff6600.mythicroll tier <1-3>|r - GM: Reroll a specific tier.")
            player:SendBroadcastMessage("|cffff6600.mythicroll tier <1-3> <affix>|r - GM: Set a specific affix (e.g., resistant).")
            player:SendBroadcastMessage("|cffff6600.mythicreset|r - GM: Start full server rating reset.")
            player:SendBroadcastMessage("|cffff6600.mythicreset confirm|r - GM: Confirm the reset within 30 seconds.")
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
        local pendingTime = __MYTHIC_RESET_PENDING__[guid]
        if not pendingTime or now - pendingTime > RESET_CONFIRM_TIMEOUT then
            player:SendBroadcastMessage("|cffff0000[Mythic]|r No reset pending or confirmation expired. Use |cff00ff00.mythicreset|r first.")
        else
            __MYTHIC_RESET_PENDING__[guid] = nil
            CharDBExecute([[
                UPDATE character_mythic_rating
                SET total_points = 0, total_runs = 0,
                    claimed_tier1 = 0, claimed_tier2 = 0, claimed_tier3 = 0,
                    last_updated = NOW()
            ]])
            player:SendBroadcastMessage("|cff00ff00[Mythic]|r All player ratings and run counts have been reset.")
            SendWorldMessage("|cffffcc00[Mythic]|r A Game Master has reset all Mythic+ player ratings.")
        end
        return false
    end
end)

for mapId, data in pairs(MYTHIC_FINAL_BOSSES) do
    local bossId = data.final
    if bossId then
        RegisterCreatureEvent(bossId, 4, function(_, creature)
            local map = creature:GetMap()
            if not map then return end

            local instanceId = map:GetInstanceId()
            MYTHIC_MODE_ENDED[instanceId] = true
            
            if not MYTHIC_FLAG_TABLE[instanceId] then return end

            local expired = MYTHIC_TIMER_EXPIRED[instanceId]
            local tier = MYTHIC_TIER_TABLE[instanceId] or 1

            local playerDeaths = {}
            for _, player in pairs(map:GetPlayers() or {}) do
                local guid = player:GetGUIDLow()
                playerDeaths[guid] = MYTHIC_DEATHS[instanceId] and MYTHIC_DEATHS[instanceId][guid] or 0
            end

            for _, player in pairs(map:GetPlayers() or {}) do
                if player:IsAlive() and player:IsInWorld() then
                    if expired then
                        player:SendBroadcastMessage("|cffff0000[Mythic]|r Time expired. No rewards granted.")
                        MYTHIC_COMPLETION_STATE[instanceId] = "failed"
                    else
                        local deaths = playerDeaths[player:GetGUIDLow()] or 0
                        AwardMythicPoints(player, tier, deaths)
                        
                        local config = TIER_CONFIG[tier]
                        if config and player:HasAura(config.aura) then
                            player:RemoveAura(config.aura)
                        end
                    end
                end
            end

            if not expired then
                local x, y, z, o = creature:GetX(), creature:GetY(), creature:GetZ(), creature:GetO()
                x, y = x - math.cos(o) * 2, y - math.sin(o) * 2
                SpawnMythicRewardChest(x, y, z, o, creature:GetMapId(), instanceId, tier)
            end

            RemoveAffixAurasFromAllCreatures(instanceId, map)
            CleanupMythicInstance(instanceId)
        end)
    end
end
