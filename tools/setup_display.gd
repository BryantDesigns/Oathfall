extends SceneTree

func _init() -> void:
	ProjectSettings.set_setting("display/window/size/viewport_width", 480)
	ProjectSettings.set_setting("display/window/size/viewport_height", 270)
	ProjectSettings.set_setting("display/window/size/window_width_override", 1920)
	ProjectSettings.set_setting("display/window/size/window_height_override", 1080)
	ProjectSettings.set_setting("display/window/stretch/mode", "viewport")
	ProjectSettings.set_setting("display/window/stretch/aspect", "keep")
	ProjectSettings.set_setting("rendering/textures/canvas_textures/default_texture_filter", 0)  # Nearest

	var err := ProjectSettings.save()
	if err != OK:
		printerr("Failed to save ProjectSettings: ", err)
		quit(1)
		return
	print("Display settings written: 480x270 viewport, 1920x1080 window, keep aspect, nearest filter")
	quit(0)
