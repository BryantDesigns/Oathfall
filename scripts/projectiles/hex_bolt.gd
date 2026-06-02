class_name HexBolt
extends Area2D
## Linear-flight projectile. Carries its own HitboxComponent child.
## Configured by spawner: direction, damage, source.

@export var speed: float = 300.0
@export var lifetime: float = 1.5

var _direction: Vector2 = Vector2.RIGHT
var _elapsed: float = 0.0

@onready var _hitbox: HitboxComponent = $HitboxComponent

func configure(direction: Vector2, damage: int, source: Node) -> void:
	_direction = direction.normalized()
	_hitbox.damage = damage
	_hitbox.source = source
	rotation = _direction.angle()

func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= lifetime:
		queue_free()
		return
	position += _direction * speed * delta

func _on_body_entered(_body: Node) -> void:
	queue_free()  # despawn on wall hit
