"""Small offline evaluator of measured WoW Forever Warrior beta threat formulas.

No level-60 prediction or opener automation. Source: ../THREAT_RESEARCH.md
Damage inputs must be ACTUAL damage dealt, including crit/mitigation.
"""
from __future__ import annotations
from dataclasses import dataclass


@dataclass(frozen=True)
class MeasuredAction:
    spell: str
    rank: int | None = None
    damage: float = 0.0
    ap: float = 0.0
    targets_hit: int = 1


def raw_ability_threat(a: MeasuredAction) -> float:
    """Unmodified threat for a measured rank only; Cleave returns per-hit-target."""
    if a.targets_hit < 1 or a.damage < 0 or a.ap < 0:
        raise ValueError("AP/damage must be >= 0 and targets_hit >= 1")
    if (a.spell, a.rank) == ("Sunder Armor", 1):
        return a.ap * 0.05 + 35
    if (a.spell, a.rank) == ("Sunder Armor", 2):
        return a.ap * 0.05 + 76
    if (a.spell, a.rank) == ("Heroic Strike", 4):
        return a.damage + 61
    if (a.spell, a.rank) == ("Cleave", 2):
        return a.damage + 46 / a.targets_hit
    if (a.spell, a.rank) == ("Revenge", 2):
        return a.damage * 2.25
    if (a.spell, a.rank) == ("Slam", 2):
        return a.damage + 30
    if (a.spell, a.rank) == ("Shield Bash", 1):
        return a.damage + 2
    if (a.spell, a.rank) == ("Mocking Blow", 2):
        return a.damage + 50
    if (a.spell, a.rank) in {
        ("Thunder Clap", 3), ("Rend", 4), ("Hamstring", 1)
    }:
        return a.damage
    if a.spell == "Retaliation" and a.rank is None:
        return a.damage
    fixed = {
        "Battle Shout": 0,
        "Demoralizing Shout": 37,
        "Intimidating Shout": 0,
        "Concussion Blow": 0,
        "Disarm": 0,
    }
    if a.rank is None and a.spell in fixed:
        return fixed[a.spell]
    raise ValueError(f"No measured formula for {a.spell!r} rank={a.rank!r}")


def rage_gain_threat(rage_gained: float, targets_in_combat: int = 1,
                     in_combat: bool = True) -> float:
    """Raw PER TARGET rage-generated threat; pre-pull returns zero.

    Testers report potion-generated rage threat may be bugged; don't use this
    function for potions without a verified client-specific measurement.
    """
    if rage_gained < 0 or targets_in_combat < 1:
        raise ValueError("Rage must be >= 0 and targets_in_combat >= 1")
    return 5 * rage_gained / targets_in_combat if in_combat else 0


def apply_threat_multiplier(raw_threat: float, multiplier: float) -> float:
    """Supply externally verified stance/talent multiplier, not an assumed one."""
    if raw_threat < 0 or multiplier < 0:
        raise ValueError("Threat/multiplier must be >= 0")
    return raw_threat * multiplier


if __name__ == "__main__":
    print("Measured beta threat formulas only; NOT a level-60 opener simulation.")
    for a in (MeasuredAction("Sunder Armor", 2, ap=1000),
              MeasuredAction("Revenge", 2, damage=200),
              MeasuredAction("Revenge", 2, damage=400)):
        print(f"{a.spell} r{a.rank}: {raw_ability_threat(a):.1f} raw threat")
