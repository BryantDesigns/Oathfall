class_name RangedEnemy
extends Enemy
## Ranged archetype (lore: The Keening). Holds at a preferred distance from the
## hero and fires EnemyProjectiles on cooldown. Approaches if too far, kites if
## too close. No contact damage — the threat is its ranged fire.

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/projectiles/enemy_projectile.tscn")

@export var preferred_distance: float = 180.0
@export var distance_buffer: float = 30.0
@export var fire_range: float = 240.0
@export var fire_cooldown: float = 2.5
@export var projectile_damage: int = 8

var _target_hero: Node2D = null
var _fire_timer: float = 0.0

func _ready() -> void:
	super()
	add_to_group("enemies")

func _physics_process(_delta: float) -> void:
	if _target_hero == null:
		_target_hero = get_tree().get_first_node_in_group("hero")
		if _target_hero == null:
			return
	var distance := global_position.distance_to(_target_hero.global_position)
	var intent := movement_intent(distance)
	if intent == 0:
		velocity = Vector2.ZERO
	else:
		var direction := (_target_hero.global_position - global_position).normalized()
		velocity = direction * move_speed * float(intent)
	move_and_slide()

func _process(delta: float) -> void:
	_fire_timer = max(0.0, _fire_timer - delta)
	if _target_hero == null:
		return
	var distance := global_position.distance_to(_target_hero.global_position)
	if distance <= fire_range and _fire_timer == 0.0:
		_fire()
		_fire_timer = fire_cooldown

## +1 = approach, -1 = kite away, 0 = hold. Pure function for testability.
func movement_intent(distance_to_hero: float) -> int:
	if distance_to_hero > preferred_distance + distance_buffer:
		return 1
	if distance_to_hero < preferred_distance - distance_buffer:
		return -1
	return 0

func _fire() -> void:
	var direction := (_target_hero.global_position - global_position).normalized()
	var projectile := PROJECTILE_SCENE.instantiate() as EnemyProjectile
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position
	projectile.configure(direction, projectile_damage, self)
