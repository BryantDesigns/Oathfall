class_name Enemy
extends CharacterBody2D
## Base class for enemies. Composes HealthComponent + HurtboxComponent +
## HitboxComponent. Concrete enemies add AI in _physics_process.

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

func _on_died() -> void:
    EventBus.enemy_died.emit(xp_value)
    _on_pre_free()
    queue_free()

## Override for drop behavior (XP gems handled in MeleeChaser for M1).
func _on_pre_free() -> void:
    pass
