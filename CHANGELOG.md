# Changelog

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