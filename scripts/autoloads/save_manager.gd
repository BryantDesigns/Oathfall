extends Node
## Owns the in-memory SaveData and delegates persistence to a SaveBackend.
## Backend can be swapped at runtime (local file → Steam Cloud → etc.).

const CURRENT_VERSION: int = 1

var backend: SaveBackend
var data: SaveData

func _ready() -> void:
	backend = LocalFileBackend.new()
	data = SaveData.new()
	if backend.exists():
		_load()

func set_backend(new_backend: SaveBackend) -> void:
	backend = new_backend

func save() -> Error:
	return backend.save(data)

func _load() -> void:
	var loaded := backend.load()
	if loaded == null:
		return
	data = migrate(loaded)

func load() -> void:
	_load()

## Apply schema migrations to bring older save versions to CURRENT_VERSION.
## Add a new branch here whenever save_version is bumped.
func migrate(input: SaveData) -> SaveData:
	var current := input
	# while current.save_version < CURRENT_VERSION:
	#     match current.save_version:
	#         1: current = _migrate_1_to_2(current)
	return current
