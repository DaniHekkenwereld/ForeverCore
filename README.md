# ForeverCore

A small, experimental Warrior-focused UI addon for **World of Warcraft: Forever (beta)**. Built for Protection/Fury/Arms Warriors and intended to keep common raid preparation checks in one place.

> **Beta prototype:** The addon has not yet been validated in the live WoW Forever beta client. API behavior, TOC version and macro conditions may change. No combat automation is provided.

## Included in v0.3.28-beta

- **Always-visible action bars in Bartender:** enable Bartender bars 1/3/4/5/6 using Bartender's own API, show empty slots and disable fade/hide. ForeverCore no longer calls Blizzard's `SetActionBarToggles` API. Original starter spell slots are never rewritten.
- Attempt to enable default friendly nameplates automatically in raid instances (`/fc plates auto`). This depends on Blizzard restrictions and client CVar support.
- **Cooldown numbers enabled** on action buttons and **Blizzard's Cooldown Manager enabled**, using the verified client CVars `countdownForCooldowns=1` and `cooldownViewerEnabled=1` (normal CVar restrictions apply).
- **Bartender4 initialization:** resolves callable-table `LibStub` correctly, waits for Bartender's Forever preset, then sets Blizzard Art **off**, padding **0**, Button Grid **on**, opacity **100%**, no fade/hide, and Out of Range Indicator **Full Button Mode**. Bar positions, paging, ability assignments and keybindings are untouched. All UI writes are performed out of combat.
- **One-time chat tabs on each character:** `Party` for Guild, Party, Raid (including leader and raid warnings); `Whispers` for WoW and Battle.net whispers only. No Battle Shout / pre-pull reminder remains.
- Manually switch between tank, Fury, and Arms profiles.
- Raid debuff display: **Sunder Armor** stacks (up to 5), **Demoralizing Shout**, **Thunder Clap** on your hostile target. If combat auras are secret, status is unknown (`?`), never falsely marked missing.
- **Taunt feedback:** warns on a spellcast failure event if the client supplies it and reminds you to verify the boss target when you cast Taunt; **resist/miss cannot be proven** without the combat log.
- Separate drag-and-edit burst opener macro panel with **4 per spec**, **12 total** (ST threat, AoE threat, ST DPS, AoE DPS), created only when dragged so existing macro slots are not consumed unnecessarily.
- Generate 15 character-specific Warrior macros without overwriting existing ones. Combo macros are **manual**, with modifier keys for each cooldown.

## Copy Dien Warr's exact UI to future characters (v0.3.18)

On **Dien Warr**, finish adjusting Bartender4 and Blizzard Edit Mode, click **Save** in Edit Mode and exit Edit Mode. Make sure Bartender4 is fully loaded. Then run:

```text
/fc layout capture
/fc layout status
```

ForeverCore creates a dedicated **FC Dien Warr Snapshot** Bartender AceDB profile, copying all Bartender module settings (including bar positions, scales, fades, window positions and visible bars) using AceDB's `CopyProfile` API. It then returns Dien Warr to the original Bartender profile. No action slots or class spells are copied, moved or cleared. The exact bar layout is used on new characters by selecting the snapshot AceDB profile.

The current Blizzard Edit Mode layout is remembered by name. If it is a **character-only** layout, ForeverCore attempts to create a separate account-wide copy via Blizzard's layout manager, called **FC Dien Layout**, and reports a failure if that is not possible. The shared account layout contains the precise Blizzard-managed HUD positions, sizes and settings. These settings are not inferred from screenshots. Other addons beyond Bartender4, Questie and Details! are not copied by this feature.

New characters created **after the capture** automatically use the captured Bartender4, Edit Mode, Questie and Details! profiles where those addons are installed, leaving starter skills, spells, action slots and other existing characters alone. You can also run `/fc layout apply` on an existing character to opt in manually, or `/fc layout status` to inspect the saved profile. This changes Bartender4 and Edit Mode only; actionbar keybind auto-setup remains controlled by AccountSetup.lua.

Use the same monitor resolution and WoW UI scale for pixel-identical placement. The feature records the source physical screen size to help diagnose discrepancies. Bartender and Edit Mode must be present in this version of WoW Forever. Client validation is still required.

## Questie and Details! UI snapshot (v0.3.19)

**Also included in `/fc layout capture`:**

- **Questie:** the complete AceDB **profile**, including `TrackerLocation`, tracker dimensions, scale, appearance and options, stored as `FC Dien Warr Questie`. Questie `db.char` (tracked quests and quest progress) is never copied.
- **Details!:** its native `SaveProfile("FC Dien Warr Details")` saves the CURRENT live Details! window positions, sizes, skin and appearance. The snapshot enables `profile_save_pos` so its window positions are restored on new characters. Details combat records, character history and combat segments are not copied.

Use `/fc layout capture` again on the configured source character (for example, **Tester**) after installing this update. You may leave the existing Questie and Details! snapshot profiles selected; capturing them again no longer requires switching profiles. Both addons need to be enabled and loaded. Use `/fc layout status` to confirm that **all four** UI components are recorded (Bartender4, Edit Mode, Questie and Details!). If one addon is missing, the command says so; its configuration is not fabricated from screenshots.

A **new** character automatically selects the saved Questie AceDB profile and calls Details!' native `ApplyProfile`, without changing quests or combat history. For an already-created character, `/fc layout apply` opts in. The copy uses the original screen resolution and UI scale. Questie or Details! initialization may require a `/reload` after the first apply.

## Fixing newly created character keybinds & BetterBlizzFrames (v0.3.20)

- Initial keybind setup now checks newly created characters again after the game and Bartender have loaded. It retries only twice and only for a character first seen during this login, avoiding automatic overwrites of existing character custom bindings.
- Use `/fc setup status` to see the active keybinding set and whether the expected G / Scroll Down / Shift / Alt keys actually match.
- If the new character was made with an earlier addon version, `/fc setup apply` can manually retry its normal keybind preset.
- BetterBlizzFrames is a different addon with **account-wide SavedVariables** (`BetterBlizzFramesDB`), not a separate per-character UI profile to capture. It must be enabled and loaded on the character. `/fc layout status` now reports its real load state; when it is not loaded, check the WoW character-selection AddOns menu and choose **All Characters** for BetterBlizzFrames. `/bbf` opens its options when enabled.
- No changes to existing spell/action slots or Bartender's captured profile.

## Additional installed addon settings (v0.3.28, partial coverage)

When the user runs `tools/Export-PortableSnapshot.ps1`, that script **also** scans the installed addon folders and their `.toc` manifests and runs `tools/Export-AddonSettings.ps1`. It creates two additional files inside ForeverCore:

- `PortableAddonSettings.lua` — portable **account-level settings** for allowlisted UI addons. Install the generated file as part of ForeverCore; **never overwrite it with the empty GitHub placeholder**.
- `PortableAddonSettings-report.txt` — itemized **OK / NO SAVE / NO CONFIG / SKIP / NEEDS ADAPTER** statuses for every installed addon directory. Review this report before sharing the snapshot.

Default allowlist: Bagnon, Bagnon_Bank, Bagnon_Config, Bagnon_GuildBank, BetterBlizzFrames, EnhanceQoL, GTFO, Leatrix_Maps, Plater, Scrap and TinyTooltip, when their account-level variables exist. Bartender4, Questie, Details! and ForeverCore continue to use the dedicated portable snapshot. Other folders shown in the screenshot are modules, locale packs, plugins, or addons requiring specific adapters. **This is not yet an export of every setting of every addon.** No per-character SavedVariables are exported by the generic scanner.

Some other addons combine UI preferences with progress or personal data. The exporter **deliberately excludes** BagBrother inventory data, Polestar guide progress, Spoken playback state, RXP guide progress, HandyNotes personal notes, ForeverBugReporter reports, and similar data until safe settings-only adapters exist. A generic raw copy would leak personal or character-specific data to other players. Never share a raw WTF folder as a substitute.

On a new account, ForeverCore imports these packaged settings into the supported addons' native SavedVariables **once**, then attempts one `/reload` so those addons initialize with the restored preferences. It will not repeatedly overwrite later user changes. Use `/fc addons status` to inspect the account import count. Third-party addon initialization and native `/reload` support still need testing on the Forever client.

## Same UI on every WoW account on this computer (v0.3.26)

**Goal: no dragging, copying WTF folders or manually selecting Bartender profiles when creating a new character, even on a different WoW account.** Native WoW account SavedVariables cannot be read by addons belonging to another account. ForeverCore therefore loads a *portable snapshot* from its own `Interface/AddOns/ForeverCore/PortableSnapshot.lua`.

Prepare the snapshot **once** on the already configured source account:

1. Update ForeverCore on the game installation where **Dien Warr** and the finished UI are configured.
2. Log into Dien Warr, check Bartender and Blizzard Edit Mode, use `/fc layout capture`, then **log out** to save the captured information.
3. With the game closed, open PowerShell **in the installed ForeverCore addon folder** and execute:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\tools\Export-PortableSnapshot.ps1
   ```

The exporter also creates PortableAddonSettings.lua and a coverage report for extra addons. It finds the configured source account and embeds only the named Bartender AceDB parent/namespace profile, the captured Blizzard Edit Mode data, optional captured keybind profile, and available Questie tracker / Details! UI profiles. It does **not** copy character action slots, spells, quests, gameplay recordings or Details! combat history. An explicit WoW client folder may be supplied with `-GameRoot "C:\...\_classic_beta_"`, and `-Account "ACCOUNT_FOLDER"` selects a particular source account.

**After generation**, on any new WoW account using **that same client installation**, ForeverCore seeds the named Bartender profile from its own addon file, applies the captured UI on new characters, and attempts to install/select the native account Edit Mode layout. Questie and Details! are also seeded when their named profiles were present in the export. A missing Blizzard layout does not block Bartender. Existing characters keep their own UI until `/fc layout apply` is explicitly used.

On the new character, run `/fc layout status`; it must show **Portable instellingen in addon: aan** and the named Bartender snapshot. The actual client implementation still needs testing, especially the Blizzard Edit Mode save API on Forever+ and the release client. If that save API is denied, the addon reports a warning rather than claiming the Edit Mode import succeeded.

**Important for updates:** `PortableSnapshot.lua` is generated locally. Do not overwrite it with the empty repository placeholder when updating ForeverCore. Include the generated file when installing ForeverCore on another computer; it is part of the addon, not an account-specific WTF file. Re-run the exporter only after deliberately changing the source UI.

## Raid-style party frames (v0.3.24)

The checkbox **Use Raid-Style Party Frames** is now set to 1 automatically in the captured Blizzard Edit Mode layout (such as Dien). ForeverCore reads the native saved layout, changes only that one Boolean, and saves it through C_EditMode.SaveLayouts outside combat. Bar positions, Edit Mode coordinates, other unit frame settings and keybindings stay untouched.

This replaces the v0.3.23 read-only approach. The previous v0.3.22 live Edit Mode manager calls are still removed to avoid the reported secure-frame taint. Class colors remain handled by AccountSetup.lua with raidFramesDisplayClassColor=1.

The change is applied automatically at login, no command required. /fc party status checks the saved value. Because the previous implementation produced a secret-value taint error on Forever+, in-game verification is still required.


## Delayed Bartender4 profile application (v0.3.25)

A fresh character previously could miss its Bartender4 snapshot if Bartender was still loading during the initial login and no later event triggered `LayoutTemplate.lua` again. ForeverCore now retries the saved layout at 1, 3, and 7 seconds after login (outside combat), and on `ADDON_LOADED: Bartender4`, until its own per-character completion state is stored. It verifies AceDB's current profile after calling SetProfile.

This does **not** copy actions, macros, spells, or keybindings, and does **not** force the saved snapshot over existing characters. Manual `/fc layout apply` remains available to opt into the UI on an already-created character. Use `/fc layout status` to inspect the actual selected Bartender4 profile. If Bartender4 is disabled for a character, no profile can be applied; enable it in the AddOns list.

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
     PortableSnapshot.lua
     PortableDefaults.lua
     PortableAddonSettings.lua
     PortableAddonSetup.lua
     AccountSetup.lua
     ChatSetup.lua
   ```

   The client installation directory can differ. The `.toc` file must sit directly in `AddOns\ForeverCore\`.
3. Launch WoW Forever, enable **ForeverCore** on the AddOns screen and run `/fc help`.

## Fresh-character keybinds (v0.3.13) — mirrored 4-layer layout

The old v0.3.5 layout was hard to memorize. The **new default uses the same 12 key positions across modifier rows**, but leaves plain X unbound on the main actionbar to preserve Sit/Move Down. The first login of any character (regardless of name or class) applies **47 actionbar bindings plus X = Sit/Move Down**, *without* requiring a main character or using `/fc setup capture`.

| Row | Blizzard bar | Modifier | Twelve buttons, left to right |
| --- | --- | --- | --- |
| 1 | Main | None | `1` `2` `3` `4` `G` `MouseWheelDown` `R` `F` `Z` **(slot 10 unbound)** `C` `V` |
| 2 | Bottom Left | Shift | `Shift+1` `Shift+2` `Shift+3` `Shift+4` `Shift+Q` `Shift+E` `Shift+R` `Shift+F` `Shift+Z` `Shift+X` `Shift+C` `Shift+V` |
| 3 | Bottom Right | Alt | `Alt+1` `Alt+2` `Alt+3` `Alt+4` `Alt+Q` `Alt+E` `Alt+R` `Alt+F` `Alt+Z` `Alt+X` `Alt+C` `Alt+V` |
| 4 | Right | Alt+Shift | `Alt+Shift+1` `Alt+Shift+2` `Alt+Shift+3` `Alt+Shift+4` `Alt+Shift+Q` `Alt+Shift+E` `Alt+Shift+R` `Alt+Shift+F` `Alt+Shift+Z` `Alt+Shift+X` `Alt+Shift+C` `Alt+Shift+V` |

**X is Sit/Move Down** on all newly configured characters. **Shift+X, Alt+X and Alt+Shift+X remain active** on the other three bars. On an existing character with a previous ForeverCore layout, the update only restores X if it is still bound to the old `ACTIONBUTTON10`; **all other manually adjusted keybinds remain untouched**. On subsequent logins there is no re-import. Custom captured profiles still take precedence.

**Example:** `R` is row 1 / slot 7, `Shift+R` row 2 / slot 7, `Alt+R` row 3 / slot 7 and `Alt+Shift+R` row 4 / slot 7. The game bars remain visually where Blizzard puts them; the **Right** bar is normally vertical. ForeverCore binds slots, not UI placement or ability assignment.

The base keys were chosen near WASD and avoid **W/A/S/D (movement)**, Tab, Space and the dedicated mouse controls. The unmodified main-row `G` and `MouseWheelDown` are now **actionbar buttons 5 and 6** (not direct Berserker Stance or Heroic Strike bindings); modifier rows keep their previous keys. Assigning Q and E to abilities will replace WoW's default strafe-left / strafe-right on those keys; A/D can still be used for strafing if configured. Shift+Alt can also conflict with a Windows language-switch shortcut; turn off or change that OS shortcut if the combination switches layouts.

### Warrior keybinds stay fixed

| Input | Action |
| --- | --- |
| Mouse thumb `BUTTON4` | Battle Stance |
| Mouse thumb `BUTTON5` | Defensive Stance |
| `G` | Main actionbar slot 5 (place Berserker Stance there manually if desired) |
| Middle mouse `BUTTON3` | Taunt |
| Mousewheel down | Main actionbar slot 6 (place Heroic Strike there manually if desired) |
| Mousewheel up | Cleave |

Warrior still receives Battle/Defensive stance on mouse 4/5, middle-mouse Taunt and wheel-up Cleave. G and wheel-down now belong to main actionbar slots 5/6 for every class. The Shift, Alt and Alt+Shift modifier rows have not changed.

### Migrating and controlling the layout

The initial preset was introduced after v0.3.4 and v0.3.5. In v0.3.16, existing v0.3.15 characters only migrate main slots 5/6 from Q/E to G/MouseWheelDown if the previous bindings are still intact; custom bindings and modifier rows are preserved. Known **old default keybinds** are removed only when the character had the earlier ForeverCore preset and those keys still perform their exact old actions; keys manually repurposed since then are preserved. Backups of previous bindings remain available.

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
| Bottom Left, Bottom Right, Right 1 and Right 2 | Enabled as Bartender bars 6, 5, 3, 4 respectively (plus main bar 1). All have visible empty buttons; Blizzard's protected actionbar toggles are not modified. |

## New self-outline defaults (v0.3.13)

On login, ForeverCore requests the game's **Outline Mode** and **always-on self highlight (yellow player outline)**. These use documented settings from the Forever options system. The renderer-related `graphicsOutlineMode` value is requested when readable through the normal CVar API; not every Forever build exposes every graphics CVar to addons. If an API refuses a setting, use WoW Options to enable it manually. No secured actionbar or Edit Mode writes have been reintroduced. Check actual results using `/fc setup status`.

## Cooldown numbers, Cooldown Manager and Bartender4 (v0.3.14)

On login, ForeverCore requests these built-in Blizzard client settings:

| Feature | CVar | Requested value |
| --- | --- | --- |
| Numeric cooldown timer on actionbar icons | `countdownForCooldowns` | `1` |
| Blizzard Cooldown Manager | `cooldownViewerEnabled` | `1` |

The native Cooldown Manager is controlled by Blizzard. You can rearrange it in Edit Mode and configure tracked spells using `/cdm`. Some Forever client builds may restrict addon CVar writes; `/fc setup status` reports the actual readback.

**If Bartender4 is installed**, ForeverCore now correctly obtains the live Bartender4 addon (LibStub is a callable table), waits for the Forever preset to finish and then enables bars 1/3/4/5/6 with Bartender's own methods. It sets Button Grid on, opacity to 100%, no fade/hide, padding to 0, Blizzard Art off and Out of Range Indicator to Full Button Mode. Bar position, paging, number of buttons, button offset, keybinds and spell/action assignments are not changed. Runs outside combat once per character per revision; retries if initialization is incomplete. Use `/fc bartender status` for live bar/module/range diagnostics and a count of the original Blizzard action slots 1–12; use `/fc bartender apply` to retry.

**Important:** Bartender4 maintains its own action buttons, and its keybinding behavior may differ from Blizzard's default bars. In particular, Bartender's documentation says extra bars may require its own KeyBound binding setup via `/kb`. Our default Blizzard actionbar keybinds must be checked after installing Bartender4. Do not assume all 47 additional binds will transfer automatically.

Version 0.3.17 no longer calls Blizzard's protected `SetActionBarToggles` at all. All five main/extra Bartender bars are enabled through Bartender's own API. Blizzard's options remain manual when Bartender is not in use.

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
