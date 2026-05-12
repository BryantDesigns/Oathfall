class_name SaveBackend
extends RefCounted
## Abstract save backend. Subclasses implement against a specific platform.
## Methods return OK on success or a non-OK Error on failure.

func save(data: SaveData) -> Error:
    push_error("SaveBackend.save() must be overridden")
    return ERR_METHOD_NOT_FOUND

func load() -> SaveData:
    push_error("SaveBackend.load() must be overridden")
    return null

func exists() -> bool:
    push_error("SaveBackend.exists() must be overridden")
    return false
