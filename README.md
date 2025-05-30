# MythicPlus  
**Eluna script for Custom Mythic+ Difficulty, Tiered Rewards, and Weekly Affix Rotations**

## About This Script  
This is an advanced Mythic+ style Lua script tailored for *Wrath of the Lich King* heroic dungeons using the Eluna engine. It brings scalable challenge and reward mechanics inspired by retail WoW Mythic+ into a custom private server setting.

### Revamped Key System  
Mythic mode now operates through **three keystone tiers** (T1, T2, T3) instead of multiple affix combinations requiring separate keys. This means:
- Only 3 keystones are needed (one per tier).
- The script dynamically applies affix combinations based on tier.
- Affixes rotate weekly, creating a fresh challenge every reset.
- No more clutter of 20+ individual keystones.

### Affix Pool Expanded  
There are now 8 baseline affixes in the system:
- Enrage  
- Rejuvenating  
- Turtling  
- Shamanism  
- Magus  
- Priest Empowered  
- Demonism  
- Falling Stars  

Each week, 3 affixes are randomly selected:
- Tier 1: 1 affix  
- Tier 2: 2 affixes  
- Tier 3: 3 affixes  

Affixes can be easily edited or added by modifying the `WEEKLY_AFFIX_POOL` table in `Mythic.lua`.

### Tiered Rewards System  
Players earn Mythic Rating and Emblems based on key tier:
- Tier 1: Emblem of Conquest (ID 45624)  
- Tier 2: Emblem of Triumph (ID 47421)  
- Tier 3: Emblem of Frost (ID 49426)  

Rewards scale with performance and are tracked in a persistent rating system. Deaths during Mythic runs reduce rating slightly based on tier.

### Other Features  
- Buffs all mobs dynamically based on the affix combo  
- Final boss kill ends Mythic mode cleanly  
- Prevents re-use of keystone until dungeon is reset  
- Server-only logic (no client addons or AIO needed)  
- Easily extendable system for adding more affixes or rewards  

## Setup Instructions  

### SQL Setup  
- Run `KeystoneItems.sql` to install the updated 3-tier keystones.  
- **Important:** Delete any old keystone item entries as they are no longer used.

### Lua Setup  
- Place Lua scripts in your server’s script folder:  
  - `Mythic.lua` – core logic  
  - `MythicBosses.lua` – defines boss NPCs per dungeon  

- Ensure the path in `dofile(".../MythicBosses.lua")` matches your setup.

### Boss Configuration  
- Define your dungeons and boss entries in `MythicBosses.lua`:
  - Include map ID, list of boss NPC IDs, and designate the final boss.

### Customize Affixes  
- Edit `WEEKLY_AFFIX_POOL` in `Mythic.lua` to add or remove affixes.  
- Use the `AFFIX_COLOR_MAP` table to define display colors.

### Optional Config  
- Toggle weekly affix announcement on player login with a `true/false` flag.

## Notes  
- If you can’t import the SQL file, create an NPC with ID `900001` manually.  
- Items and spell IDs can be modified in the script or DB.  
- If you rename `MythicBosses.lua`, update the path in `dofile()`.

## Disclaimer  
This script is provided as-is. Make sure you understand the logic before making changes. Always back up your data.

## Credits  
**Doodihealz / Corey**  
Special thanks to the WoW Modding Community Discord for their guidance and support.
