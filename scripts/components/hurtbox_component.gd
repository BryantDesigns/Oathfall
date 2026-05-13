class_name HurtboxComponent
extends Area2D
## Receives damage from any HitboxComponent that enters it, and forwards
## that damage to a sibling HealthComponent.

@export var health_path: NodePath
@export var invulnerable: bool = false

func _ready() -> void:
    area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
    if invulnerable:
        return
    if area is HitboxComponent:
        var health := get_node_or_null(health_path) as HealthComponent
        if health:
            health.take_damage(area.damage)
