# ForeverCore

A small, experimental Warrior-focused UI addon for **World of Warcraft: Forever (beta)**. Built for Protection/Fury/Arms Warriors and intended to keep common raid preparation checks in one place.

> **Beta prototype:** The addon has not yet been validated in the live WoW Forever beta client. API behavior, TOC version and macro conditions may change. No combat automation is provided.

## Included in v0.3.15-beta

- **New-character action bars:** enable Bottom Left, Bottom Right, Right 1 and Right 2, including empty buttons, once per character. Use `/reload` to show the bars. Previously configured characters are unchanged.
- Attempt to enable default friendly nameplates automatically in raid instances (`/fc plates auto`). This depends on Blizzard restrictions and client CVar support.
- **Cooldown numbers enabled** on action buttons and **Blizzard's Cooldown Manager enabled**, using the verified client CVars `countdownForCooldowns=1` and `cooldownViewerEnabled=1` (normal CVar restrictions apply).
- **Bartender4 optional initialization:** for each character, if Bartender4 is installed, set Blizzard Art **off** and **padding 0** on Bartender actionbars. Leave scale, positions, alpha, number of rows, visibility and keybindings untouched. All Bartender UI changes are deferred until outside combat.
- **One-time chat tabs on each character:** `Party` for Guild, Party, Raid (including leader and raid warnings); `Whispers` for WoW and Battle.net whispers only. No Battle Shout / pre-pull reminder remains.
- Manually switch between tank, Fury, and Arms profiles.
- Raid debuff display: **Sunder Armor** stacks (up to 5), **Demoralizing Shout**, **Thunder Clap** on your hostile target. If combat auras are secret, status is unknown (`?`), never falsely marked missing.
- **Taunt feedback:** warns on a spellcast failure event if the client supplies it and reminds you to verify the boss target when you cast Taunt; **resist/miss cannot be proven** without the combat log.
- Separate drag-and-edit burst opener macro panel with **4 per spec**, **12 total** (ST threat, AoE threat, ST DPS, AoE DPS), created only when dragged so existing macro slots are not consumed unnecessarily.
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
     Recorder.lua
     AccountSetup.lua
     ChatSetup.lua
   ```

   The client installation directory can differ. The `.toc` file must sit directly in `AddOns\ForeverCore\`.
3. Launch WoW Forever, enable **ForeverCore** on the AddOns screen and run `/fc help`.

## Fresh-character keybinds (v0.3.13) — mirrored 4-layer layout

The old v0.3.5 layout was hard to memorize. The **new default uses the same 12 key positions across modifier rows**, but leaves plain X unbound on the main actionbar to preserve Sit/Move Down. The first login of any character (regardless of name or class) applies **47 actionbar bindings plus X = Sit/Move Down**, *without* requiring a main character or using `/fc setup capture`.

| Row | Blizzard bar | Modifier | Twelve buttons, left to right |
| --- | --- | --- | --- |
| 1 | Main | None | `1` `2` `3` `4` `Q` `E` `R` `F` `Z` **(slot 10 unbound)** `C` `V` |
| 2 | Bottom Left | Shift | `Shift+1` `Shift+2` `Shift+3` `Shift+4` `Shift+Q` `Shift+E` `Shift+R` `Shift+F` `Shift+Z` `Shift+X` `Shift+C` `Shift+V` |
| 3 | Bottom Right | Alt | `Alt+1` `Alt+2` `Alt+3` `Alt+4` `Alt+Q` `Alt+E` `Alt+R` `Alt+F` `Alt+Z` `Alt+X` `Alt+C` `Alt+V` |
| 4 | Right | Alt+Shift | `Alt+Shift+1` `Alt+Shift+2` `Alt+Shift+3` `Alt+Shift+4` `Alt+Shift+Q` `Alt+Shift+E` `Alt+Shift+R` `Alt+Shift+F` `Alt+Shift+Z` `Alt+Shift+X` `Alt+Shift+C` `Alt+Shift+V` |

**X is Sit/Move Down** on all newly configured characters. **Shift+X, Alt+X and Alt+Shift+X remain active** on the other three bars. On an existing character with a previous ForeverCore layout, the update only restores X if it is still bound to the old `ACTIONBUTTON10`; **all other manually adjusted keybinds remain untouched**. On subsequent logins there is no re-import. Custom captured profiles still take precedence.

**Example:** `R` is row 1 / slot 7, `Shift+R` row 2 / slot 7, `Alt+R` row 3 / slot 7 and `Alt+Shift+R` row 4 / slot 7. The game bars remain visually where Blizzard puts them; the **Right** bar is normally vertical. ForeverCore binds slots, not UI placement or ability assignment.

The base keys were chosen near WASD but deliberately avoid **W/A/S/D (movement)**, G (dedicated Berserker Stance), Tab, Space and the dedicated mouse controls. Assigning Q and E to abilities will replace WoW's default strafe-left / strafe-right on those keys; A/D can still be used for strafing if configured. Shift+Alt can also conflict with a Windows language-switch shortcut; turn off or change that OS shortcut if the combination switches layouts.

### Warrior keybinds stay fixed

| Input | Action |
| --- | --- |
| Mouse thumb `BUTTON4` | Battle Stance |
| Mouse thumb `BUTTON5` | Defensive Stance |
| `G` | Berserker Stance |
| Middle mouse `BUTTON3` | Taunt |
| Mousewheel down | Heroic Strike |
| Mousewheel up | Cleave |

No Warrior mouse or stance binding overlaps the 48 actionbar keys. Other classes receive the same 48 actionbar binds but not Warrior-specific abilities.

### Migrating and controlling the layout

The preset revision is bumped, so v0.3.4 and v0.3.5 characters automatically receive the new layout on their next login. Known **old default keybinds** are removed only when the character had the earlier ForeverCore preset and those keys still perform their exact old actions; keys manually repurposed since then are preserved. Backups of previous bindings remain available.

- `/fc setup layout` shows the four rows.
- `/fc setup apply` applies the current layout manually (out of combat).
- `/fc setup restore` restores the pre-import bindings on that character and opts it out of auto-import.
- `/fc setup capture` optionally saves your own full custom profile. A captured profile takes priority over the built-in layout.
- `/fc setup bindings on/off` and `/fc setup settings on/off` toggle these automatic behaviors.

Automatic settings remain: auto loot and nameplates/range where the beta API permits them. **On new characters only**, ForeverCore also records all four default extra Blizzard action bars as enabled using the eight-argument API, including the always-show flag. It never forces an immediate protected-frame refresh: use `/reload` after the initial login. Characters already initialized by an earlier ForeverCore version keep their existing actionbar settings and can adjust them in Options > Action Bars.

**Fixed after first in-game screenshot:** Old Blizzard keys (such as `5` for main-bar slot 5) could remain attached as a second binding alongside the new preset key (`Q`). The preset now removes extra bindings from its 48 target actionbar slots before assigning one key per slot. Existing backups remain available with `/fc setup restore`. The pre-pull panel also no longer demands Defensive Stance of an under-level-10 Warrior; spell-known APIs are consulted on higher-level characters where available.

**Beta caveat:** these mappings and saved-binding APIs still need validation on the actual WoW Forever client. Alt+Shift and side mouse button reporting are especially worth checking on launch.

## Commands and behavior

- `/fc setup layout`: display the four key groups and Warrior exceptions.
- `/fc setup status`: inspect the applied settings.
- `/fc setup apply`: reapply the current preset outside combat.
- `/fc setup restore`: restore the saved bindings for this character and prevent subsequent auto-import until explicitly reapplied.
- `/fc setup capture`: optionally save a custom full-profile set after you have configured a character; **it overrides** the built-in preset on future logins.
- `/fc setup bindings on/off`, `/fc setup settings on/off`, `/fc setup bars on/off`: manage the automatic behavior.

The addon binds keys to actionbar button **slots**; it does not assign spells to those slots, move bars or copy talents. Everything is applied outside combat, and actual API support must still be verified in the Forever client.

### Automatic game settings (all characters)

| Setting | Requested value |
| --- | --- |
| Auto loot | On |
| Numeric actionbar cooldown timers | On |
| Blizzard Cooldown Manager | On |
| Friendly and enemy nameplates | On where supported |
| Always show nameplates | On |
| Nameplate range | Request 60 yards (server cap may be lower) |
| Player outline (Outline Mode) | On / High (`Outline=2`, renderer `graphicsOutlineMode=2` when accessible) |
| Player self-highlight | Always enabled with outline (`findYourselfAnywhere=1`, `findYourselfModeOutline=1`) |
| Bottom Left, Bottom Right, Right 1 and Right 2 | **On, once per new character**; existing characters unchanged; `/reload` to display |

## New self-outline defaults (v0.3.13)

On login, ForeverCore requests the game's **Outline Mode** and **always-on self highlight (yellow player outline)**. These use documented settings from the Forever options system. The renderer-related `graphicsOutlineMode` value is requested when readable through the normal CVar API; not every Forever build exposes every graphics CVar to addons. If an API refuses a setting, use WoW Options to enable it manually. No secured actionbar or Edit Mode writes have been reintroduced. Check actual results using `/fc setup status`.

## Cooldown numbers, Cooldown Manager and Bartender4 (v0.3.14)

On login, ForeverCore requests these built-in Blizzard client settings:

| Feature | CVar | Requested value |
| --- | --- | --- |
| Numeric cooldown timer on actionbar icons | `countdownForCooldowns` | `1` |
| Blizzard Cooldown Manager | `cooldownViewerEnabled` | `1` |

The native Cooldown Manager is controlled by Blizzard. You can rearrange it in Edit Mode and configure tracked spells using `/cdm`. Some Forever client builds may restrict addon CVar writes; `/fc setup status` reports the actual readback.

**If Bartender4 is installed**, the new `BartenderSetup.lua` module obtains the live Bartender4 AceAddon configuration and sets the **Blizzard Art module disabled** and **each available actionbar's padding to 0**. Scale, dimensions, placements, visibility, enabled bars, keybinds, and fade settings remain unchanged. The change runs **once per character**, outside combat. Bartender4 is an optional dependency; nothing is modified if it is absent. Use `/fc bartender status` to inspect or `/fc bartender apply` for an explicit reapply if you switch profiles.

**Important:** Bartender4 maintains its own action buttons, and its keybinding behavior may differ from Blizzard's default bars. In particular, Bartender's documentation says extra bars may require its own KeyBound binding setup via `/kb`. Our default Blizzard actionbar keybinds must be checked after installing Bartender4. Do not assume all 47 additional binds will transfer automatically.

This Bartender feature does **not** change Blizzard actionbar visibility. Version 0.3.15 separately sets the four Blizzard extra bars **once on a new character only**, without calling protected UI refresh functions.

## Actionbar combat safety (v0.3.11; historical behavior)

Screenshots from an actual Forever beta client showed the extra lower actionbar disappearing in combat alongside a Blizzard **interface action blocked by an addon** notice. This is not conclusive proof ForeverCore caused the blocked action, but the previously used `SetActionBarToggles` and `Settings.SetValue` calls were unsafe and have been removed entirely from automatic login/zone behavior. The earlier `SetActionBarToggles` call passed seven values, omitting the optional eighth `alwaysShow` argument. The native API persists values for the next load, not immediate visibility.

**How to recover:** first try `/fc setup bars off` followed by `/reload` on the old installed build. After installing v0.3.11, use WoW's **Options > Action Bars** to enable Bottom Left, Bottom Right, Right 1, and Right 2 manually. If empty slots disappear, try `/console alwaysShowActionBars 1` (outside combat) and `/reload`. The addon did not edit actionbar visibility in versions 0.3.11–0.3.14. Since 0.3.15 it applies the initial setup **only to new characters** with the full eight-argument API, still without protected live UI updates. `/fc setup bars on/off` remains informational; existing characters must use WoW Options.

Existing **48 keybind slots, character-specific backups, auto loot and the Battle Shout icon** remain unchanged. Nameplate-CVar writes from Core now stop after one failed attempt per session rather than retrying on every event. If combat problems persist with ForeverCore disabled, the issue needs diagnosis outside this module as well.

## Automatically create Party and Whispers chat tabs (v0.3.12)

On a character's first login, ForeverCore creates **two ordinary Blizzard chat window tabs**. It does **not** join or create a custom numbered chat channel.

| Tab name | Messages shown |
| --- | --- |
| **Party** | `PARTY`, `PARTY_LEADER`, `RAID`, `RAID_LEADER`, `RAID_WARNING`, `GUILD` |
| **Whispers** | `WHISPER` (incoming and outgoing private messages) and `BN_WHISPER` (Battle.net whispers); no other message types or numbered channels |

The new windows start without Blizzard's default SAY, YELL, SYSTEM, or public CHANNEL groups. They appear in the ordinary chat dock. Existing named tabs are left alone, rather than overwritten. A completed installation is recorded under the character's unique GUID in account SavedVariables. **No windows are recreated at subsequent logins, reloads, or addon updates**. The regular General and Combat Log tabs are untouched.

Use `/fc chat status` to see whether this character is configured. If chat UI creation was unavailable on initial login, `/fc chat setup` retries missing tabs outside combat; the addon will report a failure rather than silently altering an existing tab. Chat API behavior still needs live WoW Forever validation.

The Battle Shout reminder UI, pre-pull check and `/fc move` controls have been **removed entirely**. Use your own WeakAura for Battle Shout monitoring. Warrior keybinds, account setup, raid debuffs, Taunt warnings, macros and the gameplay recorder are unchanged.


## Commands

| Command | Effect |
| --- | --- |
| `/fc help` | Show available commands |
| `/fc chat status` | Show whether Party/Whispers tabs have already been set up on this character |
| `/fc chat setup` | Create missing Party/Whispers tabs, once per character |
| `/fc bartender status` | Display Bartender integration setup status |
| `/fc bartender apply` | Reapply Blizzard Art off and all actionbar padding zero outside combat |
| `/fc setup` | Show account setup commands |
| `/fc setup layout` | Show four mirrored layers (none, Shift, Alt, Alt+Shift) |
| `/fc setup capture` | Optionally capture a full custom keybind profile; not required initially |
| `/fc setup status` | Show whether profile / client options are active |
| `/fc plates auto` | Try to show friendly nameplates in raid instances only |
| `/fc plates on` or `/fc plates off` | Try to force friendly nameplates on or off |
| `/fc mode tank`, `/fc mode fury`, or `/fc mode arms` | Set the Warrior profile manually |
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

## Draggable burst opener macros (v0.2.1 beta)

Use `/fc openers` for **12 editable, draggable burst openers**: ST threat, AoE threat, ST DPS and AoE DPS for Protection, Fury and Arms. These are now **cooldown-combination openers**, NOT a claim that one attack button is the full opener.

**Important:** A WoW macro cannot automatically progress through every cooldown and stance based on combat state. The opener macros require deliberate modifier presses, and stance changes may take an additional press. Do not spam modifiers blindly. In the addon, left-click/drag to pick up the macro and drop it on an action bar; right-click or Edit to customize it (255-character limit). `/macro` also works.

### All-in threat setup

For **Protection and Arms ST threat**, use Shift = **Retaliation** (Battle Stance), Ctrl = **Recklessness** (Berserker Stance), Alt = **Bloodrage**, and normal = return to **Defensive Stance** and use Shield Slam (Protection) or Mortal Strike (Arms). The AoE versions instead finish on **Thunder Clap**. Arms AoE has Alt = **Sweeping Strikes**, not Bloodrage.

For **Fury ST / AoE threat**, use Alt = **Death Wish**, Shift = Retaliation, Ctrl = Recklessness, and normal = Defensive Stance + **Bloodthirst** (ST) or **Thunder Clap** (AoE). **Death Wish is Fury-talented**, so it is not added to other specs by default.

Retaliation only counterattacks if targets attack you **from the front**. Using it without incoming melee attacks generates no retaliation hits. Recklessness boosts crit for 15 seconds but increases damage taken; Death Wish also increases damage taken. These all-in setups are risky on progression bosses and are **not proven highest-TPS builds**. They should be validated against beta logs and encounter mechanics before raid use. Defensive Stance has a threat multiplier in Forever; the default part of threat openers returns to it. **Shield Wall is a survival cooldown, not a threat-generating opener**.

### DPS burst

- **Protection ST/AoE:** Ctrl Recklessness, Alt Bloodrage, then Shield Slam / Thunder Clap. AoE also offers Shift Retaliation only if you're the one tanking.
- **Fury ST/AoE:** Alt Death Wish, Ctrl Recklessness, then Bloodthirst / Whirlwind in Berserker Stance. Shift is a manual Heroic Strike / Cleave rage dump.
- **Arms ST:** Ctrl Recklessness, Alt Bloodrage, then Mortal Strike (Shift = Overpower if proc available).
- **Arms AoE:** Alt Sweeping Strikes in Battle Stance, Ctrl Recklessness in Berserker Stance, then Whirlwind (Shift = Cleave).

### Updating macros created with v0.2.0

Previously created `FC-P-*`, `FC-F-*`, or `FC-A-*` macros **are not automatically overwritten**, to preserve user changes. To replace their ability-only text with the new burst template, use `/fc openers`, select a row, then **Edit > Default > Save**. On first drag, macros that do not yet exist use the latest burst template.

The original 15 `/fc macros` shortcuts remain unchanged. Opener macros occupy character-specific or account macro slots as available. No automatic rotation or prohibited combat API access is used.

## Raid debuffs and Taunt

With `/fc alerts on`, a compact panel shows the Sunder stack count, Demo and Thunder Clap state for your selected hostile target **inside a raid**. It only reports missing debuffs when the aura scan is readable; values hidden by Forever return `?` or an unavailable message.

With `/fc taunt on`, a `UNIT_SPELLCAST_FAILED` event for your own Taunt shows **TAUNT CAST FAILED - CHECK TARGET**, and a succeeded cast shows **TAUNT USED - VERIFY TARGET**. The second text is a *reminder*, not confirmation that Taunt landed. **A Taunt RESIST or IMMUNE outcome cannot be attributed reliably from the normal combat log**, which Forever does not expose to addons. Neither this module nor the opener macros try to bypass protected combat data.


## Passive gameplay recorder (v0.3.0 beta)

**Designed for levelling:** no new window; both types of logging are **on by default**. The addon does not submit or upload any data.

There are **two separate layers**:

1. **ForeverCore gameplay history** (local SavedVariables): timestamped personal spellcast starts/success/failures, Rage snapshots when safely readable, stance changes, combat start/stop, deaths, levels/XP, accepted/completed quests, equipment snapshots, NPC IDs when available, zone changes, and non-combat map-position checkpoints approximately every 30 seconds. It does **not** store other players' names. Data hidden by the Forever combat API are skipped instead of guessed.
2. **Blizzard's native combat log:** ForeverCore attempts to enable `LoggingCombat(true)` when entering the world, with a few bounded retries. This instructs the WoW client to write its own combat file. A successful request does **not** grant addons access to the restricted combat-log event stream. If Forever refuses the request, `/fc record status` shows that rather than falsely claiming logging is working.

You may enable **Advanced Combat Logging** in WoW System > Network for more detail when supported by the client.

### Commands

| Command | Effect |
| --- | --- |
| `/fc record` or `/fc record status` | Show recording state, session/record counts and file locations |
| `/fc record summary` | Quick counts of your own casts, failures, stance swaps, deaths, completed quests and combat time (retained events only) |
| `/fc record on` / `/fc record off` | Start/stop ForeverCore SavedVariables recording |
| `/fc record native on` / `/fc record native off` | Enable/disable automatic attempts to start Blizzard combat logging. Off does **not** shut down an existing log owned by you/another addon |
| `/fc combatlog on` / `/fc combatlog off` | Short alias for the two native options above |
| `/fc mark boss practise` | Add a manual note/marker to the gameplay history |

### Where to get data for analysis

After **logout** or **`/reload`**, find:

- `World of Warcraft/_classic_beta_/WTF/Account/<account>/SavedVariables/ForeverCore.lua` — ForeverCore recording, all characters sharing this addon installation (session data contains no character name).
- `World of Warcraft/_classic_beta_/Logs/WoWCombatLog*.txt` — the WoW client's raw combat history. The exact folder under the World of Warcraft installation may differ.

Zip and share those two files when you want a detailed analysis of your Warrior levelling and opener. **They are not accessible to ChatGPT without being uploaded.** Avoid putting logs containing player names on a public GitHub repository.

**Retention and disk usage:** ForeverCore retains the last **8 client sessions**, with a maximum of **15,000 events per session**. Older entries rotate out in batches when that cap is reached, while earlier sessions drop as new ones accumulate. Export periodically if you want a continuous levelling history. The native WoWCombatLog is not rotated or deleted by this addon and can become very large; archive or clear it yourself. SavedVariables write on normal logout or `/reload`, not after every cast, so a crash can lose recent events.

**Limits:** No addon-side parsing of `COMBAT_LOG_EVENT_UNFILTERED`, secret combat values, guaranteed per-ability damage, real threat or boss target. Auto-start via `LoggingCombat`, spell event coverage, SavedVariables persistence and the placement of raw combatlogs must still be confirmed in the actual Forever beta client. The in-game summary is retrospective, not live combat advice.

## Known limitations

- Addons cannot reliably compare protected/secret boss target data in some combat contexts. A reliable **boss targets me** alert has **not** been implemented in v0.1. Use Blizzard's target-of-target UI where supported.
- Friendly raid nameplates are restricted by Blizzard. A CVar request can be rejected or ignored, and the addon does not customize Blizzard friendly nameplates.
- Consumables are checked outside combat only; flask/food identification currently relies on English/Dutch buff-name matching. Custom Forever buffs may need explicit matching.
- SavedVariables persistence and client interface version need confirmation in the actual beta.
- A full cooldown HUD, full threat UI, encounter-specific warnings and complete options panel are not included yet. The new passive recorder is not a cooldown HUD.
- Raid debuffs might be partially/completely protected in combat, depending on beta API conditions.
- The Taunt notifier cannot reliably report the result of a resist/miss; see the section above.
- In-game testing and 12-macro button dragging still need validation on the current beta build.

## Roadmap

1. In-game API smoke test of v0.2.1, including buttons, combat restrictions and event payloads.
2. Validate boss debuff visibility and Taunt event coverage; keep unreadable combat information explicitly unknown.
3. Better pre-pull aura detection, including Forever-specific buffs.
4. Protection/Fury/Arms HUD for cooldowns, rage and defensive readiness, subject to beta API limits.\n5. Review the recorder's first real beta export, verify available events and derive levelling/threat recommendations from the readable combatlog.
5. Movable configuration UI and modules.
6. Encounter-specific warnings and safer boss target signals when supported by the addon API.

## Disclaimer

Unofficial community project; not affiliated with Blizzard Entertainment. The addon uses supported Lua addon interfaces and does not attempt protected combat actions or gameplay automation.
## Warrior threat theorycrafting (beta)

- [Measured Forever threat formulas & outstanding tests](THREAT_RESEARCH.md) — separates community-tested rank coefficients from unknown level-60 values.
- [Offline formula calculator](tools/threat_calculator.py) — computes only tested spell ranks and Rage-generated threat; it deliberately refuses unsupported ranks and does not claim a validated level-60 max-threat opener.
- Tests: `python -m unittest discover -s tools -v` (Python 3.10+).

The pre-pull and opener macros are still **manual**, and their threat priority is experimental until Shield Slam and final-rank coefficients are measured. This research does not change any in-game actionbar behavior.
