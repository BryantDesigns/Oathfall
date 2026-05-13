extends Node
## Debug boot scene. Not used as the runtime main_scene anymore (that's
## scenes/world/run.tscn from M1 onward). Kept for autoload smoke-checks
## and CI's boot verification — invoke directly with --main-pack.

func _ready() -> void:
	var all_autoloads_present := _verify_autoloads()
	var title := tr("GAME_TITLE")
	print("Booted: ", title, " | autoloads ok: ", all_autoloads_present)
	# Quit after one frame so this is safe to use in CI
	if OS.has_feature("headless"):
		await get_tree().process_frame
		get_tree().quit()

func _verify_autoloads() -> bool:
	var required_autoloads := ["EventBus", "RNG", "Settings", "SaveManager", "GameState"]
	for autoload_name in required_autoloads:
		if get_node_or_null("/root/" + autoload_name) == null:
			push_error("Missing autoload: " + autoload_name)
			return false
	return true
