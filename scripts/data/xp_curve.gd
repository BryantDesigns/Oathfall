class_name XpCurve
extends Resource
## XP thresholds. Closed-form so we don't need to store per-level arrays.
## Formula: threshold to REACH level N (from level 1) is 10 * (N-1) * N / 2.

@export var base: int = 10

func threshold_to_reach(level: int) -> int:
    if level <= 1:
        return 0
    return base * (level - 1) * level / 2

func level_at_total_xp(total_xp: int) -> int:
    var level := 1
    while threshold_to_reach(level + 1) <= total_xp:
        level += 1
    return level
