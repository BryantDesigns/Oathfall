extends GutTest

const TEST_PATH := "user://test_local_file_save.tres"

func _make_backend() -> LocalFileBackend:
	var backend := LocalFileBackend.new()
	backend.path = TEST_PATH
	return backend

func before_each() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))

func test_exists_false_when_no_file() -> void:
	assert_false(_make_backend().exists())

func test_save_then_exists_true() -> void:
	var backend := _make_backend()
	var data := SaveData.new()
	backend.save(data)
	assert_true(backend.exists())

func test_save_then_load_round_trip() -> void:
	var backend := _make_backend()
	var data := SaveData.new()
	data.run_count = 13
	data.unlocked_upgrades = ["a", "b"]
	var err: Error = backend.save(data)
	assert_eq(err, OK)

	var loaded: SaveData = backend.load()
	assert_not_null(loaded)
	assert_eq(loaded.run_count, 13)
	assert_eq(loaded.unlocked_upgrades, ["a", "b"])

func test_load_returns_null_when_missing() -> void:
	assert_null(_make_backend().load())
