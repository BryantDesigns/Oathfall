class_name Swarmer
extends Enemy
## Swarmer archetype (lore: The Fragments). Individually trivial — 1 HP, fast,
## low contact damage — but lethal in numbers. Same straight-line chase as the
## Rusher; the threat comes from spawn count, configured in the wave.

var _target_hero: Node2D = null

func _ready() -> void:
	super()
	add_to_group("enemies")

func _physics_process(_delta: float) -> void:
	if _target_hero == null:
		_target_hero = get_tree().get_first_node_in_group("hero")
		if _target_hero == null:
			return
	chase(_target_hero)
