extends SceneTree
## Smoke-loads and instantiates a scene passed after `--`. Prints OK or FAILED.

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("usage: godot --headless --script tools/_check_scene.gd -- <res://path.tscn>")
		quit(1)
		return
	var path := args[0]
	var packed := load(path) as PackedScene
	if packed == null:
		printerr("FAILED to load ", path)
		quit(1)
		return
	var instance := packed.instantiate()
	if instance == null:
		printerr("FAILED to instantiate ", path)
		quit(1)
		return
	instance.queue_free()
	print("OK ", path)
	quit(0)
