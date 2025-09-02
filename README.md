I recommend checking out Huptiq's version of this mod too! https://github.com/huptiq/MythicPlus

# Mythic+ Eluna Script for WotLK Azerothcore

A full-featured, Mythic+ style challenge system for Eluna-based Wrath of the Lich King Azerothcore servers.  
Supports timed runs, weekly affixes, rating progression, loot chests, rating penalties, setting affixes, testing loot chests, and a custom keystone NPC.

---

## Setup Instructions

## SQL Setup

Run these SQL files on the **appropriate databases**:

| File Name                    | Purpose                                                | Target DB   |
|-----------------------------|--------------------------------------------------------|-------------|
| `Chestloot.sql`             | Defines item rewards for each Mythic+ tier chest       | world       |
| `Chests.sql`                | Adds chest **GameObjects** (not NPCs) by tier          | world       |
| `KeystoneDrops.sql`         | Configures keystone drops from the chests              | world       |
| `KeystoneItems.sql`         | Adds keystone items for Tier 1, 2, and 3               | world       |
| `Character_Mythic_score.sql`| Tracks player Mythic+ rating and run history           | character   |
| `mythic_instance_state.sql` | Stores persistent Mythic+ state across sessions        | character   |

### 2. Lua Scripts
Place in your server’s Lua scripts folder:
- `Mythic.lua` (this file)
- `MythicBosses.lua` (define dungeon maps, boss IDs, and final boss)

Make sure your `dofile()` points to the correct location:
```lua
dofile(".../MythicBosses.lua")
```

### 3. Keystone NPC (Manual or SQL)
- **NPC Entry**: `900001`
- **Name**: Mythic Advisor  
- **Subname**: The Keystone Exchanger  
- **Display ID**: `14888`  
- **IconName**: `Speak`

---

## Weekly Affix System

Affixes rotate each server restart:

| Tier | Affixes Active |
|------|----------------|
| 1    | 1 Affix        |
| 2    | 2 Affixes      |
| 3    | 3 Affixes      |

Edit `WEEKLY_AFFIX_POOL` to modify or expand the affix set.  
Buffs are applied dynamically to all eligible enemy creatures.

### Affix Tiering System

Affixes are split into three distinct **difficulty tiers**. One affix from each tier is randomly selected at server start:

| Affix Tier | Description                                      |
|------------|--------------------------------------------------|
| Tier 1     | Low-impact buffs (healing, regen, weak damage or defense)      |
| Tier 2     | Moderate-impact mechanics (high defense or slightly bursty)       |
| Tier 3     | High-impact effects (Hard hitting, Massive hostile npc damage output buff) |

When Mythic+ is activated:

- **Tier 1 keys** apply a Tier 1 affix  
- **Tier 2 keys** apply Tier 1 + Tier 2 affixes  
- **Tier 3 keys** apply all three tiers of affixes  

> Each week's affix set is randomly selected — 1 per tier — from the defined `WEEKLY_AFFIX_POOL`.

### Affix Tier Table

| Tier | Affix Name         |
|------|--------------------|
| 1    | Rejuvenating       |
| 1    | Demonism           |
| 1    | Resistant          |
|------|--------------------|
| 2    | Turtling           |
| 2    | Priest Empowered   |
| 2    | Falling Stars      |
|------|--------------------|
| 3    | Enrage             |
| 3    | Rallying           |
| 3    | Consecrated        |

---

## Keystone Tiers

| Tier | Keystone Item ID | Affix Count |
|------|------------------|-------------|
| 1    | 900100           | 1           |
| 2    | 900101           | 2           |
| 3    | 900102           | 3           |

Mythic+ is initiated by using a keystone at the NPC.  
Buffs and effects persist through relogs and re-entries.
Some maps have more time than others. It was changed through testing.
Timers are always 15 minute or 30 minutes. Never more never less.

---

## Reward System

| Tier | Reward                            |
|------|-----------------------------------|
| 1    | Emblem of Conquest ×1 (45624)     |
| 2    | Emblem of Triumph ×1 (47421)      |
| 3    | Emblem of Frost ×1 (49426)        |
| 4    | Emblem of Frost ×2 (49426)        |

Players receive their next-tier keystone **from the chest** (T1 → T2, T2 → T3).
There's a Horde and Alliance version of the Tier 2 chest (Because ToC loot is faction bound 😒)

---

## Mythic Rating System

- **Starts at**: 0  
- **Caps at**: 2000
- **Progression**:
  - Tier 1: +20 rating
  - Tier 2: +40 rating
  - Tier 3: +60 rating

### Penalties

| Tier | On Death (per) | On Fail (Timeout) |
|------|----------------|-------------------|
| 1    | −3             | −10               |
| 2    | −6             | −20               |
| 3    | −9             | −30               |

Rating can’t fall below 0.  
No rewards if the timer expires. All buffs are removed.

---

## Mythic Chest Loot

- A chest spawns near the final boss upon completion
- Chest tier matches the completed key level:
  - T1: `900010`
  - T2: `900011`
  - T3: `900012`
- Approx. **25 custom loot items per tier**
- **Tier 3 chests** have a **1% chance** to drop **Invincible's Reins (ID: 50818)**

---

## Commands

### Player Commands

| Command         | Description                                |
|-----------------|--------------------------------------------|
| `.mythicrating` | Show current Mythic Rating & run count     |
| `.mythichelp`   | Displays list of Mythic+ commands          |
| `.mythicaffix`  | Displays the current Mythic+ affixes       |

### GM-Only

| Command                  | Description                                |
|--------------------------|--------------------------------------------|
| `.mythicreset`           | Initiate global rating reset (confirmation required) |
| `.mythicreset confirm`   | Confirm global rating reset within 30s     |
| `.mythicroll all`        | Rerolls all current affixes     |
| `.mythicroll tier <1-3>` | Reroll a specific tier     |
| `.mythicroll tier <1-3> <affix>`   | Set a specific affix (e.g., resistant)     |
| `.sim tier <1-3>`   | Spawn a Tier chest without awarding rating or tokens     |
| `.simclean`   | Remove nearby sim-spawned chests (default radius 80)|

---

## Internal Features

- Buffs hostile mobs based on affix set
- Auto-detects kill activity and locks keystone use until reset
- Saves persistent Mythic+ state for each player+instance
- Handles aura removal on failure or wipe
- Rating table is updated on boss kill or fail
- Resumes affix logic on re-login or zone-in
- Global affix announcement on login (toggleable)
- Death counter and timeout logic included
- Logs auto-clean up every hour (after 24h)
- The NPC keystone master will have different responses upon starting mythic mode based on your current rating.

---

## Customization Tips

-  **Add Affixes**: Edit `WEEKLY_AFFIX_POOL`
-  **Color Coding**: Modify `AFFIX_COLOR_MAP`
-  **Whitelist NPCs**: Add by creature ID or name
-  **Change Key IDs**: Update `KEY_IDS` in Lua
-  **Chest IDs**: Change via `CHEST_ENTRIES` table
-  **Invincible Drop**: Defined in chest loot logic (Tier 3, 1% drop)

---

## Credits

- **Doodihealz / Corey**
- With support from the WoW Modding Community Discord
