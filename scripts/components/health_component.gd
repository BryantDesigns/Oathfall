class_name HealthComponent
extends Node
## Numeric HP holder. Composes onto Hero, Enemy, or anything destructible.
## Does not know about hitboxes/hurtboxes — those route damage in by calling
## take_damage(). Emits signals for HUD bindings and death handling.

signal health_changed(current: int, maximum: int)
signal died

@export var max_hp: int = 100
var current_hp: int = 100
var _dead: bool = false

func _ready() -> void:
    current_hp = max_hp

func take_damage(amount: int) -> void:
    if _dead or amount <= 0:
        return
    current_hp = max(0, current_hp - amount)
    health_changed.emit(current_hp, max_hp)
    if current_hp == 0:
        _dead = true
        died.emit()

func heal(amount: int) -> void:
    if _dead or amount <= 0:
        return
    current_hp = min(max_hp, current_hp + amount)
    health_changed.emit(current_hp, max_hp)

func is_dead() -> bool:
    return _dead

func set_max_hp(new_max: int) -> void:
    max_hp = max(1, new_max)
    current_hp = min(current_hp, max_hp)
    health_changed.emit(current_hp, max_hp)
