extends Node
## Run controller. Owns the active arena, hero, HUD, modal, and wave spawner.
## Reacts to leveled_up (opens modal), run_ended (results), and
## all_waves_completed (victory).

const ARENA_SCENE: PackedScene = preload("res://scenes/rooms/arena_m1.tscn")
const HERO_SCENE: PackedScene = preload("res://scenes/heroes/dreadhunter.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/hud.tscn")
const MODAL_SCENE: PackedScene = preload("res://scenes/ui/level_up_modal.tscn")
const RESULTS_SCENE: PackedScene = preload("res://scenes/ui/results_screen.tscn")
const DIFFICULTY_CURVE: DifficultyCurve = preload("res://resources/difficulty_curve.tres")

var _hero: Dreadhunter
var _xp_component: XpComponent
var _hud: HUD
var _level_up_modal: LevelUpModal
var _arena: Node
var _wave_spawner: WaveSpawner
var _results_shown: bool = false

func _ready() -> void:
	GameState.start_run("dreadhunter", int(Time.get_ticks_usec()))
	SaveManager.data.run_count += 1
	SaveManager.save()

	_arena = ARENA_SCENE.instantiate()
	add_child(_arena)

	_hero = HERO_SCENE.instantiate() as Dreadhunter
	_hero.global_position = Vector2.ZERO
	add_child(_hero)

	_xp_component = _hero.get_node("XpComponent") as XpComponent
	_xp_component.leveled_up.connect(_on_leveled_up)

	_hud = HUD_SCENE.instantiate() as HUD
	add_child(_hud)
	_hud.bind_to(_hero, _xp_component)

	_level_up_modal = MODAL_SCENE.instantiate() as LevelUpModal
	add_child(_level_up_modal)
	_level_up_modal.upgrade_chosen.connect(_on_upgrade_chosen)

	EventBus.run_ended.connect(_on_run_ended)

	_wave_spawner = WaveSpawner.new()
	_wave_spawner.waves = WaveLibrary.default_waves()
	_wave_spawner.difficulty = DIFFICULTY_CURVE
	_wave_spawner.spawn_handler = _spawn_enemy
	_wave_spawner.all_waves_completed.connect(_on_all_waves_completed)
	add_child(_wave_spawner)
	_wave_spawner.start()

func _on_leveled_up(_level: int) -> void:
	_level_up_modal.open()

func _on_upgrade_chosen(upgrade: Upgrade) -> void:
	upgrade.apply(_hero)

func _on_all_waves_completed() -> void:
	EventBus.run_ended.emit(true)

func _on_run_ended(_won: bool) -> void:
	if _results_shown:
		return
	_results_shown = true
	_wave_spawner.stop()
	var results_screen := RESULTS_SCENE.instantiate()
	add_child(results_screen)

func _spawn_enemy(enemy_scene: PackedScene, hp_multiplier: float, speed_multiplier: float) -> void:
	if _hero == null or _hero.health.is_dead():
		return
	var spawn_angle := RNG.randf_range(0.0, TAU)
	var spawn_offset := Vector2.RIGHT.rotated(spawn_angle) * _wave_spawner.spawn_radius
	var enemy := enemy_scene.instantiate() as Enemy
	add_child(enemy)
	enemy.global_position = _hero.global_position + spawn_offset
	enemy.apply_difficulty(hp_multiplier, speed_multiplier)
