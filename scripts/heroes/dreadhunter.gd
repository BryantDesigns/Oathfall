class_name Dreadhunter
extends Hero
## Dreadhunter — ranged DPS hero.
## M1 abilities: Hex-Bolt Salvo (base attack), Tetherhook (ability_1).
## Tetherhook is wired in Task 12.

const HEX_BOLT_SCENE: PackedScene = preload("res://scenes/projectiles/hex_bolt.tscn")
const TETHER_SCENE: PackedScene = preload("res://scenes/projectiles/tether_chain.tscn")

@export var salvo_count: int = 3
@export var salvo_spread_degrees: float = 8.0
@export var salvo_damage: int = 1
@export var salvo_cooldown: float = 0.5
@export var tether_cooldown: float = 0.4

var _salvo_timer: float = 0.0
var _tether_timer: float = 0.0

func _process(delta: float) -> void:
	_salvo_timer = max(0.0, _salvo_timer - delta)
	if Input.is_action_pressed("attack") and _salvo_timer == 0.0:
		_fire_salvo()
		_salvo_timer = salvo_cooldown
	_tether_timer = max(0.0, _tether_timer - delta)
	if Input.is_action_just_pressed("ability_1") and _tether_timer == 0.0:
		_fire_tether()
		_tether_timer = tether_cooldown

func _fire_salvo() -> void:
	var base_direction := aim_direction()
	var half_spread_radians := deg_to_rad(salvo_spread_degrees) * 0.5
	var angle_step := 0.0
	if salvo_count > 1:
		angle_step = (half_spread_radians * 2.0) / float(salvo_count - 1)
	for i in salvo_count:
		var angle_offset := -half_spread_radians + angle_step * float(i)
		var bolt_direction := base_direction.rotated(angle_offset)
		var bolt := HEX_BOLT_SCENE.instantiate() as HexBolt
		get_tree().current_scene.add_child(bolt)
		bolt.global_position = global_position
		bolt.configure(bolt_direction, salvo_damage, self)

func _fire_tether() -> void:
	var tether := TETHER_SCENE.instantiate() as TetherChain
	get_tree().current_scene.add_child(tether)
	tether.global_position = global_position
	tether.configure(aim_direction(), self)

func _ready() -> void:
	super()
	add_to_group("hero")
