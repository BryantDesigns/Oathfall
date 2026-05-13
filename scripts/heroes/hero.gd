class_name Hero
extends CharacterBody2D
## Base class for all heroes. Handles movement and component refs.
## Subclasses (Dreadhunter, etc.) add abilities.

@export var move_speed: float = 150.0
@export var health_path: NodePath
@export var hurtbox_path: NodePath

var health: HealthComponent
var hurtbox: HurtboxComponent
var aim: AimProvider

func _ready() -> void:
    health = get_node_or_null(health_path) as HealthComponent
    hurtbox = get_node_or_null(hurtbox_path) as HurtboxComponent
    if health == null:
        push_error("Hero requires HealthComponent at health_path")
    if hurtbox == null:
        push_error("Hero requires HurtboxComponent at hurtbox_path")
    aim = MouseAimProvider.new(self)
    health.died.connect(_on_died)

func _physics_process(_delta: float) -> void:
    var input_vector := Vector2(
        Input.get_axis("move_left", "move_right"),
        Input.get_axis("move_up", "move_down"),
    )
    if input_vector.length_squared() > 0:
        input_vector = input_vector.normalized()
    velocity = input_vector * move_speed
    move_and_slide()

func aim_direction() -> Vector2:
    return aim.aim_direction(global_position)

func _on_died() -> void:
    EventBus.run_ended.emit(false)
    set_physics_process(false)
