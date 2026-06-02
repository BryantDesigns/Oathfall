extends GutTest

var _spawns: Array = []  # each element: [enemy_scene, hp_mult, speed_mult]

func _record(enemy_scene: PackedScene, hp_mult: float, speed_mult: float) -> void:
	_spawns.append([enemy_scene, hp_mult, speed_mult])

func _entry(count: int, interval: float) -> SpawnEntry:
	var entry := SpawnEntry.new()
	entry.count = count
	entry.interval = interval
	return entry

func _wave(entries: Array[SpawnEntry], duration: float) -> Wave:
	var wave := Wave.new()
	wave.entries = entries
	wave.duration = duration
	return wave

func _make_spawner(waves: Array[Wave]) -> WaveSpawner:
	var spawner := WaveSpawner.new()
	spawner.set_process(false)  # drive advance() manually in tests
	spawner.waves = waves
	spawner.spawn_handler = _record
	add_child_autofree(spawner)
	return spawner

func before_each() -> void:
	_spawns.clear()

func test_start_emits_wave_started() -> void:
	var spawner := _make_spawner([_wave([_entry(1, 1.0)], 3.0)])
	watch_signals(spawner)
	spawner.start()
	assert_eq(spawner.current_wave_index, 0)
	assert_signal_emitted_with_parameters(spawner, "wave_started", [0])

func test_spawns_all_enemies_then_completes() -> void:
	var spawner := _make_spawner([_wave([_entry(3, 1.0)], 3.0)])
	watch_signals(spawner)
	spawner.start()
	for _i in 3:
		spawner.advance(1.0)
	assert_eq(_spawns.size(), 3, "spawns one per interval")
	assert_signal_emit_count(spawner, "wave_completed", 1)
	assert_signal_emit_count(spawner, "all_waves_completed", 1)

func test_empty_wave_list_completes_immediately() -> void:
	var empty: Array[Wave] = []
	var spawner := _make_spawner(empty)
	watch_signals(spawner)
	spawner.start()
	assert_signal_emit_count(spawner, "all_waves_completed", 1)

func test_difficulty_multipliers_applied_per_wave() -> void:
	var curve := DifficultyCurve.new()
	curve.hp_growth_per_wave = 0.25
	curve.speed_growth_per_wave = 0.05
	var spawner := _make_spawner([
		_wave([_entry(1, 0.0)], 0.1),
		_wave([_entry(1, 0.0)], 0.1),
	])
	spawner.difficulty = curve
	spawner.start()
	spawner.advance(0.2)  # spawns wave 0, then advances to wave 1
	spawner.advance(0.2)  # spawns wave 1, then completes
	assert_eq(_spawns.size(), 2)
	assert_almost_eq(_spawns[0][1], 1.0, 0.001)   # wave 0 hp mult
	assert_almost_eq(_spawns[0][2], 1.0, 0.001)   # wave 0 speed mult
	assert_almost_eq(_spawns[1][1], 1.25, 0.001)  # wave 1 hp mult
	assert_almost_eq(_spawns[1][2], 1.05, 0.001)  # wave 1 speed mult

func test_two_entry_wave_schedules_independently() -> void:
	var spawner := _make_spawner([_wave([_entry(2, 1.0), _entry(1, 2.0)], 3.0)])
	spawner.start()
	spawner.advance(1.0)
	assert_eq(_spawns.size(), 1, "only entry[0] fires at t=1")
	spawner.advance(1.0)
	assert_eq(_spawns.size(), 3, "entry[0] fires again and entry[1] fires at t=2")
