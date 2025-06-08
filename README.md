# MythicPlus
**Eluna script for Custom Mythic+ Difficulty, Tiered Rewards, Timed runs, Ratings, and Weekly Affix Rotations**

**YOU MUST MANUALLY SET THE MYTHIC BOSS SCRIPT LOCATION. dofile("C:/Build/bin/RelWithDebInfo/lua_scripts/Generic/MythicPlus/MythicBosses.lua") PROBABLY WON'T WORK FOR YOU**

## About This Script
This is an advanced Mythic+ style Lua script tailored for *Wrath of the Lich King* heroic dungeons using the Eluna engine. It brings scalable challenge and reward mechanics inspired by retail WoW Mythic+ into a custom private server setting.

This version adds persistent dungeon state tracking via the `character_mythic_instance_state` table, allowing players to resume Mythic+ effects after re-entry. It also includes NPC whitelisting support, enabling specific creatures to receive buffs regardless of faction alignment.

Logs should autoclear after 24 hours and immediately if the mythic fails due to time running out.

---

## 🔑 Revamped Key System
Mythic mode now operates through **three keystone tiers** (T1, T2, T3) instead of multiple affix combinations requiring separate keys. This means:

- Only 3 keystones are needed (one per tier)
- The script dynamically applies affix combinations based on tier
- Affixes rotate on server reset, which helps keep the challenge exciting!
- No more clutter of 20+ individual keystones
- NEW `.mythicrating` command to display your current rating!
- Added a timer system based on deserter debuffs. If the debuff expires the mythic mode is marked as failed. It will persist through death. (15 minute and 30 minute timer used respectively)

---

## 🌪️ Affix Pool Expanded
There are now **8 baseline affixes** in the system:

- Enrage  
- Rejuvenating  
- Turtling  
- Shamanism  
- Magus  
- Priest Empowered  
- Demonism  
- Falling Stars

Each server restart, 3 affixes are randomly selected:

- **Tier 1**: 1 affix  
- **Tier 2**: 2 affixes  
- **Tier 3**: 3 affixes

> Affixes can be edited or expanded in the `WEEKLY_AFFIX_POOL` table in `Mythic.lua`.

---

## 🏅 Tiered Rewards System

Players earn Mythic Rating and Emblems based on key tier:

## 🎁 Reward Tiers

| Tier | Reward                          |
|------|----------------------------------|
| 1    | Emblem of Conquest (ID: 45624)  |
| 2    | Emblem of Triumph (ID: 47421)   |
| 3    | Emblem of Frost (ID: 49426)     |
| 4    | Emblem of Frost ×2 (ID: 49426)  |

---

## 📊 Rating Tiers

| Rating Range | Quality    | Corresponding Reward Tier |
|--------------|------------|----------------------------|
| 1–500        | Uncommon   | Tier 1                     |
| 501–1000     | Rare       | Tier 2                     |
| 1001–1800    | Epic       | Tier 3                     |
| 1801–2000    | Legendary  | Tier 4                     |

---

Should you fail Mythic mode by running out of time, all buffs present from any of the affixes will immediately be removed. You will lose half of whatever rating a completed key would give. That plays out as the following:

## ❌ Mythic Failure: Outcomes & Penalties

Should you **fail Mythic mode** by running out of time or losing your keystone aura, the following will occur:

- All affix-related buffs are removed from nearby enemies.
- Rating is deducted equal to **half of the points** that would have been gained for that tier.
- No rewards or new keystones will be granted.

### 🔻 Rating Penalty Chart

| Mythic Tier | Normal Rating Gain | Failure Penalty (−50%) |
|-------------|--------------------|-------------------------|
| Tier 1      | 20                 | -10                     |
| Tier 2      | 40                 | -20                     |
| Tier 3      | 60                 | -30                     |

> Rating never drops below 0, even if the penalty would exceed your current score.

---

## 🧮 Rating System Explained

The script includes a scoring system that tracks each character’s Mythic Rating. This system is stored in the database and updates automatically.

- **Starting Rating**: 0  
- **Rating Cap**: 2000  

### ✅ Rating Gains:
- Tier 1 Completion: +20  
- Tier 2 Completion: +40  
- Tier 3 Completion: +60  

### ❌ Rating Losses (on death):
- Tier 1: -3 per death  
- Tier 2: -6 per death  
- Tier 3: -9 per death  

Players receive tiered rewards as they hit milestones. Current rating is shown when a keystone is used and when a dungeon is completed.

---

## ⚙️ Other Features

- Buffs all mobs dynamically based on affix combo  
- Final boss kill ends Mythic mode and cleans up instance state  
- Supports persistent re-entry: buffs resume even after logout or wipe  
- Prevents re-use of keystone until dungeon is reset  
- Server-only logic (no AIO, addons, or patches required)  
- Clean, extendable code for adding more affixes or features  
- Global affix announcement on login (optional)  
- Automatic cleanup: stale instance data removed every hour after 24h

---

## 🧰 Setup Instructions

### 🗃️ SQL Setup

- `KeystoneItems.sql` → Adds 3-tier keystone items  
- `Character_Mythic_score.sql` → Adds player rating tracking table  
- `mythic_instance_state.sql` → Adds persistent instance state tracking table

> These should be executed on your **character database**.

---

### 🧠 Lua Setup

Place these files in your server's Lua script directory:

- `Mythic.lua` – Core system logic  
- `MythicBosses.lua` – Boss NPC IDs and final boss definitions  

Ensure the `dofile(".../MythicBosses.lua")` path is correct based on your directory structure.

---

### 🧟 Boss Configuration

In `MythicBosses.lua`, define each dungeon:

- `mapId`  
- A list of boss creature IDs  
- Which creature is the **final boss**

---

### 🎨 Customize Affixes

- Edit `WEEKLY_AFFIX_POOL` in `Mythic.lua` to add/remove affixes  
- Use `AFFIX_COLOR_MAP` to customize display colors  

---

### 🔧 Optional Config

- Toggle weekly affix announcement on player login with a true/false flag.

### 📝 Notes
- If you can’t import SQL files, manually create an NPC with entry 900001
- Items and spell IDs can be modified freely in the script or database
- If you rename MythicBosses.lua, update the path in dofile()

### ⚠️ Disclaimer
- This script is provided as-is. Always back up your server and database before applying changes. Modify with understanding.

### 👑 Credits
- Doodihealz / Corey
- Special thanks to the WoW Modding Community Discord for their ongoing support and feedback.

### ❕I'm open to reasonable and balanced suggestions❕
