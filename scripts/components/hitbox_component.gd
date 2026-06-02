class_name HitboxComponent
extends Area2D
## Carries damage when it overlaps a HurtboxComponent. Set damage at spawn
## (projectile) or once at scene load (enemy contact-damage hitbox).

@export var damage: int = 1
var source: Node = null  ## who created this hitbox (for telemetry / friendly fire)
