class_name MouseAimProvider
extends AimProvider
## Reads the global mouse position from a viewport. Constructed with a
## CanvasItem (the hero or a node in its tree) to pick up the right viewport.

var _canvas_item: CanvasItem

func _init(canvas_item: CanvasItem) -> void:
    _canvas_item = canvas_item

func aim_world_point(_origin: Vector2) -> Vector2:
    return _canvas_item.get_global_mouse_position()
