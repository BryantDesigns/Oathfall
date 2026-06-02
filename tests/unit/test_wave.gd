extends GutTest

func _entry(count: int) -> SpawnEntry:
	var entry := SpawnEntry.new()
	entry.count = count
	return entry

func test_defaults() -> void:
	var wave := Wave.new()
	assert_eq(wave.entries, [])
	assert_almost_eq(wave.duration, 15.0, 0.001)

func test_total_enemy_count_empty_is_zero() -> void:
	assert_eq(Wave.new().total_enemy_count(), 0)

func test_total_enemy_count_sums_entries() -> void:
	var wave := Wave.new()
	wave.entries = [_entry(8), _entry(20), _entry(4)]
	assert_eq(wave.total_enemy_count(), 32)
