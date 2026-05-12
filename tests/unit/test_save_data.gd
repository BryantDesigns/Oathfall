extends GutTest

func test_default_version_is_one() -> void:
    var data := SaveData.new()
    assert_eq(data.save_version, 1)

func test_default_run_count_is_zero() -> void:
    var data := SaveData.new()
    assert_eq(data.run_count, 0)

func test_default_unlocked_upgrades_is_empty_array() -> void:
    var data := SaveData.new()
    assert_eq(data.unlocked_upgrades, [])

func test_save_and_load_round_trip_via_resource_saver() -> void:
    var data := SaveData.new()
    data.run_count = 7
    data.unlocked_upgrades = ["dread_marks_2", "tetherhook_3"]

    var path := "user://test_save.tres"
    var save_err := ResourceSaver.save(data, path)
    assert_eq(save_err, OK)

    var loaded: SaveData = ResourceLoader.load(path)
    assert_eq(loaded.save_version, 1)
    assert_eq(loaded.run_count, 7)
    assert_eq(loaded.unlocked_upgrades, ["dread_marks_2", "tetherhook_3"])

    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
