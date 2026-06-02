class_name Enemy
extends CharacterBody2D
## Base class for enemies. Composes HealthComponent + HurtboxComponent +
## HitboxComponent. Concrete enemies add AI in _physics_process. On death,
## drops an XP gem worth xp_value.

const XP_GEM_SCENE: PackedScene = preload("res://scenes/pickups/xp_gem.tscn")

@export var move_speed: float = 70.0
@export var health_path: NodePath
@export var hurtbox_path: NodePath
@export var xp_value: int = 1

var health: HealthComponent
var hurtbox: HurtboxComponent

func _ready() -> void:
	health = get_node_or_null(health_path) as HealthComponent
	hurtbox = get_node_or_null(hurtbox_path) as HurtboxComponent
	if health:
		health.died.connect(_on_died)

## Scale stats for the wave this enemy spawned in. Called by the spawner AFTER
## the enemy is added to the tree (so health is resolved).
func apply_difficulty(hp_multiplier: float, speed_multiplier: float) -> void:
	move_speed *= speed_multiplier
	if health == null:
		health = get_node_or_null(health_path) as HealthComponent
	if health:
		var scaled_hp := int(round(health.max_hp * hp_multiplier))
		health.set_max_hp(scaled_hp)
		health.current_hp = health.max_hp

## Velocity vector from `from` toward `to` at `speed`. Returns ZERO if the
## points are effectively coincident. Static so it is trivially testable.
static func velocity_toward(from: Vector2, to: Vector2, speed: float) -> Vector2:
	var offset := to - from
	if offset.length_squared() <= 1.0:
		return Vector2.ZERO
	return offset.normalized() * speed

func _on_died() -> void:
	EventBus.enemy_died.emit(xp_value)
	_on_pre_free()
	queue_free()

## Drop an XP gem worth this enemy's xp_value at its death position.
func _on_pre_free() -> void:
	var xp_gem := XP_GEM_SCENE.instantiate()
	xp_gem.value = xp_value
	xp_gem.global_position = global_position
	get_tree().current_scene.add_child(xp_gem)
