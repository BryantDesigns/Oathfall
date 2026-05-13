class_name XpComponent
extends Node
## Holds total XP and current level. Emits leveled_up(new_level) once per
## level boundary crossed (including multi-level jumps).

signal xp_changed(total_xp: int, current_level: int)
signal leveled_up(new_level: int)

@export var curve: XpCurve
var total_xp: int = 0
var level: int = 1

func gain_xp(amount: int) -> void:
	if amount <= 0:
		return
	total_xp += amount
	xp_changed.emit(total_xp, level)
	var new_level := curve.level_at_total_xp(total_xp)
	while level < new_level:
		level += 1
		leveled_up.emit(level)
