print("[Mythic] Mythic.lua loaded successfully.")

dofile("Scripts/MythicPlus/MythicBosses.lua")

local PEDESTAL_NPC_ENTRY = 900001

local TIERS = {
    [1] = {
        icon = "Interface\\Icons\\INV_Enchant_AbyssCrystal",
        rewardChance = 1.5,
        keys = {
            [1] = { id = 900100, name = "|cff8B4513Enrage|r", auras = {8599}, interval = 6000 },
            [2] = { id = 900101, name = "|cff00FF00Rejuvenation|r", auras = {48441, 61301}, interval = 6000 },
            [3] = { id = 900102, name = "|cff66ccffTurtling|r", auras = {871}, interval = 4000 }
        }
    },
    [2] = {
        icon = "Interface\\Icons\\INV_Enchant_VoidCrystal",
        rewardChance = 2.0,
        keys = {
            [1] = { id = 900103, name = "|cff228b22Enrage + Rejuvenation|r", auras = {8599, 48441, 61301}, interval = 6000 },
            [2] = { id = 900104, name = "|cff800080Enrage + Turtling|r", auras = {8599, 871}, interval = 6000 },
            [3] = { id = 900105, name = "|cff88ddffTurtling + Rejuvenation|r", auras = {871, 48441, 61301}, interval = 6000 }
        }
    },
    [3] = {
        icon = "Interface\\Icons\\INV_Enchant_NexusCrystal",
        rewardChance = 5.0,
        keys = {
            [1] = { id = 900106, name = "|cffff0000All Effects (Mythic Tier 3)|r", auras = {8599, 48441, 61301, 871}, interval = 6000 }
        }
    }
}

local MYSTERY_REWARD_ID = 50274
local MYTHIC_SCAN_RADIUS = 240
local MYTHIC_ENTRY_RANGE = { start = 1, stop = 60000 }

if MYTHIC_FLAG_TABLE == nil then MYTHIC_FLAG_TABLE = {} end
if MYTHIC_AFFIXES_TABLE == nil then MYTHIC_AFFIXES_TABLE = {} end
if MYTHIC_LOOP_HANDLERS == nil then MYTHIC_LOOP_HANDLERS = {} end
if MYTHIC_REWARD_CHANCE_TABLE == nil then MYTHIC_REWARD_CHANCE_TABLE = {} end

local function ApplyAuraToNearbyCreatures(player, affixes)
    local seen = {}
    local map = player:GetMap()
    if not map then return end

    for entry = MYTHIC_ENTRY_RANGE.start, MYTHIC_ENTRY_RANGE.stop do
        local creature = player:GetNearestCreature(MYTHIC_SCAN_RADIUS, entry)
        if creature then
            local guid = creature:GetGUIDLow()
            if not seen[guid] and creature:IsAlive() and creature:IsInWorld() then
                seen[guid] = true
                for _, spellId in ipairs(affixes) do
                    creature:CastSpell(creature, spellId, true)
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

function Pedestal_OnGossipHello(event, player, creature)
    local map = player:GetMap()
    if not map then return end

    local instanceId = map:GetInstanceId()
    player:GossipClearMenu()

    if MYTHIC_FLAG_TABLE[instanceId] then
        player:GossipMenuAddItem(0, "|cffff0000You've already used a keystone.|r", 0, 999)
    else
        player:GossipMenuAddItem(0, "|cff000000Select a Mythic Keystone Tier|r", 0, 999)
        for tier = 1, 3 do
            local data = TIERS[tier]
            player:GossipMenuAddItem(10, "Tier " .. tier, 0, 100 + tier, false, "", 0, data.icon)
        end
    end

    player:GossipSendMenu(1, creature)
end

function Pedestal_OnGossipSelect(event, player, creature, sender, intid, code)
    if intid == 999 then
        player:GossipComplete()
        return
    end

    if intid >= 100 and intid <= 103 then
        local tier = intid - 100
        local tierData = TIERS[tier]
        player:GossipClearMenu()
        player:GossipMenuAddItem(0, "|cff000000Which keystone will you use? (Tier " .. tier .. ")|r", 0, 999, false, "", 0, tierData.icon)

        for index, key in ipairs(tierData.keys) do
            if player:HasItem(key.id) then
                player:GossipMenuAddItem(0, key.name, 0, (tier * 10) + index)
            else
                player:GossipMenuAddItem(0, key.name .. " |cffff0000(Missing)|r", 0, 900 + index)
            end
        end

        player:GossipMenuAddItem(0, "<< Back", 0, 998)
        player:GossipSendMenu(1, creature)
        return
    end

    if intid == 998 then
        Pedestal_OnGossipHello(event, player, creature)
        return
    end

    local selectedTier = math.floor(intid / 10)
    local keyIndex = intid % 10
    local selected = TIERS[selectedTier] and TIERS[selectedTier].keys[keyIndex]

    if not selected then
        player:GossipComplete()
        return
    end

    local map = player:GetMap()
    if not map then
        player:SendBroadcastMessage("You must be in a valid dungeon.")
        player:GossipComplete()
        return
    end

    local instanceId = map:GetInstanceId()
    local mapId = player:GetMapId()
    if not instanceId then
        player:SendBroadcastMessage("Could not get instance ID.")
        player:GossipComplete()
        return
    end

    if not player:HasItem(selected.id) then
        player:SendBroadcastMessage("You do not have that keystone.")
        player:GossipComplete()
        return
    end

    MYTHIC_FLAG_TABLE[instanceId] = true
    MYTHIC_AFFIXES_TABLE[instanceId] = selected.auras
    MYTHIC_REWARD_CHANCE_TABLE[instanceId] = TIERS[selectedTier].rewardChance
    player:SendBroadcastMessage("|cff00ff00Mythic Mode activated with affix: " .. selected.name .. "|r")
    player:RemoveItem(selected.id, 1)
    ApplyAuraToNearbyCreatures(player, selected.auras)
    StartAuraLoop(player, instanceId, mapId, selected.auras, selected.interval)
    player:GossipComplete()
end

RegisterCreatureGossipEvent(PEDESTAL_NPC_ENTRY, 1, Pedestal_OnGossipHello)
RegisterCreatureGossipEvent(PEDESTAL_NPC_ENTRY, 2, Pedestal_OnGossipSelect)

local function OnBossKilled(event, creature, killer)
    if not creature or not killer then return end
    if killer:GetObjectType() ~= "Player" then return end

    local player = killer
    local map = creature:GetMap()
    if not map then return end

    local instanceId = map:GetInstanceId()
    local mapId = creature:GetMapId()
    if not instanceId or not MYTHIC_FLAG_TABLE[instanceId] then return end

    local bossData = MythicBosses[mapId]
    if not bossData then return end

    local creatureId = creature:GetEntry()
    for _, bossId in ipairs(bossData.bosses) do
        if bossId == creatureId then
            local chance = MYTHIC_REWARD_CHANCE_TABLE[instanceId] or 0
            local roll = math.random()
            if roll <= (chance / 100) then
                player:AddItem(MYSTERY_REWARD_ID, 1)
                player:SendBroadcastMessage("|cffffff00You received a mysterious prize from the boss!|r")
            end
            break
        end
    end

    if creatureId == bossData.final then
        MYTHIC_FLAG_TABLE[instanceId] = nil
        MYTHIC_AFFIXES_TABLE[instanceId] = nil
        MYTHIC_REWARD_CHANCE_TABLE[instanceId] = nil
        if MYTHIC_LOOP_HANDLERS[instanceId] then
            RemoveEventById(MYTHIC_LOOP_HANDLERS[instanceId])
            MYTHIC_LOOP_HANDLERS[instanceId] = nil
        end
        player:SendBroadcastMessage("|cffff4444Final boss defeated. Mythic Mode ended.|r")
    end
end

local function onKillBoss(event, player, boss)
    if not boss then return end
    for _, data in pairs(MythicBosses) do
        for _, bossId in ipairs(data.bosses) do
            if boss:GetEntry() == bossId then
                OnBossKilled(nil, boss, player)
                return
            end
        end
    end
end

RegisterPlayerEvent(7, onKillBoss)
RegisterPlayerEvent(58, onKillBoss)
