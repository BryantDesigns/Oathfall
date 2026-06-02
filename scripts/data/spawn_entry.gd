class_name SpawnEntry
extends Resource
## One enemy type within a Wave: which scene, how many, and how often.

@export var enemy_scene: PackedScene
@export var count: int = 1
@export var interval: float = 1.0  ## seconds between spawns of this entry
