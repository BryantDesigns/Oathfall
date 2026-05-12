extends GutTest

const TEST_PATH := "user://settings_test.cfg"

func before_each() -> void:
    if FileAccess.file_exists(TEST_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))

func test_default_master_volume_is_one() -> void:
    Settings.reset_to_defaults()
    assert_eq(Settings.master_volume, 1.0)

func test_set_master_volume_clamps_to_unit_interval() -> void:
    Settings.master_volume = 1.5
    assert_eq(Settings.master_volume, 1.0)
    Settings.master_volume = -0.5
    assert_eq(Settings.master_volume, 0.0)

func test_save_and_load_round_trip() -> void:
    Settings.master_volume = 0.42
    Settings.locale = "fr"
    Settings.save_to(TEST_PATH)

    Settings.reset_to_defaults()
    assert_eq(Settings.master_volume, 1.0)

    Settings.load_from(TEST_PATH)
    assert_eq(Settings.master_volume, 0.42)
    assert_eq(Settings.locale, "fr")
