class_name WaveLibrary
extends RefCounted
## Static factory for the M2a prototype wave sequence. Tune here; .tres-authored
## waves are a future enhancement.

const RUSHER: PackedScene = preload("res://scenes/enemies/melee_chaser.tscn")
const SWARMER: PackedScene = preload("res://scenes/enemies/swarmer.tscn")
const RANGED: PackedScene = preload("res://scenes/enemies/ranged_enemy.tscn")

static func _entry(scene: PackedScene, count: int, interval: float) -> SpawnEntry:
	var entry := SpawnEntry.new()
	entry.enemy_scene = scene
	entry.count = count
	entry.interval = interval
	return entry

static func _wave(entries: Array[SpawnEntry], duration: float) -> Wave:
	var wave := Wave.new()
	wave.entries = entries
	wave.duration = duration
	return wave

static func default_waves() -> Array[Wave]:
	return [
		_wave([_entry(RUSHER, 8, 1.5)], 15.0),
		_wave([_entry(RUSHER, 8, 1.5), _entry(SWARMER, 20, 0.5)], 18.0),
		_wave([_entry(RUSHER, 6, 1.5), _entry(SWARMER, 16, 0.5), _entry(RANGED, 4, 3.0)], 20.0),
	]
