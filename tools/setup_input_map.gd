extends SceneTree

func _init() -> void:
    var key_actions := {
        "move_up": KEY_W,
        "move_down": KEY_S,
        "move_left": KEY_A,
        "move_right": KEY_D,
        "dash": KEY_SPACE,
        "ability_1": KEY_SHIFT,
        "pause": KEY_ESCAPE,
    }

    for action in key_actions:
        var ev := InputEventKey.new()
        ev.physical_keycode = key_actions[action]
        ProjectSettings.set_setting("input/" + action, {
            "deadzone": 0.5,
            "events": [ev],
        })

    var mb := InputEventMouseButton.new()
    mb.button_index = MOUSE_BUTTON_LEFT
    ProjectSettings.set_setting("input/attack", {
        "deadzone": 0.5,
        "events": [mb],
    })

    var err := ProjectSettings.save()
    if err != OK:
        printerr("Failed to save ProjectSettings: ", err)
        quit(1)
        return
    print("Input map written successfully")
    quit(0)
