class_name LocalFileBackend
extends SaveBackend
## Saves to a Resource file under user:// (platform-specific user data dir).

var path: String = "user://oathfall_save.tres"

func save(data: SaveData) -> Error:
	return ResourceSaver.save(data, path)

func load() -> SaveData:
	if not FileAccess.file_exists(path):
		return null
	var resource := ResourceLoader.load(path)
	if resource is SaveData:
		return resource
	return null

func exists() -> bool:
	return FileAccess.file_exists(path)
