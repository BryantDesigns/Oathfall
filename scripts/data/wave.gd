class_name Wave
extends Resource
## A single wave: a set of SpawnEntry configs plus how long the wave lasts
## before the spawner advances to the next wave.

@export var entries: Array[SpawnEntry] = []
@export var duration: float = 15.0  ## seconds before advancing to the next wave

func total_enemy_count() -> int:
	var total := 0
	for entry in entries:
		total += entry.count
	return total
