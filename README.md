# ForeverCore

A small, experimental Warrior-focused UI addon for **World of Warcraft: Forever (beta)**. Built for Protection/Fury/Arms Warriors and intended to keep common raid preparation checks in one place.

> **Beta prototype:** The addon has not yet been validated in the live WoW Forever beta client. API behavior, TOC version and macro conditions may change. No combat automation is provided.

## Included in v0.3.2-beta

- Attempt to enable default friendly nameplates automatically in raid instances (`/fc plates auto`). This depends on Blizzard restrictions and client CVar support.
- Movable pre-pull status panel.
- Out-of-combat checks for a flask buff, food buff and Battle Shout, plus a shield/stance check for the tank profile.
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
     Recorder.lua
   ```

   The client installation directory can differ. The `.toc` file must sit directly in `AddOns\ForeverCore\`.
3. Launch WoW Forever, enable **ForeverCore** on the AddOns screen and run `/fc help`.

## Fresh-character setup (v0.3.2) — no main character required

**From the very first character on launch**, ForeverCore sets auto loot and friendly/enemy nameplates, and requests maximum nameplate range (60 yards; actual cap controlled by client/server). No captured bindings or existing character are needed for these settings.

For **new Warriors**, it now also applies these **six known keybinds** automatically, without clearing any other keybinds:

| Key | Action |
| --- | --- |
| Mouse thumb button 1 (`BUTTON4`) | Battle Stance (`SHAPESHIFTBUTTON1`) |
| Mouse thumb button 2 (`BUTTON5`) | Defensive Stance (`SHAPESHIFTBUTTON2`) |
| `G` | Berserker Stance (`SHAPESHIFTBUTTON3`) |
| Middle mouse (`BUTTON3`) | Taunt (direct spell binding) |
| Scroll down (`MOUSEWHEELDOWN`) | Heroic Strike (direct spell binding) |
| Scroll up (`MOUSEWHEELUP`) | Cleave (direct spell binding) |

Mouse thumb buttons are assumed to report as `BUTTON4` and `BUTTON5`. Actual hardware numbering should be verified on launch. The direct spell bindings use English spell names; check localized client support. Stances and abilities become useful as the Warrior learns them.

The other keybinds are **not guessed** or overwritten. Other classes receive the shared client settings but no Warrior spell bindings. For complete starter layouts on other classes, dedicated class presets must be defined.

After you've configured the remaining keys on a character, you can optionally use `/fc setup capture` to create a complete shared keybind profile. That captured profile then takes precedence over the built-in six-key starter on future logins. The account-wide profile applies on all characters regardless of their names, filtered to avoid pushing class-specific spell bindings to other classes.

Before modifying a character's bindings the addon saves a per-character restore point. Run `/fc setup restore` to recover it, or `/fc setup apply` to force the selected profile again. Changes run only **outside combat** and might be rejected by Forever beta API restrictions.

| Automatic game setting | Requested value |
| --- | --- |
| Auto loot | On (`autoLootDefault=1`) |
| Enemy nameplates | On (`nameplateShowEnemies=1`) |
| Friendly nameplates | On, when available |
| Always show nameplates | On (`nameplateShowAll=1`) |
| Nameplate range | Request 60 yards, limited by the game |

**Important:** Keybinds are not the same as action bar contents. The starter uses direct spell and stance bindings, so its six mapped abilities don't depend on action bar placement. Other spells, talent builds, equipment and any additional actionbar layout remain character-specific.

Commands: `/fc setup status` (inspect), `/fc setup capture` (optional full profile), `/fc setup apply` (reapply), `/fc setup restore` (restore previous binds), `/fc setup bindings on/off`, `/fc setup settings on/off`.

## Commands

| Command | Effect |
| --- | --- |
| `/fc help` | Show available commands |
| `/fc setup` | Show account setup commands |
| `/fc setup capture` | Optionally capture all your edited keybinds; not required on the first character |
| `/fc setup status` | Show whether profile / client options are active |
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
