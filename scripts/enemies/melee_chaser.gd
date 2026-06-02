class_name MeleeChaser
extends Enemy
## Walks at the hero in a straight line. Deals contact damage on overlap.
## XP gem drop is wired in Task 11.

const XP_GEM_SCENE: PackedScene = preload("res://scenes/pickups/xp_gem.tscn")

var _target_hero: Node2D = null

func _ready() -> void:
	super()
	add_to_group("enemies")

func _physics_process(_delta: float) -> void:
	if _target_hero == null:
		_target_hero = get_tree().get_first_node_in_group("hero")
		if _target_hero == null:
			return
	var toward_hero := (_target_hero.global_position - global_position)
	if toward_hero.length_squared() > 1.0:
		velocity = toward_hero.normalized() * move_speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()

func _on_pre_free() -> void:
	var xp_gem := XP_GEM_SCENE.instantiate()
	xp_gem.global_position = global_position
	get_tree().current_scene.add_child(xp_gem)
