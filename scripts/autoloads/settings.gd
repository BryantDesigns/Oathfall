extends Node
## User-configurable settings: audio, locale, accessibility.
## Persists to user://settings.cfg across runs.

const DEFAULT_PATH := "user://settings.cfg"

var _master_volume: float = 1.0
var _sfx_volume: float = 1.0
var _music_volume: float = 1.0
var locale: String = "en"

var master_volume: float:
	get: return _master_volume
	set(value): _master_volume = clampf(value, 0.0, 1.0)

var sfx_volume: float:
	get: return _sfx_volume
	set(value): _sfx_volume = clampf(value, 0.0, 1.0)

var music_volume: float:
	get: return _music_volume
	set(value): _music_volume = clampf(value, 0.0, 1.0)

func _ready() -> void:
	load_from(DEFAULT_PATH)

func reset_to_defaults() -> void:
	_master_volume = 1.0
	_sfx_volume = 1.0
	_music_volume = 1.0
	locale = "en"

func save_to(path: String) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", _master_volume)
	cfg.set_value("audio", "sfx", _sfx_volume)
	cfg.set_value("audio", "music", _music_volume)
	cfg.set_value("i18n", "locale", locale)
	cfg.save(path)

func load_from(path: String) -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(path)
	if err != OK:
		reset_to_defaults()
		return
	_master_volume = cfg.get_value("audio", "master", 1.0)
	_sfx_volume = cfg.get_value("audio", "sfx", 1.0)
	_music_volume = cfg.get_value("audio", "music", 1.0)
	locale = cfg.get_value("i18n", "locale", "en")
