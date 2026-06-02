class_name WaveSpawner
extends Node
## Drives a sequence of Waves: schedules per-entry spawns, advances to the next
## wave after each wave's duration, and applies the DifficultyCurve multiplier
## for the current wave. Actual enemy instancing is delegated to spawn_handler:
##   spawn_handler.call(enemy_scene: PackedScene, hp_mult: float, speed_mult: float)
## so this scheduling logic is unit-testable without scenes or a hero.

signal wave_started(wave_index: int)
signal wave_completed(wave_index: int)
signal all_waves_completed

var waves: Array[Wave] = []
var difficulty: DifficultyCurve
var spawn_radius: float = 220.0
var spawn_handler: Callable

var current_wave_index: int = -1
var _wave_elapsed: float = 0.0
var _entry_timers: Array[float] = []
var _entry_remaining: Array[int] = []
var _finished: bool = false

func start() -> void:
	if waves.is_empty():
		_finished = true
		all_waves_completed.emit()
		return
	_begin_wave(0)

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if current_wave_index < 0 or _finished:
		return
	var wave := waves[current_wave_index]
	_wave_elapsed += delta
	for i in wave.entries.size():
		var entry := wave.entries[i]
		_entry_timers[i] += delta
		while _entry_remaining[i] > 0 and _entry_timers[i] >= entry.interval:
			_entry_timers[i] -= entry.interval
			_entry_remaining[i] -= 1
			_spawn(entry)
	if _wave_elapsed >= wave.duration:
		_complete_current_wave()

func stop() -> void:
	_finished = true

func _spawn(entry: SpawnEntry) -> void:
	if not spawn_handler.is_valid():
		return
	var hp_mult := 1.0
	var speed_mult := 1.0
	if difficulty:
		hp_mult = difficulty.hp_multiplier(current_wave_index)
		speed_mult = difficulty.speed_multiplier(current_wave_index)
	spawn_handler.call(entry.enemy_scene, hp_mult, speed_mult)

func _begin_wave(index: int) -> void:
	current_wave_index = index
	_wave_elapsed = 0.0
	_entry_timers.clear()
	_entry_remaining.clear()
	for entry in waves[index].entries:
		_entry_timers.append(0.0)
		_entry_remaining.append(entry.count)
	wave_started.emit(index)

func _complete_current_wave() -> void:
	var completed_index := current_wave_index
	wave_completed.emit(completed_index)
	if completed_index + 1 >= waves.size():
		_finished = true
		all_waves_completed.emit()
	else:
		_begin_wave(completed_index + 1)
