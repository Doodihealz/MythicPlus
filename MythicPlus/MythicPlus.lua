-------------------------------------------------------------------------------
-- MythicPlus - Mythic+ Dungeon Tracker for WotLK 3.3.5
-- /mythic        - Toggle main window
-- /mythic start  - Start a mythic+ run
-- /mythic stop   - End the current run
-- /mythic tier   - Cycle to next tier set
-- /mythic reset  - Reset all progress
-- /mythic key N  - Set keystone level (e.g. /mythic key 15)
-- /mythic help   - Show commands
--
-- AIO Integration: server can push state via AIO handlers:
--   AIO.Handle(player, "MythicPlus", "StartRun",    dataTable)
--   AIO.Handle(player, "MythicPlus", "StopRun",     dataTable)
--   AIO.Handle(player, "MythicPlus", "UpdateAll",   dataTable)
--   AIO.Handle(player, "MythicPlus", "SetKills",    current, required)
--   AIO.Handle(player, "MythicPlus", "SetTimer",    secondsRemaining)
--   AIO.Handle(player, "MythicPlus", "SetDeaths",   deathCount)
--   AIO.Handle(player, "MythicPlus", "SetTier",     tierNum)
--   AIO.Handle(player, "MythicPlus", "SetProgress",  pct)
--   AIO.Handle(player, "MythicPlus", "SetAffixes",  affixTable)
--   AIO.Handle(player, "MythicPlus", "Show")
--   AIO.Handle(player, "MythicPlus", "Hide")
-------------------------------------------------------------------------------

local addon = CreateFrame("Frame", "MythicPlusAddon", UIParent)

-- Some client/runtime combinations can emit chat events without a matching
-- CHAT_* format global (e.g. CHAT_FOO_GET), which makes ChatFrame.lua call
-- format(nil, ...) and throw a global UI error. Fill missing formats safely.
local function InstallChatFormatGuard()
    if _G.__MYTHICPLUS_CHATFORMAT_GUARD_INSTALLED__ then
        return
    end
    if type(ChatFrame_OnEvent) ~= "function" then
        return
    end

    _G.__MYTHICPLUS_CHATFORMAT_GUARD_INSTALLED__ = true

    local originalChatFrameOnEvent = ChatFrame_OnEvent

    local function EnsureFormatGlobal(name)
        if type(name) == "string" and name ~= "" and _G[name] == nil then
            _G[name] = "%s"
        end
    end

    ChatFrame_OnEvent = function(self, event, ...)
        if type(event) == "string" then
            local chatType = event:match("^CHAT_MSG_(.+)$")
            if chatType then
                EnsureFormatGlobal("CHAT_" .. chatType .. "_GET")

                if chatType == "CHANNEL_NOTICE" or chatType == "CHANNEL_NOTICE_USER" then
                    local noticeType = select(1, ...)
                    if type(noticeType) == "string" and noticeType ~= "" then
                        EnsureFormatGlobal("CHAT_" .. noticeType .. "_NOTICE")
                    end
                end
            end
        end

        return originalChatFrameOnEvent(self, event, ...)
    end
end

InstallChatFormatGuard()

-- AIO availability flag (true if AIO addon is loaded)
local AIO_AVAILABLE = (AIO ~= nil)
local MEDIA_ROOT = "Interface\\AddOns\\MythicPlus\\Media\\"
local BACKGROUND_TEXTURE_PRIMARY = MEDIA_ROOT .. "Mythicplusbackground_wow.tga"
local BACKGROUND_TEXTURE_FALLBACK = MEDIA_ROOT .. "Mythicplusbackground.tga"
local BACKGROUND_TEXTURE_FALLBACK2 = MEDIA_ROOT .. "Mythicplusbackground.png"
local LOGO_TEXTURE_PRIMARY = MEDIA_ROOT .. "Mythicpluslogo.tga"
local LOGO_TEXTURE_FALLBACK = MEDIA_ROOT .. "Mythicpluslogo.png"
local BARGLOW_TEXTURE_PRIMARY = MEDIA_ROOT .. "Barglow.tga"
local BARGLOW_TEXTURE_FALLBACK = MEDIA_ROOT .. "Barglow.png"
local STAR_TEXTURE_PRIMARY    = MEDIA_ROOT .. "Star.tga"
local STAR_TEXTURE_FALLBACK   = MEDIA_ROOT .. "Star.png"
local STAR_TEXTURE_WARNED     = false
local BARGLOW_TRIGGER_RATIO = 0.80
local BARGLOW_FADE_DURATION = 0.24
local BARGLOW_MAX_SPREAD = 8
local BARGLOW_MAX_ALPHA = 0.60
local DEFAULT_COMPLETION_TARGET_PCT = 80
local SERVER_HEARTBEAT_IDLE_SEC = 30
local SERVER_HEARTBEAT_ACTIVE_SEC = 10
local ADDON_BUILD_VERSION = "1.1.0"
local THEME_ACCENT        = {0.53, 0.50, 1.00}
local THEME_BORDER        = {0.34, 0.31, 0.62}
local THEME_HEADER_BG     = {0.11, 0.10, 0.18}
local THEME_CONTROL_IDLE  = {0.78, 0.74, 1.00}
local THEME_CONTROL_HOVER = {0.92, 0.89, 1.00}
local THEME_GLOW          = {0.70, 0.64, 1.00}
local THEME_CHAT_PREFIX = "|cff8888ff[MythicPlus]|r"
local ADDON_GITHUB_URL = "https://github.com/Doodihealz/MythicPlus"
local FRAME_DEFAULT_WIDTH = 320
local FRAME_DEFAULT_EXPANDED_HEIGHT = 400
local FRAME_DEFAULT_MINIMIZED_HEIGHT = 208
local FRAME_MIN_WIDTH_EXPANDED = 300
local FRAME_MIN_WIDTH_MINIMIZED = 260
local FRAME_MIN_HEIGHT_EXPANDED = 320
local FRAME_MIN_HEIGHT_MINIMIZED = 168
local EXPANDED_LAYOUT_FIXED_HEIGHT = 90
local EXPANDED_LAYOUT_AFFIX_RATIO = 0.58
local EXPANDED_LAYOUT_MIN_AFFIX_HEIGHT = 118
local EXPANDED_LAYOUT_MIN_STATS_HEIGHT = 92
local MINIMIZED_LAYOUT_FIXED_HEIGHT = 76
local MINIMIZED_LAYOUT_MIN_STATS_HEIGHT = 92

-------------------------------------------------------------------------------
-- Saved Variables & Defaults
-------------------------------------------------------------------------------
local defaults = {
    pos = nil,          -- {x, y} center position
    keyLevel = 10,
    lastTierSet = 1,
    timerMinutes = 30,
    locked = false,
    alwaysHideCloseButton = false,
    windowOpacity = 1.00,
    autoHideOutOfMythic = false,
    minimized = false,
    pollRate = 0.25,    -- seconds between UI refreshes
    visible = false,    -- whether window was open at logout
    runSnapshot = nil,  -- last in-progress run state for /reload continuity
    lastKnownAffixes = nil, -- persisted server affix payload for solo/idle display
    width = FRAME_DEFAULT_WIDTH,
    heightExpanded = FRAME_DEFAULT_EXPANDED_HEIGHT,
    heightMinimized = FRAME_DEFAULT_MINIMIZED_HEIGHT,
    resizeEnabled = true,
    githubLinkEnabled = true,
    showAffixTips = true,
}

-------------------------------------------------------------------------------
-- Affix Pools (thematic for WotLK)
-------------------------------------------------------------------------------
local AFFIX_TIER_SETS = {
    {
        tier1 = { "Devouring", "Rot", "Falling Stars" },
        tier2 = { "Consecration", "Bursting" },
        tier3 = { "Annihilation" },
    },
    {
        tier1 = { "Plagued", "Necrotic", "Bolstering" },
        tier2 = { "Sanguine", "Explosive" },
        tier3 = { "Tyrannical" },
    },
    {
        tier1 = { "Fortified", "Raging", "Spiteful" },
        tier2 = { "Quaking", "Storming" },
        tier3 = { "Infernal" },
    },
    {
        tier1 = { "Teeming", "Volcanic", "Entangling" },
        tier2 = { "Grievous", "Inspiring" },
        tier3 = { "Prideful" },
    },
}

-------------------------------------------------------------------------------
-- State
-------------------------------------------------------------------------------
local state = {
    running = false,
    startTime = 0,
    duration = 0,       -- remaining run time in seconds
    timerMax = 0,       -- original total run duration in seconds
    killsRequired = 0,
    killsCurrent = 0,
    currentTierSet = 1,
    keyLevel = 10,
    paused = false,
    finished = false,
    deaths = 0,
    serverControlled = false,  -- true when server drives the run via AIO
    minimized = false,
    summary = nil,      -- { timeTaken, deaths, rating }
    summaryPendingUntil = 0,
    summaryShown = false,
    awaitingFinalBossAfterTimeout = false,
    completionTargetPct = DEFAULT_COMPLETION_TARGET_PCT,
    idleSince = 0,
    lastServerHeartbeatAt = 0,
    expandedHeight = FRAME_DEFAULT_EXPANDED_HEIGHT,
    minimizedHeight = FRAME_DEFAULT_MINIMIZED_HEIGHT,
    gmAffixEditor = {
        canEdit = false,
        nextRerollAt = 0,
        tiers = {},
    },
    gmLocalMode = false,  -- force-show GM affix panel via /mythic gmaffix
}

local function IsMythicModeActive()
    return (state.running and not state.finished) or state.awaitingFinalBossAfterTimeout
end

local function SendTimerAddonHeartbeat(force)
    if not AIO_AVAILABLE or not AIO or not AIO.Handle then
        return false
    end
    if type(UnitExists) == "function" and not UnitExists("player") then
        return false
    end

    local now = GetTime()
    local interval = IsMythicModeActive() and SERVER_HEARTBEAT_ACTIVE_SEC or SERVER_HEARTBEAT_IDLE_SEC
    local last = tonumber(state.lastServerHeartbeatAt or 0) or 0
    if not force and last > 0 and (now - last) < interval then
        return false
    end

    local ok = pcall(AIO.Handle, "MythicPlusServer", "TimerAddonReady", ADDON_BUILD_VERSION)
    if ok then
        state.lastServerHeartbeatAt = now
        return true
    end
    return false
end

local function SendTimerAddonShutdown()
    if not AIO_AVAILABLE or not AIO or not AIO.Handle then
        return false
    end
    if type(UnitExists) == "function" and not UnitExists("player") then
        return false
    end
    return pcall(AIO.Handle, "MythicPlusServer", "TimerAddonGone", ADDON_BUILD_VERSION)
end

-------------------------------------------------------------------------------
-- Utility
-------------------------------------------------------------------------------
local function FormatTime(sec)
    if sec <= 0 then return "0:00" end
    local m = math.floor(sec / 60)
    local s = math.floor(sec - m * 60)
    return string.format("%d:%02d", m, s)
end

function MythicPlusFormatLongDuration(sec)
    local v = tonumber(sec) or 0
    if v < 0 then v = 0 end
    local h = math.floor(v / 3600)
    local m = math.floor((v % 3600) / 60)
    local s = math.floor(v % 60)
    if h > 0 then
        return string.format("%dh %dm %ds", h, m, s)
    end
    if m > 0 then
        return string.format("%dm %ds", m, s)
    end
    return string.format("%ds", s)
end

local function Clamp01(v)
    if not v then return 0 end
    if v < 0 then return 0 end
    if v > 1 then return 1 end
    return v
end

local function ClampValue(v, minV, maxV)
    local n = tonumber(v) or minV
    if n < minV then n = minV end
    if n > maxV then n = maxV end
    return n
end

local function ColorizeRGB(text, r, g, b)
    r = math.floor(Clamp01(r) * 255 + 0.5)
    g = math.floor(Clamp01(g) * 255 + 0.5)
    b = math.floor(Clamp01(b) * 255 + 0.5)
    return string.format("|cff%02x%02x%02x%s|r", r, g, b, text or "")
end

local function ColorText(text, colorCode)
    return string.format("%s%s|r", colorCode or "|cffffffff", text or "")
end

local function NormalizePercent(pct, fallback)
    local p = tonumber(pct) or tonumber(fallback) or DEFAULT_COMPLETION_TARGET_PCT
    p = math.floor(p + 0.5)
    if p < 1 then p = 1 end
    if p > 100 then p = 100 end
    return p
end

local function GetCompletionTargetPct()
    return NormalizePercent(state.completionTargetPct, DEFAULT_COMPLETION_TARGET_PCT)
end

local function GetCompletionDisplayPct()
    local targetPct = GetCompletionTargetPct()
    if state.killsRequired <= 0 then
        return 0, targetPct
    end
    local pct = (state.killsCurrent / state.killsRequired) * targetPct
    if pct < 0 then pct = 0 end
    if pct > 100 then pct = 100 end
    return pct, targetPct
end

local function GetProgressColorCode(value, goal)
    if not goal or goal <= 0 then
        return "|cffffffff"
    end
    local ratio = value / goal
    if ratio >= 1 then
        return "|cff1eff00"
    elseif ratio >= 0.66 then
        return "|cffffff00"
    elseif ratio >= 0.33 then
        return "|cffff8000"
    end
    return "|cffff3333"
end

local function GetTierColorCode(tier)
    if tier == 1 then
        return "|cff0070dd"
    elseif tier == 2 then
        return "|cffa335ee"
    elseif tier == 3 then
        return "|cffff8000"
    end
    return "|cffffffff"
end

local function GetDeathsColorCode(deaths)
    local d = tonumber(deaths) or 0
    if d <= 0 then
        return "|cffffffff"
    elseif d == 1 then
        return "|cffffff00"
    elseif d == 2 then
        return "|cffff8000"
    end
    return "|cffff3333"
end

local function GetRatingColorCode(rating)
    local r = tonumber(rating)
    if not r then
        return "|cffffffff"
    elseif r >= 1800 then
        return "|cffff8000"
    elseif r >= 1000 then
        return "|cffa335ee"
    elseif r >= 500 then
        return "|cff0070dd"
    end
    return "|cff1eff00"
end

local function GetTimeTakenColorCode(elapsed, allowed)
    local e = tonumber(elapsed)
    if not e then
        return "|cffffffff"
    end
    local a = tonumber(allowed) or 0
    if a <= 0 then
        return "|cffffffff"
    end
    local ratio = e / a
    if ratio <= 0.70 then
        return "|cff1eff00"
    elseif ratio <= 0.90 then
        return "|cffffff00"
    elseif ratio <= 1.00 then
        return "|cffff8000"
    end
    return "|cffff3333"
end

local function GetTimerGradientColor(remaining, total)
    if not total or total <= 0 then
        return 1, 0, 0
    end
    local pct = Clamp01(remaining / total)
    -- 100% time left -> green, 50% -> yellow, 0% -> red.
    if pct >= 0.5 then
        local t = (1 - pct) * 2
        return t, 1, 0
    end
    return 1, pct * 2, 0
end

local function GetProgressPct()
    if state.killsRequired <= 0 then return 0 end
    return math.min(state.killsCurrent / state.killsRequired, 1.0)
end

local function OpenAddonGithubURL()
    if type(OpenURL) == "function" then
        local ok, result = pcall(OpenURL, ADDON_GITHUB_URL)
        if ok and result ~= false then
            return true
        end
    end
    if type(LaunchURL) == "function" then
        local ok, result = pcall(LaunchURL, ADDON_GITHUB_URL)
        if ok and result ~= false then
            return true
        end
    end

    local popupKey = "MYTHICPLUS_GITHUB_LINK"
    if type(StaticPopupDialogs) == "table" and type(StaticPopup_Show) == "function" then
        if not StaticPopupDialogs[popupKey] then
            StaticPopupDialogs[popupKey] = {
                text = "Mythic+ Tracker GitHub URL",
                button1 = CLOSE,
                timeout = 0,
                whileDead = 1,
                hideOnEscape = 1,
                hasEditBox = 1,
                maxLetters = 255,
                preferredIndex = 3,
                OnShow = function(self)
                    if not self or not self.editBox then
                        return
                    end
                    self.editBox:SetText(ADDON_GITHUB_URL)
                    self.editBox:SetAutoFocus(true)
                    self.editBox:SetFocus()
                    self.editBox:HighlightText()
                end,
                EditBoxOnEscapePressed = function(self)
                    if self and self:GetParent() then
                        self:GetParent():Hide()
                    end
                end,
                EditBoxOnEnterPressed = function(self)
                    if self then
                        self:HighlightText()
                    end
                end,
            }
        end
        local popup = StaticPopup_Show(popupKey)
        if popup and popup.editBox then
            popup.editBox:SetText(ADDON_GITHUB_URL)
            popup.editBox:SetFocus()
            popup.editBox:HighlightText()
        end
    end

    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(THEME_CHAT_PREFIX .. " GitHub: " .. ADDON_GITHUB_URL)
    end
    return false
end

local function TrySetTexture(textureObject, primaryPath, fallbackPath)
    if not textureObject then return false end
    local ok = textureObject:SetTexture(primaryPath)
    if ok then return true end
    if fallbackPath then
        return textureObject:SetTexture(fallbackPath) and true or false
    end
    return false
end

local function GetCurrentAffixes()
    local idx = state.currentTierSet
    if idx < 1 or idx > #AFFIX_TIER_SETS then idx = 1 end
    return AFFIX_TIER_SETS[idx]
end

local function DeepCopyTable(value)
    if type(value) ~= "table" then
        return value
    end
    local out = {}
    for k, v in pairs(value) do
        out[k] = DeepCopyTable(v)
    end
    return out
end

local function IsServerAffixPayload(affixTable)
    if type(affixTable) ~= "table" then
        return false
    end
    local first = affixTable[1]
    if type(first) ~= "table" then
        return false
    end
    return type(first.name) == "string" and first.name ~= ""
end

local function SaveLastKnownAffixes(affixTable)
    if not IsServerAffixPayload(affixTable) then
        return
    end
    state.serverAffixes = DeepCopyTable(affixTable)
    if MythicPlusDB then
        MythicPlusDB.lastKnownAffixes = DeepCopyTable(affixTable)
    end
end

local function GetBestAvailableAffixes()
    if IsServerAffixPayload(state.serverAffixes) then
        return state.serverAffixes
    end
    if MythicPlusDB and IsServerAffixPayload(MythicPlusDB.lastKnownAffixes) then
        state.serverAffixes = DeepCopyTable(MythicPlusDB.lastKnownAffixes)
        return state.serverAffixes
    end
    return nil
end

local lastLateAioEnsureAt = 0
local function EnsureLateAIOAffixHandler()
    if _G.__MYTHICPLUS_LATE_AIO_AFFIX_HANDLER__ then
        return true
    end
    if not AIO or not AIO.AddHandlers then
        return false
    end

    local handlers = nil
    local ok, added = pcall(AIO.AddHandlers, "MythicPlus", {})
    if ok and type(added) == "table" then
        handlers = added
    end
    if not handlers then
        return false
    end

    if type(handlers.SetAffixes) ~= "function" then
        handlers.SetAffixes = function(player, affixTable)
            if type(affixTable) ~= "table" then return end
            SaveLastKnownAffixes(affixTable)
            local refreshFn = _G.__MYTHICPLUS_REFRESH_AFFIX_TEXT__
            if type(refreshFn) == "function" then
                refreshFn()
            end
        end
    end

    _G.__MYTHICPLUS_LATE_AIO_AFFIX_HANDLER__ = true
    return true
end

local lastAffixSyncRequestAt = 0
local function RequestAffixSyncIfNeeded()
    local now = GetTime()
    if (now - (lastAffixSyncRequestAt or 0)) < 3 then
        return
    end
    lastAffixSyncRequestAt = now
    if (now - (lastLateAioEnsureAt or 0)) >= 3 then
        lastLateAioEnsureAt = now
        EnsureLateAIOAffixHandler()
    end
    SendTimerAddonHeartbeat(true)
end

function RequestGmAffixEditorSync(force)
    if not AIO_AVAILABLE or not AIO or not AIO.Handle then
        return false
    end
    local now = GetTime()
    state.gmAffixLastSyncRequestAt = tonumber(state.gmAffixLastSyncRequestAt or 0) or 0
    if not force and (now - state.gmAffixLastSyncRequestAt) < 2 then
        return false
    end
    state.gmAffixLastSyncRequestAt = now
    local ok = pcall(AIO.Handle, "MythicPlusServer", "RequestGmAffixEditorData")
    return ok and true or false
end

local AFFIX_NAME_ALIASES = {
    ["Consecration"] = "Consecrated",
    ["Bursting"] = "Burst",
}

-- Difficulty ratings: 1 = Easy, 2 = Moderate, 3 = Extreme
local AFFIX_DIFFICULTY = {
    -- Tier 1
    ["Rejuvenating"]    = 1,
    ["Demonism"]        = 1,
    ["Resistant"]       = 1,
    ["Death Empowered"] = 2,
    ["Devouring"]       = 2,
    -- Tier 2
    ["Turtling"]        = 2,
    ["Priest Empowered"]= 3,
    ["Falling Stars"]   = 2,
    ["Burst"]           = 2,
    ["Rot"]             = 1,
    -- Tier 3
    ["Enrage"]          = 3,
    ["Rallying"]        = 2,
    ["Consecrated"]     = 2,
    ["Assassinate"]     = 3,
    ["Annihilation"]    = 3,
}
local AFFIX_DIFFICULTY_LABEL = { "Easy", "Moderate", "Extreme" }
local AFFIX_DIFFICULTY_COLOR = {
    { 0.27, 1.00, 0.27 },  -- 1 star  Easy     : green
    { 1.00, 0.82, 0.00 },  -- 2 stars Moderate : gold
    { 1.00, 0.27, 0.27 },  -- 3 stars Extreme  : red
}

local AFFIX_TOOLTIP_DATA = {
    ["Rejuvenating"] = {
        impact = "Buffs enemies",
        lines = {
            "Rejuvenation (48441): heals the enemy over 15 seconds.",
            "Riptide (61301): instant heal plus HoT sustain.",
        },
    },
    ["Demonism"] = {
        impact = "Buffs enemies, hits players nearby",
        lines = {
            "Fel Armor (47893): increases enemy spell power and self-healing.",
            "Immolation Aura (50589): deals periodic Fire damage around the enemy.",
        },
    },
    ["Resistant"] = {
        impact = "Buffs enemies",
        lines = {
            "Fire Ward (43010): absorbs elemental damage.",
            "Frost Ward (43012): absorbs elemental damage.",
            "Mage Armor (43024): increases resistance and defensive uptime.",
        },
    },
    ["Death Empowered"] = {
        impact = "Buffs enemies",
        lines = {
            "Blood Presence (48266): increases enemy damage and self-healing.",
            "Lichborne (49039): grants undead immunity utility effects.",
        },
    },
    ["Devouring"] = {
        impact = "Hits players",
        lines = {
            "Devour Magic (48011): removes a beneficial magic buff from you.",
            "Spell Lock (24259): silences the target, preventing spellcasting.",
        },
    },
    ["Turtling"] = {
        impact = "Buffs enemies",
        lines = {
            "Shield Wall (871): heavily reduces enemy damage taken.",
            "Shamanistic Rage (30823): reduces enemy damage taken and sustains resources.",
        },
    },
    ["Priest Empowered"] = {
        impact = "Buffs enemies",
        lines = {
            "Power Word: Fortitude (48161): increases enemy Stamina, raising their max health.",
            "Power Word: Shield (48066): absorbs incoming damage, protecting the enemy briefly.",
            "Fear Ward (6346): makes the enemy immune to Fear effects.",
            "Inner Fire (48168): boosts enemy armor and spell power.",
            "Vampiric Embrace (15286): heals the enemy on each successful shadow attack.",
        },
    },
    ["Falling Stars"] = {
        impact = "Hits players",
        lines = {
            "Starfall (53201): repeated Arcane hits on nearby players.",
            "Moonfire (48463): direct hit plus damage-over-time pressure.",
        },
    },
    ["Burst"] = {
        impact = "Hits players",
        lines = {
            "Arcane Explosion (42921): instant AoE Arcane damage to nearby players.",
            "Fire Blast (42873): instant direct Fire damage to a player.",
            "Flame Shock (49233): direct Fire hit plus sustained damage-over-time.",
            "Lava Burst (60043): heavy direct Fire damage, auto-crits on Flame Shocked targets.",
        },
    },
    ["Rot"] = {
        impact = "Hits players",
        lines = {
            "Curse of Agony (47864): stacking Shadow damage-over-time, intensifies over duration.",
            "Corruption (47813): sustained Shadow damage-over-time on the target.",
            "Unstable Affliction (47843): Shadow DoT that punishes dispels with burst backlash.",
            "Immolate (47811): direct Fire hit followed by sustained damage-over-time.",
        },
    },
    ["Enrage"] = {
        impact = "Buffs enemies",
        lines = {
            "Enrage (8599): increases enemy physical damage and attack speed.",
            "Experienced (71188): increases enemy damage by 30% and attack/cast speed by 20%.",
        },
    },
    ["Rallying"] = {
        impact = "Buffs enemies",
        lines = {
            "Battle Shout (47436): increases enemy attack power, boosting melee damage output.",
            "Abomination's Might (53138): raises enemy attack power and Strength for the group.",
            "Horn of Winter (57330): grants attack power and Strength, stacking melee pressure.",
        },
    },
    ["Consecrated"] = {
        impact = "Buffs enemies, hits players nearby",
        lines = {
            "Divine Storm (53385): enemy cleave damage with self-support.",
            "Consecration (48819): persistent ground AoE that damages players in range.",
        },
    },
    ["Assassinate"] = {
        impact = "Buffs enemies, hits players",
        lines = {
            "Cold Blood (14177): guarantees the enemy's next ability critically strikes.",
            "Blade Flurry (13877): enemy attacks hit an additional nearby player.",
            "Ghostly Strike (14278): deals damage and increases enemy dodge chance.",
            "Fan of Knives (51723): AoE physical damage to all nearby players.",
        },
    },
    ["Annihilation"] = {
        impact = "Hits players",
        lines = {
            "Starfire (48465): heavy direct Arcane damage to a player.",
            "Devouring Plague (48300): direct Shadow damage plus sustained drain-heal DoT.",
            "Mind Blast (48127): high direct Shadow damage with a cooldown.",
            "Holy Fire (48135): direct Holy damage followed by damage-over-time.",
        },
    },
}

-------------------------------------------------------------------------------
-- Affix Tips: short per-affix action fragments, combined at display time
-- Only the 15 real affixes from WEEKLY_AFFIX_POOL are listed.
-------------------------------------------------------------------------------
local AFFIX_TIPS = {
    -- Tier 1 (enemy theme)
    ["Rejuvenating"]    = "Purge enemy healing-over-time effects early",
    ["Demonism"]        = "Maintain range and avoid Immolation Aura",
    ["Resistant"]       = "Favor physical damage; magic is less effective",
    ["Death Empowered"] = "Interrupt cast chains and purge key buffs",
    ["Devouring"]       = "Reapply stolen buffs quickly",
    -- Tier 2 (mechanic)
    ["Turtling"]        = "Delay burst while enemy defensives are active",
    ["Priest Empowered"]= "Purge shields and dispel priority buffs",
    ["Falling Stars"]   = "Stay spread and sidestep Starfall",
    ["Burst"]           = "Use defensives and interrupt Lava Burst",
    ["Rot"]             = "Stabilize DoTs and never dispel Unstable Affliction",
    -- Tier 3 (damage amplifier)
    ["Enrage"]          = "Soothe/Tranq Shot enrages or kite safely",
    ["Rallying"]        = "Prioritize buff totems and support adds",
    ["Consecrated"]     = "Move enemies out of Consecration quickly",
    ["Assassinate"]     = "Track Cold Blood windows and trade defensives",
    ["Annihilation"]    = "Interrupt Starfire and Mind Blast on cooldown",
}

local GetAffixTip  -- forward declaration

local function NormalizeAffixName(name)
    if type(name) ~= "string" then
        return ""
    end
    local normalized = name
        :gsub("|c%x%x%x%x%x%x%x%x", "")
        :gsub("|r", "")
        :gsub("^%s+", "")
        :gsub("%s+$", "")
    if AFFIX_NAME_ALIASES[normalized] then
        normalized = AFFIX_NAME_ALIASES[normalized]
    end
    return normalized
end

GetAffixTip = function(affixNames)
    if not affixNames or #affixNames == 0 then return nil end
    local parts = {}
    local seen = {}
    for _, name in ipairs(affixNames) do
        local clean = NormalizeAffixName(name)
        if clean ~= "" and not seen[clean] then
            seen[clean] = true
            local tip = AFFIX_TIPS[clean]
            if tip then
                parts[#parts + 1] = tip
            end
        end
    end
    if #parts == 0 then return nil end
    return table.concat(parts, ". ") .. "."
end

local function GetImpactTextColor(impact)
    local text = string.lower(tostring(impact or ""))
    local hasBuff = string.find(text, "buffs enemies", 1, true) ~= nil
    local hasHit = string.find(text, "hits players", 1, true) ~= nil
    if hasBuff and hasHit then
        return 1.0, 0.78, 0.38
    end
    if hasHit then
        return 1.0, 0.50, 0.50
    end
    if hasBuff then
        return 0.62, 1.0, 0.62
    end
    return 0.95, 0.95, 0.95
end

-- Defensive override map for tooltip lines with stale/wrong IDs.
-- Prevents icon drift when a line name and spell ID do not match.
local tooltipRuntime = {
    idOverrides = {
        ["Curse of Agony"] = 47864,
    },
    iconById = {},
    iconByName = {},
    affixTooltipCache = {},
}

local function GetSpellIconTextureById(spellId)
    if not spellId or spellId <= 0 then
        return nil
    end
    local cached = tooltipRuntime.iconById[spellId]
    if cached then
        return cached
    end
    if type(GetSpellTexture) == "function" then
        local tex = GetSpellTexture(spellId)
        if tex then
            tooltipRuntime.iconById[spellId] = tex
            return tex
        end
    end
    if type(GetSpellInfo) == "function" then
        local _, _, tex = GetSpellInfo(spellId)
        if tex then
            tooltipRuntime.iconById[spellId] = tex
            return tex
        end
    end
    return nil
end

local function GetSpellIconTextureByName(spellName)
    local name = tostring(spellName or "")
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then
        return nil
    end
    local cached = tooltipRuntime.iconByName[name]
    if cached then
        return cached
    end
    if type(GetSpellInfo) == "function" then
        local _, _, tex = GetSpellInfo(name)
        if tex then
            tooltipRuntime.iconByName[name] = tex
            return tex
        end
    end
    return nil
end

local function ParseTooltipSpellLine(text)
    local name, idText = string.match(text or "", "^%s*(.-)%s*%((%d+)%)%s*:")
    if not idText then
        return nil, nil
    end
    local spellId = tonumber(idText)
    if not spellId then
        return nil, nil
    end
    name = tostring(name or ""):gsub("^%s+", ""):gsub("%s+$", "")
    return name, spellId
end

local function FormatTooltipEffectLine(line)
    local text = tostring(line or "")
    local spellName, spellId = ParseTooltipSpellLine(text)
    if not spellId then
        return "- " .. text
    end
    local overrideId = tooltipRuntime.idOverrides[spellName]
    if overrideId then
        spellId = overrideId
    end
    local texture = GetSpellIconTextureById(spellId)
    if not texture and spellName ~= "" then
        texture = GetSpellIconTextureByName(spellName)
    end
    if not texture then
        return "- " .. text
    end
    return string.format("- |T%s:20:20:0:0|t %s", texture, text)
end

-- Determine kill requirement from key level
local function CalcKillsRequired(keyLevel)
    return math.floor(30 + keyLevel * 2.2)
end

local fadeState = {
    active = false,
    startAt = 0,
    duration = 1.0,
    fromAlpha = 1.0,
    toAlpha = 1.0,
    hideOnComplete = false,
}

-------------------------------------------------------------------------------
-- Backdrops
-------------------------------------------------------------------------------
local backdrop_main = {
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

local backdrop_inner = {
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

local backdrop_bar = {
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 10,
    insets = { left = 2, right = 2, top = 2, bottom = 2 },
}

-------------------------------------------------------------------------------
-- Main Frame
-------------------------------------------------------------------------------
local frame = CreateFrame("Frame", "MythicPlusFrame", UIParent)
frame:SetWidth(FRAME_DEFAULT_WIDTH)
frame:SetHeight(FRAME_DEFAULT_EXPANDED_HEIGHT)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
frame:SetBackdrop(backdrop_main)
frame:SetBackdropColor(0.08, 0.08, 0.08, 0.35)
frame:SetBackdropBorderColor(THEME_BORDER[1], THEME_BORDER[2], THEME_BORDER[3], 1)
frame:SetFrameStrata("HIGH")
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:SetResizable(true)
frame:SetMinResize(FRAME_MIN_WIDTH_EXPANDED, FRAME_MIN_HEIGHT_EXPANDED)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
local UpdateTrackerLayout = nil
local UpdateResizeControlState = nil
local UpdateGithubLinkButtons = nil
local resizeHandle = nil

local function SaveFramePosition()
    local x, y = frame:GetCenter()
    if MythicPlusDB and x and y then
        MythicPlusDB.pos = { x, y }
    end
end

local function SaveCurrentFrameSize()
    if not MythicPlusDB then
        return
    end

    MythicPlusDB.width = math.floor((frame:GetWidth() or FRAME_DEFAULT_WIDTH) + 0.5)
    if state.minimized then
        state.minimizedHeight = math.floor((frame:GetHeight() or FRAME_DEFAULT_MINIMIZED_HEIGHT) + 0.5)
        MythicPlusDB.heightMinimized = state.minimizedHeight
    else
        state.expandedHeight = math.floor((frame:GetHeight() or FRAME_DEFAULT_EXPANDED_HEIGHT) + 0.5)
        MythicPlusDB.heightExpanded = state.expandedHeight
    end
end

local function IsResizeEnabled()
    if MythicPlusDB and MythicPlusDB.resizeEnabled ~= nil then
        return MythicPlusDB.resizeEnabled and true or false
    end
    return defaults.resizeEnabled
end

local function IsGithubLinkEnabled()
    if MythicPlusDB and MythicPlusDB.githubLinkEnabled ~= nil then
        return MythicPlusDB.githubLinkEnabled and true or false
    end
    return defaults.githubLinkEnabled
end

frame:SetScript("OnDragStart", function() this:StartMoving() end)
frame:SetScript("OnDragStop", function()
    this:StopMovingOrSizing()
    SaveFramePosition()
end)

local function GetConfiguredOpacity()
    local a = (MythicPlusDB and MythicPlusDB.windowOpacity) or defaults.windowOpacity
    a = tonumber(a) or defaults.windowOpacity
    if a < 0.10 then a = 0.10 end
    if a > 1.00 then a = 1.00 end
    return a
end

local function GetConfiguredPollRate()
    local rate = (MythicPlusDB and MythicPlusDB.pollRate) or defaults.pollRate
    rate = tonumber(rate) or defaults.pollRate
    if rate < 0.10 then rate = 0.10 end
    if rate > 2.00 then rate = 2.00 end
    return rate
end

local ApplyVisualOpacity = nil

local function SetFrameOpacityFromConfig()
    frame:SetAlpha(1.0)
    if ApplyVisualOpacity then
        ApplyVisualOpacity(GetConfiguredOpacity())
    end
end

local function HideTrackerWindow()
    if IsMythicModeActive() then
        if MythicPlusDB then MythicPlusDB.visible = true end
        fadeState.active = false
        if not frame:IsShown() then
            frame:Show()
        end
        SetFrameOpacityFromConfig()
        state.idleSince = 0
        return false
    end

    if MythicPlusDB then MythicPlusDB.visible = false end
    fadeState.active = false
    frame:Hide()
    return true
end

local function StartFrameFade(targetAlpha, duration, hideOnComplete)
    if not frame:IsShown() then return end
    fadeState.active = true
    fadeState.startAt = GetTime()
    fadeState.duration = duration or 1.0
    fadeState.fromAlpha = frame:GetAlpha() or 1.0
    fadeState.toAlpha = targetAlpha or 0
    fadeState.hideOnComplete = hideOnComplete and true or false
end

local function ProcessFrameFade(now)
    if not fadeState.active or not frame:IsShown() then return end
    local elapsed = now - (fadeState.startAt or now)
    local d = fadeState.duration or 1.0
    local t = d > 0 and (elapsed / d) or 1
    if t > 1 then t = 1 end
    local alpha = fadeState.fromAlpha + (fadeState.toAlpha - fadeState.fromAlpha) * t
    frame:SetAlpha(alpha)

    if t >= 1 then
        fadeState.active = false
        if fadeState.hideOnComplete and (fadeState.toAlpha or 0) <= 0.01 then
            HideTrackerWindow()
        end
    end
end

frame:SetScript("OnShow", function()
    fadeState.active = false
    SetFrameOpacityFromConfig()
    if IsMythicModeActive() then
        state.idleSince = 0
    else
        state.idleSince = GetTime()
    end
end)

frame:SetScript("OnHide", function()
    fadeState.active = false
    if IsMythicModeActive() then
        if MythicPlusDB then MythicPlusDB.visible = true end
        frame:Show()
        SetFrameOpacityFromConfig()
        state.idleSince = 0
        return
    end
    state.idleSince = 0
end)
frame:Hide()

local windowBackground = frame:CreateTexture(nil, "BACKGROUND")
windowBackground:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
windowBackground:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)
windowBackground:SetTexCoord(0, 1, 0, 1)
windowBackground:SetVertexColor(1, 1, 1, 0.62)
local windowBackgroundFallbackMode = false
if (not TrySetTexture(windowBackground, BACKGROUND_TEXTURE_PRIMARY, BACKGROUND_TEXTURE_FALLBACK))
   and (not TrySetTexture(windowBackground, BACKGROUND_TEXTURE_FALLBACK2, nil)) then
    windowBackgroundFallbackMode = true
    windowBackground:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
    windowBackground:SetVertexColor(0.10, 0.10, 0.10, 0.90)
end

-- Outer glow border
local borderFrame = CreateFrame("Frame", nil, frame)
borderFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", -3, 3)
borderFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 3, -3)
borderFrame:SetBackdrop({
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
borderFrame:SetBackdropBorderColor(THEME_BORDER[1] * 0.7, THEME_BORDER[2] * 0.7, THEME_BORDER[3] * 0.7, 1)

resizeHandle = CreateFrame("Button", nil, frame)
resizeHandle:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 6)
resizeHandle:SetWidth(18)
resizeHandle:SetHeight(18)
resizeHandle:SetFrameLevel(frame:GetFrameLevel() + 20)
resizeHandle:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
resizeHandle:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
resizeHandle:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
resizeHandle:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_TOPLEFT")
    GameTooltip:SetText("Resize window")
    GameTooltip:Show()
end)
resizeHandle:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)
resizeHandle:SetScript("OnMouseDown", function()
    if arg1 ~= "LeftButton" then
        return
    end
    if not IsResizeEnabled() then
        return
    end
    fadeState.active = false
    frame:StartSizing("BOTTOMRIGHT")
end)
resizeHandle:SetScript("OnMouseUp", function()
    if arg1 ~= "LeftButton" then
        return
    end
    frame:StopMovingOrSizing()
    SaveCurrentFrameSize()
    SaveFramePosition()
    if UpdateTrackerLayout then
        UpdateTrackerLayout(true)
    end
end)

-------------------------------------------------------------------------------
-- Title Bar
-------------------------------------------------------------------------------
local titleBar = CreateFrame("Frame", nil, frame)
titleBar:SetHeight(28)
titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -6)
titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)
titleBar:SetBackdrop(backdrop_inner)
titleBar:SetBackdropColor(THEME_HEADER_BG[1], THEME_HEADER_BG[2], THEME_HEADER_BG[3], 0.88)
titleBar:SetBackdropBorderColor(THEME_BORDER[1], THEME_BORDER[2], THEME_BORDER[3], 1)

local titleLogo = titleBar:CreateTexture(nil, "ARTWORK")
titleLogo:SetPoint("LEFT", titleBar, "LEFT", 8, 0)
titleLogo:SetWidth(22)
titleLogo:SetHeight(22)
titleLogo:SetTexCoord(0.08, 0.92, 0.08, 0.92)
if not TrySetTexture(titleLogo, LOGO_TEXTURE_PRIMARY, LOGO_TEXTURE_FALLBACK) then
    titleLogo:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
end

local titleLogoLinkBtn = CreateFrame("Button", nil, titleBar)
titleLogoLinkBtn:SetPoint("CENTER", titleLogo, "CENTER", 0, 0)
titleLogoLinkBtn:SetWidth(24)
titleLogoLinkBtn:SetHeight(24)
titleLogoLinkBtn:SetHitRectInsets(-2, -2, -2, -2)
titleLogoLinkBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
titleLogoLinkBtn:SetScript("OnEnter", function()
    if not IsGithubLinkEnabled() then
        return
    end
    titleLogo:SetVertexColor(THEME_CONTROL_HOVER[1], THEME_CONTROL_HOVER[2], THEME_CONTROL_HOVER[3], 1)
    GameTooltip:SetOwner(this, "ANCHOR_BOTTOMLEFT")
    GameTooltip:SetText("Mythic+ Tracker GitHub")
    GameTooltip:AddLine(ADDON_GITHUB_URL, 0.75, 0.82, 1, true)
    GameTooltip:AddLine("Click to open or copy link.", 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
end)
titleLogoLinkBtn:SetScript("OnLeave", function()
    titleLogo:SetVertexColor(1, 1, 1, 1)
    GameTooltip:Hide()
end)
titleLogoLinkBtn:SetScript("OnClick", function()
    if not IsGithubLinkEnabled() then
        return
    end
    OpenAddonGithubURL()
end)

local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
titleText:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")
titleText:SetPoint("LEFT", titleLogo, "RIGHT", 6, 0)
titleText:SetTextColor(1, 1, 1, 1)
titleText:SetText("|cff8888ffMythic+|r Tracker")

-- Close button (inside title bar, right side)
local closeBtn = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
closeBtn:SetWidth(22)
closeBtn:SetHeight(22)
closeBtn:SetPoint("RIGHT", titleBar, "RIGHT", -1, 0)
closeBtn:SetScript("OnClick", function()
    HideTrackerWindow()
end)
local gearBtn = CreateFrame("Button", nil, titleBar)
gearBtn:SetWidth(20)
gearBtn:SetHeight(20)
gearBtn:SetPoint("RIGHT", closeBtn, "LEFT", 2, 0)
gearBtn:EnableMouse(true)
gearBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")

local gearTex = gearBtn:CreateTexture(nil, "ARTWORK")
gearTex:SetTexture("Interface\\Icons\\Trade_Engineering")
gearTex:SetWidth(16)
gearTex:SetHeight(16)
gearTex:SetPoint("CENTER", 0, 0)
gearTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
gearTex:SetVertexColor(THEME_CONTROL_IDLE[1], THEME_CONTROL_IDLE[2], THEME_CONTROL_IDLE[3], 1)

gearBtn:SetScript("OnEnter", function()
    gearTex:SetVertexColor(THEME_CONTROL_HOVER[1], THEME_CONTROL_HOVER[2], THEME_CONTROL_HOVER[3], 1)
    GameTooltip:SetOwner(this, "ANCHOR_BOTTOMLEFT")
    GameTooltip:SetText("Options")
    GameTooltip:Show()
end)
gearBtn:SetScript("OnLeave", function()
    gearTex:SetVertexColor(THEME_CONTROL_IDLE[1], THEME_CONTROL_IDLE[2], THEME_CONTROL_IDLE[3], 1)
    GameTooltip:Hide()
end)
gearBtn:SetScript("OnClick", function() ToggleOptionsPanel() end)

-- Minimize / restore button (inside title bar, left of gear)
local minimizeBtn = CreateFrame("Button", nil, titleBar)
minimizeBtn:SetWidth(20)
minimizeBtn:SetHeight(20)
minimizeBtn:SetPoint("RIGHT", gearBtn, "LEFT", 0, 0)
minimizeBtn:EnableMouse(true)
minimizeBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")

local minBtnLabel = minimizeBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
minBtnLabel:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
minBtnLabel:SetPoint("CENTER", 0, 1)
minBtnLabel:SetTextColor(THEME_CONTROL_IDLE[1], THEME_CONTROL_IDLE[2], THEME_CONTROL_IDLE[3], 1)
minBtnLabel:SetText("-")

minimizeBtn:SetScript("OnEnter", function()
    minBtnLabel:SetTextColor(THEME_CONTROL_HOVER[1], THEME_CONTROL_HOVER[2], THEME_CONTROL_HOVER[3], 1)
end)
minimizeBtn:SetScript("OnLeave", function()
    minBtnLabel:SetTextColor(THEME_CONTROL_IDLE[1], THEME_CONTROL_IDLE[2], THEME_CONTROL_IDLE[3], 1)
end)
minimizeBtn:SetScript("OnClick", function() ToggleMinimize() end)

-- Minimized-state header bar (shown only when minimized, replaces title bar)
local miniBar = CreateFrame("Frame", nil, frame)
miniBar:SetHeight(24)
miniBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -4)
miniBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -4)
miniBar:SetBackdrop(backdrop_inner)
miniBar:SetBackdropColor(THEME_HEADER_BG[1], THEME_HEADER_BG[2], THEME_HEADER_BG[3], 0.88)
miniBar:SetBackdropBorderColor(THEME_BORDER[1], THEME_BORDER[2], THEME_BORDER[3], 1)
miniBar:Hide()

local miniLogo = miniBar:CreateTexture(nil, "ARTWORK")
miniLogo:SetPoint("LEFT", miniBar, "LEFT", 6, 0)
miniLogo:SetWidth(16)
miniLogo:SetHeight(16)
miniLogo:SetTexCoord(0.08, 0.92, 0.08, 0.92)
if not TrySetTexture(miniLogo, LOGO_TEXTURE_PRIMARY, LOGO_TEXTURE_FALLBACK) then
    miniLogo:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
end

local miniLogoLinkBtn = CreateFrame("Button", nil, miniBar)
miniLogoLinkBtn:SetPoint("CENTER", miniLogo, "CENTER", 0, 0)
miniLogoLinkBtn:SetWidth(18)
miniLogoLinkBtn:SetHeight(18)
miniLogoLinkBtn:SetHitRectInsets(-2, -2, -2, -2)
miniLogoLinkBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
miniLogoLinkBtn:SetScript("OnEnter", function()
    if not IsGithubLinkEnabled() then
        return
    end
    miniLogo:SetVertexColor(THEME_CONTROL_HOVER[1], THEME_CONTROL_HOVER[2], THEME_CONTROL_HOVER[3], 1)
    GameTooltip:SetOwner(this, "ANCHOR_BOTTOMLEFT")
    GameTooltip:SetText("Mythic+ Tracker GitHub")
    GameTooltip:AddLine(ADDON_GITHUB_URL, 0.75, 0.82, 1, true)
    GameTooltip:AddLine("Click to open or copy link.", 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
end)
miniLogoLinkBtn:SetScript("OnLeave", function()
    miniLogo:SetVertexColor(1, 1, 1, 1)
    GameTooltip:Hide()
end)
miniLogoLinkBtn:SetScript("OnClick", function()
    if not IsGithubLinkEnabled() then
        return
    end
    OpenAddonGithubURL()
end)

UpdateGithubLinkButtons = function()
    local enabled = IsGithubLinkEnabled()
    if enabled then
        titleLogoLinkBtn:Show()
        miniLogoLinkBtn:Show()
    else
        titleLogoLinkBtn:Hide()
        miniLogoLinkBtn:Hide()
    end
    titleLogo:SetVertexColor(1, 1, 1, 1)
    miniLogo:SetVertexColor(1, 1, 1, 1)
    GameTooltip:Hide()
end

local miniTitle = miniBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
miniTitle:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
miniTitle:SetPoint("LEFT", miniLogo, "RIGHT", 4, 0)
miniTitle:SetTextColor(1, 1, 1, 1)
miniTitle:SetText("|cff8888ffM+|r")

local miniCloseBtn = CreateFrame("Button", nil, miniBar, "UIPanelCloseButton")
miniCloseBtn:SetWidth(20)
miniCloseBtn:SetHeight(20)
miniCloseBtn:SetPoint("RIGHT", miniBar, "RIGHT", -1, 0)
miniCloseBtn:SetScript("OnClick", function()
    HideTrackerWindow()
end)

local miniGearBtn = CreateFrame("Button", nil, miniBar)
miniGearBtn:SetWidth(18)
miniGearBtn:SetHeight(18)
miniGearBtn:SetPoint("RIGHT", miniCloseBtn, "LEFT", 2, 0)
miniGearBtn:EnableMouse(true)
miniGearBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")

local miniGearTex = miniGearBtn:CreateTexture(nil, "ARTWORK")
miniGearTex:SetTexture("Interface\\Icons\\Trade_Engineering")
miniGearTex:SetWidth(14)
miniGearTex:SetHeight(14)
miniGearTex:SetPoint("CENTER", 0, 0)
miniGearTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
miniGearTex:SetVertexColor(THEME_CONTROL_IDLE[1], THEME_CONTROL_IDLE[2], THEME_CONTROL_IDLE[3], 1)

miniGearBtn:SetScript("OnEnter", function()
    miniGearTex:SetVertexColor(THEME_CONTROL_HOVER[1], THEME_CONTROL_HOVER[2], THEME_CONTROL_HOVER[3], 1)
    GameTooltip:SetOwner(this, "ANCHOR_BOTTOMLEFT")
    GameTooltip:SetText("Options")
    GameTooltip:Show()
end)
miniGearBtn:SetScript("OnLeave", function()
    miniGearTex:SetVertexColor(THEME_CONTROL_IDLE[1], THEME_CONTROL_IDLE[2], THEME_CONTROL_IDLE[3], 1)
    GameTooltip:Hide()
end)
miniGearBtn:SetScript("OnClick", function() ToggleOptionsPanel() end)

local miniRestoreBtn = CreateFrame("Button", nil, miniBar)
miniRestoreBtn:SetWidth(18)
miniRestoreBtn:SetHeight(18)
miniRestoreBtn:SetPoint("RIGHT", miniGearBtn, "LEFT", 0, 0)
miniRestoreBtn:EnableMouse(true)
miniRestoreBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")

local miniRestoreLabel = miniRestoreBtn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
miniRestoreLabel:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")
miniRestoreLabel:SetPoint("CENTER", 0, 1)
miniRestoreLabel:SetTextColor(THEME_CONTROL_IDLE[1], THEME_CONTROL_IDLE[2], THEME_CONTROL_IDLE[3], 1)
miniRestoreLabel:SetText("+")

miniRestoreBtn:SetScript("OnEnter", function()
    miniRestoreLabel:SetTextColor(THEME_CONTROL_HOVER[1], THEME_CONTROL_HOVER[2], THEME_CONTROL_HOVER[3], 1)
end)
miniRestoreBtn:SetScript("OnLeave", function()
    miniRestoreLabel:SetTextColor(THEME_CONTROL_IDLE[1], THEME_CONTROL_IDLE[2], THEME_CONTROL_IDLE[3], 1)
end)
miniRestoreBtn:SetScript("OnClick", function() ToggleMinimize() end)

local function ResetRunSummary()
    state.summary = nil
    state.summaryPendingUntil = 0
    state.summaryShown = false
end

local function QueueRunSummary(data)
    local elapsed = nil
    local deaths = state.deaths or 0
    local rating = nil

    if type(data) == "table" then
        if type(data.elapsed) == "number" then
            elapsed = math.max(0, math.floor(data.elapsed + 0.5))
        elseif type(data.timeTaken) == "number" then
            elapsed = math.max(0, math.floor(data.timeTaken + 0.5))
        end
        if type(data.deaths) == "number" then
            deaths = math.max(0, math.floor(data.deaths + 0.5))
        end
        if type(data.rating) == "number" then
            rating = math.max(0, math.floor(data.rating + 0.5))
        elseif type(data.newRating) == "number" then
            rating = math.max(0, math.floor(data.newRating + 0.5))
        end
    end

    state.summary = {
        timeTaken = elapsed,
        deaths = deaths,
        rating = rating,
    }
    state.summaryPendingUntil = GetTime() + 10
    state.summaryShown = true
end

local function UpdateHeaderButtonAnchors(forceHideClose)
    gearBtn:ClearAllPoints()
    minimizeBtn:ClearAllPoints()
    miniGearBtn:ClearAllPoints()
    miniRestoreBtn:ClearAllPoints()

    if forceHideClose then
        gearBtn:SetPoint("RIGHT", titleBar, "RIGHT", -3, 0)
        minimizeBtn:SetPoint("RIGHT", gearBtn, "LEFT", 0, 0)
        miniGearBtn:SetPoint("RIGHT", miniBar, "RIGHT", -3, 0)
        miniRestoreBtn:SetPoint("RIGHT", miniGearBtn, "LEFT", 0, 0)
    else
        gearBtn:SetPoint("RIGHT", closeBtn, "LEFT", 2, 0)
        minimizeBtn:SetPoint("RIGHT", gearBtn, "LEFT", 0, 0)
        miniGearBtn:SetPoint("RIGHT", miniCloseBtn, "LEFT", 2, 0)
        miniRestoreBtn:SetPoint("RIGHT", miniGearBtn, "LEFT", 0, 0)
    end
end

local function UpdateCloseButtonsForRunState()
    local forceHide = MythicPlusDB and MythicPlusDB.alwaysHideCloseButton
    local lockClose = forceHide or IsMythicModeActive()
    UpdateHeaderButtonAnchors(forceHide and true or false)
    if lockClose then
        closeBtn:Hide()
        miniCloseBtn:Hide()
    else
        closeBtn:Show()
        miniCloseBtn:Show()
    end
end

local function ForceShowTrackerForRun()
    if MythicPlusDB then
        MythicPlusDB.visible = true
    end
    fadeState.active = false
    if not frame:IsShown() then
        frame:Show()
    else
        SetFrameOpacityFromConfig()
    end
    state.idleSince = 0
end

local function SetFrameHeightGrowUp(newHeight)
    local cx, cy = frame:GetCenter()
    local oldHeight = frame:GetHeight() or 0
    if not cx or not cy or oldHeight <= 0 then
        frame:SetHeight(newHeight)
        SaveCurrentFrameSize()
        return
    end

    local bottom = cy - (oldHeight / 2)
    frame:SetHeight(newHeight)
    local newCy = bottom + (newHeight / 2)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx, newCy)
    SaveFramePosition()
    SaveCurrentFrameSize()
end

-------------------------------------------------------------------------------
-- Affix Display Panel (scrollable text area)
-------------------------------------------------------------------------------
local affixPanel = CreateFrame("Frame", nil, frame)
affixPanel:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, -6)
affixPanel:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", 0, -6)
affixPanel:SetHeight(180)
affixPanel:SetBackdrop(backdrop_inner)
affixPanel:SetBackdropColor(0.05, 0.05, 0.05, 0.48)
affixPanel:SetBackdropBorderColor(THEME_BORDER[1], THEME_BORDER[2], THEME_BORDER[3], 1)

-- Scroll frame (no template — clean look, mousewheel scrolling only)
local scrollChild = nil
local scrollFrame = CreateFrame("ScrollFrame", "MythicPlusAffixScroll", affixPanel)
scrollFrame:SetPoint("TOPLEFT", affixPanel, "TOPLEFT", 8, -8)
scrollFrame:SetPoint("BOTTOMRIGHT", affixPanel, "BOTTOMRIGHT", -8, 6)
scrollFrame:EnableMouseWheel(true)
scrollFrame:SetScript("OnMouseWheel", function()
    local cur = scrollFrame:GetVerticalScroll()
    local max = scrollChild:GetHeight() - scrollFrame:GetHeight()
    if max < 0 then max = 0 end
    local newVal = cur - (arg1 * 20)
    if newVal < 0 then newVal = 0 end
    if newVal > max then newVal = max end
    scrollFrame:SetVerticalScroll(newVal)
end)

scrollChild = CreateFrame("Frame", nil, scrollFrame)
scrollChild:SetWidth(scrollFrame:GetWidth() or 260)
scrollChild:SetHeight(400)
scrollFrame:SetScrollChild(scrollChild)

-- Affix panel header (inside the panel, at the top)
local affixTitle = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
affixTitle:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
affixTitle:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 2, -2)
affixTitle:SetJustifyH("LEFT")
affixTitle:SetTextColor(1, 1, 1, 1)
affixTitle:SetText("Mythic Affixes")

local affixText = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
affixText:SetFont(STANDARD_TEXT_FONT, 12, "NONE")
affixText:SetPoint("TOPLEFT", affixTitle, "BOTTOMLEFT", 0, -4)
affixText:SetPoint("RIGHT", scrollChild, "RIGHT", -2, 0)
affixText:SetJustifyH("LEFT")
affixText:SetJustifyV("TOP")
affixText:SetWidth(260)
affixText:SetWordWrap(true)
affixText:SetTextColor(1, 1, 1, 1)
affixText:SetText("")

local affixRows = {}

-- Singleton popup that shows the difficulty label when hovering stars
local starTipFrame = CreateFrame("Frame", "MythicPlusStarTip", UIParent)
starTipFrame:SetHeight(22)
starTipFrame:SetWidth(80)
starTipFrame:SetBackdrop({
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 10,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
starTipFrame:SetBackdropColor(0.05, 0.05, 0.09, 0.95)
starTipFrame:SetBackdropBorderColor(THEME_BORDER[1], THEME_BORDER[2], THEME_BORDER[3], 1)
starTipFrame:SetFrameStrata("TOOLTIP")
starTipFrame:Hide()

local starTipLabel = starTipFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
starTipLabel:SetPoint("CENTER", starTipFrame, "CENTER", 0, 0)
starTipLabel:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")

local function UpdateRowStarDisplay(row, difficulty)
    if not row.starFrame then return end
    local count = tonumber(difficulty) or 0
    row.starDifficulty = count
    if count < 1 then
        row.starFrame:Hide()
        row.starHover:Hide()
        return
    end
    local col = AFFIX_DIFFICULTY_COLOR[count] or { 1, 1, 1 }
    for i = 1, 3 do
        if i <= count then
            row.starFrame.stars[i]:SetVertexColor(col[1], col[2], col[3], 1.0)
            row.starFrame.stars[i]:Show()
        else
            row.starFrame.stars[i]:Hide()
        end
    end
    row.starFrame:Show()
    row.starHover:Show()
end

local function HideAffixRows()
    for _, row in ipairs(affixRows) do
        row.tooltipInfo = nil
        row:Hide()
    end
end

local function EnsureAffixRow(index)
    local row = affixRows[index]
    if row then
        return row
    end

    row = CreateFrame("Button", nil, scrollChild)
    row:SetHeight(16)
    row:SetPoint("LEFT", scrollChild, "LEFT", 2, 0)
    row:SetPoint("RIGHT", scrollChild, "RIGHT", -2, 0)
    row:EnableMouse(false)

    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.label:SetFont(STANDARD_TEXT_FONT, 12, "NONE")
    row.label:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.label:SetPoint("RIGHT", row, "RIGHT", -66, 0)  -- leave room for 3 stars
    row.label:SetJustifyH("LEFT")
    row.label:SetJustifyV("MIDDLE")
    row.label:SetTextColor(1, 1, 1, 1)

    -- Star difficulty: plain Frame child so textures never get suppressed by the Button
    local sf = CreateFrame("Frame", nil, row)
    sf:SetWidth(64)
    sf:SetHeight(20)
    sf:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    sf:SetFrameLevel(row:GetFrameLevel() + 2)
    sf.stars = {}
    for i = 1, 3 do
        local s = sf:CreateTexture(nil, "OVERLAY")
        if not TrySetTexture(s, STAR_TEXTURE_PRIMARY, STAR_TEXTURE_FALLBACK) then
            s:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
            if not STAR_TEXTURE_WARNED then
                STAR_TEXTURE_WARNED = true
                DEFAULT_CHAT_FRAME:AddMessage("|cffff6060MythicPlus:|r Star texture not found – using fallback icon.")
            end
        end
        s:SetWidth(20)
        s:SetHeight(20)
        if i == 1 then
            s:SetPoint("RIGHT", sf, "RIGHT", 0, 0)
        else
            s:SetPoint("RIGHT", sf.stars[i - 1], "LEFT", -2, 0)
        end
        s:Hide()
        sf.stars[i] = s
    end
    sf:Hide()
    row.starFrame = sf

    -- Invisible hover zone over the star cluster
    row.starHover = CreateFrame("Frame", nil, row)
    row.starHover:SetWidth(64)
    row.starHover:SetHeight(20)
    row.starHover:SetPoint("RIGHT", row, "RIGHT", -1, 0)
    row.starHover:EnableMouse(true)
    row.starHover:Hide()
    row.starHover:SetScript("OnEnter", function(self)
        GameTooltip:Hide()
        local d = self:GetParent().starDifficulty or 0
        if d < 1 then return end
        local lbl = AFFIX_DIFFICULTY_LABEL[d] or "Unknown"
        local col = AFFIX_DIFFICULTY_COLOR[d] or { 1, 1, 1 }
        starTipLabel:SetTextColor(col[1], col[2], col[3], 1)
        starTipLabel:SetText(lbl)
        starTipFrame:SetWidth(starTipLabel:GetStringWidth() + 14)
        starTipFrame:ClearAllPoints()
        starTipFrame:SetPoint("TOP", self, "BOTTOM", 0, -2)
        starTipFrame:Show()
    end)
    row.starHover:SetScript("OnLeave", function()
        starTipFrame:Hide()
    end)

    row:SetScript("OnEnter", function(self)
        if not self.tooltipInfo then
            return
        end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine(self.tooltipInfo.title or "Affix", 1.0, 0.82, 0.0, true)
        GameTooltip:AddLine(" ")
        local ir, ig, ib = GetImpactTextColor(self.tooltipInfo.impact)
        GameTooltip:AddLine("Type: " .. (self.tooltipInfo.impact or "Unknown"), ir, ig, ib, true)
        GameTooltip:AddLine(" ")
        local tooltipLines = self.tooltipInfo.lines or {}
        for i, line in ipairs(tooltipLines) do
            GameTooltip:AddLine(FormatTooltipEffectLine(line), 0.88, 0.88, 0.88, true)
            if i < #tooltipLines then
                GameTooltip:AddLine(" ")
            end
        end
        GameTooltip:Show()
    end)

    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    affixRows[index] = row
    return row
end

local function BuildAffixTooltip(name)
    local cleanName = NormalizeAffixName(name)
    if cleanName == "" then
        return nil
    end
    local cached = tooltipRuntime.affixTooltipCache[cleanName]
    if cached then
        return cached
    end
    local data = AFFIX_TOOLTIP_DATA[cleanName]
    if not data then
        return nil
    end
    local tooltipInfo = {
        title = cleanName,
        impact = data.impact,
        lines = data.lines,
        difficulty = AFFIX_DIFFICULTY[cleanName],
    }
    tooltipRuntime.affixTooltipCache[cleanName] = tooltipInfo
    return tooltipInfo
end

local function RenderAffixRows(entries)
    HideAffixRows()
    affixText:Hide()

    local previous = nil
    local count = 0
    local totalHeight = 0
    for _, entry in ipairs(entries or {}) do
        count = count + 1
        local row = EnsureAffixRow(count)
        local isTierSpacer = entry.isTierSpacer == true
        local isTip = entry.isTip == true
        local rowHeight = isTierSpacer and 4 or 16
        local rowGap = 1

        -- Tip rows use smaller font, full width, word-wrap, and dynamic height
        if isTip then
            row.label:SetFont(STANDARD_TEXT_FONT, 10, "NONE")
            row.label:ClearAllPoints()
            row.label:SetPoint("LEFT", row, "LEFT", 0, 0)
            row.label:SetPoint("RIGHT", row, "RIGHT", -2, 0)
            row.label:SetWordWrap(true)
            row.label:SetNonSpaceWrap(true)
            -- Set text now so we can measure wrapped height
            row.label:SetText(entry.text or "")
            local availWidth = (scrollChild:GetWidth() or 200) - 6
            if availWidth < 60 then availWidth = 200 end
            row.label:SetWidth(availWidth)
            local textH = row.label:GetStringHeight() or 14
            rowHeight = math.max(textH + 4, 16)
            rowGap = 2
        else
            row.label:SetFont(STANDARD_TEXT_FONT, 12, "NONE")
            row.label:ClearAllPoints()
            row.label:SetPoint("LEFT", row, "LEFT", 0, 0)
            row.label:SetPoint("RIGHT", row, "RIGHT", -66, 0)
            row.label:SetWordWrap(false)
            row.label:SetNonSpaceWrap(false)
        end

        row:ClearAllPoints()
        if previous then
            row:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -rowGap)
            totalHeight = totalHeight + rowGap + rowHeight
        else
            row:SetPoint("TOPLEFT", affixTitle, "BOTTOMLEFT", 0, -4)
            totalHeight = rowHeight
        end
        row:SetPoint("RIGHT", scrollChild, "RIGHT", -2, 0)
        row:SetHeight(rowHeight)
        row.label:SetText(isTierSpacer and "" or (entry.text or ""))
        row.tooltipInfo = isTierSpacer and nil or entry.tooltipInfo
        row:EnableMouse((not isTierSpacer) and entry.tooltipInfo and true or false)
        local difficulty = (not isTip and not isTierSpacer and entry.tooltipInfo and entry.tooltipInfo.difficulty) or 0
        UpdateRowStarDisplay(row, difficulty)
        row:Show()
        previous = row
    end

    if count == 0 then
        affixText:SetText("|cffaaaaaaWaiting for server affix sync...|r")
        affixText:Show()
        local titleH = affixTitle:GetStringHeight() or 14
        local textH = affixText:GetStringHeight() or 16
        scrollChild:SetHeight(math.max(titleH + textH + 20, 180))
        return
    end

    local titleH = affixTitle:GetStringHeight() or 14
    local rowBlockH = totalHeight
    scrollChild:SetHeight(math.max(titleH + 4 + rowBlockH + 20, 180))

    local max = scrollChild:GetHeight() - scrollFrame:GetHeight()
    if max < 0 then max = 0 end
    local cur = scrollFrame:GetVerticalScroll()
    if cur > max then
        scrollFrame:SetVerticalScroll(max)
    end
end

-------------------------------------------------------------------------------
-- Progress Bar
-------------------------------------------------------------------------------
local barContainer = CreateFrame("Frame", nil, frame)
barContainer:SetHeight(28)
barContainer:SetPoint("TOPLEFT", affixPanel, "BOTTOMLEFT", 0, -8)
barContainer:SetPoint("TOPRIGHT", affixPanel, "BOTTOMRIGHT", 0, -8)
barContainer:SetBackdrop(backdrop_bar)
barContainer:SetBackdropColor(0.05, 0.05, 0.05, 0.58)
barContainer:SetBackdropBorderColor(THEME_BORDER[1], THEME_BORDER[2], THEME_BORDER[3], 1)

local progressBar = CreateFrame("StatusBar", "MythicPlusProgressBar", barContainer)
progressBar:SetPoint("TOPLEFT", barContainer, "TOPLEFT", 4, -4)
progressBar:SetPoint("BOTTOMRIGHT", barContainer, "BOTTOMRIGHT", -4, 4)
progressBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
progressBar:SetStatusBarColor(THEME_ACCENT[1], THEME_ACCENT[2], THEME_ACCENT[3], 1)
progressBar:SetMinMaxValues(0, 1)
progressBar:SetValue(0)
progressBar:SetFrameLevel(barContainer:GetFrameLevel() + 1)

-- Bar background (dark fill behind the bar)
local barBg = progressBar:CreateTexture(nil, "BACKGROUND")
barBg:SetAllPoints(progressBar)
barBg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
barBg:SetVertexColor(0.15, 0.15, 0.15, 0.8)

-- Bar text overlay
local barText = progressBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
barText:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
barText:SetPoint("CENTER", progressBar, "CENTER", 0, 0)
barText:SetTextColor(1, 1, 1, 1)
barText:SetText("0%")
local BAR_TEXT_NORMAL_SIZE = 11
local BAR_TEXT_ALERT_SIZE = 16
local function SetBarTextAlertMode(alert)
    if alert then
        barText:SetFont(STANDARD_TEXT_FONT, BAR_TEXT_ALERT_SIZE, "OUTLINE")
    else
        barText:SetFont(STANDARD_TEXT_FONT, BAR_TEXT_NORMAL_SIZE, "OUTLINE")
    end
end

-- Threshold glow effect (appears from top/bottom around 90% kill progress)
local barGlowTop = progressBar:CreateTexture(nil, "OVERLAY")
barGlowTop:SetPoint("BOTTOMLEFT", progressBar, "TOPLEFT", 0, 0)
barGlowTop:SetPoint("BOTTOMRIGHT", progressBar, "TOPRIGHT", 0, 0)
barGlowTop:SetHeight(0)
barGlowTop:SetBlendMode("ADD")
barGlowTop:SetTexCoord(0, 1, 0, 1)

local barGlowBottom = progressBar:CreateTexture(nil, "OVERLAY")
barGlowBottom:SetPoint("TOPLEFT", progressBar, "BOTTOMLEFT", 0, 0)
barGlowBottom:SetPoint("TOPRIGHT", progressBar, "BOTTOMRIGHT", 0, 0)
barGlowBottom:SetHeight(0)
barGlowBottom:SetBlendMode("ADD")
barGlowBottom:SetTexCoord(0, 1, 1, 0)

barGlowTop:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
barGlowBottom:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
barGlowTop:SetVertexColor(THEME_GLOW[1], THEME_GLOW[2], THEME_GLOW[3], 1)
barGlowBottom:SetVertexColor(THEME_GLOW[1], THEME_GLOW[2], THEME_GLOW[3], 1)

local barGlowAnim = {
    active = false,
    targetShown = false,
    startAt = 0,
    duration = BARGLOW_FADE_DURATION,
    from = 0,
    to = 0,
    current = 0,
}

local function SetBarGlowAmount(amount)
    local a = Clamp01(amount)
    local spread = BARGLOW_MAX_SPREAD * a
    local alpha = BARGLOW_MAX_ALPHA * a

    barGlowTop:SetHeight(spread)
    barGlowBottom:SetHeight(spread)
    barGlowTop:SetAlpha(alpha)
    barGlowBottom:SetAlpha(alpha)

    if alpha <= 0.001 then
        barGlowTop:Hide()
        barGlowBottom:Hide()
    else
        barGlowTop:Show()
        barGlowBottom:Show()
    end

    barGlowAnim.current = a
end

local function StartBarGlowAnimation(show)
    local target = show and 1 or 0
    local current = barGlowAnim.current or 0
    if barGlowAnim.active and barGlowAnim.to == target then
        return
    end
    barGlowAnim.active = true
    barGlowAnim.startAt = GetTime()
    barGlowAnim.duration = BARGLOW_FADE_DURATION
    barGlowAnim.from = current
    barGlowAnim.to = target
end

local function UpdateBarGlowTrigger()
    local ratio = 0
    if state.killsRequired > 0 then
        ratio = state.killsCurrent / state.killsRequired
    end
    local shouldShow = (state.running and not state.finished and ratio >= BARGLOW_TRIGGER_RATIO) and true or false
    if shouldShow ~= barGlowAnim.targetShown then
        barGlowAnim.targetShown = shouldShow
        StartBarGlowAnimation(shouldShow)
    end
end

local function ProcessBarGlow(now)
    if not barGlowAnim.active then return end
    local elapsed = now - (barGlowAnim.startAt or now)
    local d = barGlowAnim.duration or BARGLOW_FADE_DURATION
    local t = d > 0 and (elapsed / d) or 1
    if t > 1 then t = 1 end
    local a = barGlowAnim.from + (barGlowAnim.to - barGlowAnim.from) * t
    SetBarGlowAmount(a)
    if t >= 1 then
        barGlowAnim.active = false
        SetBarGlowAmount(barGlowAnim.to)
    end
end

SetBarGlowAmount(0)

-------------------------------------------------------------------------------
-- Stats Panel (kills, tier, time)
-------------------------------------------------------------------------------
local statsPanel = CreateFrame("Frame", nil, frame)
statsPanel:SetPoint("TOPLEFT", barContainer, "BOTTOMLEFT", 0, -8)
statsPanel:SetPoint("TOPRIGHT", barContainer, "BOTTOMRIGHT", 0, -8)
statsPanel:SetHeight(130)
statsPanel:SetBackdrop(backdrop_inner)
statsPanel:SetBackdropColor(0.05, 0.05, 0.05, 0.48)
statsPanel:SetBackdropBorderColor(THEME_BORDER[1], THEME_BORDER[2], THEME_BORDER[3], 1)

ApplyVisualOpacity = function(alpha)
    local a = alpha or GetConfiguredOpacity()
    if a < 0.10 then a = 0.10 end
    if a > 1.00 then a = 1.00 end

    frame:SetBackdropColor(0.08, 0.08, 0.08, a)

    if windowBackgroundFallbackMode then
        windowBackground:SetVertexColor(0.10, 0.10, 0.10, a)
    else
        windowBackground:SetVertexColor(1, 1, 1, a)
    end

    titleBar:SetBackdropColor(THEME_HEADER_BG[1], THEME_HEADER_BG[2], THEME_HEADER_BG[3], a)
    miniBar:SetBackdropColor(THEME_HEADER_BG[1], THEME_HEADER_BG[2], THEME_HEADER_BG[3], a)
    affixPanel:SetBackdropColor(0.05, 0.05, 0.05, a)
    barContainer:SetBackdropColor(0.05, 0.05, 0.05, a)
    statsPanel:SetBackdropColor(0.05, 0.05, 0.05, a)
    barBg:SetVertexColor(0.15, 0.15, 0.15, a)

    local opt = _G["MythicPlusOptionsPanel"]
    if opt and opt.SetBackdropColor then
        local oa = a + 0.12
        if oa > 1 then oa = 1 end
        opt:SetBackdropColor(0.12, 0.12, 0.12, oa)
    end
end

-- Centralized stat labels
local function CreateStatLine(parent, yOffset, label, value)
    local line = {}
    line.label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    line.label:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")
    line.label:SetPoint("TOP", parent, "TOP", 0, yOffset)
    line.label:SetJustifyH("CENTER")
    line.label:SetTextColor(1, 1, 1, 1)
    line.label:SetText(value or label)
    return line
end

local statKills   = CreateStatLine(statsPanel, -14,  "Kills",  "0 / 0 kills")
local statPct     = CreateStatLine(statsPanel, -36,  "Pct",    "0% Complete")
local statTier    = CreateStatLine(statsPanel, -58,  "Tier",   "Current Tier: 1")
local statTimer   = CreateStatLine(statsPanel, -80,  "Timer",  "30:00 Remaining")
local statDeaths  = CreateStatLine(statsPanel, -102, "Deaths", "0 Deaths")
local idleWaitCentered = false

local function SetIdleWaitMessageCentered(enabled)
    if enabled then
        if idleWaitCentered then return end
        statDeaths.label:ClearAllPoints()
        statDeaths.label:SetPoint("CENTER", statsPanel, "CENTER", 0, 0)
        idleWaitCentered = true
        return
    end

    if not idleWaitCentered then return end
    statDeaths.label:ClearAllPoints()
    statDeaths.label:SetPoint("TOP", statsPanel, "TOP", 0, -102)
    idleWaitCentered = false
end

local function GetExpandedPanelHeights(frameHeight)
    local available = math.floor((frameHeight or FRAME_DEFAULT_EXPANDED_HEIGHT) - EXPANDED_LAYOUT_FIXED_HEIGHT + 0.5)
    local minTotal = EXPANDED_LAYOUT_MIN_AFFIX_HEIGHT + EXPANDED_LAYOUT_MIN_STATS_HEIGHT
    if available < minTotal then
        available = minTotal
    end

    local affixHeight = math.floor(available * EXPANDED_LAYOUT_AFFIX_RATIO + 0.5)
    local statsHeight = available - affixHeight

    if affixHeight < EXPANDED_LAYOUT_MIN_AFFIX_HEIGHT then
        affixHeight = EXPANDED_LAYOUT_MIN_AFFIX_HEIGHT
        statsHeight = available - affixHeight
    end
    if statsHeight < EXPANDED_LAYOUT_MIN_STATS_HEIGHT then
        statsHeight = EXPANDED_LAYOUT_MIN_STATS_HEIGHT
        affixHeight = available - statsHeight
    end
    if affixHeight < EXPANDED_LAYOUT_MIN_AFFIX_HEIGHT then
        affixHeight = EXPANDED_LAYOUT_MIN_AFFIX_HEIGHT
    end

    return affixHeight, statsHeight
end

local applyingLayout = false
UpdateTrackerLayout = function(persistSize)
    if applyingLayout then
        return
    end
    applyingLayout = true

    local minW = state.minimized and FRAME_MIN_WIDTH_MINIMIZED or FRAME_MIN_WIDTH_EXPANDED
    local minH = state.minimized and FRAME_MIN_HEIGHT_MINIMIZED or FRAME_MIN_HEIGHT_EXPANDED
    frame:SetMinResize(minW, minH)

    local curW = frame:GetWidth() or FRAME_DEFAULT_WIDTH
    local curH = frame:GetHeight() or (state.minimized and FRAME_DEFAULT_MINIMIZED_HEIGHT or FRAME_DEFAULT_EXPANDED_HEIGHT)
    local clampedW = curW < minW and minW or curW
    local clampedH = curH < minH and minH or curH
    if clampedW ~= curW then
        frame:SetWidth(clampedW)
    end
    if clampedH ~= curH then
        frame:SetHeight(clampedH)
    end

    if state.minimized then
        barContainer:ClearAllPoints()
        barContainer:SetPoint("TOPLEFT", miniBar, "BOTTOMLEFT", 0, -6)
        barContainer:SetPoint("TOPRIGHT", miniBar, "BOTTOMRIGHT", 0, -6)

        local statsHeight = math.floor((frame:GetHeight() or FRAME_DEFAULT_MINIMIZED_HEIGHT) - MINIMIZED_LAYOUT_FIXED_HEIGHT + 0.5)
        if statsHeight < MINIMIZED_LAYOUT_MIN_STATS_HEIGHT then
            statsHeight = MINIMIZED_LAYOUT_MIN_STATS_HEIGHT
        end
        statsPanel:SetHeight(statsHeight)
    else
        local affixHeight, statsHeight = GetExpandedPanelHeights(frame:GetHeight() or FRAME_DEFAULT_EXPANDED_HEIGHT)
        affixPanel:SetHeight(affixHeight)

        barContainer:ClearAllPoints()
        barContainer:SetPoint("TOPLEFT", affixPanel, "BOTTOMLEFT", 0, -8)
        barContainer:SetPoint("TOPRIGHT", affixPanel, "BOTTOMRIGHT", 0, -8)
        statsPanel:SetHeight(statsHeight)
    end

    local panelWidth = affixPanel:GetWidth()
    if not panelWidth or panelWidth <= 0 then
        panelWidth = (frame:GetWidth() or FRAME_DEFAULT_WIDTH) - 12
    end
    local scrollWidth = math.max(panelWidth - 20, 120)
    scrollChild:SetWidth(scrollWidth)
    affixText:SetWidth(scrollWidth - 2)

    local max = scrollChild:GetHeight() - scrollFrame:GetHeight()
    if max < 0 then max = 0 end
    local cur = scrollFrame:GetVerticalScroll()
    if cur > max then
        scrollFrame:SetVerticalScroll(max)
    end

    if persistSize then
        SaveCurrentFrameSize()
    end
    applyingLayout = false
end

UpdateResizeControlState = function()
    local enabled = IsResizeEnabled()
    frame:SetResizable(enabled)
    if not enabled then
        frame:StopMovingOrSizing()
    end
    if resizeHandle then
        if enabled then
            resizeHandle:Show()
        else
            resizeHandle:Hide()
            GameTooltip:Hide()
        end
    end
    if UpdateTrackerLayout then
        UpdateTrackerLayout(false)
    end
end

frame:SetScript("OnSizeChanged", function()
    if UpdateTrackerLayout then
        UpdateTrackerLayout(true)
    end
end)


-------------------------------------------------------------------------------
-- Toggle Minimize (hide title + affixes, show only bottom half)
-------------------------------------------------------------------------------
function ToggleMinimize()
    if state.minimized then
        state.minimizedHeight = math.floor((frame:GetHeight() or state.minimizedHeight or FRAME_DEFAULT_MINIMIZED_HEIGHT) + 0.5)
        if MythicPlusDB then
            MythicPlusDB.heightMinimized = state.minimizedHeight
        end
    else
        state.expandedHeight = math.floor((frame:GetHeight() or state.expandedHeight or FRAME_DEFAULT_EXPANDED_HEIGHT) + 0.5)
        if MythicPlusDB then
            MythicPlusDB.heightExpanded = state.expandedHeight
        end
    end

    state.minimized = not state.minimized
    if MythicPlusDB then MythicPlusDB.minimized = state.minimized end
    ApplyMinimizeState()
end

function ApplyMinimizeState()
    if state.minimized then
        titleBar:Hide()
        affixPanel:Hide()
        miniBar:Show()
        local targetHeight = ClampValue(state.minimizedHeight, FRAME_MIN_HEIGHT_MINIMIZED, 1000)
        SetFrameHeightGrowUp(targetHeight)
        minBtnLabel:SetText("+")
    else
        miniBar:Hide()
        titleBar:Show()
        affixPanel:Show()
        local targetHeight = ClampValue(state.expandedHeight, FRAME_MIN_HEIGHT_EXPANDED, 1400)
        SetFrameHeightGrowUp(targetHeight)
        minBtnLabel:SetText("-")
    end
    if UpdateTrackerLayout then
        UpdateTrackerLayout(true)
    end
    if UpdateResizeControlState then
        UpdateResizeControlState()
    end
    UpdateCloseButtonsForRunState()
end

-------------------------------------------------------------------------------
-- Options Panel (overlay inside the main frame)
-------------------------------------------------------------------------------
local OPTIONS_PANEL_MIN_HEIGHT = 260

local optionsPanel = CreateFrame("Frame", "MythicPlusOptionsPanel", frame)
optionsPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
optionsPanel:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
optionsPanel:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
optionsPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
optionsPanel:SetBackdrop(backdrop_main)
optionsPanel:SetBackdropColor(0.12, 0.12, 0.12, 0.98)
optionsPanel:SetBackdropBorderColor(THEME_BORDER[1], THEME_BORDER[2], THEME_BORDER[3], 1)
optionsPanel:SetFrameLevel(frame:GetFrameLevel() + 20)
optionsPanel:EnableMouse(true)
optionsPanel:SetMovable(true)
optionsPanel:RegisterForDrag("LeftButton")
optionsPanel:SetScript("OnDragStart", function()
    if not (MythicPlusDB and MythicPlusDB.locked) then
        frame:StartMoving()
    end
end)
optionsPanel:SetScript("OnDragStop", function()
    frame:StopMovingOrSizing()
    SaveFramePosition()
end)
optionsPanel:Hide()

local optTitle = optionsPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
optTitle:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")
optTitle:SetPoint("TOP", optionsPanel, "TOP", 0, -14)
optTitle:SetTextColor(1, 1, 1, 1)
optTitle:SetText("Window Options")

-- Close options button (top right of overlay)
local optCloseBtn = CreateFrame("Button", nil, optionsPanel, "UIPanelCloseButton")
optCloseBtn:SetWidth(22)
optCloseBtn:SetHeight(22)
optCloseBtn:SetPoint("TOPRIGHT", optionsPanel, "TOPRIGHT", -4, -4)
optCloseBtn:SetScript("OnClick", function()
    if optionsPanel:IsShown() then
        ToggleOptionsPanel()
    end
end)

-- Helper: create a labeled slider
local function CreateOptionSlider(parent, yOff, label, minVal, maxVal, step, initVal, onChanged)
    local sl = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    sl:SetWidth(200)
    sl:SetHeight(16)
    sl:SetPoint("TOP", parent, "TOP", 0, yOff)
    sl:SetMinMaxValues(minVal, maxVal)
    sl:SetValueStep(step)
    sl:SetValue(initVal)
    sl:SetOrientation("HORIZONTAL")

    local slLabel = sl:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    slLabel:SetPoint("BOTTOM", sl, "TOP", 0, 2)
    slLabel:SetText(label .. ": " .. initVal)

    sl:SetScript("OnValueChanged", function()
        local val = math.floor(this:GetValue() + 0.5)
        slLabel:SetText(label .. ": " .. val)
        if onChanged then onChanged(val) end
    end)

    sl.slLabel = slLabel
    return sl
end

-- Hidden advanced sliders (wrapped to reduce top-level local count)
do
    local keySlider = CreateOptionSlider(optionsPanel, -46, "Key Level", 1, 99, 1, state.keyLevel, function(val)
        state.keyLevel = val
        state.killsRequired = CalcKillsRequired(val)
        if MythicPlusDB then MythicPlusDB.keyLevel = val end
        if RefreshStats then RefreshStats() end
    end)

    local timerSlider = CreateOptionSlider(optionsPanel, -96, "Timer (min)", 1, 120, 1,
        (MythicPlusDB and MythicPlusDB.timerMinutes or defaults.timerMinutes), function(val)
        if MythicPlusDB then MythicPlusDB.timerMinutes = val end
        if not state.running then
            state.duration = val * 60
            state.timerMax = state.duration
            if RefreshStats then RefreshStats() end
        end
    end)

    local affixSlider = CreateOptionSlider(optionsPanel, -146, "Affix Set", 1, #AFFIX_TIER_SETS, 1, state.currentTierSet, function(val)
        state.currentTierSet = val
        if MythicPlusDB then MythicPlusDB.lastTierSet = val end
        if RefreshAffixText then RefreshAffixText() end
        if RefreshStats then RefreshStats() end
    end)

    local pollSlider = CreateOptionSlider(optionsPanel, -196, "Poll Rate (s)", 1, 20, 1,
        math.floor(GetConfiguredPollRate() * 10 + 0.5), function(val)
        local rate = ClampValue(val / 10, 0.10, 2.00)
        if MythicPlusDB then MythicPlusDB.pollRate = rate end
    end)
    pollSlider:SetScript("OnValueChanged", function()
        local val = math.floor(this:GetValue() + 0.5)
        local rate = ClampValue(val / 10, 0.10, 2.00)
        pollSlider.slLabel:SetText("Poll Rate: " .. string.format("%.1fs", rate))
        if MythicPlusDB then MythicPlusDB.pollRate = rate end
    end)
    pollSlider.slLabel:SetText("Poll Rate: " .. string.format("%.1fs", GetConfiguredPollRate()))

    keySlider:Hide()
    timerSlider:Hide()
    affixSlider:Hide()
    pollSlider:Hide()
end

-- Lock window checkbox
local lockCheck = CreateFrame("CheckButton", nil, optionsPanel, "UICheckButtonTemplate")
lockCheck:SetWidth(24)
lockCheck:SetHeight(24)
lockCheck:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 22, -58)
lockCheck:SetChecked(MythicPlusDB and MythicPlusDB.locked or false)
lockCheck.label = lockCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
lockCheck.label:SetPoint("LEFT", lockCheck, "RIGHT", 4, 0)
lockCheck.label:SetText("Lock Window Position")
lockCheck:SetScript("OnClick", function()
    local checked = this:GetChecked()
    if MythicPlusDB then MythicPlusDB.locked = checked end
    if checked then
        frame:SetScript("OnDragStart", nil)
    else
        frame:SetScript("OnDragStart", function() this:StartMoving() end)
    end
end)

-- Always-hide close buttons checkbox
local hideCloseCheck = CreateFrame("CheckButton", nil, optionsPanel, "UICheckButtonTemplate")
hideCloseCheck:SetWidth(24)
hideCloseCheck:SetHeight(24)
hideCloseCheck:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 22, -84)
hideCloseCheck:SetChecked(MythicPlusDB and MythicPlusDB.alwaysHideCloseButton or false)
hideCloseCheck.label = hideCloseCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
hideCloseCheck.label:SetPoint("LEFT", hideCloseCheck, "RIGHT", 4, 0)
hideCloseCheck.label:SetText("Always Hide Close Button")
hideCloseCheck:SetScript("OnClick", function()
    local checked = this:GetChecked()
    if MythicPlusDB then MythicPlusDB.alwaysHideCloseButton = checked end
    UpdateCloseButtonsForRunState()
end)

-- Auto-hide when idle checkbox
local autoHideCheck = CreateFrame("CheckButton", nil, optionsPanel, "UICheckButtonTemplate")
autoHideCheck:SetWidth(24)
autoHideCheck:SetHeight(24)
autoHideCheck:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 22, -110)
autoHideCheck:SetChecked(MythicPlusDB and MythicPlusDB.autoHideOutOfMythic or false)
autoHideCheck.label = autoHideCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
autoHideCheck.label:SetPoint("LEFT", autoHideCheck, "RIGHT", 4, 0)
autoHideCheck.label:SetText("Auto-hide when idle (20s)")
autoHideCheck:SetScript("OnClick", function()
    local checked = this:GetChecked()
    if MythicPlusDB then MythicPlusDB.autoHideOutOfMythic = checked end
    if checked then
        state.idleSince = GetTime()
    else
        fadeState.active = false
        SetFrameOpacityFromConfig()
        state.idleSince = 0
    end
end)

-- Enable resize handle checkbox
local resizeCheck = CreateFrame("CheckButton", nil, optionsPanel, "UICheckButtonTemplate")
resizeCheck:SetWidth(24)
resizeCheck:SetHeight(24)
resizeCheck:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 22, -136)
resizeCheck:SetChecked(IsResizeEnabled())
resizeCheck.label = resizeCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
resizeCheck.label:SetPoint("LEFT", resizeCheck, "RIGHT", 4, 0)
resizeCheck.label:SetText("Enable Resize Handle")
resizeCheck:SetScript("OnClick", function()
    local checked = this:GetChecked() and true or false
    if MythicPlusDB then
        MythicPlusDB.resizeEnabled = checked
    end
    if UpdateResizeControlState then
        UpdateResizeControlState()
    end
end)

-- Enable GitHub logo link checkbox
local githubLinkCheck = CreateFrame("CheckButton", nil, optionsPanel, "UICheckButtonTemplate")
githubLinkCheck:SetWidth(24)
githubLinkCheck:SetHeight(24)
githubLinkCheck:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 22, -162)
githubLinkCheck:SetChecked(IsGithubLinkEnabled())
githubLinkCheck.label = githubLinkCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
githubLinkCheck.label:SetPoint("LEFT", githubLinkCheck, "RIGHT", 4, 0)
githubLinkCheck.label:SetText("Enable GitHub Logo Link")
githubLinkCheck:SetScript("OnClick", function()
    local checked = this:GetChecked() and true or false
    if MythicPlusDB then
        MythicPlusDB.githubLinkEnabled = checked
    end
    if UpdateGithubLinkButtons then
        UpdateGithubLinkButtons()
    end
end)

-- Show Affix Tips checkbox
local tipsCheck = CreateFrame("CheckButton", nil, optionsPanel, "UICheckButtonTemplate")
tipsCheck:SetWidth(24)
tipsCheck:SetHeight(24)
tipsCheck:SetPoint("TOPLEFT", optionsPanel, "TOPLEFT", 22, -188)
tipsCheck:SetChecked(MythicPlusDB and MythicPlusDB.showAffixTips ~= false)
tipsCheck.label = tipsCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
tipsCheck.label:SetPoint("LEFT", tipsCheck, "RIGHT", 4, 0)
tipsCheck.label:SetText("Show Affix Tips")
tipsCheck:SetScript("OnClick", function()
    local checked = this:GetChecked() and true or false
    if MythicPlusDB then MythicPlusDB.showAffixTips = checked end
    local refreshFn = _G.__MYTHICPLUS_REFRESH_AFFIX_TEXT__
    if type(refreshFn) == "function" then refreshFn() end
end)

-- GM-only affix editor (server-authoritative)
MYTHICPLUS_GM_AFFIX_PANEL = CreateFrame("Frame", nil, optionsPanel)
local gmAffixPanel = MYTHICPLUS_GM_AFFIX_PANEL
gmAffixPanel:SetPoint("BOTTOMLEFT", optionsPanel, "BOTTOMLEFT", 18, 18)
gmAffixPanel:SetPoint("BOTTOMRIGHT", optionsPanel, "BOTTOMRIGHT", -18, 18)
gmAffixPanel:SetHeight(120)
gmAffixPanel:SetBackdrop(backdrop_inner)
gmAffixPanel:SetBackdropColor(0.05, 0.05, 0.09, 0.90)
gmAffixPanel:SetBackdropBorderColor(THEME_BORDER[1], THEME_BORDER[2], THEME_BORDER[3], 1)
gmAffixPanel:Hide()

MYTHICPLUS_GM_AFFIX_TITLE = gmAffixPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
local gmAffixTitle = MYTHICPLUS_GM_AFFIX_TITLE
gmAffixTitle:SetPoint("TOPLEFT", gmAffixPanel, "TOPLEFT", 8, -8)
gmAffixTitle:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
gmAffixTitle:SetTextColor(1, 0.82, 0.2, 1)
gmAffixTitle:SetText("GM Affix Editor")

MYTHICPLUS_GM_AFFIX_TIMER = gmAffixPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
local gmAffixTimer = MYTHICPLUS_GM_AFFIX_TIMER
gmAffixTimer:SetPoint("TOPRIGHT", gmAffixPanel, "TOPRIGHT", -8, -8)
gmAffixTimer:SetJustifyH("RIGHT")
gmAffixTimer:SetTextColor(0.80, 0.80, 0.80, 1)
gmAffixTimer:SetText("")

MYTHICPLUS_GM_AFFIX_ROWS = MYTHICPLUS_GM_AFFIX_ROWS or {}
local gmAffixRows = MYTHICPLUS_GM_AFFIX_ROWS

function MythicPlusFindGmAffixOptionIndex(options, affixName)
    for i, opt in ipairs(options or {}) do
        if opt and opt.name == affixName then
            return i
        end
    end
    return 1
end

function MythicPlusUpdateGmAffixRowDisplay(row)
    local options = row.options or {}
    local count = #options
    if count <= 0 then
        row.nameText:SetText("|cff777777No options|r")
        row.prevBtn:Disable()
        row.nextBtn:Disable()
        row.applyBtn:Disable()
        row.selectedName = ""
        return
    end

    if not row.selectedIndex or row.selectedIndex < 1 then
        row.selectedIndex = 1
    elseif row.selectedIndex > count then
        row.selectedIndex = count
    end

    local selected = options[row.selectedIndex] or {}
    row.selectedName = selected.name or ""
    row.nameText:SetText((selected.color or "|cffffffff") .. (row.selectedName ~= "" and row.selectedName or "Unknown") .. "|r")
    row.prevBtn:Enable()
    row.nextBtn:Enable()
    if row.selectedName ~= "" and row.selectedName ~= (row.currentName or "") then
        row.applyBtn:Enable()
    else
        row.applyBtn:Disable()
    end
end

for tier = 1, 3 do
    local row = CreateFrame("Frame", nil, gmAffixPanel)
    row:SetPoint("TOPLEFT", gmAffixPanel, "TOPLEFT", 8, -24 - ((tier - 1) * 28))
    row:SetPoint("TOPRIGHT", gmAffixPanel, "TOPRIGHT", -8, -24 - ((tier - 1) * 28))
    row:SetHeight(22)
    row.tier = tier
    row.options = {}
    row.currentName = ""
    row.selectedIndex = 1
    row.selectedName = ""

    row.tierText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.tierText:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.tierText:SetWidth(34)
    row.tierText:SetJustifyH("LEFT")
    row.tierText:SetText(string.format("T%d", tier))
    row.tierText:SetTextColor(0.88, 0.88, 0.88, 1)

    row.prevBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.prevBtn:SetPoint("LEFT", row.tierText, "RIGHT", 2, 0)
    row.prevBtn:SetWidth(20)
    row.prevBtn:SetHeight(18)
    row.prevBtn:SetText("<")

    row.applyBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.applyBtn:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.applyBtn:SetWidth(40)
    row.applyBtn:SetHeight(18)
    row.applyBtn:SetText("Set")

    row.nextBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.nextBtn:SetPoint("RIGHT", row.applyBtn, "LEFT", -2, 0)
    row.nextBtn:SetWidth(20)
    row.nextBtn:SetHeight(18)
    row.nextBtn:SetText(">")

    row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.nameText:SetPoint("LEFT", row.prevBtn, "RIGHT", 4, 0)
    row.nameText:SetPoint("RIGHT", row.nextBtn, "LEFT", -4, 0)
    row.nameText:SetJustifyH("LEFT")
    row.nameText:SetTextColor(1, 1, 1, 1)
    row.nameText:SetText("")

    row.prevBtn:SetScript("OnClick", function(self)
        local parent = self:GetParent()
        local options = parent.options or {}
        local count = #options
        if count <= 0 then return end
        parent.selectedIndex = parent.selectedIndex - 1
        if parent.selectedIndex < 1 then
            parent.selectedIndex = count
        end
        MythicPlusUpdateGmAffixRowDisplay(parent)
    end)

    row.nextBtn:SetScript("OnClick", function(self)
        local parent = self:GetParent()
        local options = parent.options or {}
        local count = #options
        if count <= 0 then return end
        parent.selectedIndex = parent.selectedIndex + 1
        if parent.selectedIndex > count then
            parent.selectedIndex = 1
        end
        MythicPlusUpdateGmAffixRowDisplay(parent)
    end)

    row.applyBtn:SetScript("OnClick", function(self)
        local parent = self:GetParent()
        if not parent.selectedName or parent.selectedName == "" then
            return
        end
        if not AIO_AVAILABLE or not AIO or not AIO.Handle then
            return
        end
        pcall(AIO.Handle, "MythicPlusServer", "SetWeeklyAffixTier", parent.tier, parent.selectedName)
    end)

    gmAffixRows[tier] = row
end

function MythicPlusRefreshGmAffixEditorUI()
    local editor = state.gmAffixEditor or {}
    if editor.canEdit ~= true and not state.gmLocalMode then
        gmAffixPanel:Hide()
        return
    end

    gmAffixPanel:Show()
    local remaining = math.max(0, (tonumber(editor.nextRerollAt or 0) or 0) - ((type(time) == "function" and time()) or 0))
    gmAffixTimer:SetText("6h reset: " .. MythicPlusFormatLongDuration(remaining))

    for tier = 1, 3 do
        local row = gmAffixRows[tier]
        local tierData = (type(editor.tiers) == "table") and editor.tiers[tier] or nil
        if type(tierData) ~= "table" then
            row:Hide()
        else
            row:Show()
            row.options = type(tierData.options) == "table" and tierData.options or {}
            row.currentName = tostring(tierData.current or "")
            row.selectedIndex = MythicPlusFindGmAffixOptionIndex(row.options, row.currentName)
            MythicPlusUpdateGmAffixRowDisplay(row)
        end
    end
end
_G.__MYTHICPLUS_REFRESH_GM_AFFIX_EDITOR_UI__ = MythicPlusRefreshGmAffixEditorUI

gmAffixPanel:SetScript("OnUpdate", function(_, elapsed)
    if not gmAffixPanel:IsShown() then
        state.gmAffixPanelUpdateElapsed = 0
        return
    end
    state.gmAffixPanelUpdateElapsed = (state.gmAffixPanelUpdateElapsed or 0) + (elapsed or arg1 or 0)
    if state.gmAffixPanelUpdateElapsed < 0.25 then
        return
    end
    state.gmAffixPanelUpdateElapsed = 0
    local editor = state.gmAffixEditor or {}
    if editor.canEdit ~= true then
        return
    end
    local remaining = math.max(0, (tonumber(editor.nextRerollAt or 0) or 0) - ((type(time) == "function" and time()) or 0))
    gmAffixTimer:SetText("6h reset: " .. MythicPlusFormatLongDuration(remaining))
end)

-- Opacity slider
local opacitySlider = CreateOptionSlider(optionsPanel, -218, "Opacity", 10, 100, 1,
    math.floor(GetConfiguredOpacity() * 100 + 0.5), nil)
opacitySlider:SetScript("OnValueChanged", function()
    local val = math.floor(this:GetValue() + 0.5)
    opacitySlider.slLabel:SetText("Opacity: " .. val .. "%")
    local alpha = val / 100
    if MythicPlusDB then MythicPlusDB.windowOpacity = alpha end
    fadeState.active = false
    SetFrameOpacityFromConfig()
end)
opacitySlider.slLabel:SetText("Opacity: " .. math.floor(GetConfiguredOpacity() * 100 + 0.5) .. "%")

function ToggleOptionsPanel()
    if optionsPanel:IsShown() then
        if state.optionsExpandedForPanel then
            state.optionsExpandedForPanel = false
            local restoreHeight = ClampValue(state.optionsRestoreHeight or state.minimizedHeight or FRAME_DEFAULT_MINIMIZED_HEIGHT, FRAME_MIN_HEIGHT_MINIMIZED, 1000)
            state.optionsRestoreHeight = nil
            state.minimizedHeight = restoreHeight
            if MythicPlusDB then
                MythicPlusDB.heightMinimized = restoreHeight
            end
            if state.minimized then
                SetFrameHeightGrowUp(restoreHeight)
                if UpdateTrackerLayout then
                    UpdateTrackerLayout(false)
                end
            end
        end
        optionsPanel:Hide()
    else
        -- Sync controls before showing.
        fadeState.active = false
        SetFrameOpacityFromConfig()
        state.idleSince = GetTime()
        lockCheck:SetChecked(MythicPlusDB and MythicPlusDB.locked or false)
        hideCloseCheck:SetChecked(MythicPlusDB and MythicPlusDB.alwaysHideCloseButton or false)
        autoHideCheck:SetChecked(MythicPlusDB and MythicPlusDB.autoHideOutOfMythic or false)
        resizeCheck:SetChecked(IsResizeEnabled())
        githubLinkCheck:SetChecked(IsGithubLinkEnabled())
        local tipsVal = MythicPlusDB and MythicPlusDB.showAffixTips
        if tipsVal == nil then tipsVal = true end
        tipsCheck:SetChecked(tipsVal)
        opacitySlider:SetValue(math.floor(GetConfiguredOpacity() * 100 + 0.5))
        RequestGmAffixEditorSync(true)
        local refreshGmEditor = _G.__MYTHICPLUS_REFRESH_GM_AFFIX_EDITOR_UI__
        if type(refreshGmEditor) == "function" then
            refreshGmEditor()
        end
        if state.minimized then
            local curHeight = frame:GetHeight() or state.minimizedHeight or FRAME_DEFAULT_MINIMIZED_HEIGHT
            if curHeight < OPTIONS_PANEL_MIN_HEIGHT then
                state.optionsExpandedForPanel = true
                state.optionsRestoreHeight = curHeight
                SetFrameHeightGrowUp(OPTIONS_PANEL_MIN_HEIGHT)
                if UpdateTrackerLayout then
                    UpdateTrackerLayout(false)
                end
            else
                state.optionsExpandedForPanel = false
                state.optionsRestoreHeight = nil
            end
        else
            state.optionsExpandedForPanel = false
            state.optionsRestoreHeight = nil
        end
        optionsPanel:Show()
    end
end

-------------------------------------------------------------------------------
-- Update Affix Display Text
-------------------------------------------------------------------------------
local function RefreshAffixText()
    if state.summary and state.summaryShown then
        HideAffixRows()
        affixText:Show()
        affixTitle:SetText("|cffffffffRun Summary|r")
        local timeText = state.summary.timeTaken and FormatTime(state.summary.timeTaken) or "N/A"
        local deathText = tostring(state.summary.deaths or 0)
        local ratingText = state.summary.rating and tostring(state.summary.rating) or "N/A"
        local timeColor = GetTimeTakenColorCode(state.summary.timeTaken, state.timerMax)
        local timeValue = state.summary.timeTaken and ColorText(timeText, timeColor) or "|cffffffffN/A|r"
        local deathValue = ColorText(deathText, GetDeathsColorCode(state.summary.deaths or 0))
        local ratingValue = state.summary.rating and ColorText(ratingText, GetRatingColorCode(state.summary.rating)) or "|cffffffffN/A|r"
        affixText:SetText(table.concat({
            "|cffffffffTime taken:|r " .. timeValue,
            "|cffffffffDeaths:|r " .. deathValue,
            "|cffffffffNew Rating:|r " .. ratingValue,
        }, "\n"))
        local titleH = affixTitle:GetStringHeight() or 14
        local textH = affixText:GetStringHeight() or 60
        scrollChild:SetHeight(math.max(titleH + textH + 20, 180))
        return
    end

    if state.awaitingFinalBossAfterTimeout then
        HideAffixRows()
        affixText:Show()
        affixTitle:SetText("|cffff2020TIME RAN OUT|r")
        affixText:SetText(table.concat({
            "|cffff6060You are over the timer.|r",
            "|cffffffffDefeat the final boss to finalize this run.|r",
            "|cffffffffFinal rating will display after finalization.|r",
        }, "\n"))
        local titleH = affixTitle:GetStringHeight() or 14
        local textH = affixText:GetStringHeight() or 60
        scrollChild:SetHeight(math.max(titleH + textH + 20, 180))
        return
    end

    local affixSource = GetBestAvailableAffixes()
    affixTitle:SetText("|cffffffffMythic Affixes|r")
    if not affixSource then
        HideAffixRows()
        affixText:Show()
        affixText:SetText("|cffaaaaaaWaiting for server affix sync...|r")
        RequestAffixSyncIfNeeded()
        local titleH = affixTitle:GetStringHeight() or 14
        local textH = affixText:GetStringHeight() or 16
        scrollChild:SetHeight(math.max(titleH + textH + 20, 180))
        return
    end

    local entries = {}

    if affixSource and type(affixSource) == "table"
       and affixSource[1] and type(affixSource[1]) == "table"
       and affixSource[1].name then
        -- Server format: flat list of {name, color, tier}
        local byTier = {}
        for _, aff in ipairs(affixSource) do
            local t = aff.tier or 1
            if not byTier[t] then byTier[t] = {} end
            table.insert(byTier[t], aff)
        end
        for t = 1, 3 do
            if byTier[t] and #byTier[t] > 0 then
                table.insert(entries, {
                    text = string.format("|cffffffffTier|r %s", ColorText(tostring(t), GetTierColorCode(t))),
                })
                for _, aff in ipairs(byTier[t]) do
                    local name = NormalizeAffixName(aff.name or "")
                    local c = aff.color or "|cffffffff"
                    if name ~= "" then
                        table.insert(entries, {
                            text = "  |cffffffff-|r " .. c .. name .. "|r",
                            tooltipInfo = BuildAffixTooltip(name),
                        })
                    end
                end
                table.insert(entries, { isTierSpacer = true })
            end
        end
    end

    if entries[#entries] and entries[#entries].isTierSpacer then
        table.remove(entries, #entries)
    end

    -- Append a contextual tip if enabled
    local showTips = MythicPlusDB and MythicPlusDB.showAffixTips
    if showTips == nil then showTips = true end
    if showTips and affixSource and type(affixSource) == "table" then
        local allNames = {}
        for _, aff in ipairs(affixSource) do
            if aff.name then
                allNames[#allNames + 1] = aff.name
            end
        end
        local tip = GetAffixTip(allNames)
        if tip then
            table.insert(entries, { isTierSpacer = true })
            table.insert(entries, { text = "|cffbbbbbbTip:|r |cffaaddff" .. tip .. "|r", isTip = true })
        end
    end

    RenderAffixRows(entries)
end
_G.__MYTHICPLUS_REFRESH_AFFIX_TEXT__ = RefreshAffixText

-------------------------------------------------------------------------------
-- Update Stats Display
-------------------------------------------------------------------------------
local function RefreshStats()
    SetBarTextAlertMode(false)

    if state.summary and state.summaryShown then
        SetIdleWaitMessageCentered(false)
        local timeText = state.summary.timeTaken and FormatTime(state.summary.timeTaken) or "N/A"
        local deathText = tostring(state.summary.deaths or 0)
        local ratingText = state.summary.rating and tostring(state.summary.rating) or "N/A"
        local timeColor = GetTimeTakenColorCode(state.summary.timeTaken, state.timerMax)
        local timeLine = "|cffffffffTime taken:|r " .. (state.summary.timeTaken and ColorText(timeText, timeColor) or "|cffffffffN/A|r")
        if state.timerMax and state.timerMax > 0 then
            timeLine = timeLine .. " |cffffffff/|r " .. ColorText(FormatTime(state.timerMax), timeColor)
        end
        statKills.label:SetText(timeLine)
        statPct.label:SetText("|cffffffffDeaths:|r " .. ColorText(deathText, GetDeathsColorCode(state.summary.deaths or 0)))
        if state.summary.rating then
            statTier.label:SetText("|cffffffffNew Rating:|r " .. ColorText(ratingText, GetRatingColorCode(state.summary.rating)))
        else
            statTier.label:SetText("|cffffffffNew Rating:|r |cffffffffN/A|r")
        end
        statTimer.label:SetText("|cffffffffRun Summary|r")
        statDeaths.label:SetText("|cffffffffReady for next run|r")
        progressBar:SetValue(1)
        barText:SetText("|cff33ff33COMPLETE|r")
        progressBar:SetStatusBarColor(0.2, 1.0, 0.2, 1)
        UpdateBarGlowTrigger()
        UpdateCloseButtonsForRunState()
        return
    end

    if state.awaitingFinalBossAfterTimeout then
        SetIdleWaitMessageCentered(false)
        local completionPct, targetPct = GetCompletionDisplayPct()
        local completionShown = math.floor(completionPct + 0.5)
        local killColor = GetProgressColorCode(state.killsCurrent, math.max(state.killsRequired, 1))
        local completionColor = GetProgressColorCode(completionPct, targetPct)
        local targetColor = GetProgressColorCode(targetPct, targetPct)

        local curKillsText = ColorText(tostring(state.killsCurrent), killColor)
        local reqKillsText = ColorText(tostring(state.killsRequired), killColor)
        statKills.label:SetText(string.format("%s |cffffffff/|r %s |cffffffffkills|r", curKillsText, reqKillsText))
        statPct.label:SetText(string.format("%s |cffffffff/|r %s |cffffffffComplete, final boss required|r", ColorText(string.format("%d%%", completionShown), completionColor), ColorText(string.format("%d%%", targetPct), targetColor)))
        statTier.label:SetText(string.format("|cffffffffCurrent Tier:|r %s", ColorText(tostring(state.currentTierSet), GetTierColorCode(state.currentTierSet))))
        statTimer.label:SetText("|cffff2020TIME RAN OUT|r")
        statDeaths.label:SetText("|cffff9090Defeat final boss to finalize run|r")
        progressBar:SetValue(1)
        SetBarTextAlertMode(true)
        barText:SetText("|cffff2020TIME RAN OUT|r")
        progressBar:SetStatusBarColor(0.90, 0.12, 0.12, 1)
        UpdateBarGlowTrigger()
        UpdateCloseButtonsForRunState()
        return
    end

    -- When idle (no run active and not just finished), show inactive state
    if not state.running and not state.finished then
        SetIdleWaitMessageCentered(true)
        statKills.label:SetText("")
        statPct.label:SetText("")
        statTier.label:SetText("")
        statTimer.label:SetText("")
        statDeaths.label:SetText("|cffffffffWaiting for Mythic Mode|r")
        progressBar:SetValue(0)
        barText:SetText("")
        progressBar:SetStatusBarColor(0.2, 0.2, 0.2, 0.9)
        UpdateBarGlowTrigger()
        UpdateCloseButtonsForRunState()
        return
    end

    SetIdleWaitMessageCentered(false)
    local completionPct, targetPct = GetCompletionDisplayPct()
    local completionShown = math.floor(completionPct + 0.5)
    local killColor = GetProgressColorCode(state.killsCurrent, math.max(state.killsRequired, 1))
    local completionColor = GetProgressColorCode(completionPct, targetPct)
    local targetColor = GetProgressColorCode(targetPct, targetPct)

    local curKillsText = ColorText(tostring(state.killsCurrent), killColor)
    local reqKillsText = ColorText(tostring(state.killsRequired), killColor)
    statKills.label:SetText(string.format("%s |cffffffff/|r %s |cffffffffkills|r", curKillsText, reqKillsText))
    statPct.label:SetText(string.format("%s |cffffffff/|r %s |cffffffffComplete, final boss required|r", ColorText(string.format("%d%%", completionShown), completionColor), ColorText(string.format("%d%%", targetPct), targetColor)))
    statTier.label:SetText(string.format("|cffffffffCurrent Tier:|r %s", ColorText(tostring(state.currentTierSet), GetTierColorCode(state.currentTierSet))))

    -- Timer
    if state.running and not state.finished then
        local elapsed = GetTime() - state.startTime
        local remaining = state.duration - elapsed
        if remaining < 0 then remaining = 0 end
        local totalForColor = state.timerMax > 0 and state.timerMax or state.duration
        local r, g, b = GetTimerGradientColor(remaining, totalForColor)
        statTimer.label:SetText(string.format("%s |cffffffffRemaining|r", ColorizeRGB(FormatTime(remaining), r, g, b)))
    elseif state.finished then
        statTimer.label:SetText("|cffffffffRun Complete!|r")
    else
        local totalForColor = state.timerMax > 0 and state.timerMax or state.duration
        local r, g, b = GetTimerGradientColor(state.duration, totalForColor)
        statTimer.label:SetText(string.format("%s |cffffffffRemaining|r", ColorizeRGB(FormatTime(state.duration), r, g, b)))
    end

    -- Deaths
    statDeaths.label:SetText(string.format("%s |cffffffffDeaths|r", ColorText(tostring(state.deaths), GetDeathsColorCode(state.deaths))))

    -- Progress bar
    progressBar:SetValue(GetProgressPct())
    barText:SetText(ColorText(string.format("%d%%", completionShown), completionColor))

    -- Color the bar based on progress
    if completionPct >= targetPct then
        progressBar:SetStatusBarColor(0.2, 1.0, 0.2, 1)
    else
        progressBar:SetStatusBarColor(THEME_ACCENT[1], THEME_ACCENT[2], THEME_ACCENT[3], 1)
    end

    UpdateBarGlowTrigger()
    UpdateCloseButtonsForRunState()
end

-------------------------------------------------------------------------------
-- Run Control Functions (global for button access)
-------------------------------------------------------------------------------
function StartMythicRun()
    ResetRunSummary()
    state.awaitingFinalBossAfterTimeout = false
    state.running = true
    state.finished = false
    state.idleSince = 0
    state.startTime = GetTime()
    state.killsCurrent = 0
    state.killsRequired = CalcKillsRequired(state.keyLevel)
    state.completionTargetPct = DEFAULT_COMPLETION_TARGET_PCT
    local total = (MythicPlusDB and MythicPlusDB.timerMinutes or defaults.timerMinutes) * 60
    state.duration = total
    state.timerMax = total
    RefreshAffixText()
    RefreshStats()
    ForceShowTrackerForRun()
end

function StopMythicRun()
    state.awaitingFinalBossAfterTimeout = false
    state.running = false
    state.finished = true
    state.serverControlled = false
    ResetRunSummary()
    RefreshStats()
end

function ResetMythicRun()
    ResetRunSummary()
    state.awaitingFinalBossAfterTimeout = false
    state.running = false
    state.finished = false
    state.idleSince = 0
    state.startTime = 0
    state.killsCurrent = 0
    state.killsRequired = CalcKillsRequired(state.keyLevel)
    state.duration = (MythicPlusDB and MythicPlusDB.timerMinutes or defaults.timerMinutes) * 60
    state.timerMax = state.duration
    state.deaths = 0
    state.serverControlled = false
    RefreshStats()
end

function CycleAffixes()
    state.currentTierSet = state.currentTierSet + 1
    if state.currentTierSet > #AFFIX_TIER_SETS then
        state.currentTierSet = 1
    end
    if MythicPlusDB then
        MythicPlusDB.lastTierSet = state.currentTierSet
    end
    RefreshAffixText()
    RefreshStats()
end

-------------------------------------------------------------------------------
-- OnUpdate — Timer tick + kill tracking via combat log
-------------------------------------------------------------------------------
local updateElapsed = 0
frame:SetScript("OnUpdate", function(_, elapsed)
    local now = GetTime()
    SendTimerAddonHeartbeat(false)
    ProcessBarGlow(now)
    ProcessFrameFade(now)

    if MythicPlusDB and MythicPlusDB.autoHideOutOfMythic and frame:IsShown() then
        local inMythicMode = IsMythicModeActive()
        if inMythicMode then
            state.idleSince = 0
        elseif optionsPanel:IsShown() then
            state.idleSince = now
        else
            if state.idleSince <= 0 then
                state.idleSince = now
            elseif (now - state.idleSince) >= 20 and not fadeState.active then
                StartFrameFade(0, 1.0, true)
            end
        end
    else
        state.idleSince = 0
    end

    local frameElapsed = elapsed or arg1 or 0
    updateElapsed = updateElapsed + frameElapsed
    local rate = GetConfiguredPollRate()
    if updateElapsed < rate then return end
    updateElapsed = 0

    if state.summary and state.summaryShown and state.summaryPendingUntil > 0 and now >= state.summaryPendingUntil then
        ResetRunSummary()
        state.killsCurrent = 0
        state.killsRequired = 0
        state.finished = false
        RefreshAffixText()
        RefreshStats()
        return
    end

    if not state.running or state.finished then return end

    local elapsedRun = now - state.startTime
    local remaining = state.duration - elapsedRun

    -- Local timeout handling is only for non-server-controlled runs.
    if (not state.serverControlled) and remaining <= 0 then
        state.finished = true
        state.running = false
    end

    RefreshStats()
end)

-------------------------------------------------------------------------------
-- Combat Log — Track kills automatically
-------------------------------------------------------------------------------
local combatFrame = CreateFrame("Frame", nil, UIParent)
combatFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
combatFrame:SetScript("OnEvent", function()
    if not state.running or state.finished then return end
    -- Skip local kill tracking when server controls the run
    if state.serverControlled then return end

    -- In WotLK 3.3.5 combat log args come via arg1..argN
    -- arg2 = event type
    local eventType = arg2

    if eventType == "PARTY_KILL" then
        state.killsCurrent = state.killsCurrent + 1
        if frame:IsShown() then
            RefreshStats()
        end
    end
end)

-------------------------------------------------------------------------------
-- Slash Command
-------------------------------------------------------------------------------
SLASH_MYTHICPLUS1 = "/mythic"
SLASH_MYTHICPLUS2 = "/mplus"
SlashCmdList["MYTHICPLUS"] = function(msg)
    if not msg or msg == "" then
        if frame:IsShown() then
            HideTrackerWindow()
        else
            if MythicPlusDB then MythicPlusDB.visible = true end
            frame:Show()
            RefreshAffixText()
            RefreshStats()
        end
        return
    end

    local cmd, rest = msg:match("^(%S+)%s*(.*)")
    cmd = cmd and cmd:lower() or ""

    if cmd == "start" then
        StartMythicRun()
        if not frame:IsShown() then frame:Show() end

    elseif cmd == "stop" then
        StopMythicRun()

    elseif cmd == "reset" then
        ResetMythicRun()

    elseif cmd == "tier" or cmd == "affixes" then
        CycleAffixes()

    elseif cmd == "key" then
        local level = tonumber(rest)
        if level and level >= 1 and level <= 99 then
            state.keyLevel = level
            state.killsRequired = CalcKillsRequired(level)
            if MythicPlusDB then MythicPlusDB.keyLevel = level end
            RefreshStats()
            DEFAULT_CHAT_FRAME:AddMessage(THEME_CHAT_PREFIX .. " Key level set to |cffffcc00+" .. level .. "|r (" .. state.killsRequired .. " kills)")
        else
            DEFAULT_CHAT_FRAME:AddMessage(THEME_CHAT_PREFIX .. " Usage: /mythic key <1-99>")
        end

    elseif cmd == "timer" then
        local mins = tonumber(rest)
        if mins and mins >= 1 and mins <= 120 then
            if MythicPlusDB then MythicPlusDB.timerMinutes = mins end
            if not state.running then
                state.duration = mins * 60
                RefreshStats()
            end
            DEFAULT_CHAT_FRAME:AddMessage(THEME_CHAT_PREFIX .. " Timer set to |cffffcc00" .. mins .. " minutes|r")
        else
            DEFAULT_CHAT_FRAME:AddMessage(THEME_CHAT_PREFIX .. " Usage: /mythic timer <1-120>")
        end

    elseif cmd == "kill" or cmd == "addkill" then
        -- Manual kill add for testing
        local count = tonumber(rest) or 1
        state.killsCurrent = math.min(state.killsCurrent + count, state.killsRequired)
        RefreshStats()
        DEFAULT_CHAT_FRAME:AddMessage(THEME_CHAT_PREFIX .. " Added " .. count .. " kill(s). Total: " .. state.killsCurrent .. "/" .. state.killsRequired)

    elseif cmd == "lock" then
        if MythicPlusDB then
            MythicPlusDB.locked = not MythicPlusDB.locked
            local status = MythicPlusDB.locked and "locked" or "unlocked"
            DEFAULT_CHAT_FRAME:AddMessage(THEME_CHAT_PREFIX .. " Window " .. status)
        end

    elseif cmd == "gmaffix" then
        state.gmLocalMode = not state.gmLocalMode
        if state.gmLocalMode then
            state.gmAffixEditor = state.gmAffixEditor or {}
            state.gmAffixEditor.canEdit = true
            if not optionsPanel:IsShown() then
                ToggleOptionsPanel()
            else
                local refreshGmEditor = _G.__MYTHICPLUS_REFRESH_GM_AFFIX_EDITOR_UI__
                if type(refreshGmEditor) == "function" then refreshGmEditor() end
            end
            DEFAULT_CHAT_FRAME:AddMessage(THEME_CHAT_PREFIX .. " GM affix editor |cff00ff00enabled|r. Open settings (gear icon) if not visible.")
        else
            state.gmAffixEditor = state.gmAffixEditor or {}
            state.gmAffixEditor.canEdit = false
            local refreshGmEditor = _G.__MYTHICPLUS_REFRESH_GM_AFFIX_EDITOR_UI__
            if type(refreshGmEditor) == "function" then refreshGmEditor() end
            DEFAULT_CHAT_FRAME:AddMessage(THEME_CHAT_PREFIX .. " GM affix editor |cffff4444disabled|r.")
        end

    elseif cmd == "help" then
        DEFAULT_CHAT_FRAME:AddMessage(THEME_CHAT_PREFIX .. " Commands:")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffcc00/mythic|r - Toggle window")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffcc00/mythic start|r - Start a run")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffcc00/mythic stop|r - Stop current run")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffcc00/mythic reset|r - Reset progress")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffcc00/mythic tier|r - Cycle affix sets")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffcc00/mythic key N|r - Set key level (1-99)")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffcc00/mythic timer N|r - Set timer in minutes")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffcc00/mythic kill [N]|r - Add manual kill(s)")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffcc00/mythic lock|r - Toggle window lock")
        DEFAULT_CHAT_FRAME:AddMessage("  |cffffcc00/mythic gmaffix|r - Toggle GM affix editor (opens settings)")
    else
        DEFAULT_CHAT_FRAME:AddMessage(THEME_CHAT_PREFIX .. " Unknown command. Type |cffffcc00/mythic help|r for usage.")
    end
end

-------------------------------------------------------------------------------
-- SavedVariables — Load / Save
-------------------------------------------------------------------------------
function BuildRunSnapshot()
    local remaining = state.duration or 0
    if state.running and not state.finished and state.startTime and state.startTime > 0 then
        remaining = math.max(0, (state.duration or 0) - (GetTime() - state.startTime))
    end
    return {
        running = IsMythicModeActive() and true or false,
        serverControlled = state.serverControlled and true or false,
        awaitingFinalBossAfterTimeout = state.awaitingFinalBossAfterTimeout and true or false,
        killsCurrent = math.max(0, math.floor(tonumber(state.killsCurrent or 0) or 0)),
        killsRequired = math.max(0, math.floor(tonumber(state.killsRequired or 0) or 0)),
        deaths = math.max(0, math.floor(tonumber(state.deaths or 0) or 0)),
        durationRemaining = math.max(0, tonumber(remaining or 0) or 0),
        timerMax = math.max(0, tonumber(state.timerMax or 0) or 0),
        completionTargetPct = NormalizePercent(state.completionTargetPct, DEFAULT_COMPLETION_TARGET_PCT),
        currentTierSet = math.max(1, math.floor(tonumber(state.currentTierSet or 1) or 1)),
        savedAt = (type(time) == "function") and time() or 0,
    }
end

function RestoreRunSnapshot(snapshot)
    if type(snapshot) ~= "table" or not snapshot.running then
        return false
    end

    local nowEpoch = (type(time) == "function") and time() or 0
    local savedAt = tonumber(snapshot.savedAt or 0) or 0
    if nowEpoch > 0 and savedAt > 0 and (nowEpoch - savedAt) > (4 * 60 * 60) then
        return false
    end

    state.awaitingFinalBossAfterTimeout = snapshot.awaitingFinalBossAfterTimeout == true
    if state.awaitingFinalBossAfterTimeout then
        state.running = false
        state.finished = true
    else
        state.running = true
        state.finished = false
    end
    state.serverControlled = snapshot.serverControlled == true
    state.killsCurrent = math.max(0, math.floor(tonumber(snapshot.killsCurrent or 0) or 0))

    local restoredReq = math.max(0, math.floor(tonumber(snapshot.killsRequired or 0) or 0))
    if restoredReq > 0 then
        state.killsRequired = restoredReq
    end

    state.deaths = math.max(0, math.floor(tonumber(snapshot.deaths or 0) or 0))
    state.currentTierSet = math.max(1, math.floor(tonumber(snapshot.currentTierSet or state.currentTierSet) or state.currentTierSet))
    state.completionTargetPct = NormalizePercent(snapshot.completionTargetPct, state.completionTargetPct)

    local remaining = math.max(0, tonumber(snapshot.durationRemaining or state.duration) or state.duration)
    state.duration = remaining
    local restoredMax = math.max(0, tonumber(snapshot.timerMax or state.timerMax) or state.timerMax)
    if restoredMax > 0 then
        state.timerMax = restoredMax
    end
    if state.timerMax <= 0 or remaining > state.timerMax then
        state.timerMax = remaining
    end
    state.startTime = GetTime()
    return true
end

addon:RegisterEvent("ADDON_LOADED")
addon:RegisterEvent("PLAYER_LOGOUT")
addon:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "MythicPlus" then
        -- Initialize saved vars
        if not MythicPlusDB then
            MythicPlusDB = {}
            for k, v in pairs(defaults) do
                MythicPlusDB[k] = v
            end
        end
        -- Fill any missing keys
        for k, v in pairs(defaults) do
            if MythicPlusDB[k] == nil then
                MythicPlusDB[k] = v
            end
        end

        MythicPlusDB.keyLevel = ClampValue(math.floor(tonumber(MythicPlusDB.keyLevel) or defaults.keyLevel), 1, 99)
        MythicPlusDB.lastTierSet = ClampValue(math.floor(tonumber(MythicPlusDB.lastTierSet) or defaults.lastTierSet), 1, #AFFIX_TIER_SETS)
        MythicPlusDB.timerMinutes = ClampValue(math.floor(tonumber(MythicPlusDB.timerMinutes) or defaults.timerMinutes), 1, 120)
        MythicPlusDB.pollRate = GetConfiguredPollRate()

        -- Restore state from saved vars
        state.keyLevel = MythicPlusDB.keyLevel
        state.currentTierSet = MythicPlusDB.lastTierSet
        state.killsRequired = CalcKillsRequired(state.keyLevel)
        state.duration = MythicPlusDB.timerMinutes * 60
        state.timerMax = state.duration
        SetFrameOpacityFromConfig()
        state.minimized = MythicPlusDB.minimized or false
        state.expandedHeight = ClampValue(MythicPlusDB.heightExpanded or defaults.heightExpanded, FRAME_MIN_HEIGHT_EXPANDED, 1400)
        state.minimizedHeight = ClampValue(MythicPlusDB.heightMinimized or defaults.heightMinimized, FRAME_MIN_HEIGHT_MINIMIZED, 1000)
        local minWForMode = state.minimized and FRAME_MIN_WIDTH_MINIMIZED or FRAME_MIN_WIDTH_EXPANDED
        local restoredWidth = ClampValue(MythicPlusDB.width or defaults.width, minWForMode, 1800)
        frame:SetWidth(restoredWidth)
        if state.minimized then
            frame:SetHeight(state.minimizedHeight)
        else
            frame:SetHeight(state.expandedHeight)
        end
        if IsServerAffixPayload(MythicPlusDB.lastKnownAffixes) then
            state.serverAffixes = DeepCopyTable(MythicPlusDB.lastKnownAffixes)
        else
            MythicPlusDB.lastKnownAffixes = nil
        end
        local restoredSnapshot = RestoreRunSnapshot(MythicPlusDB.runSnapshot)

        -- Restore window position
        if MythicPlusDB.pos then
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", MythicPlusDB.pos[1], MythicPlusDB.pos[2])
        end

        -- Apply lock state to dragging
        if MythicPlusDB.locked then
            frame:SetScript("OnDragStart", nil)
        end

        if UpdateGithubLinkButtons then
            UpdateGithubLinkButtons()
        end

        -- Restore minimized state
        ApplyMinimizeState()

        -- Restore visibility
        if MythicPlusDB.visible then
            frame:Show()
        end
        if restoredSnapshot then
            ForceShowTrackerForRun()
        end

        RefreshAffixText()
        RefreshStats()
        UpdateCloseButtonsForRunState()
        SendTimerAddonHeartbeat(true)
        RequestGmAffixEditorSync(true)

    elseif event == "PLAYER_LOGOUT" then
        SendTimerAddonShutdown()
        if MythicPlusDB then
            MythicPlusDB.keyLevel = state.keyLevel
            MythicPlusDB.lastTierSet = state.currentTierSet
            MythicPlusDB.minimized = state.minimized
            MythicPlusDB.visible = frame:IsShown() and true or false
            MythicPlusDB.runSnapshot = BuildRunSnapshot()
            MythicPlusDB.width = math.floor((frame:GetWidth() or FRAME_DEFAULT_WIDTH) + 0.5)
            MythicPlusDB.heightExpanded = state.expandedHeight
            MythicPlusDB.heightMinimized = state.minimizedHeight
            MythicPlusDB.resizeEnabled = IsResizeEnabled()
            MythicPlusDB.githubLinkEnabled = IsGithubLinkEnabled()
            -- Position is already saved on drag stop
        end
    end
end)

-------------------------------------------------------------------------------
-- ESC key does NOT close this frame (removed from UISpecialFrames)
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- AIO Integration — Server-controlled state
-- The server can call any of these handlers to push data to this client.
-- All handlers are registered under the name "MythicPlus".
-- If AIO is not loaded these are silently skipped.
-------------------------------------------------------------------------------
if AIO_AVAILABLE then
    local MythicPlusHandlers = {}

    -- Server sets kill count: AIO.Handle(player, "MythicPlus", "SetKills", current, required)
    function MythicPlusHandlers.SetKills(player, current, required)
        if type(current) == "number" then
            state.killsCurrent = math.max(0, math.floor(current + 0.5))
        end
        if type(required) == "number" then
            local req = math.max(0, math.floor(required + 0.5))
            state.killsRequired = req
        end
        if frame:IsShown() then RefreshStats() end
    end

    -- Server sets progress percent: AIO.Handle(player, "MythicPlus", "SetProgress", pct)
    function MythicPlusHandlers.SetProgress(player, pct)
        if type(pct) ~= "number" then return end
        pct = math.max(0, math.min(pct, 100))
        if state.killsRequired > 0 then
            state.killsCurrent = math.floor(state.killsRequired * pct / 100)
        end
        RefreshStats()
    end

    -- Server sets current tier: AIO.Handle(player, "MythicPlus", "SetTier", tierNum)
    function MythicPlusHandlers.SetTier(player, tierNum)
        if type(tierNum) ~= "number" then return end
        state.currentTierSet = tierNum
        RefreshAffixText()
        RefreshStats()
    end

    -- Server sets timer: AIO.Handle(player, "MythicPlus", "SetTimer", seconds)
    function MythicPlusHandlers.SetTimer(player, seconds)
        if type(seconds) ~= "number" then return end
        seconds = math.max(0, seconds)
        state.duration = seconds
        if state.timerMax <= 0 or seconds > state.timerMax then
            state.timerMax = seconds
        end
        state.startTime = GetTime()
        RefreshStats()
    end

    -- Server sets affixes: AIO.Handle(player, "MythicPlus", "SetAffixes", affixTable)
    -- Accepts server format: {{name="X", color="|cffXXXXXX", tier=1}, ...}
    -- or legacy format: {tier1={names}, tier2={names}, tier3={names}}
    function MythicPlusHandlers.SetAffixes(player, affixTable)
        if type(affixTable) ~= "table" then return end
        SaveLastKnownAffixes(affixTable)
        RefreshAffixText()
    end

    -- Server pushes GM affix editor context:
    -- { canEdit=true/false, nextRerollAt=epochSec, tiers={{tier=1,current=\"X\",options={{name,color},...}},...} }
    function MythicPlusHandlers.SetGmAffixEditorData(player, data)
        local editor = {
            canEdit = false,
            nextRerollAt = 0,
            tiers = {},
        }

        if type(data) == "table" then
            editor.canEdit = data.canEdit == true
            editor.nextRerollAt = tonumber(data.nextRerollAt or 0) or 0
            local srcTiers = type(data.tiers) == "table" and data.tiers or {}
            for key, tierData in pairs(srcTiers) do
                if type(tierData) == "table" then
                    local tierNum = tonumber(tierData.tier or key)
                    if tierNum and tierNum >= 1 and tierNum <= 3 then
                        local normalizedTier = {
                            current = tostring(tierData.current or ""),
                            options = {},
                        }
                        if type(tierData.options) == "table" then
                            for _, opt in ipairs(tierData.options) do
                                if type(opt) == "table" then
                                    local name = tostring(opt.name or "")
                                    if name ~= "" then
                                        table.insert(normalizedTier.options, {
                                            name = name,
                                            color = opt.color or "|cffffffff",
                                        })
                                    end
                                end
                            end
                        end
                        editor.tiers[tierNum] = normalizedTier
                    end
                end
            end
        end

        state.gmAffixEditor = editor
        local refreshGmEditor = _G.__MYTHICPLUS_REFRESH_GM_AFFIX_EDITOR_UI__
        if type(refreshGmEditor) == "function" then
            refreshGmEditor()
        end
    end

    -- Server sets death count: AIO.Handle(player, "MythicPlus", "SetDeaths", count)
    function MythicPlusHandlers.SetDeaths(player, count)
        if type(count) == "number" then
            state.deaths = count
        end
        if frame:IsShown() then RefreshStats() end
    end

    -- Server pushes full state: AIO.Handle(player, "MythicPlus", "UpdateAll", data)
    -- data = { tier, timer, timerMax, forcePct, kills={cur,req}, affixes, deaths, running, keyLevel }
    function MythicPlusHandlers.UpdateAll(player, data)
        if type(data) ~= "table" then return end

        if data.keyLevel and type(data.keyLevel) == "number" then
            state.keyLevel = data.keyLevel
        end
        if data.kills and type(data.kills) == "table" then
            if type(data.kills[1]) == "number" then
                state.killsCurrent = math.max(0, math.floor(data.kills[1] + 0.5))
            end
            if type(data.kills[2]) == "number" then
                local req = math.max(0, math.floor(data.kills[2] + 0.5))
                state.killsRequired = req
            end
        elseif data.pct and type(data.pct) == "number" then
            local p = math.max(0, math.min(data.pct, 100))
            if state.killsRequired > 0 then
                state.killsCurrent = math.floor(state.killsRequired * p / 100)
            end
        end
        if data.tier and type(data.tier) == "number" then
            state.currentTierSet = data.tier
        end
        if data.forcePct and type(data.forcePct) == "number" then
            state.completionTargetPct = NormalizePercent(data.forcePct, DEFAULT_COMPLETION_TARGET_PCT)
        end
        if data.timerMax and type(data.timerMax) == "number" then
            state.timerMax = math.max(0, data.timerMax)
        end
        if data.timer and type(data.timer) == "number" then
            state.duration = math.max(0, data.timer)
            if state.timerMax <= 0 or state.duration > state.timerMax then
                state.timerMax = state.duration
            end
            state.startTime = GetTime()
        end
        if data.affixes and type(data.affixes) == "table" then
            SaveLastKnownAffixes(data.affixes)
        end
        if data.deaths and type(data.deaths) == "number" then
            state.deaths = data.deaths
        end
        if data.running then
            ResetRunSummary()
            state.serverControlled = true
            if state.awaitingFinalBossAfterTimeout then
                state.running = false
                state.finished = true
            elseif not state.running then
                state.running = true
                state.finished = false
                if not state.startTime or state.startTime == 0 then
                    state.startTime = GetTime()
                end
            end
            ForceShowTrackerForRun()
            SendTimerAddonHeartbeat(true)
        end

        RefreshAffixText()
        RefreshStats()
    end

    -- Server starts a run: AIO.Handle(player, "MythicPlus", "StartRun", data)
    -- data = { tier, timer, timerMax, forcePct, kills={cur,req}, affixes, deaths, keyLevel }
    function MythicPlusHandlers.StartRun(player, data)
        ResetRunSummary()
        state.awaitingFinalBossAfterTimeout = false
        state.serverControlled = true
        state.deaths = 0
        state.killsCurrent = 0
        if type(data) == "table" then
            if data.keyLevel and type(data.keyLevel) == "number" then
                state.keyLevel = data.keyLevel
            end
            if data.kills and type(data.kills) == "table" then
                if type(data.kills[1]) == "number" then
                    state.killsCurrent = math.max(0, math.floor(data.kills[1] + 0.5))
                end
                if type(data.kills[2]) == "number" then
                    state.killsRequired = math.max(0, math.floor(data.kills[2] + 0.5))
                end
            end
            if data.forcePct and type(data.forcePct) == "number" then
                state.completionTargetPct = NormalizePercent(data.forcePct, DEFAULT_COMPLETION_TARGET_PCT)
            end
            if data.timerMax and type(data.timerMax) == "number" then
                state.timerMax = math.max(0, data.timerMax)
            end
            if data.timer and type(data.timer) == "number" then
                state.duration = math.max(0, data.timer)
                if state.timerMax <= 0 or state.duration > state.timerMax then
                    state.timerMax = state.duration
                end
            end
            if data.tier and type(data.tier) == "number" then
                state.currentTierSet = data.tier
            end
            if data.affixes and type(data.affixes) == "table" then
                SaveLastKnownAffixes(data.affixes)
            end
            if data.deaths and type(data.deaths) == "number" then
                state.deaths = data.deaths
            end
        end
        state.running = true
        state.finished = false
        state.startTime = GetTime()
        SendTimerAddonHeartbeat(true)
        RefreshAffixText()
        RefreshStats()
        ForceShowTrackerForRun()
    end

    -- Server stops the run: AIO.Handle(player, "MythicPlus", "StopRun", data)
    -- data = { completed = true/false }
    function MythicPlusHandlers.StopRun(player, data)
        local payload = (type(data) == "table") and data or {}
        local wasCompleted = payload.completed and true or false
        local wasExpired = payload.expired and true or false
        local isFinalized = (payload.finalized == false) and false or true

        if type(payload.deaths) == "number" then
            state.deaths = math.max(0, math.floor(payload.deaths + 0.5))
        end

        if wasExpired and not isFinalized then
            state.awaitingFinalBossAfterTimeout = true
            state.running = false
            state.finished = true
            state.serverControlled = true
            ResetRunSummary()
            ForceShowTrackerForRun()
            RefreshAffixText()
            RefreshStats()
            return
        end

        local hasSummaryData =
            type(payload.elapsed) == "number" or
            type(payload.timeTaken) == "number" or
            type(payload.rating) == "number" or
            type(payload.newRating) == "number" or
            type(payload.deaths) == "number"
        local shouldShowSummary = isFinalized and (wasCompleted or wasExpired or hasSummaryData)

        state.awaitingFinalBossAfterTimeout = false
        state.running = false
        state.finished = true
        state.serverControlled = false

        if shouldShowSummary then
            QueueRunSummary(payload)
            if wasCompleted then
                statTimer.label:SetText("Run Complete!")
            elseif wasExpired then
                statTimer.label:SetText("Time Ran Out")
            else
                statTimer.label:SetText("Run Ended")
            end
            ForceShowTrackerForRun()
        else
            ResetRunSummary()
            if wasExpired then
                statTimer.label:SetText("Time Expired")
            else
                statTimer.label:SetText("Run Ended")
            end
        end
        RefreshStats()
        RefreshAffixText()
    end

    -- Server shows the window
    function MythicPlusHandlers.Show(player)
        if MythicPlusDB then
            MythicPlusDB.visible = true
        end
        fadeState.active = false
        frame:Show()
        SetFrameOpacityFromConfig()
        if IsMythicModeActive() then
            state.idleSince = 0
        else
            state.idleSince = GetTime()
        end
        RefreshAffixText()
        RefreshStats()
    end

    -- Server hides the window
    function MythicPlusHandlers.Hide(player)
        HideTrackerWindow()
    end

    AIO.AddHandlers("MythicPlus", MythicPlusHandlers)
end
