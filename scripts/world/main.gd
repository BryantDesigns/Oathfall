extends Node
## Boot scene. Verifies all autoloads are present and prints the
## localized title. In M1 this becomes the title screen with Play.

func _ready() -> void:
	var ok := _verify_autoloads()
	var title := tr("GAME_TITLE")
	print("Booted: ", title, " | autoloads ok: ", ok)

func _verify_autoloads() -> bool:
	var required := ["EventBus", "RNG", "Settings", "SaveManager", "GameState"]
	for name in required:
		if not Engine.has_singleton(name) and get_node_or_null("/root/" + name) == null:
			push_error("Missing autoload: " + name)
			return false
	return true
