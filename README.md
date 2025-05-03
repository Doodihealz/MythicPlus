# MythicPlus
Eluna script for "Custom" difficulty and rewards

About This Script
-----------------
This is a Mythic+ style Lua script designed for Wrath of the Lich King heroic dungeons using the Eluna engine. 
Players use custom keystone items to activate enhanced difficulty within a dungeon, applying buffs to all NPCs 
inside the instance. Each keystone can apply one or more effects (such as Enrage, Rejuvenation, etc.), and bosses may 
offer a chance at special reward items.

This script is modular and can be customized to add more keystones, effects, or dungeons.

Features
--------
- Buffs mobs in Wrath of the Lich King heroic dungeons
- Keystone system with affix combinations and multiple tiers
- Bosses can drop custom reward items based on keystone tier
- Final boss kill ends Mythic mode and cleans up flags
- Runs entirely through Eluna scripting
- Script will auto stop if player leaves the instance
- Script will not accept another key once one is used until dungeon is reset or .reload eluna command is used

Setup Instructions
------------------
1. Import the provided SQL files to add:
   - Keystone items
   - Mythic pedestal NPC

2. Place the Lua scripts in your server's `Scripts` directory. Make sure to have both files named:
   - Mythic.lua (main logic)
   - MythicBosses.lua (dungeon + boss definitions)

3. Edit `MythicBosses.lua` to define any additional dungeons:
   - Include each dungeon's map ID and a list of boss NPC IDs
   - Mark the final boss for proper Mythic mode cleanup

4. Customize affixes or item rewards as needed inside the Lua files.

-NOTES- 
- If SQL files won't copy, just make an npc id 900001, name it whatever, and make sure you're able to speak to it. The script will do the rest.
- The item ids can be adjusted in the script or adjusted in your database. Whichever you prefer.
- dofile("Scripts/MythicPlus/MythicBosses.lua") will look for the file of bosses named MythicBosses. So if you rename that file be sure to edit the script code otherwise bosses won't give special rewards!

Disclaimer
----------
This script is provided as-is. If you modify or extend it without understanding the logic, 
support may not be available.

Credits
-------
Doodihealz/Corey

Special thanks to the WoW Modding Community Discord. You guys are awesome with helping noobs like me out!
