# Warrior threat research — WoW Forever beta

**Status:** community-measured, unmodified threat formulas; NOT confirmed level-60 coefficients. Beta builds can change the numbers. Keep the formula data separate from validated class mechanics and from in-game addon warnings.

**Primary source:** community threat testing supplied 18 Oct 2026; [individual published tests](https://docs.google.com/spreadsheets/d/e/2PACX-1vQxd44ah_iUJNcTdH2mpI9nTMNbQEGV9COXkD1nRHi6NGxiU-TvdtkIJBik7KkgN6gKCs7Sn2E-LVxU/pubhtml#gid=0).
**Official cross-check:** [Blizzard's Forever Warrior deep dive](https://news.blizzard.com/en-us/article/24301514/world-of-warcraft-forever-class-deep-dives-priest-and-warrior) confirms Sunder AP scaling and separate Recklessness/Retaliation/Shield Wall cooldowns, **not the numbers below**.

## Tested raw formulas

`Damage` is **actual damage dealt**, already accounting for armor, critical hit, talents and so on. Do not double-apply critical-hit modifiers. `AP` means attack power. All threat values below are **before stance and Defiance multipliers**.

| Tested ability/rank | Unmodified threat |
|---|---|
| Sunder Armor r1 | `AP * 0.05 + 35` |
| Sunder Armor r2 | `AP * 0.05 + 76` |
| Heroic Strike r4 | `Damage + 61` |
| Cleave r2 | `Damage + (46 / targetsHit)` per hit target |
| Revenge r2 | `Damage * 2.25` |
| Thunder Clap r3 | `Damage` |
| Rend r4 | `Damage` (apply to actual damaging ticks) |
| Slam r2 | `Damage + 30` |
| Hamstring r1 | `Damage` (r1 observed 4–5) |
| Shield Bash r1 | `Damage + 2` (r1 observed 4–5) |
| Mocking Blow r2 | `Damage + 50` |
| Battle Shout | `0` |
| Demoralizing Shout | `37` |
| Intimidating Shout | `0` |
| Concussion Blow | `0` |
| Disarm | `0` |
| Retaliation hit | `Damage` |

**Tentative damage scaling:** Revenge ~28% of AP; Thunder Clap ~7% of AP. Sunder's ~5% AP coefficient may be slightly lower and/or rank/level-dependent. Do not assume measured lower-rank formulas work at rank 5/6.

## Threat from Rage gained

Community testing reports `5 threat * each Rage generated`, **split between enemies in combat with the Warrior**. A talented block/dodge/parry that gives 5 Rage would therefore generate 25 total raw threat, divided over engaged enemies. Untalented Bloodrage generates 10 Rage instantly plus 10 over time; that is potentially 50 + 50 raw threat **when these gains occur in combat**.

**Crucial:** Pre-pull Bloodrage and Mighty Rage Potion primarily add Rage as a *resource*. Do not assign potion/Bloodrage threat to a boss that is not in combat. Testers also report potion-generated Rage threat may be bugged; do not model 5 threat/Rage from the potion as established. Whether stance multipliers modify Rage-generated threat must be separately measured.

## Application to max-threat Protection opener

1. **Before combat:** start in Defensive Stance, prepare Retaliation in Battle Stance, Recklessness/Berserker Rage in Berserker Stance; return to Defensive, Bloodrage and pre-pot Mighty Rage Potion immediately before pull. Full macro/GCD/stance interaction must be beta-client tested.
2. **Manual Charge** using Vanguard, then calculate Rage including the cap (100), stance-loss/decay, Bloodrage ticks and the potion's 45–75 Rage.
3. **Recklessness window:** actual crit damage matters for damaging abilities. Revenge r2's 2.25× multiplier is particularly promising; Sunder's measured rank 1/2 formulas have no direct crit component. Do NOT assume five Sunders is optimal during Recklessness.
4. **Shield Slam:** initial candidate for first GCD, but **its numeric bonus/coefficients are not yet measured here**. Do not invent its threat or assert a mathematically proven level-60 priority.
5. **Heroic Strike:** account for replacing a normal melee swing and its lost Rage generation; Retaliation: count only triggered hits and their actual damage; Rage procs: count correct distribution over targets.
6. **Boss model:** use actual crit/hit rates, boss armor, boss swing times, Shield Block/Revenge activation, GCD and buff duration. Compare both 3–5-sec snap threat and 10–15-sec cumulative threat.

### Illustrative calculation only (NOT level 60)

With AP=1000: Sunder Armor r2 = `1000 * 0.05 + 76 = 126` raw threat.
Revenge r2 hitting for 200 damage = `200 * 2.25 = 450` raw threat, or 900 if the actual critical hit deals 400 damage. Apply a **verified** stance/Defiance multiplier afterwards.

### Open measurements

- Shield Slam full per-rank threat formula (fixed amount, block value, crit behavior).
- Final-rank Sunder/Revenge/Thunder Clap/Heroic Strike/Cleave.
- Actual AP scaling and any additional talents.
- Potion/Bloodrage threat in and outside combat; Rage threat split and stance interaction.
- Simultaneous Recklessness + Retaliation buff persistence across stance changes in Forever and remaining buff time after pre-pull.
- Level-60 damage, Rage income and boss swing timeline.

**Research discipline:** note Forever client build, test date, level, spell rank, AP, equipped shield, talents, stance, actual damage, crit flag, Rage before/after, targets engaged, and observed threat whenever changing a coefficient. Never silently substitute Classic/SoD coefficients or Wowhead tooltip values for unverified Forever data.

Offline formula evaluator: [tools/threat_calculator.py](tools/threat_calculator.py); run tests with `python -m unittest discover -s tools`. It intentionally rejects unsupported ranks including level-60 Shield Slam.
