class_name SaveData
extends Resource
## Versioned, serializable save state.
## Bump save_version when the schema changes and add a migration in
## SaveManager.

@export var save_version: int = 1
@export var run_count: int = 0
@export var wins: int = 0
@export var unlocked_upgrades: Array[String] = []
@export var unlocked_heroes: Array[String] = ["oathbreaker"]
