# Changelog

## 0.3.22-beta — 2026-10-31

- Enable Blizzard **Use Raid-Style Party Frames** automatically via the actual Edit Mode party frame setting, not by forcing protected frame visibility. Save the active custom Edit Mode layout without changing positions or other settings.
- Set `raidFramesDisplayClassColor=1` outside combat, for class-colored raid and raid-style party healthbars. Legacy `useCompactPartyFrames` CVar is attempted only when the modern Edit Mode API is unavailable.
- Add `/fc party status` and `/fc party apply` to inspect or retry. Defer while in combat or the Edit Mode interface is being edited. No modifications to the user's captured Bartender layout, binds, or action slot contents.
- Actual WoW Forever client validation still required.


## 0.3.21-beta — 2026-10-31

- Fix cross-account import: do not block Bartender4's saved snapshot on a missing Blizzard Edit Mode account layout. Apply each independently and track completion per character.
- Improve /fc layout status by showing the actual Bartender profile and whether Bartender and Edit Mode parts were separately applied.
- Report actionable warnings when account-wide Bartender SavedVariables or account Edit Mode layouts are unavailable.
- Importing Blizzard Edit Mode between Battle.net accounts still requires an explicit in-game Share/Import step. Resolution and UI scale must also match. Character abilities and binds remain untouched.


## 0.3.20-beta — 2026-10-31

- Re-check **only newly created characters** 2 and 6 seconds after world entry. A successful first keybinding write can be overwritten by the game's later loading phases; perform a limited repair when the requested main/Shift/Alt bindings are missing.
- Detect and report the current binding set and keybind verification in `/fc setup status`; existing characters keep their customized bindings unless the user explicitly runs `/fc setup apply`.
- BetterBlizzFrames uses account-wide SavedVariables. Add a live loaded/not loaded check to `/fc layout status`; do not overwrite its global settings or infer its UI appearance from screenshots.
- Keybind changes do not delete or copy class spell slots, spells, quest data, or Bartender layouts. In-client verification still required.


## 0.3.19-beta — 2026-10-26

- Extend `/fc layout capture` on Dien Warr to save the active Questie AceDB profile (including tracker position, dimensions and options) and Details!' live window layout (including position, sizes and skins) alongside Bartender4 and Blizzard Edit Mode.
- Use Questie's own `SetProfile` and `CopyProfile` to snapshot only `db.profile`, never `db.char` quest tracking or progress. Restore Dien Warr's original Questie profile after capture.
- Use Details!' official `SaveProfile(name)` and `ApplyProfile(name)` methods; force the snapshot's `profile_save_pos` to retain exact source window positions, without copying combat logs and character data.
- Apply both additional addon UI profiles automatically to new characters, with bounded retries when addon initialization is delayed. Existing characters require manual `/fc layout apply`; per-addon revision markers prevent repeated profile resets.
- Add extra UI status lines and optional TOC dependency ordering. Requires testing in the installed versions of Questie, Details! and Forever client.


## 0.3.18-beta — 2026-10-26

- Add a dedicated `/fc layout capture` command to snapshot the complete, currently configured Bartender4 AceDB profile from Dien Warr into the account-wide `FC Dien Warr Snapshot` profile. Safely restore the source profile after copying and keep all action slot contents/class spells untouched.
- Capture the active Blizzard Edit Mode layout. Reuse its exact account layout by name; if character-only, create an account-wide duplicate through Blizzard's own layout manager when available.
- Automatically select both snapshots for characters first seen after capture. Preserve existing characters, with optional manual `/fc layout apply`.
- Add `/fc layout status`, screen-resolution readback, and stop the previous automatic Bartender defaults from overwriting the new captured layout.
- Real game client capture is needed: screenshot pixel positions alone are insufficient to reconstruct complete saved UI profiles.


## 0.3.17-beta — 2026-10-26

- Fix Bartender4 integration being skipped entirely: LibStub is a callable table rather than a Lua function. Resolve the real Bartender4 addon and wait until the Forever preset has finished initializing.
- Enable Bartender's main bar (ID 1), two right bars (IDs 3/4), and two lower bars (IDs 5/6) using its own `EnableBar` API; enable Button Grid and disable alpha fade/hide so empty buttons stay visible. Do not change paging, action offsets, number of buttons, positions, or spell/action assignments.
- Turn off Bartender's Blizzard Art module with its real `ToggleModule` API, not by only writing a setting. Apply Full Button Mode (`outofrange = "button"`) and refresh buttons.
- Remove `SetActionBarToggles` entirely from ForeverCore; this protected UI write previously caused disappearing bars and may conflict with Bartender. Keep original starter action slots untouched.
- Do not save completion when Bartender is not ready or a live setting fails. Add useful `/fc bartender status` diagnostics, including action-slot occupancy.
- Requires validation in the user's actual WoW Forever client and Bartender4 build; no claim of successful in-game test.


## 0.3.16-beta — 2026-10-26

- Keep Blizzard empty action buttons visible with `alwaysShowActionBars=1` when the client exposes the CVar. New-character initialization already explicitly passes `alwaysShow=true` to the eight-argument `SetActionBarToggles` API.
- For Bartender4, enable `showgrid` on existing configured bars (including empty buttons) and set `Bartender4.db.profile.outofrange = "button"` for Full Button Mode; refresh the live buttons using Bartender's native `UpdateButtonConfig` method.
- Main bar now uses `1 2 3 4 G MouseWheelDown R F Z [X reserved] C V`. The Shift, Alt and Shift+Alt rows remain unchanged. The former direct Warrior G = Berserker Stance and MouseWheelDown = Heroic Strike binds are removed in favor of the two main actionbar slots.
- Existing characters on v0.3.15 receive only a guarded Q/E -> G/MouseWheelDown main-row migration if the original bindings are intact. Do not reset other keybinds. Bartender defaults are versioned to apply once to existing characters.
- Still requires testing with WoW Forever and the installed Bartender4 version.


## 0.3.15-beta — 2026-10-26

- On the first ForeverCore login of a new character, enable Blizzard Bottom Left, Bottom Right, Right 1, and Right 2 action bars, including empty-button visibility.
- Use all eight `SetActionBarToggles` arguments: preserve optional bars 5–7 and explicitly enable `alwaysShow`. Only write outside combat, never directly update protected frames, and mark completion once per character GUID.
- Skip characters already initialized by an earlier ForeverCore version. On first-run characters, retry when the API is not ready or the character is in combat. The bars take effect after `/reload` or relog.
- Existing Bartender4 settings, action bar placement, spells, and keybinds remain untouched. This change still requires validation in the actual Forever client.

## 0.3.14-beta — 2026-10-25

- Enable numeric actionbar cooldown countdown timers via `countdownForCooldowns=1` on login.
- Enable the native Blizzard Cooldown Manager via `cooldownViewerEnabled=1` on login; position and tracked spell configuration stay under Blizzard Edit Mode and `/cdm`.
- Add optional `BartenderSetup.lua` integration: when Bartender4 is installed and initialized, disable its Blizzard Art module and set padding to `0` for all available Bartender actionbars, once per character, only outside combat.
- Do not touch Bartender bar scale, positions, visibility, number of buttons, keybindings or other controls. Use `/fc bartender status` and `/fc bartender apply` for inspection and explicit reapply.
- Important: Bartender4 actionbar buttons do not necessarily inherit all default Blizzard binding commands; test `/kb` if bindings do not carry over.
- Still pending validation in the real Forever launch client and Bartender4 build.


## 0.3.13-beta — 2026-10-25

- Restore unmodified **X** to Blizzard's **SITORSTAND (Sit/Move Down)** on the builtin ergonomic setup. Main actionbar slot 10 is intentionally left unbound.
- Keep `Shift+X`, `Alt+X`, and `Alt+Shift+X` mapped to their existing modifier-layer actionbar slots.
- New characters get all 47 actionbar bindings plus `X = SITORSTAND`. Existing characters only get an **X-only migration** if `X` still maps to the old `ACTIONBUTTON10`; no other keybinds are re-imported or overwritten on addon updates.
- Request both Forever visual options on login: Outline Mode (`Outline=2` and renderer `graphicsOutlineMode=2` when CVar-accessible), plus always-on player self-outline (`findYourselfModeOutline=1`, `findYourselfAnywhere=1`).
- Report outline/highlight readbacks via `/fc setup status`. Secure actionbar visibility remains manual after the prior beta taint issue.
- Pending in-client validation on Forever 1.60 beta; game may reject or override renderer CVars.


## 0.3.12-beta — 2026-10-24

- Removed the Battle Shout reminder completely, including its pulse icon, frame, aura polling and obsolete pre-pull /fc commands. Existing Warrior skills, macros and keybinds remain unchanged.
- New `ChatSetup.lua`: on a character's first login create a Blizzard chat tab called **Party** with Guild, Party, Party Leader, Raid, Raid Leader and Raid Warning groups.
- Create a second tab called **Whispers** with only regular/Battle.net whisper message groups (incoming and outgoing), removing default chat groups and public channels.
- Leave existing chat tabs alone; store completion by character GUID in SavedVariables so subsequent logins/reloads do not create duplicates.
- Add `/fc chat setup` (manual retry) and `/fc chat status`.
- Pending real Forever client validation of chat frame APIs.


## 0.3.11-beta — 2026-10-23

- Emergency compatibility fix after user's Forever beta screenshots showed an extra actionbar vanishing during combat and an interface-action-blocked warning.
- Remove all automatic `SetActionBarToggles`, `Settings.SetValue`, and actionbar-CVar writes from login, zone changes and addon settings. Bar visibility is now set only by Blizzard's own UI.
- Force legacy `autoActionBars` setting off, including existing accounts with a previously saved true value; `/fc setup bars on/off` now gives manual instructions without touching secured Blizzard bars.
- Prior code passed 7 arguments to a Forever actionbar API supporting an eighth `alwaysShow` argument; do not silently change that state again.
- Stop repeated `nameplateShowFriends` writes after the first rejected write in each session, preventing repeated in-chat warnings.
- Preserve existing keybinds, auto loot, Battle Shout icon and other modules.
- Root cause is suspected, not yet confirmed; requires A/B test with addon enabled/disabled in the Forever client.


## 0.3.10-beta — 2026-10-23

- Removed the Defensive Stance reminder icon, glow and stance-state checks from the pre-pull HUD.
- The sole remaining pre-pull reminder is Battle Shout (44x44 pulsing icon when missing).
- Preserved `/fc move`, showing just the Battle Shout icon while positioning.
- No changes to stance keybinds, macro functionality, nameplates, or other modules.


## 0.3.9-beta — 2026-10-23

- Replaced 438x100 black text pre-pull dialog with **two 44x44 spell artwork icons**, Battle Shout and Defensive Stance.
- Icons are shown only for missing conditions and pulse with a compact amber glow; when both are satisfied no UI is visible.
- Defensive Stance icon only appears on tank profile once the stance is learnable; no extra alerts for offensive cooldowns.
- Preserved `/fc move` with a temporary icon preview for dragging. Saved position retained from prior versions.
- Hide reminders when client auras are protected/unreadable or while combat information cannot be safely determined.
- The existing flask/food detection remains in the code but is intentionally not rendered in this minimalist reminder.
- WoW Forever client verification pending.


## 0.3.8-beta — 2026-10-23

- Beta screenshot confirmed pre-pull HUD loads, regular and modified bars are visible, but old secondary bindings (e.g. main slot 5's old `5`) remain next to the new `Q` assignment.
- Preset now checks every targeted actionbar command and removes extra legacy/default keys before applying its unique intended key. This keeps an existing restore backup; `/fc setup restore` remains available.
- Pre-pull check no longer warns level-8 Warriors about Defensive Stance; checks whether the stance has been learned at later levels, if the API is available.
- Updated starter preset revision so fixes apply on the next character login after upgrading.
- Pending live client retest for proper key labels and error-free load.


## 0.3.7-beta — 2026-10-23

- Fix `AccountSetup.lua` load-blocking Lua syntax error (`if` changed to `elseif` in `/fc setup` command handling); previous builds reported `end expected near <eof>`.
- No binding layout changes; 0.3.6 ergonomic preset remains intact.


## 0.3.6-beta — 2026-10-23

- Rebuilt the screenshot-derived keybind preset into **four identical 12-key patterns**: no modifier, Shift, Alt, Alt+Shift.
- Each layer uses `1 2 3 4 Q E R F Z X C V`, yielding 48 actionbar bindings across Main, Bottom Left, Bottom Right and Right.
- Kept G, mouse-side Battle/Defensive Stance buttons, middle-mouse Taunt, and mousewheel Heroic Strike/Cleave dedicated to Warriors.
- Added guarded cleanup of old 0.3.4 / 0.3.5 preset bindings, clearing only unchanged legacy mappings while keeping manually edited bindings.
- Updated `/fc setup layout`; normal Blizzard Right Action Bar remains vertical.
- Real WoW Forever client tests pending; check Alt+Shift key handling and OS input-language shortcuts.


## 0.3.5-beta — 2026-10-23

- Reorganized all 29 screenshot-derived actionbar hotkeys into four consistent groups: unmodified keys on the Main and Bottom Left bars, Shift-only on Bottom Right, Alt-only on Right.
- Preserved Warrior-specific bindings (G = Berserker Stance, mousewheel down = Heroic Strike, wheel up = Cleave, middle mouse = Taunt, side buttons for Battle/Defensive Stance), taking priority over overlapping actionbar slots.
- Versioned the built-in preset so already initialized characters receive the revised grouping, unless a manually captured profile overrides it.
- Updated `/fc setup layout` to show the new key groups.
- This changes **bindings only**; the default Right bar remains vertical. In-client testing is still pending.


## 0.3.4-beta — 2026-10-23

- Built in 29 readable hotkeys from the supplied three-row actionbar screenshot. Mapped presumed row 1 to Main, row 2 to Bottom Left, row 3 to Bottom Right; trailing two to Right Action Bar.
- Preset now applies automatically on **any** character without capturing from an existing main. Previously unmapped keys remain unchanged.
- Existing Warrior direct stance/spell bindings (G, side mouse, scroll down/up, Taunt) take precedence on Warriors.
- Added `/fc setup layout` to view the preset in-game.
- Explicitly excluded hidden/ambiguous hotkeys and countdown timer text, and marked screenshot row-to-Blizzard-bar mapping as an assumption.
- Still pending on-client verification for hotkey labels, SHIFT-SPACE interpretation and inferred row-to-bar IDs.


## 0.3.3-beta — 2026-10-22

- Automatically enable all four additional Blizzard action bars on new and existing characters: Bottom Left, Bottom Right, Right 1 and Right 2.
- Prefer Forever's native Get/SetActionBarToggles API, preserving additional bar 5–7 settings; use modern settings proxies and CVar fallbacks where supported.
- Out-of-combat only, with clear warning if none of the client methods works.
- Added `/fc setup bars on/off` and bar status to `/fc setup status`.
- Pending test in actual Forever beta, as some action bar toggles apply only after reload.


## 0.3.2-beta — 2026-10-22

- No existing main character required: bootstrap the six known Warrior bindings automatically on first-ever Warrior login (mouse side 1/2 for Battle/Defensive, G Berserker, middle Taunt, scroll down Heroic Strike, scroll up Cleave).
- Preserve every other keybind in starter mode; optional full profile capture remains available later.
- Non-Warriors receive client settings but no Warrior-specific starter binds.
- Per-character restore saves to character binding set to avoid unintentionally changing account-wide binding definitions.
- This requires live Forever-client testing, particularly side mouse button numbering, direct spell binding compatibility and secure API restrictions.


## 0.3.1-beta — 2026-10-22

- Added `AccountSetup.lua`: character-name-independent account-level onboarding using shared SavedVariables.
- Auto-enable auto loot, friendly/enemy nameplates and always-show plates, requesting 60-yard nameplate distance within client/server limits.
- Capture all existing keybindings on a chosen main character via `/fc setup capture`; synchronize to other/new characters on first login. No guessing your layout.
- Save backups of prior bindings, offer `/fc setup restore`, manual apply and opt-out commands.
- Preserve existing recorder, threat research and Warrior macro modules unchanged.
- Pending in-client compatibility tests on Forever beta.


## 0.2.1-beta — 2026-10-16

- Replaced 12 ability-shortcut templates with user-triggered **all-in burst openers** for ST/AoE threat and DPS across Prot/Fury/Arms.
- Threat setup now includes stance-swapped Retaliation and Recklessness; Fury adds talented Death Wish, Arms AoE can use Sweeping Strikes.
- Shift/Ctrl/Alt cast deliberate burst phases; normal press returns to the intended stance and attacks. No automated multi-GCD rotations.
- Previously created macro bodies remain intact until manually changed via Openers > Edit > Default > Save.
- Beta-only and pending in-game verification. Not proven optimal TPS/DPS.


## 0.2.0-beta — 2026-10-16

- New `RaidWarnings.lua`: hostile target Sunder Armor stacks, Demoralizing Shout and Thunder Clap in raids, with unknown fallback when combat auras are protected.
- Taunt cast-failure notice and post-cast verification reminder (no unsupported miss/resist claims).
- New `Openers.lua`: 12 draggable and editable Warrior macros (4 each for Protection, Fury, Arms). Macro creation is lazy to conserve macro slots; Save updates an existing opener macro.
- New `/fc openers`, `/fc alerts`, `/fc taunt`, and Arms profile support.
- Macro documentation and per-spec manual opener priorities.
- **Pending in-game verification on current beta**.

## 0.1.0-beta — 2026-10-16

- Initial prototype.
- Raid-only friendly nameplate setting (best effort).
- Out-of-combat pre-pull checks and draggable panel.
- Manual tank/Fury profile selection.
- 15 Warrior macro definitions, created on request with `/fc macros`.