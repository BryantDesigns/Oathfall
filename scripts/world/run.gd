extends Node
## Run controller. Owns the active arena, hero, HUD, and modal. Spawns
## enemies on a timer. Reacts to leveled_up (opens modal) and run_ended.

const ARENA_SCENE: PackedScene = preload("res://scenes/rooms/arena_m1.tscn")
const HERO_SCENE: PackedScene = preload("res://scenes/heroes/dreadhunter.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/hud.tscn")
const MODAL_SCENE: PackedScene = preload("res://scenes/ui/level_up_modal.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/melee_chaser.tscn")
const RESULTS_SCENE: PackedScene = preload("res://scenes/ui/results_screen.tscn")

const SPAWN_RING_RADIUS: float = 220.0
const SPAWN_INTERVAL: float = 1.5

var _hero: Dreadhunter
var _xp_component: XpComponent
var _hud: HUD
var _level_up_modal: LevelUpModal
var _arena: Node
var _spawn_timer: Timer

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

	_spawn_timer = _arena.get_node("EnemySpawnTimer") as Timer
	_spawn_timer.timeout.connect(_spawn_enemy)

func _on_leveled_up(_level: int) -> void:
	_level_up_modal.open()

func _on_upgrade_chosen(upgrade: Upgrade) -> void:
	upgrade.apply(_hero)

func _on_run_ended(_won: bool) -> void:
	_spawn_timer.stop()
	var results_screen := RESULTS_SCENE.instantiate()
	add_child(results_screen)

func _spawn_enemy() -> void:
	if _hero == null or _hero.health.is_dead():
		return
	var spawn_angle := RNG.randf_range(0.0, TAU)
	var spawn_offset := Vector2.RIGHT.rotated(spawn_angle) * SPAWN_RING_RADIUS
	var spawn_position := _hero.global_position + spawn_offset
	var enemy := ENEMY_SCENE.instantiate() as MeleeChaser
	enemy.global_position = spawn_position
	add_child(enemy)
