class_name Upgrade
extends Resource
## Data-driven upgrade. Each instance carries an id, display fields, and
## the deltas it applies. Designed to be stacked: apply() can be called
## multiple times, unapply() reverses one stack.
##
## M1 supports three stat kinds: max_hp_pct, salvo_damage_flat, move_speed_pct.
## Add new kinds as needed; keep them additive so order-of-application
## doesn't change outcomes.

@export var id: StringName
@export_multiline var description: String
@export var max_hp_pct: float = 0.0       ## e.g. 0.20 = +20% max HP
@export var salvo_damage_flat: int = 0    ## e.g. 1 = +1 damage per bolt
@export var move_speed_pct: float = 0.0   ## e.g. 0.15 = +15% move speed

func apply(hero: Object) -> void:
    if max_hp_pct != 0.0 and hero.health:
        var hp_bonus := int(round(hero.health.max_hp * max_hp_pct))
        hero.health.set_max_hp(hero.health.max_hp + hp_bonus)
        hero.health.heal(hp_bonus)
    if salvo_damage_flat != 0:
        hero.salvo_damage += salvo_damage_flat
    if move_speed_pct != 0.0:
        hero.move_speed *= (1.0 + move_speed_pct)

func unapply(hero: Object) -> void:
    if max_hp_pct != 0.0 and hero.health:
        var hp_bonus := int(round(hero.health.max_hp * max_hp_pct / (1.0 + max_hp_pct)))
        hero.health.set_max_hp(hero.health.max_hp - hp_bonus)
    if salvo_damage_flat != 0:
        hero.salvo_damage -= salvo_damage_flat
    if move_speed_pct != 0.0:
        hero.move_speed /= (1.0 + move_speed_pct)
