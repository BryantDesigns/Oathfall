extends GutTest

func test_defaults() -> void:
	var entry := SpawnEntry.new()
	assert_eq(entry.count, 1)
	assert_almost_eq(entry.interval, 1.0, 0.001)
	assert_null(entry.enemy_scene)

func test_fields_assignable() -> void:
	var entry := SpawnEntry.new()
	entry.count = 8
	entry.interval = 1.5
	assert_eq(entry.count, 8)
	assert_almost_eq(entry.interval, 1.5, 0.001)
