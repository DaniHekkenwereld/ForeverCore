# ForeverCore

A small, experimental Warrior-focused UI addon for **World of Warcraft: Forever (beta)**. Built for Protection/Fury/Arms Warriors and intended to keep common raid preparation checks in one place.

> **Beta prototype:** The addon has not yet been validated in the live WoW Forever beta client. API behavior, TOC version and macro conditions may change. No combat automation is provided.

## Included in v0.2.0-beta

- Attempt to enable default friendly nameplates automatically in raid instances (`/fc plates auto`). This depends on Blizzard restrictions and client CVar support.
- Movable pre-pull status panel.
- Out-of-combat checks for a flask buff, food buff and Battle Shout, plus a shield/stance check for the tank profile.
- Manually switch between tank, Fury, and Arms profiles.
- Raid debuff display: **Sunder Armor** stacks (up to 5), **Demoralizing Shout**, **Thunder Clap** on your hostile target. If combat auras are secret, status is unknown (`?`), never falsely marked missing.
- **Taunt feedback:** warns on a spellcast failure event if the client supplies it and reminds you to verify the boss target when you cast Taunt; **resist/miss cannot be proven** without the combat log.
- Separate drag-and-edit opener macro panel with **4 per spec**, **12 total** (ST threat, AoE threat, ST DPS, AoE DPS), created only when dragged so existing macro slots are not consumed unnecessarily.
- Generate 15 character-specific Warrior macros without overwriting existing ones. Combo macros are **manual**, with modifier keys for each cooldown.

## Installation

1. Exit WoW.
2. Copy the **contents of this repository** into your addon directory under a folder named `ForeverCore`, such as:

   ```text
   World of Warcraft\_classic_beta_\Interface\AddOns\ForeverCore\
     ForeverCore_Camelot.toc
     Core.lua
     RaidWarnings.lua
     Openers.lua
   ```

   The client installation directory can differ. The `.toc` file must sit directly in `AddOns\ForeverCore\`.
3. Launch WoW Forever, enable **ForeverCore** on the AddOns screen and run `/fc help`.

## Commands

| Command | Effect |
| --- | --- |
| `/fc help` | Show available commands |
| `/fc check` | Run the pre-pull check again (out of combat) |
| `/fc move` | Drag the status panel (out of combat) |
| `/fc show on` or `/fc show off` | Show/hide the panel outside raid instances |
| `/fc plates auto` | Try to show friendly nameplates in raid instances only |
| `/fc plates on` or `/fc plates off` | Try to force friendly nameplates on or off |
| `/fc mode tank`, `/fc mode fury`, or `/fc mode arms` | Set the Warrior profile manually |
| `/fc flask on/off` | Toggle flask check |
| `/fc food on/off` | Toggle food check |
| `/fc shout on/off` | Toggle Battle Shout check |
| `/fc macros` | Create the 15 original character-specific Warrior macros |
| `/fc openers` | Open draggable/editable macros for Protection, Fury and Arms |
| `/fc openers prot` / `fury` / `arms` | Open the macro window on a specific specialization tab |
| `/fc alerts on/off` | Toggle the target debuff status panel during raids |
| `/fc taunt on/off` | Toggle Taunt cast and cast-failure notices in raids |

To use new macros, open `/macro` and drag them to your action bars.

### Combo macro behavior

- `FC-ReckRet`: normal press = Recklessness; Shift = Retaliation.
- `FC-ReckWall`: normal press = Recklessness; Shift = Shield Wall.
- `FC-All3`: normal = Recklessness; Shift = Retaliation; Ctrl = Shield Wall.

**Important:** Stance changes may require a second button press. Shield Wall requires a shield. These macros must be tested against the current Forever beta class design; none casts multiple combat cooldowns automatically.

## Draggable opener macros (v0.2)

Open `/fc openers`. Select **Protection / Fury / Arms**, then choose any of the 4 rows:

- **ST threat**: practical high-threat buttons for a single enemy.
- **AoE threat**: Thunder Clap as the main multi-target tool, with Demo Shout and Cleave on modifiers.
- **ST DPS**: primary spec attack, with procs/Execute/Rend on modifiers where relevant.
- **AoE DPS**: appropriate AoE attacks and manual rage dumps.

**Left-click or drag** a row's `Drag: opener` button to pick up the macro on your cursor, then drop it on an action bar. **Right-click** the same button or choose **Edit** to change its exact text inside ForeverCore (up to 255 characters). Existing macros are never automatically overwritten when you drag them again. Edits saved in the ForeverCore editor update the existing macro, if present. You can alternatively use `/macro`.

The first time you drag each opener, ForeverCore creates a macro. It tries a character-specific macro slot first and an account-wide slot if the character-specific limit has been reached. The original 15 macros from `/fc macros` are unchanged. Opener names use `FC-P-*` (Prot), `FC-F-*` (Fury), or `FC-A-*` (Arms). It never deletes your macros.

### Opener logic

The pane describes the *recommended manual opening order* above every macro. The normal press uses the primary ability, and **Shift / Ctrl / Alt** choose secondary abilities where specified. It deliberately does **not** use `/castsequence` for procs such as Revenge or dynamic priorities, because a failed proc/cooldown/rage check would stall a sequence. A WoW macro cannot choose a mathematically optimal attack in combat. Keep stances, talent choices, rage and situation in mind. Arms and Fury threat variants are emergency tank openers, not replacements for a Protection build.

Examples of beta-era priorities to evaluate in raids:

| Spec | ST threat | AoE threat | ST DPS | AoE DPS |
| --- | --- | --- | --- | --- |
| Protection | Shield Slam > Revenge proc > Sunder | Thunder Clap > tab Revenge/Shield Slam > Cleave (spare rage) | Shield Slam > Revenge | Thunder Clap > Cleave (spare rage) |
| Fury | Defensive Stance, Bloodthirst > Revenge proc > Sunder | Defensive Stance, Thunder Clap > tab Sunder/Revenge | Bloodthirst > Whirlwind > rage dump | Whirlwind > Cleave (spare rage) |
| Arms | Defensive Stance, Mortal Strike > Revenge proc > Sunder | Defensive Stance, Thunder Clap > tab Sunder/Revenge | Mortal Strike > Rend / Overpower proc | Sweeping Strikes > Cleave / Mortal Strike |

Check the associated talents and stance requirements. This table is a **prototype for testing**, not a measured max-TPS or max-DPS ranking: encounters, beta tuning and procs change the best opener.

## Raid debuffs and Taunt

With `/fc alerts on`, a compact panel shows the Sunder stack count, Demo and Thunder Clap state for your selected hostile target **inside a raid**. It only reports missing debuffs when the aura scan is readable; values hidden by Forever return `?` or an unavailable message.

With `/fc taunt on`, a `UNIT_SPELLCAST_FAILED` event for your own Taunt shows **TAUNT CAST FAILED - CHECK TARGET**, and a succeeded cast shows **TAUNT USED - VERIFY TARGET**. The second text is a *reminder*, not confirmation that Taunt landed. **A Taunt RESIST or IMMUNE outcome cannot be attributed reliably from the normal combat log**, which Forever does not expose to addons. Neither this module nor the opener macros try to bypass protected combat data.

## Known limitations

- Addons cannot reliably compare protected/secret boss target data in some combat contexts. A reliable **boss targets me** alert has **not** been implemented in v0.1. Use Blizzard's target-of-target UI where supported.
- Friendly raid nameplates are restricted by Blizzard. A CVar request can be rejected or ignored, and the addon does not customize Blizzard friendly nameplates.
- Consumables are checked outside combat only; flask/food identification currently relies on English/Dutch buff-name matching. Custom Forever buffs may need explicit matching.
- SavedVariables persistence and client interface version need confirmation in the actual beta.
- A full cooldown HUD, full threat UI, encounter-specific warnings and complete options panel are not included yet.
- Raid debuffs might be partially/completely protected in combat, depending on beta API conditions.
- The Taunt notifier cannot reliably report the result of a resist/miss; see the section above.
- In-game testing and 12-macro button dragging still need validation on the current beta build.

## Roadmap

1. In-game API smoke test of v0.2, including buttons, combat restrictions and event payloads.
2. Validate boss debuff visibility and Taunt event coverage; keep unreadable combat information explicitly unknown.
3. Better pre-pull aura detection, including Forever-specific buffs.
4. Protection/Fury/Arms HUD for cooldowns, rage and defensive readiness, subject to beta API limits.
5. Movable configuration UI and modules.
6. Encounter-specific warnings and safer boss target signals when supported by the addon API.

## Disclaimer

Unofficial community project; not affiliated with Blizzard Entertainment. The addon uses supported Lua addon interfaces and does not attempt protected combat actions or gameplay automation.