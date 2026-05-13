class_name XpGem
extends Area2D
## Drops at enemy death position. Idle until the hero enters magnet radius,
## then accelerates toward the hero and is consumed on contact.

@export var value: int = 1
@export var magnet_radius: float = 100.0
@export var magnet_speed: float = 200.0

var _target_hero: Node2D = null
var _magnetized: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if _target_hero == null:
		_target_hero = get_tree().get_first_node_in_group("hero")
		if _target_hero == null:
			return
	var distance_to_hero := global_position.distance_to(_target_hero.global_position)
	if not _magnetized and distance_to_hero <= magnet_radius:
		_magnetized = true
	if _magnetized:
		var direction_to_hero := (_target_hero.global_position - global_position).normalized()
		position += direction_to_hero * magnet_speed * delta

func _on_body_entered(body: Node) -> void:
	if body is Hero:
		var xp_component := body.get_node_or_null("XpComponent") as XpComponent
		if xp_component:
			xp_component.gain_xp(value)
		queue_free()
