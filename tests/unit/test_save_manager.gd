extends GutTest

const TEST_PATH := "user://test_sm_save.tres"

func before_each() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	var backend := LocalFileBackend.new()
	backend.path = TEST_PATH
	SaveManager.set_backend(backend)
	SaveManager.data = SaveData.new()

func test_default_backend_is_set_after_ready() -> void:
	assert_not_null(SaveManager.backend)

func test_save_persists_data_via_backend() -> void:
	SaveManager.data.run_count = 5
	var err := SaveManager.save()
	assert_eq(err, OK)

	var raw_loaded: SaveData = ResourceLoader.load(TEST_PATH)
	assert_eq(raw_loaded.run_count, 5)

func test_load_replaces_in_memory_data() -> void:
	SaveManager.data.run_count = 99
	SaveManager.save()

	SaveManager.data = SaveData.new()
	assert_eq(SaveManager.data.run_count, 0)

	SaveManager.load()
	assert_eq(SaveManager.data.run_count, 99)

func test_load_no_file_keeps_fresh_data() -> void:
	SaveManager.data = SaveData.new()
	SaveManager.data.run_count = 7
	SaveManager.load()
	assert_eq(SaveManager.data.run_count, 7, "Load with no file is a no-op")

func test_migrate_v1_to_v1_is_noop() -> void:
	var data := SaveData.new()
	data.save_version = 1
	var migrated := SaveManager.migrate(data)
	assert_eq(migrated.save_version, 1)
	assert_same(data, migrated)
