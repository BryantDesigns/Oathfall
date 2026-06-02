class_name TetherChain
extends Area2D
## Travels in a line until it hits an enemy. On hit, pulls that enemy toward
## the source hero over a brief duration, then despawns.

@export var speed: float = 600.0
@export var max_range: float = 250.0
@export var pull_speed: float = 800.0
@export var pull_target_distance: float = 30.0

enum Phase { FLYING, PULLING, DONE }

var _direction: Vector2 = Vector2.RIGHT
var _origin_position: Vector2
var _source_hero: Node2D = null
var _hooked_enemy: Node2D = null
var _phase: int = Phase.FLYING

func configure(direction: Vector2, source: Node2D) -> void:
	_direction = direction.normalized()
	_source_hero = source
	_origin_position = source.global_position
	rotation = _direction.angle()
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	match _phase:
		Phase.FLYING:
			position += _direction * speed * delta
			if global_position.distance_to(_origin_position) >= max_range:
				queue_free()
		Phase.PULLING:
			if _hooked_enemy == null or _source_hero == null:
				queue_free()
				return
			var toward_source := _source_hero.global_position - _hooked_enemy.global_position
			if toward_source.length() <= pull_target_distance:
				queue_free()
				return
			var pull_direction := toward_source.normalized()
			_hooked_enemy.global_position += pull_direction * pull_speed * delta
			global_position = _hooked_enemy.global_position

func _on_area_entered(area: Area2D) -> void:
	if _phase != Phase.FLYING:
		return
	if area is HurtboxComponent:
		var target := area.get_parent() as Node2D
		if target is Enemy:
			_hooked_enemy = target
			_phase = Phase.PULLING

func _on_body_entered(_body: Node) -> void:
	if _phase == Phase.FLYING:
		queue_free()
