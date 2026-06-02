# M2a — Wave System & Enemy Roster Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. All commits should end with the `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>` trailer per repo convention.

**Goal:** Replace M1's single-timer melee spawner with a data-driven wave system that spawns three enemy archetypes (Rusher, Swarmer, Ranged) across escalating waves with per-wave difficulty scaling, ending the run when all waves are cleared.

**Architecture:** Enemy archetypes build on the existing `Enemy` base (`CharacterBody2D` + Health/Hurtbox/Hitbox components). M1's `MeleeChaser` becomes the Rusher; we add a `Swarmer` (low HP, high count) and a `RangedEnemy` (kites and fires an `EnemyProjectile`). Spawning is data-driven: `SpawnEntry` and `Wave` resources describe what spawns and when; a `WaveSpawner` node schedules spawns, advances waves, applies a `DifficultyCurve` multiplier, and emits lifecycle signals. The `Run` controller injects a spawn handler (instancing + positioning) so the spawner's scheduling logic stays pure and unit-testable.

**Tech Stack:** Godot 4.6.2 (GDScript), GUT for tests, all M1 infrastructure (5 autoloads, EventBus, RNG, component pattern, XpGem pickup, Run controller).

**This is M2a of a sequenced M2.** Later sub-plans (each its own document): M2b Dread Marks & Upgrade Pool, M2c Boss Fight, M2d Meta Progression & Telemetry, M2e Steam Integration. Oathbreaker (confirmed in M2 scope) lands in its own hero sub-plan.

**Tuning baseline (prototype scale — design-doc final numbers are deferred to a balance pass):**
- Rusher (MeleeChaser, existing): 3 HP, 70 px/s, 10 contact dmg, xp 1
- Swarmer: 1 HP, 110 px/s, 5 contact dmg, xp 1 — spawns in large counts
- Ranged: 4 HP, 60 px/s, no contact dmg, fires every 2.5s, projectile 180 px/s / 8 dmg, preferred distance 180 px, xp 2
- Difficulty: +25% enemy HP and +5% enemy move speed per wave index (wave 0 = ×1.0)
- Waves: W1 rushers only; W2 rushers + swarmers; W3 rushers + swarmers + ranged

---

## File Structure

```
Oathfall/
├── scripts/
│   ├── data/
│   │   ├── spawn_entry.gd          # NEW — one enemy type's spawn config
│   │   ├── wave.gd                 # NEW — a wave (entries + duration)
│   │   ├── difficulty_curve.gd     # NEW — per-wave stat multipliers
│   │   └── wave_library.gd         # NEW — static factory for the M2a wave sequence
│   ├── enemies/
│   │   ├── enemy.gd                # MODIFY — apply_difficulty(), chase helper, base XP drop
│   │   ├── melee_chaser.gd         # MODIFY — drop via base, use chase helper (Rusher)
│   │   ├── swarmer.gd              # NEW — Swarmer archetype (lore: The Fragments)
│   │   └── ranged_enemy.gd         # NEW — Ranged archetype (lore: The Keening)
│   ├── projectiles/
│   │   └── enemy_projectile.gd     # NEW — hostile bolt fired by RangedEnemy
│   ├── systems/
│   │   └── wave_spawner.gd         # NEW — schedules spawns, advances waves
│   └── world/
│       └── run.gd                  # MODIFY — drive WaveSpawner instead of arena Timer
├── scenes/
│   ├── enemies/
│   │   ├── swarmer.tscn            # NEW
│   │   └── ranged_enemy.tscn       # NEW
│   └── projectiles/
│       └── enemy_projectile.tscn   # NEW
├── resources/
│   └── difficulty_curve.tres       # NEW
├── tools/
│   └── _check_scene.gd             # NEW (temporary; deleted in final task)
└── tests/unit/
    ├── test_spawn_entry.gd         # NEW
    ├── test_wave.gd                # NEW
    ├── test_difficulty_curve.gd    # NEW
    ├── test_enemy.gd               # NEW (apply_difficulty + velocity_toward)
    ├── test_ranged_enemy.gd        # NEW (movement_intent)
    ├── test_wave_library.gd        # NEW
    └── test_wave_spawner.gd        # NEW
```

**File responsibilities:**
- `spawn_entry.gd` / `wave.gd` / `difficulty_curve.gd`: pure data Resources, no scene/tree dependencies.
- `wave_library.gd`: a code factory returning the prototype wave list (designer-tunable here; `.tres`-authored waves are a future enhancement, deferred to keep array-of-subresource authoring out of scope).
- `wave_spawner.gd`: scheduling + wave lifecycle only. Actual instancing is delegated to an injected `spawn_handler` Callable so the logic is unit-testable headlessly.
- Enemy scripts: AI in `_physics_process`; shared movement via the base `chase()` helper.
- `run.gd`: owns the spawner, supplies the spawn handler, reacts to `all_waves_completed`.

---

## Pre-Flight

- [ ] **Step 1: Confirm M1 is the current tip and tests are green**

```bash
cd /Users/bryantdesigns/Documents/projects/misc/Oathfall
git status
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gdir=res://tests/smoke -gexit 2>&1 | tail -6
```

Expected: clean working tree on `m1-prototype-core`; "52 passing" (or higher).

- [ ] **Step 2: Create the feature branch off M1**

```bash
git checkout -b m2a-wave-system-enemies m1-prototype-core
```

> [!note] M1 PR is still open. Branch off `m1-prototype-core` so this work stacks on M1. When opening the M2a PR, base it on `main` after M1 merges (or on `m1-prototype-core` if reviewing as a stack).

---

## Task 1: SpawnEntry resource

**Files:**
- Create: `scripts/data/spawn_entry.gd`
- Create: `tests/unit/test_spawn_entry.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_spawn_entry.gd`:

```gdscript
extends GutTest

func test_defaults() -> void:
	var entry := SpawnEntry.new()
	assert_eq(entry.count, 1)
	assert_almost_eq(entry.interval, 1.0, 0.001)
	assert_null(entry.enemy_scene)

func test_fields_assignable() -> void:
	var entry := SpawnEntry.new()
	entry.count = 8
	entry.interval = 1.5
	assert_eq(entry.count, 8)
	assert_almost_eq(entry.interval, 1.5, 0.001)
```

- [ ] **Step 2: Run red**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_spawn_entry.gd -gexit
```

Expected: fail — `SpawnEntry` not defined.

- [ ] **Step 3: Implement**

Create `scripts/data/spawn_entry.gd`:

```gdscript
class_name SpawnEntry
extends Resource
## One enemy type within a Wave: which scene, how many, and how often.

@export var enemy_scene: PackedScene
@export var count: int = 1
@export var interval: float = 1.0  ## seconds between spawns of this entry
```

- [ ] **Step 4: Run green**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_spawn_entry.gd -gexit
```

Expected: 2/2 passed.

- [ ] **Step 5: Commit**

```bash
git add scripts/data/spawn_entry.gd tests/unit/test_spawn_entry.gd
git add scripts/data/*.uid tests/unit/*.uid 2>/dev/null || true
git commit -m "feat: add SpawnEntry resource for wave configuration"
```

---

## Task 2: Wave resource

**Files:**
- Create: `scripts/data/wave.gd`
- Create: `tests/unit/test_wave.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_wave.gd`:

```gdscript
extends GutTest

func _entry(count: int) -> SpawnEntry:
	var entry := SpawnEntry.new()
	entry.count = count
	return entry

func test_defaults() -> void:
	var wave := Wave.new()
	assert_eq(wave.entries, [])
	assert_almost_eq(wave.duration, 15.0, 0.001)

func test_total_enemy_count_empty_is_zero() -> void:
	assert_eq(Wave.new().total_enemy_count(), 0)

func test_total_enemy_count_sums_entries() -> void:
	var wave := Wave.new()
	wave.entries = [_entry(8), _entry(20), _entry(4)]
	assert_eq(wave.total_enemy_count(), 32)
```

- [ ] **Step 2: Run red**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_wave.gd -gexit
```

Expected: fail — `Wave` not defined.

- [ ] **Step 3: Implement**

Create `scripts/data/wave.gd`:

```gdscript
class_name Wave
extends Resource
## A single wave: a set of SpawnEntry configs plus how long the wave lasts
## before the spawner advances to the next wave.

@export var entries: Array[SpawnEntry] = []
@export var duration: float = 15.0  ## seconds before advancing to the next wave

func total_enemy_count() -> int:
	var total := 0
	for entry in entries:
		total += entry.count
	return total
```

- [ ] **Step 4: Run green**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_wave.gd -gexit
```

Expected: 3/3 passed.

- [ ] **Step 5: Commit**

```bash
git add scripts/data/wave.gd tests/unit/test_wave.gd
git add scripts/data/*.uid tests/unit/*.uid 2>/dev/null || true
git commit -m "feat: add Wave resource with entry aggregation"
```

---

## Task 3: DifficultyCurve resource

**Files:**
- Create: `scripts/data/difficulty_curve.gd`
- Create: `tests/unit/test_difficulty_curve.gd`
- Create: `resources/difficulty_curve.tres`

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_difficulty_curve.gd`:

```gdscript
extends GutTest

func _curve() -> DifficultyCurve:
	var curve := DifficultyCurve.new()
	curve.hp_growth_per_wave = 0.25
	curve.speed_growth_per_wave = 0.05
	return curve

func test_wave_zero_is_baseline() -> void:
	var curve := _curve()
	assert_almost_eq(curve.hp_multiplier(0), 1.0, 0.001)
	assert_almost_eq(curve.speed_multiplier(0), 1.0, 0.001)

func test_wave_two_scales() -> void:
	var curve := _curve()
	assert_almost_eq(curve.hp_multiplier(2), 1.5, 0.001)
	assert_almost_eq(curve.speed_multiplier(2), 1.1, 0.001)
```

- [ ] **Step 2: Run red**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_difficulty_curve.gd -gexit
```

Expected: fail — `DifficultyCurve` not defined.

- [ ] **Step 3: Implement**

Create `scripts/data/difficulty_curve.gd`:

```gdscript
class_name DifficultyCurve
extends Resource
## Per-wave stat multipliers. Closed-form so no per-wave arrays are needed.
## wave_index is 0-based; wave 0 returns the baseline (1.0).

@export var hp_growth_per_wave: float = 0.25    ## +25% enemy HP per wave index
@export var speed_growth_per_wave: float = 0.05 ## +5% enemy move speed per wave index

func hp_multiplier(wave_index: int) -> float:
	return 1.0 + hp_growth_per_wave * float(wave_index)

func speed_multiplier(wave_index: int) -> float:
	return 1.0 + speed_growth_per_wave * float(wave_index)
```

- [ ] **Step 4: Run green**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_difficulty_curve.gd -gexit
```

Expected: 2/2 passed.

- [ ] **Step 5: Author the .tres**

Create `resources/difficulty_curve.tres`:

```
[gd_resource type="Resource" script_class="DifficultyCurve" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/data/difficulty_curve.gd" id="1"]

[resource]
script = ExtResource("1")
hp_growth_per_wave = 0.25
speed_growth_per_wave = 0.05
```

- [ ] **Step 6: Commit**

```bash
git add scripts/data/difficulty_curve.gd tests/unit/test_difficulty_curve.gd resources/difficulty_curve.tres
git add scripts/data/*.uid tests/unit/*.uid 2>/dev/null || true
git commit -m "feat: add DifficultyCurve resource with per-wave multipliers"
```

---

## Task 4: Enemy base — difficulty scaling + shared XP drop

**Files:**
- Modify: `scripts/enemies/enemy.gd`
- Modify: `scripts/enemies/melee_chaser.gd`
- Create: `tests/unit/test_enemy.gd`

Move the XP-gem drop from `MeleeChaser` into the `Enemy` base so every enemy drops a gem (DRY), set the gem's value from the enemy's `xp_value`, and add `apply_difficulty()` plus a static `velocity_toward()` helper (used by the chase helper in Task 5 and by tests now).

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_enemy.gd`:

```gdscript
extends GutTest

func _make_enemy(max_hp: int = 4) -> Enemy:
	var enemy := Enemy.new()
	var health := HealthComponent.new()
	health.name = "HealthComponent"
	health.max_hp = max_hp
	enemy.add_child(health)
	enemy.health_path = NodePath("HealthComponent")
	add_child_autofree(enemy)
	return enemy

func test_velocity_toward_points_at_target() -> void:
	var v := Enemy.velocity_toward(Vector2.ZERO, Vector2(100, 0), 70.0)
	assert_almost_eq(v.x, 70.0, 0.001)
	assert_almost_eq(v.y, 0.0, 0.001)

func test_velocity_toward_zero_when_coincident() -> void:
	var v := Enemy.velocity_toward(Vector2(5, 5), Vector2(5, 5), 70.0)
	assert_eq(v, Vector2.ZERO)

func test_apply_difficulty_scales_hp_and_speed() -> void:
	var enemy := _make_enemy(4)
	enemy.move_speed = 70.0
	enemy.apply_difficulty(2.0, 1.5)
	assert_eq(enemy.health.max_hp, 8)
	assert_eq(enemy.health.current_hp, 8)
	assert_almost_eq(enemy.move_speed, 105.0, 0.001)
```

- [ ] **Step 2: Run red**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_enemy.gd -gexit
```

Expected: fail — `Enemy.velocity_toward` / `apply_difficulty` not defined.

- [ ] **Step 3: Rewrite `scripts/enemies/enemy.gd`**

Replace the entire file with:

```gdscript
class_name Enemy
extends CharacterBody2D
## Base class for enemies. Composes HealthComponent + HurtboxComponent +
## HitboxComponent. Concrete enemies add AI in _physics_process. On death,
## drops an XP gem worth xp_value.

const XP_GEM_SCENE: PackedScene = preload("res://scenes/pickups/xp_gem.tscn")

@export var move_speed: float = 70.0
@export var health_path: NodePath
@export var hurtbox_path: NodePath
@export var xp_value: int = 1

var health: HealthComponent
var hurtbox: HurtboxComponent

func _ready() -> void:
	health = get_node_or_null(health_path) as HealthComponent
	hurtbox = get_node_or_null(hurtbox_path) as HurtboxComponent
	if health:
		health.died.connect(_on_died)

## Scale stats for the wave this enemy spawned in. Called by the spawner AFTER
## the enemy is added to the tree (so health is resolved).
func apply_difficulty(hp_multiplier: float, speed_multiplier: float) -> void:
	move_speed *= speed_multiplier
	if health == null:
		health = get_node_or_null(health_path) as HealthComponent
	if health:
		var scaled_hp := int(round(health.max_hp * hp_multiplier))
		health.set_max_hp(scaled_hp)
		health.current_hp = health.max_hp

## Velocity vector from `from` toward `to` at `speed`. Returns ZERO if the
## points are effectively coincident. Static so it is trivially testable.
static func velocity_toward(from: Vector2, to: Vector2, speed: float) -> Vector2:
	var offset := to - from
	if offset.length_squared() <= 1.0:
		return Vector2.ZERO
	return offset.normalized() * speed

func _on_died() -> void:
	EventBus.enemy_died.emit(xp_value)
	_on_pre_free()
	queue_free()

## Drop an XP gem worth this enemy's xp_value at its death position.
func _on_pre_free() -> void:
	var xp_gem := XP_GEM_SCENE.instantiate()
	xp_gem.value = xp_value
	xp_gem.global_position = global_position
	get_tree().current_scene.add_child(xp_gem)
```

- [ ] **Step 4: Simplify `scripts/enemies/melee_chaser.gd`**

The base now handles the XP drop, so remove the override and its preload. Replace the file with:

```gdscript
class_name MeleeChaser
extends Enemy
## Rusher archetype (lore: The Grasp). Walks at the hero in a straight line and
## deals contact damage on overlap. XP drop is handled by the Enemy base.

var _target_hero: Node2D = null

func _ready() -> void:
	super()
	add_to_group("enemies")

func _physics_process(_delta: float) -> void:
	if _target_hero == null:
		_target_hero = get_tree().get_first_node_in_group("hero")
		if _target_hero == null:
			return
	velocity = Enemy.velocity_toward(global_position, _target_hero.global_position, move_speed)
	move_and_slide()
```

(The `chase()` helper introduced in Task 5 will replace the two-line velocity/move block; left explicit here so this task is self-contained.)

- [ ] **Step 5: Run green (new + regression)**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_enemy.gd -gexit
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gdir=res://tests/smoke -gexit 2>&1 | tail -6
```

Expected: `test_enemy.gd` 3/3 passed; full suite still green (no regressions).

- [ ] **Step 6: Commit**

```bash
git add scripts/enemies/enemy.gd scripts/enemies/melee_chaser.gd tests/unit/test_enemy.gd
git add tests/unit/*.uid 2>/dev/null || true
git commit -m "feat: add enemy difficulty scaling and shared XP drop in base"
```

---

## Task 5: Enemy base — shared chase helper

**Files:**
- Modify: `scripts/enemies/enemy.gd`
- Modify: `scripts/enemies/melee_chaser.gd`

Extract the "move toward a target and slide" pattern into the base so MeleeChaser (and Swarmer in Task 6) share it.

- [ ] **Step 1: Add the `chase()` helper to `scripts/enemies/enemy.gd`**

Add this method to `enemy.gd`, immediately after `velocity_toward()`:

```gdscript
## Move toward a target node this frame using move_and_slide(). Concrete
## chasers call this from _physics_process.
func chase(target: Node2D) -> void:
	velocity = velocity_toward(global_position, target.global_position, move_speed)
	move_and_slide()
```

- [ ] **Step 2: Use the helper in `scripts/enemies/melee_chaser.gd`**

Replace the `_physics_process` body so it ends with `chase(_target_hero)`:

```gdscript
func _physics_process(_delta: float) -> void:
	if _target_hero == null:
		_target_hero = get_tree().get_first_node_in_group("hero")
		if _target_hero == null:
			return
	chase(_target_hero)
```

- [ ] **Step 3: Run the suite (no behavior change expected)**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gdir=res://tests/smoke -gexit 2>&1 | tail -6
```

Expected: still green.

- [ ] **Step 4: Commit**

```bash
git add scripts/enemies/enemy.gd scripts/enemies/melee_chaser.gd
git commit -m "refactor: extract shared chase helper into Enemy base"
```

---

## Task 6: Swarmer enemy

**Files:**
- Create: `scripts/enemies/swarmer.gd`
- Create: `scenes/enemies/swarmer.tscn`
- Create: `tools/_check_scene.gd` (temporary smoke-load helper, reused in Tasks 7, 8, 11)

- [ ] **Step 1: Implement script**

Create `scripts/enemies/swarmer.gd`:

```gdscript
class_name Swarmer
extends Enemy
## Swarmer archetype (lore: The Fragments). Individually trivial — 1 HP, fast,
## low contact damage — but lethal in numbers. Same straight-line chase as the
## Rusher; the threat comes from spawn count, configured in the wave.

var _target_hero: Node2D = null

func _ready() -> void:
	super()
	add_to_group("enemies")

func _physics_process(_delta: float) -> void:
	if _target_hero == null:
		_target_hero = get_tree().get_first_node_in_group("hero")
		if _target_hero == null:
			return
	chase(_target_hero)
```

- [ ] **Step 2: Build the scene**

Create `scenes/enemies/swarmer.tscn` (collision layers per `docs/collision-layers.md`: body=4, enemy hurtbox=16/mask 8, enemy hitbox=32/mask 64):

```
[gd_scene load_steps=7 format=3]

[ext_resource type="Script" path="res://scripts/enemies/swarmer.gd" id="1"]
[ext_resource type="Script" path="res://scripts/components/health_component.gd" id="2"]
[ext_resource type="Script" path="res://scripts/components/hurtbox_component.gd" id="3"]
[ext_resource type="Script" path="res://scripts/components/hitbox_component.gd" id="4"]

[sub_resource type="CircleShape2D" id="shape_body"]
radius = 3.0

[sub_resource type="CircleShape2D" id="shape_hurt"]
radius = 3.0

[sub_resource type="CircleShape2D" id="shape_hit"]
radius = 3.0

[node name="Swarmer" type="CharacterBody2D"]
collision_layer = 4
collision_mask = 1
script = ExtResource("1")
move_speed = 110.0
health_path = NodePath("HealthComponent")
hurtbox_path = NodePath("HurtboxComponent")
xp_value = 1

[node name="Visual" type="ColorRect" parent="."]
offset_left = -3.0
offset_top = -3.0
offset_right = 3.0
offset_bottom = 3.0
color = Color(0.7, 0.3, 0.5, 1)

[node name="Body" type="CollisionShape2D" parent="."]
shape = SubResource("shape_body")

[node name="HealthComponent" type="Node" parent="."]
script = ExtResource("2")
max_hp = 1

[node name="HurtboxComponent" type="Area2D" parent="."]
collision_layer = 16
collision_mask = 8
script = ExtResource("3")
health_path = NodePath("../HealthComponent")

[node name="HurtShape" type="CollisionShape2D" parent="HurtboxComponent"]
shape = SubResource("shape_hurt")

[node name="HitboxComponent" type="Area2D" parent="."]
collision_layer = 32
collision_mask = 64
damage = 5
script = ExtResource("4")

[node name="HitShape" type="CollisionShape2D" parent="HitboxComponent"]
shape = SubResource("shape_hit")
```

- [ ] **Step 3: Create the smoke-load helper**

Create `tools/_check_scene.gd`:

```gdscript
extends SceneTree
## Smoke-loads and instantiates a scene passed after `--`. Prints OK or FAILED.

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("usage: godot --headless --script tools/_check_scene.gd -- <res://path.tscn>")
		quit(1)
		return
	var path := args[0]
	var packed := load(path) as PackedScene
	if packed == null:
		printerr("FAILED to load ", path)
		quit(1)
		return
	var instance := packed.instantiate()
	if instance == null:
		printerr("FAILED to instantiate ", path)
		quit(1)
		return
	instance.queue_free()
	print("OK ", path)
	quit(0)
```

- [ ] **Step 4: Smoke-load the swarmer scene**

```bash
godot --headless --script tools/_check_scene.gd -- res://scenes/enemies/swarmer.tscn
```

Expected: `OK res://scenes/enemies/swarmer.tscn`.

- [ ] **Step 5: Commit**

```bash
git add scripts/enemies/swarmer.gd scenes/enemies/swarmer.tscn tools/_check_scene.gd
git add scripts/enemies/*.uid scenes/enemies/*.uid tools/*.uid 2>/dev/null || true
git commit -m "feat: add Swarmer enemy archetype"
```

---

## Task 7: EnemyProjectile

**Files:**
- Create: `scripts/projectiles/enemy_projectile.gd`
- Create: `scenes/projectiles/enemy_projectile.tscn`

A hostile linear projectile. Its HitboxComponent sits on the enemy-hitbox layer (32) and masks the hero hurtbox (64), so it damages the hero — the mirror of `HexBolt`, which hits enemies.

- [ ] **Step 1: Implement script**

Create `scripts/projectiles/enemy_projectile.gd`:

```gdscript
class_name EnemyProjectile
extends Area2D
## Linear-flight hostile projectile fired by ranged enemies. Carries a
## HitboxComponent child that damages the hero. Despawns on lifetime or wall.

@export var speed: float = 180.0
@export var lifetime: float = 3.0

var _direction: Vector2 = Vector2.RIGHT
var _elapsed: float = 0.0

@onready var _hitbox: HitboxComponent = $HitboxComponent

func configure(direction: Vector2, damage: int, source: Node) -> void:
	_direction = direction.normalized()
	_hitbox.damage = damage
	_hitbox.source = source
	rotation = _direction.angle()

func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= lifetime:
		queue_free()
		return
	position += _direction * speed * delta

func _on_body_entered(_body: Node) -> void:
	queue_free()  # despawn on wall hit
```

- [ ] **Step 2: Build the scene**

Create `scenes/projectiles/enemy_projectile.tscn`:

```
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/projectiles/enemy_projectile.gd" id="1"]
[ext_resource type="Script" path="res://scripts/components/hitbox_component.gd" id="2"]

[sub_resource type="CircleShape2D" id="shape_hit"]
radius = 3.0

[sub_resource type="CircleShape2D" id="shape_body"]
radius = 3.0

[node name="EnemyProjectile" type="Area2D"]
collision_layer = 0
collision_mask = 1
script = ExtResource("1")

[node name="Visual" type="ColorRect" parent="."]
offset_left = -3.0
offset_top = -1.0
offset_right = 3.0
offset_bottom = 1.0
color = Color(0.75, 0.35, 0.85, 1)

[node name="Body" type="CollisionShape2D" parent="."]
shape = SubResource("shape_body")

[node name="HitboxComponent" type="Area2D" parent="."]
collision_layer = 32
collision_mask = 64
script = ExtResource("2")

[node name="HitShape" type="CollisionShape2D" parent="HitboxComponent"]
shape = SubResource("shape_hit")

[connection signal="body_entered" from="." to="." method="_on_body_entered"]
```

- [ ] **Step 3: Smoke-load**

```bash
godot --headless --script tools/_check_scene.gd -- res://scenes/projectiles/enemy_projectile.tscn
```

Expected: `OK res://scenes/projectiles/enemy_projectile.tscn`.

- [ ] **Step 4: Commit**

```bash
git add scripts/projectiles/enemy_projectile.gd scenes/projectiles/enemy_projectile.tscn
git add scripts/projectiles/*.uid scenes/projectiles/*.uid 2>/dev/null || true
git commit -m "feat: add EnemyProjectile for ranged enemy attacks"
```

---

## Task 8: Ranged enemy

**Files:**
- Create: `scripts/enemies/ranged_enemy.gd`
- Create: `scenes/enemies/ranged_enemy.tscn`
- Create: `tests/unit/test_ranged_enemy.gd`

Keeps a preferred distance from the hero (approach / hold / kite) and fires an `EnemyProjectile` on cooldown when in range. The movement decision is extracted as a pure `movement_intent()` for unit testing.

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_ranged_enemy.gd`:

```gdscript
extends GutTest

func _make_ranged() -> RangedEnemy:
	var ranged := RangedEnemy.new()
	ranged.preferred_distance = 180.0
	ranged.distance_buffer = 30.0
	return ranged

func test_intent_approach_when_far() -> void:
	assert_eq(_make_ranged().movement_intent(250.0), 1)

func test_intent_kite_when_close() -> void:
	assert_eq(_make_ranged().movement_intent(100.0), -1)

func test_intent_hold_within_buffer() -> void:
	assert_eq(_make_ranged().movement_intent(180.0), 0)
```

- [ ] **Step 2: Run red**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_ranged_enemy.gd -gexit
```

Expected: fail — `RangedEnemy` not defined.

- [ ] **Step 3: Implement script**

Create `scripts/enemies/ranged_enemy.gd`:

```gdscript
class_name RangedEnemy
extends Enemy
## Ranged archetype (lore: The Keening). Holds at a preferred distance from the
## hero and fires EnemyProjectiles on cooldown. Approaches if too far, kites if
## too close. No contact damage — the threat is its ranged fire.

const PROJECTILE_SCENE: PackedScene = preload("res://scenes/projectiles/enemy_projectile.tscn")

@export var preferred_distance: float = 180.0
@export var distance_buffer: float = 30.0
@export var fire_range: float = 240.0
@export var fire_cooldown: float = 2.5
@export var projectile_damage: int = 8

var _target_hero: Node2D = null
var _fire_timer: float = 0.0

func _ready() -> void:
	super()
	add_to_group("enemies")

func _physics_process(_delta: float) -> void:
	if _target_hero == null:
		_target_hero = get_tree().get_first_node_in_group("hero")
		if _target_hero == null:
			return
	var distance := global_position.distance_to(_target_hero.global_position)
	var intent := movement_intent(distance)
	if intent == 0:
		velocity = Vector2.ZERO
	else:
		var direction := (_target_hero.global_position - global_position).normalized()
		velocity = direction * move_speed * float(intent)
	move_and_slide()

func _process(delta: float) -> void:
	_fire_timer = max(0.0, _fire_timer - delta)
	if _target_hero == null:
		return
	var distance := global_position.distance_to(_target_hero.global_position)
	if distance <= fire_range and _fire_timer == 0.0:
		_fire()
		_fire_timer = fire_cooldown

## +1 = approach, -1 = kite away, 0 = hold. Pure function for testability.
func movement_intent(distance_to_hero: float) -> int:
	if distance_to_hero > preferred_distance + distance_buffer:
		return 1
	if distance_to_hero < preferred_distance - distance_buffer:
		return -1
	return 0

func _fire() -> void:
	var direction := (_target_hero.global_position - global_position).normalized()
	var projectile := PROJECTILE_SCENE.instantiate() as EnemyProjectile
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = global_position
	projectile.configure(direction, projectile_damage, self)
```

- [ ] **Step 4: Run green**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_ranged_enemy.gd -gexit
```

Expected: 3/3 passed.

- [ ] **Step 5: Build the scene**

Create `scenes/enemies/ranged_enemy.tscn` (no contact HitboxComponent — ranged enemies don't melee):

```
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/enemies/ranged_enemy.gd" id="1"]
[ext_resource type="Script" path="res://scripts/components/health_component.gd" id="2"]
[ext_resource type="Script" path="res://scripts/components/hurtbox_component.gd" id="3"]

[sub_resource type="CircleShape2D" id="shape_body"]
radius = 5.0

[sub_resource type="CircleShape2D" id="shape_hurt"]
radius = 5.0

[node name="RangedEnemy" type="CharacterBody2D"]
collision_layer = 4
collision_mask = 1
script = ExtResource("1")
move_speed = 60.0
health_path = NodePath("HealthComponent")
hurtbox_path = NodePath("HurtboxComponent")
xp_value = 2

[node name="Visual" type="ColorRect" parent="."]
offset_left = -5.0
offset_top = -5.0
offset_right = 5.0
offset_bottom = 5.0
color = Color(0.55, 0.45, 0.85, 1)

[node name="Body" type="CollisionShape2D" parent="."]
shape = SubResource("shape_body")

[node name="HealthComponent" type="Node" parent="."]
script = ExtResource("2")
max_hp = 4

[node name="HurtboxComponent" type="Area2D" parent="."]
collision_layer = 16
collision_mask = 8
script = ExtResource("3")
health_path = NodePath("../HealthComponent")

[node name="HurtShape" type="CollisionShape2D" parent="HurtboxComponent"]
shape = SubResource("shape_hurt")
```

- [ ] **Step 6: Smoke-load**

```bash
godot --headless --script tools/_check_scene.gd -- res://scenes/enemies/ranged_enemy.tscn
```

Expected: `OK res://scenes/enemies/ranged_enemy.tscn`.

- [ ] **Step 7: Commit**

```bash
git add scripts/enemies/ranged_enemy.gd scenes/enemies/ranged_enemy.tscn tests/unit/test_ranged_enemy.gd
git add scripts/enemies/*.uid scenes/enemies/*.uid tests/unit/*.uid 2>/dev/null || true
git commit -m "feat: add RangedEnemy archetype with kiting and projectile fire"
```

---

## Task 9: WaveLibrary factory

**Files:**
- Create: `scripts/data/wave_library.gd`
- Create: `tests/unit/test_wave_library.gd`

The prototype wave sequence, built in code (designer-tunable here). `.tres`-authored waves are deferred (array-of-subresource authoring is out of scope for M2a).

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_wave_library.gd`:

```gdscript
extends GutTest

func test_returns_three_waves() -> void:
	assert_eq(WaveLibrary.default_waves().size(), 3)

func test_wave_totals_escalate() -> void:
	var waves := WaveLibrary.default_waves()
	assert_eq(waves[0].total_enemy_count(), 8)
	assert_eq(waves[1].total_enemy_count(), 28)
	assert_eq(waves[2].total_enemy_count(), 26)

func test_first_wave_is_rushers_only() -> void:
	var waves := WaveLibrary.default_waves()
	assert_eq(waves[0].entries.size(), 1)

func test_third_wave_has_three_entry_types() -> void:
	var waves := WaveLibrary.default_waves()
	assert_eq(waves[2].entries.size(), 3)
```

- [ ] **Step 2: Run red**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_wave_library.gd -gexit
```

Expected: fail — `WaveLibrary` not defined.

- [ ] **Step 3: Implement**

Create `scripts/data/wave_library.gd`:

```gdscript
class_name WaveLibrary
extends RefCounted
## Static factory for the M2a prototype wave sequence. Tune here; .tres-authored
## waves are a future enhancement.

const RUSHER: PackedScene = preload("res://scenes/enemies/melee_chaser.tscn")
const SWARMER: PackedScene = preload("res://scenes/enemies/swarmer.tscn")
const RANGED: PackedScene = preload("res://scenes/enemies/ranged_enemy.tscn")

static func _entry(scene: PackedScene, count: int, interval: float) -> SpawnEntry:
	var entry := SpawnEntry.new()
	entry.enemy_scene = scene
	entry.count = count
	entry.interval = interval
	return entry

static func _wave(entries: Array[SpawnEntry], duration: float) -> Wave:
	var wave := Wave.new()
	wave.entries = entries
	wave.duration = duration
	return wave

static func default_waves() -> Array[Wave]:
	return [
		_wave([_entry(RUSHER, 8, 1.5)], 15.0),
		_wave([_entry(RUSHER, 8, 1.5), _entry(SWARMER, 20, 0.5)], 18.0),
		_wave([_entry(RUSHER, 6, 1.5), _entry(SWARMER, 16, 0.5), _entry(RANGED, 4, 3.0)], 20.0),
	]
```

- [ ] **Step 4: Run green**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_wave_library.gd -gexit
```

Expected: 4/4 passed.

- [ ] **Step 5: Commit**

```bash
git add scripts/data/wave_library.gd tests/unit/test_wave_library.gd
git add scripts/data/*.uid tests/unit/*.uid 2>/dev/null || true
git commit -m "feat: add WaveLibrary factory for the M2a wave sequence"
```

---

## Task 10: WaveSpawner

**Files:**
- Create: `scripts/systems/wave_spawner.gd`
- Create: `tests/unit/test_wave_spawner.gd`

Schedules spawns within a wave, advances waves on duration, applies the difficulty multiplier per wave, and emits lifecycle signals. Instancing is delegated to an injected `spawn_handler` Callable so the scheduling logic is fully unit-testable headlessly (no scenes, no hero, no tree timing).

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_wave_spawner.gd`:

```gdscript
extends GutTest

var _spawns: Array = []  # each element: [enemy_scene, hp_mult, speed_mult]

func _record(enemy_scene: PackedScene, hp_mult: float, speed_mult: float) -> void:
	_spawns.append([enemy_scene, hp_mult, speed_mult])

func _entry(count: int, interval: float) -> SpawnEntry:
	var entry := SpawnEntry.new()
	entry.count = count
	entry.interval = interval
	return entry

func _wave(entries: Array[SpawnEntry], duration: float) -> Wave:
	var wave := Wave.new()
	wave.entries = entries
	wave.duration = duration
	return wave

func _make_spawner(waves: Array[Wave]) -> WaveSpawner:
	var spawner := WaveSpawner.new()
	spawner.set_process(false)  # drive advance() manually in tests
	spawner.waves = waves
	spawner.spawn_handler = _record
	add_child_autofree(spawner)
	return spawner

func before_each() -> void:
	_spawns.clear()

func test_start_emits_wave_started() -> void:
	var spawner := _make_spawner([_wave([_entry(1, 1.0)], 3.0)])
	watch_signals(spawner)
	spawner.start()
	assert_eq(spawner.current_wave_index, 0)
	assert_signal_emitted_with_parameters(spawner, "wave_started", [0])

func test_spawns_all_enemies_then_completes() -> void:
	var spawner := _make_spawner([_wave([_entry(3, 1.0)], 3.0)])
	watch_signals(spawner)
	spawner.start()
	for _i in 3:
		spawner.advance(1.0)
	assert_eq(_spawns.size(), 3, "spawns one per interval")
	assert_signal_emit_count(spawner, "wave_completed", 1)
	assert_signal_emit_count(spawner, "all_waves_completed", 1)

func test_empty_wave_list_completes_immediately() -> void:
	var empty: Array[Wave] = []
	var spawner := _make_spawner(empty)
	watch_signals(spawner)
	spawner.start()
	assert_signal_emit_count(spawner, "all_waves_completed", 1)

func test_difficulty_multipliers_applied_per_wave() -> void:
	var curve := DifficultyCurve.new()
	curve.hp_growth_per_wave = 0.25
	curve.speed_growth_per_wave = 0.05
	var spawner := _make_spawner([
		_wave([_entry(1, 0.0)], 0.1),
		_wave([_entry(1, 0.0)], 0.1),
	])
	spawner.difficulty = curve
	spawner.start()
	spawner.advance(0.2)  # spawns wave 0, then advances to wave 1
	spawner.advance(0.2)  # spawns wave 1, then completes
	assert_eq(_spawns.size(), 2)
	assert_almost_eq(_spawns[0][1], 1.0, 0.001)   # wave 0 hp mult
	assert_almost_eq(_spawns[0][2], 1.0, 0.001)   # wave 0 speed mult
	assert_almost_eq(_spawns[1][1], 1.25, 0.001)  # wave 1 hp mult
	assert_almost_eq(_spawns[1][2], 1.05, 0.001)  # wave 1 speed mult
```

- [ ] **Step 2: Run red**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_wave_spawner.gd -gexit
```

Expected: fail — `WaveSpawner` not defined.

- [ ] **Step 3: Implement**

Create `scripts/systems/wave_spawner.gd`:

```gdscript
class_name WaveSpawner
extends Node
## Drives a sequence of Waves: schedules per-entry spawns, advances to the next
## wave after each wave's duration, and applies the DifficultyCurve multiplier
## for the current wave. Actual enemy instancing is delegated to spawn_handler:
##   spawn_handler.call(enemy_scene: PackedScene, hp_mult: float, speed_mult: float)
## so this scheduling logic is unit-testable without scenes or a hero.

signal wave_started(wave_index: int)
signal wave_completed(wave_index: int)
signal all_waves_completed

var waves: Array[Wave] = []
var difficulty: DifficultyCurve
var spawn_radius: float = 220.0
var spawn_handler: Callable

var current_wave_index: int = -1
var _wave_elapsed: float = 0.0
var _entry_timers: Array[float] = []
var _entry_remaining: Array[int] = []
var _finished: bool = false

func start() -> void:
	if waves.is_empty():
		_finished = true
		all_waves_completed.emit()
		return
	_begin_wave(0)

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if current_wave_index < 0 or _finished:
		return
	var wave := waves[current_wave_index]
	_wave_elapsed += delta
	for i in wave.entries.size():
		var entry := wave.entries[i]
		_entry_timers[i] += delta
		while _entry_remaining[i] > 0 and _entry_timers[i] >= entry.interval:
			_entry_timers[i] -= entry.interval
			_entry_remaining[i] -= 1
			_spawn(entry)
	if _wave_elapsed >= wave.duration:
		_complete_current_wave()

func stop() -> void:
	_finished = true

func _spawn(entry: SpawnEntry) -> void:
	if not spawn_handler.is_valid():
		return
	var hp_mult := 1.0
	var speed_mult := 1.0
	if difficulty:
		hp_mult = difficulty.hp_multiplier(current_wave_index)
		speed_mult = difficulty.speed_multiplier(current_wave_index)
	spawn_handler.call(entry.enemy_scene, hp_mult, speed_mult)

func _begin_wave(index: int) -> void:
	current_wave_index = index
	_wave_elapsed = 0.0
	_entry_timers.clear()
	_entry_remaining.clear()
	for entry in waves[index].entries:
		_entry_timers.append(0.0)
		_entry_remaining.append(entry.count)
	wave_started.emit(index)

func _complete_current_wave() -> void:
	var completed_index := current_wave_index
	wave_completed.emit(completed_index)
	if completed_index + 1 >= waves.size():
		_finished = true
		all_waves_completed.emit()
	else:
		_begin_wave(completed_index + 1)
```

- [ ] **Step 4: Run green**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_wave_spawner.gd -gexit
```

Expected: 4/4 passed.

- [ ] **Step 5: Commit**

```bash
git add scripts/systems/wave_spawner.gd tests/unit/test_wave_spawner.gd
git add scripts/systems/*.uid tests/unit/*.uid 2>/dev/null || true
git commit -m "feat: add WaveSpawner with injectable spawn handler and difficulty"
```

---

## Task 11: Wire WaveSpawner into the Run controller

**Files:**
- Modify: `scripts/world/run.gd`

Replace M1's arena `EnemySpawnTimer` + single-enemy `_spawn_enemy` with the data-driven `WaveSpawner`. The run ends in victory when all waves are cleared.

- [ ] **Step 1: Rewrite `scripts/world/run.gd`**

Replace the entire file with:

```gdscript
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
```

> [!note] The arena's `EnemySpawnTimer` node is now unused (the spawner owns its own timing). Leaving it in `arena_m1.tscn` is harmless; removing it is optional cleanup deferred to a later arena pass.
>
> Known limitation: `all_waves_completed` emits `run_ended(true)` (victory), but the results screen still shows "Defeat" text from M1. Victory/defeat differentiation on the results screen is owned by the **M2d Meta Progression** plan. For M2a, reaching victory correctly ends the run and shows the restart button.

- [ ] **Step 2: Smoke-load the run scene**

```bash
godot --headless --script tools/_check_scene.gd -- res://scenes/world/run.tscn
```

Expected: `OK res://scenes/world/run.tscn` (loads + instantiates with no parse/preload errors).

- [ ] **Step 3: Run the full suite (regression check)**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gdir=res://tests/smoke -gexit 2>&1 | tail -8
```

Expected: all green (M1 52 + M2a additions).

- [ ] **Step 4: Commit**

```bash
git add scripts/world/run.gd
git add scripts/world/*.uid 2>/dev/null || true
git commit -m "feat: drive enemy spawning via WaveSpawner in Run controller"
```

---

## Task 12: Final verification, manual playtest, tag & PR prep

This is the milestone-gate task. Remove the smoke-load helper, verify everything, and prepare the PR.

- [ ] **Step 1: Remove the temporary smoke helper**

```bash
git rm tools/_check_scene.gd
rm -f tools/_check_scene.gd.uid
git commit -m "chore: remove temporary scene smoke-load helper"
```

- [ ] **Step 2: Full test sweep**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gdir=res://tests/smoke -gexit 2>&1 | tail -10
```

Expected: every test passes. New M2a tests: spawn_entry 2 + wave 3 + difficulty_curve 2 + enemy 3 + ranged_enemy 3 + wave_library 4 + wave_spawner 4 = **21 new**, total ~73.

- [ ] **Step 3: Manual playtest**

```bash
godot --path .
```

Manual checklist (tick each):
- [ ] Wave 1: only rushers (cyan-red squares) spawn on a ring around the hero.
- [ ] Wave 2 (after ~15s): swarmers (small magenta squares) appear in large numbers alongside rushers.
- [ ] Wave 3 (after ~33s): ranged enemies (purple squares) appear, keep their distance, and fire purple bolts at the hero.
- [ ] Ranged enemies back away when you close in and re-approach when you get far.
- [ ] Ranged bolts damage the hero (HP bar drops on hit).
- [ ] Killing any enemy type drops a green XP gem; ranged drops are worth more XP (faster bar fill per kill).
- [ ] Later waves' enemies are visibly tankier and a bit faster than wave 1.
- [ ] Surviving all three waves ends the run (results screen with restart appears).
- [ ] Dying mid-run still shows the results screen and "Play Again" restarts cleanly.
- [ ] No errors in the Godot Output/Debugger panel.

If anything fails, fix it with a focused `fix:` commit before tagging.

- [ ] **Step 4: Confirm clean tree**

```bash
git status
```

Expected: "nothing to commit, working tree clean".

- [ ] **Step 5: Tag the milestone**

```bash
git tag -a m2a-wave-system-enemies -m "M2a complete: data-driven wave spawner, 3 enemy archetypes, difficulty scaling"
```

- [ ] **Step 6: Push and open the PR**

```bash
git push -u origin HEAD
git push origin refs/tags/m2a-wave-system-enemies
```

Then open a PR targeting `main` (after M1 merges) or `m1-prototype-core` (to review as a stack). Watch CI to green.

---

## Self-Review

**Spec coverage** (against Developer Todos "Wave System" + spec §10 M2 "Wave spawner, 3 enemy types, escalating waves"):

| Requirement | Task |
|---|---|
| `WaveSpawner` with configurable spawn waves as Resources | Tasks 1, 2, 9, 10 (Wave/SpawnEntry resources; WaveLibrary factory; spawner) |
| 3 enemy types with distinct behaviors (melee, ranged, swarmer) | Rusher = MeleeChaser (existing, refactored T4/T5); Swarmer T6; Ranged T7+T8 |
| Difficulty curve scaling enemy stats per wave | Task 3 (DifficultyCurve) + Task 4 (`apply_difficulty`) + Task 10 (applied per wave) |
| GUT tests for wave config + enemy behavior | Tasks 1–3, 4, 8, 9, 10 (21 new tests) |

**Placeholder scan:** every code step contains complete code. No "TBD"/"similar to". The only intentional deferrals are explicitly named: `.tres`-authored waves → future; results-screen victory text → M2d; arena `EnemySpawnTimer` removal → optional later cleanup.

**Type consistency:**
- `Enemy.velocity_toward(from, to, speed) -> Vector2` (static) and `chase(target)` — used by MeleeChaser (T5), Swarmer (T6).
- `Enemy.apply_difficulty(hp_multiplier, speed_multiplier)` — called by `Run._spawn_enemy` (T11) with the exact two-float signature the spawner passes (T10 `_spawn`).
- `SpawnEntry` fields (`enemy_scene`, `count`, `interval`), `Wave` (`entries`, `duration`, `total_enemy_count()`), `DifficultyCurve` (`hp_multiplier`/`speed_multiplier`) used consistently across `WaveLibrary` (T9) and `WaveSpawner` (T10).
- `WaveSpawner.spawn_handler` Callable signature `(PackedScene, float, float)` matches both the test recorder (T10) and `Run._spawn_enemy` (T11).
- `RangedEnemy.movement_intent(distance) -> int` ∈ {-1, 0, 1} used by its own `_physics_process`.
- `EnemyProjectile.configure(direction, damage, source)` mirrors `HexBolt.configure` and is called by `RangedEnemy._fire`.

**Collision layers:** Swarmer/Ranged bodies = layer 4 (enemy body), hurtboxes = 16/mask 8, Swarmer hitbox = 32/mask 64, EnemyProjectile hitbox = 32/mask 64 — all consistent with `docs/collision-layers.md` (no new layers introduced).

**Deferred to later M2 sub-plans (intentional):** Tank/Exploder/Elite/Herald archetypes, the 3-faction skinning + contamination/convergence difficulty layers, Named Dead system, boss (M2c), Dread Marks & upgrades (M2b), meta progression & telemetry (M2d), Steam (M2e), Oathbreaker hero (own sub-plan).

---

## Execution Handoff

Plan complete and saved to `docs/plans/2026-05-28-m2a-wave-system-enemies.md`. Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration (same cadence as M0/M1).

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

Which approach?
