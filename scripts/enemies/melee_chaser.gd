class_name MeleeChaser
extends Enemy
## Rusher archetype (lore: The Grasp). Walks at the hero in a straight line and
## deals contact damage on overlap. XP drop is handled by the Enemy base.

var _target_hero: Node2D = null

func _ready() -> void:
	super()
	add_to_group("enemies")

func _physics_process(_delta: float) -> void:
	if _target_hero == null:
		_target_hero = get_tree().get_first_node_in_group("hero")
		if _target_hero == null:
			return
	velocity = Enemy.velocity_toward(global_position, _target_hero.global_position, move_speed)
	move_and_slide()
