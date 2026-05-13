# M1 Prototype Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a playable Dreadhunter prototype. Move, aim, fire Hex-Bolt Salvo, fire Tetherhook, kill one enemy type (melee chaser), drop XP gems, vacuum-collect them, level up, choose 1 of 3 stat upgrades, get hit, die, see results, restart. Full vertical-slice loop in one hardcoded arena.

**Architecture:** Component-based, data-driven. Reusable `HealthComponent` / `HitboxComponent` / `HurtboxComponent` / `XPComponent` nodes drop into any scene. `Hero` and `Enemy` are thin `CharacterBody2D` base classes that compose components. Aim is abstracted behind `AimProvider` (mouse impl now; virtual-stick impl in M3). Upgrades are Resources with `apply(hero)` / `unapply(hero)`. A `Run` controller scene wires arena + hero + HUD + modal and handles the death/results/restart cycle. Damage flows: `Hitbox` (Area2D, carries damage) overlaps `Hurtbox` (Area2D on a thing with a HealthComponent) → calls `HealthComponent.take_damage()`.

**Tech Stack:** Godot 4.6.2 (GDScript), GUT for tests, all infrastructure from M0 (5 autoloads, SaveManager, RNG, EventBus, Settings, GameState, tr() localization).

**Locked design decisions (from /writing-plans alignment pass):**
- Base resolution: 480×270, viewport stretch + keep aspect
- M1 signature ability: **Tetherhook** (no damage, pulls target toward hero)
- M1 enemy: melee chaser — straight-line AI, 3 HP, contact damage 10
- XP model: drop-on-kill gems with vacuum-collect radius
- M1 upgrades: +max_hp (+20%), +damage (+1 flat per bolt), +move_speed (+15%)
- Arena: 30×20 tiles of ColorRect floor + 4 StaticBody2D walls (programmer art)

**Tuning baseline (placeholders for M2 to retune):**
- Hero: 100 HP, 150 px/s move speed
- Hex-Bolt Salvo: 3 bolts, 8° total spread, 1 dmg each, 0.5s cooldown, 300 px/s bolt speed, 1.5s lifetime
- Tetherhook: 0 dmg, 0.4s cooldown, 600 px/s chain speed, 250 px max range, pulls target to within 30 px of hero
- Melee chaser: 3 HP, 70 px/s, 10 dmg on contact (0.5s contact cooldown so it doesn't drain instantly)
- XP gem: drops 1 XP, 100 px vacuum radius, 200 px/s magnet speed
- XP curve: level N→N+1 requires `10 * N * (N+1) / 2` XP (10, 30, 60, 100, 150…)

---

## File Structure

```
Oathfall/
├── scenes/
│   ├── heroes/
│   │   └── dreadhunter.tscn
│   ├── enemies/
│   │   └── melee_chaser.tscn
│   ├── projectiles/
│   │   ├── hex_bolt.tscn
│   │   └── tether_chain.tscn
│   ├── pickups/
│   │   └── xp_gem.tscn
│   ├── rooms/
│   │   └── arena_m1.tscn
│   ├── ui/
│   │   ├── hud.tscn
│   │   ├── level_up_modal.tscn
│   │   └── results_screen.tscn
│   └── world/
│       ├── main.tscn          # (existing) updated to load run.tscn
│       └── run.tscn           # (new) run controller
├── scripts/
│   ├── components/            # (new dir)
│   │   ├── health_component.gd
│   │   ├── hitbox_component.gd
│   │   ├── hurtbox_component.gd
│   │   └── xp_component.gd
│   ├── heroes/
│   │   ├── hero.gd
│   │   └── dreadhunter.gd
│   ├── enemies/
│   │   ├── enemy.gd
│   │   └── melee_chaser.gd
│   ├── projectiles/
│   │   ├── hex_bolt.gd
│   │   └── tether_chain.gd
│   ├── pickups/
│   │   └── xp_gem.gd
│   ├── platform/
│   │   ├── aim_provider.gd        # (new) abstract base
│   │   └── mouse_aim_provider.gd  # (new) desktop impl
│   ├── data/
│   │   ├── upgrade.gd          # Resource class
│   │   └── xp_curve.gd         # Resource class
│   ├── ui/
│   │   ├── hud.gd
│   │   ├── level_up_modal.gd
│   │   └── results_screen.gd
│   └── world/
│       ├── main.gd             # (existing) updated
│       └── run.gd              # (new) run controller
├── resources/
│   ├── upgrades/
│   │   ├── upgrade_hp.tres
│   │   ├── upgrade_damage.tres
│   │   └── upgrade_speed.tres
│   └── xp_curve.tres
└── tests/unit/
    ├── test_health_component.gd
    ├── test_hitbox_hurtbox.gd
    ├── test_xp_component.gd
    ├── test_upgrade.gd
    └── test_xp_curve.gd
```

**File responsibilities:**
- Each component file: one responsibility, <80 lines.
- Hero/Enemy base classes: composition of components + movement; no combat logic.
- Hero/Enemy concrete classes: ability/AI logic only.
- Projectile files: lifetime + motion + Hitbox config.
- `run.gd`: scene transitions and run lifecycle; doesn't own combat logic.
- Tests are pure-data wherever possible; physics/scene-integration tested manually.

---

## Pre-Flight

- [ ] **Step 1: Verify M0 is complete and green**

```bash
cd /Users/bryantdesigns/Documents/projects/misc/Oathfall
git log --oneline -1 m0-foundations
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gdir=res://tests/smoke -gexit 2>&1 | tail -5
```

Expected: tag exists, "30/30 passed" (or higher if M0 had extras).

- [ ] **Step 2: Create feature branch off m0-foundations**

```bash
git checkout -b m1-prototype-core m0-foundations
```

- [ ] **Step 3: Confirm working tree clean**

```bash
git status
```

Expected: "nothing to commit, working tree clean".

---

## Task 1: Configure 480×270 base resolution and stretch mode

**Files:**
- Modify: `project.godot`

The plan's headless approach is the same as for input map: write a one-shot GDScript that sets `ProjectSettings` and saves.

- [ ] **Step 1: Write setup script**

Create `tools/setup_display.gd`:

```gdscript
extends SceneTree

func _init() -> void:
    ProjectSettings.set_setting("display/window/size/viewport_width", 480)
    ProjectSettings.set_setting("display/window/size/viewport_height", 270)
    ProjectSettings.set_setting("display/window/size/window_width_override", 1920)
    ProjectSettings.set_setting("display/window/size/window_height_override", 1080)
    ProjectSettings.set_setting("display/window/stretch/mode", "viewport")
    ProjectSettings.set_setting("display/window/stretch/aspect", "keep")
    ProjectSettings.set_setting("rendering/textures/canvas_textures/default_texture_filter", 0)  # Nearest

    var err := ProjectSettings.save()
    if err != OK:
        printerr("Failed to save ProjectSettings: ", err)
        quit(1)
        return
    print("Display settings written: 480x270 viewport, 1920x1080 window, keep aspect, nearest filter")
    quit(0)
```

- [ ] **Step 2: Run it**

```bash
godot --headless --script tools/setup_display.gd
```

Expected: prints success line, exit 0.

- [ ] **Step 3: Verify project.godot**

```bash
grep -A 1 'viewport_width\|viewport_height\|stretch/mode\|stretch/aspect\|default_texture_filter' project.godot
```

Expected: all five values present.

- [ ] **Step 4: Commit**

```bash
git add tools/setup_display.gd project.godot
git add tools/setup_display.gd.uid 2>/dev/null || true
git commit -m "feat: configure 480x270 base resolution with viewport stretch"
```

---

## Task 2: HealthComponent (TDD)

**Files:**
- Create: `scripts/components/health_component.gd`
- Create: `tests/unit/test_health_component.gd`

- [ ] **Step 1: Write failing test**

Create `tests/unit/test_health_component.gd`:

```gdscript
extends GutTest

func _make_health(max_hp: int = 100) -> HealthComponent:
    var health := HealthComponent.new()
    health.max_hp = max_hp
    health.current_hp = max_hp
    return health

func test_starts_full() -> void:
    var health := _make_health(50)
    assert_eq(health.current_hp, 50)
    assert_false(health.is_dead())

func test_take_damage_reduces_hp() -> void:
    var health := _make_health(100)
    health.take_damage(30)
    assert_eq(health.current_hp, 70)

func test_take_damage_clamps_at_zero() -> void:
    var health := _make_health(10)
    health.take_damage(999)
    assert_eq(health.current_hp, 0)
    assert_true(health.is_dead())

func test_heal_does_not_exceed_max() -> void:
    var health := _make_health(100)
    health.current_hp = 50
    health.heal(999)
    assert_eq(health.current_hp, 100)

func test_died_signal_fires_once() -> void:
    var health := _make_health(10)
    watch_signals(health)
    health.take_damage(5)
    assert_signal_emit_count(health, "died", 0)
    health.take_damage(10)
    assert_signal_emit_count(health, "died", 1)
    health.take_damage(10)
    assert_signal_emit_count(health, "died", 1, "died fires only on transition")

func test_health_changed_signal_fires() -> void:
    var health := _make_health(100)
    watch_signals(health)
    health.take_damage(10)
    assert_signal_emitted_with_parameters(health, "health_changed", [90, 100])
```

- [ ] **Step 2: Run red**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_health_component.gd -gexit
```

Expected: fail (HealthComponent undefined).

- [ ] **Step 3: Implement**

Create `scripts/components/health_component.gd`:

```gdscript
class_name HealthComponent
extends Node
## Numeric HP holder. Composes onto Hero, Enemy, or anything destructible.
## Does not know about hitboxes/hurtboxes — those route damage in by calling
## take_damage(). Emits signals for HUD bindings and death handling.

signal health_changed(current: int, maximum: int)
signal died

@export var max_hp: int = 100
var current_hp: int = 100
var _dead: bool = false

func _ready() -> void:
    current_hp = max_hp

func take_damage(amount: int) -> void:
    if _dead or amount <= 0:
        return
    current_hp = max(0, current_hp - amount)
    health_changed.emit(current_hp, max_hp)
    if current_hp == 0:
        _dead = true
        died.emit()

func heal(amount: int) -> void:
    if _dead or amount <= 0:
        return
    current_hp = min(max_hp, current_hp + amount)
    health_changed.emit(current_hp, max_hp)

func is_dead() -> bool:
    return _dead

func set_max_hp(new_max: int) -> void:
    max_hp = max(1, new_max)
    current_hp = min(current_hp, max_hp)
    health_changed.emit(current_hp, max_hp)
```

- [ ] **Step 4: Run green**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_health_component.gd -gexit
```

Expected: 6/6 passed.

- [ ] **Step 5: Commit**

```bash
git add scripts/components/health_component.gd tests/unit/test_health_component.gd
git add scripts/components/*.uid tests/unit/*.uid 2>/dev/null || true
git commit -m "feat: add HealthComponent with HP and death tracking"
```

---

## Task 3: HitboxComponent and HurtboxComponent (TDD)

**Files:**
- Create: `scripts/components/hitbox_component.gd`
- Create: `scripts/components/hurtbox_component.gd`
- Create: `tests/unit/test_hitbox_hurtbox.gd`

Both extend Area2D. Hitbox carries `damage` and a `source` reference. Hurtbox listens for entering Hitboxes, looks up the sibling HealthComponent, and calls `take_damage`. Collision layer/mask wiring happens later in each scene; tests cover the routing logic directly.

- [ ] **Step 1: Write failing test**

Create `tests/unit/test_hitbox_hurtbox.gd`:

```gdscript
extends GutTest

func test_hitbox_default_damage() -> void:
    var hitbox := HitboxComponent.new()
    assert_eq(hitbox.damage, 1)
    hitbox.free()

func test_hitbox_carries_source() -> void:
    var hitbox := HitboxComponent.new()
    var fake_source := Node.new()
    hitbox.source = fake_source
    assert_same(hitbox.source, fake_source)
    hitbox.free()
    fake_source.free()

func test_hurtbox_routes_damage_to_sibling_health() -> void:
    var owner_node := Node.new()
    add_child_autofree(owner_node)

    var health := HealthComponent.new()
    health.max_hp = 50
    owner_node.add_child(health)

    var hurtbox := HurtboxComponent.new()
    owner_node.add_child(hurtbox)
    hurtbox.health_path = health.get_path()

    var hitbox := HitboxComponent.new()
    hitbox.damage = 7

    # Simulate the area_entered signal directly
    hurtbox._on_area_entered(hitbox)

    assert_eq(health.current_hp, 43)

    hitbox.free()

func test_hurtbox_ignores_damage_when_disabled() -> void:
    var owner_node := Node.new()
    add_child_autofree(owner_node)

    var health := HealthComponent.new()
    health.max_hp = 50
    owner_node.add_child(health)

    var hurtbox := HurtboxComponent.new()
    hurtbox.invulnerable = true
    owner_node.add_child(hurtbox)
    hurtbox.health_path = health.get_path()

    var hitbox := HitboxComponent.new()
    hitbox.damage = 7
    hurtbox._on_area_entered(hitbox)

    assert_eq(health.current_hp, 50)
    hitbox.free()
```

- [ ] **Step 2: Run red**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_hitbox_hurtbox.gd -gexit
```

Expected: parse-fail (HitboxComponent / HurtboxComponent undefined).

- [ ] **Step 3: Implement HitboxComponent**

Create `scripts/components/hitbox_component.gd`:

```gdscript
class_name HitboxComponent
extends Area2D
## Carries damage when it overlaps a HurtboxComponent. Set damage at spawn
## (projectile) or once at scene load (enemy contact-damage hitbox).

@export var damage: int = 1
var source: Node = null  ## who created this hitbox (for telemetry / friendly fire)
```

- [ ] **Step 4: Implement HurtboxComponent**

Create `scripts/components/hurtbox_component.gd`:

```gdscript
class_name HurtboxComponent
extends Area2D
## Receives damage from any HitboxComponent that enters it, and forwards
## that damage to a sibling HealthComponent.

@export var health_path: NodePath
@export var invulnerable: bool = false

func _ready() -> void:
    area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
    if invulnerable:
        return
    if area is HitboxComponent:
        var health := get_node_or_null(health_path) as HealthComponent
        if health:
            health.take_damage(area.damage)
```

- [ ] **Step 5: Run green**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_hitbox_hurtbox.gd -gexit
```

Expected: 4/4 passed.

- [ ] **Step 6: Commit**

```bash
git add scripts/components/hitbox_component.gd scripts/components/hurtbox_component.gd tests/unit/test_hitbox_hurtbox.gd
git add scripts/components/*.uid tests/unit/*.uid 2>/dev/null || true
git commit -m "feat: add HitboxComponent and HurtboxComponent for damage routing"
```

---

## Task 4: AimProvider abstraction and MouseAimProvider

**Files:**
- Create: `scripts/platform/aim_provider.gd`
- Create: `scripts/platform/mouse_aim_provider.gd`

No tests — the mouse impl reads `Input.get_global_mouse_position()` which is integration-level. The abstraction is what we're locking in.

- [ ] **Step 1: Write the interface**

Create `scripts/platform/aim_provider.gd`:

```gdscript
class_name AimProvider
extends RefCounted
## Returns a continuous aim vector. Concrete impls per input device.
## MouseAimProvider for desktop; VirtualStickAimProvider added in M3 for mobile.

## Returns the world-space point the player is aiming at, relative to the
## supplied origin. The hero passes its global_position as origin.
func aim_world_point(_origin: Vector2) -> Vector2:
    push_error("AimProvider.aim_world_point() must be overridden")
    return Vector2.ZERO

## Convenience: unit vector from origin toward aim point. Returns RIGHT
## as a safe default if origin == aim point.
func aim_direction(origin: Vector2) -> Vector2:
    var aim_target := aim_world_point(origin)
    var offset := aim_target - origin
    if offset.length_squared() < 0.001:
        return Vector2.RIGHT
    return offset.normalized()
```

- [ ] **Step 2: Write the mouse impl**

Create `scripts/platform/mouse_aim_provider.gd`:

```gdscript
class_name MouseAimProvider
extends AimProvider
## Reads the global mouse position from a viewport. Constructed with a
## CanvasItem (the hero or a node in its tree) to pick up the right viewport.

var _canvas_item: CanvasItem

func _init(canvas_item: CanvasItem) -> void:
    _canvas_item = canvas_item

func aim_world_point(_origin: Vector2) -> Vector2:
    return _canvas_item.get_global_mouse_position()
```

- [ ] **Step 3: Commit**

```bash
git add scripts/platform/aim_provider.gd scripts/platform/mouse_aim_provider.gd
git add scripts/platform/*.uid 2>/dev/null || true
git commit -m "feat: add AimProvider abstraction with mouse implementation"
```

---

## Task 5: Hero base class

**Files:**
- Create: `scripts/heroes/hero.gd`

`Hero` is a `CharacterBody2D` with `HealthComponent` and `HurtboxComponent` referenced via NodePath. Movement reads from Input Map. Concrete hero scenes wire the actual nodes.

- [ ] **Step 1: Implement**

Create `scripts/heroes/hero.gd`:

```gdscript
class_name Hero
extends CharacterBody2D
## Base class for all heroes. Handles movement and component refs.
## Subclasses (Dreadhunter, etc.) add abilities.

@export var move_speed: float = 150.0
@export var health_path: NodePath
@export var hurtbox_path: NodePath

var health: HealthComponent
var hurtbox: HurtboxComponent
var aim: AimProvider

func _ready() -> void:
    health = get_node_or_null(health_path) as HealthComponent
    hurtbox = get_node_or_null(hurtbox_path) as HurtboxComponent
    if health == null:
        push_error("Hero requires HealthComponent at health_path")
    if hurtbox == null:
        push_error("Hero requires HurtboxComponent at hurtbox_path")
    aim = MouseAimProvider.new(self)
    health.died.connect(_on_died)

func _physics_process(_delta: float) -> void:
    var input_vector := Vector2(
        Input.get_axis("move_left", "move_right"),
        Input.get_axis("move_up", "move_down"),
    )
    if input_vector.length_squared() > 0:
        input_vector = input_vector.normalized()
    velocity = input_vector * move_speed
    move_and_slide()

func aim_direction() -> Vector2:
    return aim.aim_direction(global_position)

func _on_died() -> void:
    EventBus.run_ended.emit(false)
    set_physics_process(false)
```

- [ ] **Step 2: Commit**

```bash
git add scripts/heroes/hero.gd
git add scripts/heroes/*.uid 2>/dev/null || true
git commit -m "feat: add Hero base CharacterBody2D with movement and components"
```

---

## Task 6: HexBolt projectile

**Files:**
- Create: `scripts/projectiles/hex_bolt.gd`
- Create: `scenes/projectiles/hex_bolt.tscn`

Simple linear projectile with a HitboxComponent. Despawns on lifetime or wall hit.

- [ ] **Step 1: Implement script**

Create `scripts/projectiles/hex_bolt.gd`:

```gdscript
class_name HexBolt
extends Area2D
## Linear-flight projectile. Carries its own HitboxComponent child.
## Configured by spawner: direction, damage, source.

@export var speed: float = 300.0
@export var lifetime: float = 1.5

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

Create `scenes/projectiles/hex_bolt.tscn`:

```
[gd_scene load_steps=4 format=3]

[ext_resource type="Script" path="res://scripts/projectiles/hex_bolt.gd" id="1"]
[ext_resource type="Script" path="res://scripts/components/hitbox_component.gd" id="2"]

[sub_resource type="CircleShape2D" id="shape_hit"]
radius = 3.0

[sub_resource type="CircleShape2D" id="shape_body"]
radius = 3.0

[node name="HexBolt" type="Area2D"]
collision_layer = 0
collision_mask = 1
script = ExtResource("1")

[node name="Visual" type="ColorRect" parent="."]
offset_left = -3.0
offset_top = -1.0
offset_right = 3.0
offset_bottom = 1.0
color = Color(0.95, 0.85, 0.4, 1)

[node name="Body" type="CollisionShape2D" parent="."]
shape = SubResource("shape_body")

[node name="HitboxComponent" type="Area2D" parent="."]
collision_layer = 8
collision_mask = 0
script = ExtResource("2")

[node name="HitShape" type="CollisionShape2D" parent="HitboxComponent"]
shape = SubResource("shape_hit")

[connection signal="body_entered" from="." to="." method="_on_body_entered"]
```

**Collision layers we're committing to:**
- Layer 1 = world/walls
- Layer 2 = hero body
- Layer 4 = enemy body
- Layer 8 = hero hitbox (bolts, tether)
- Layer 16 = enemy hurtbox
- Layer 32 = enemy hitbox (contact)
- Layer 64 = hero hurtbox
- Layer 128 = pickups

(Document this in `docs/collision-layers.md` in Task 23.)

- [ ] **Step 3: Smoke-verify the scene loads**

```bash
godot --headless --path . --check-only --script <(echo 'extends SceneTree
func _init():
    var packed_scene = load("res://scenes/projectiles/hex_bolt.tscn")
    print("LOADED" if packed_scene != null else "FAILED")
    quit(0)') 2>&1 | tail -3
```

If `--check-only --script <(...)` syntax doesn't work in 4.6, alternative inline:

Write `tools/_check_scene.gd`:

```gdscript
extends SceneTree
func _init() -> void:
    var packed_scene := load("res://scenes/projectiles/hex_bolt.tscn") as PackedScene
    if packed_scene == null:
        printerr("FAILED to load hex_bolt.tscn")
        quit(1)
        return
    var instance := packed_scene.instantiate()
    if instance == null:
        printerr("FAILED to instantiate hex_bolt.tscn")
        quit(1)
        return
    instance.queue_free()
    print("OK")
    quit(0)
```

Run: `godot --headless --script tools/_check_scene.gd`. Expected: `OK`. Delete the helper after: `rm tools/_check_scene.gd tools/_check_scene.gd.uid 2>/dev/null || true`.

- [ ] **Step 4: Commit**

```bash
git add scripts/projectiles/hex_bolt.gd scenes/projectiles/hex_bolt.tscn
git add scripts/projectiles/*.uid scenes/projectiles/*.uid 2>/dev/null || true
git commit -m "feat: add HexBolt projectile scene and script"
```

---

## Task 7: Dreadhunter scene with Hex-Bolt Salvo

**Files:**
- Create: `scripts/heroes/dreadhunter.gd`
- Create: `scenes/heroes/dreadhunter.tscn`

Dreadhunter extends Hero, adds the salvo attack on the `attack` input action.

- [ ] **Step 1: Implement script**

Create `scripts/heroes/dreadhunter.gd`:

```gdscript
class_name Dreadhunter
extends Hero
## Dreadhunter — ranged DPS hero.
## M1 abilities: Hex-Bolt Salvo (base attack), Tetherhook (ability_1).
## Tetherhook is wired in Task 12.

const HEX_BOLT_SCENE: PackedScene = preload("res://scenes/projectiles/hex_bolt.tscn")

@export var salvo_count: int = 3
@export var salvo_spread_degrees: float = 8.0
@export var salvo_damage: int = 1
@export var salvo_cooldown: float = 0.5

var _salvo_timer: float = 0.0

func _process(delta: float) -> void:
    _salvo_timer = max(0.0, _salvo_timer - delta)
    if Input.is_action_pressed("attack") and _salvo_timer == 0.0:
        _fire_salvo()
        _salvo_timer = salvo_cooldown

func _fire_salvo() -> void:
    var base_direction := aim_direction()
    var half_spread_radians := deg_to_rad(salvo_spread_degrees) * 0.5
    var angle_step := 0.0
    if salvo_count > 1:
        angle_step = (half_spread_radians * 2.0) / float(salvo_count - 1)
    for i in salvo_count:
        var angle_offset := -half_spread_radians + angle_step * float(i)
        var bolt_direction := base_direction.rotated(angle_offset)
        var bolt := HEX_BOLT_SCENE.instantiate() as HexBolt
        get_tree().current_scene.add_child(bolt)
        bolt.global_position = global_position
        bolt.configure(bolt_direction, salvo_damage, self)
```

- [ ] **Step 2: Build the scene**

Create `scenes/heroes/dreadhunter.tscn`:

```
[gd_scene load_steps=6 format=3]

[ext_resource type="Script" path="res://scripts/heroes/dreadhunter.gd" id="1"]
[ext_resource type="Script" path="res://scripts/components/health_component.gd" id="2"]
[ext_resource type="Script" path="res://scripts/components/hurtbox_component.gd" id="3"]

[sub_resource type="CircleShape2D" id="shape_body"]
radius = 6.0

[sub_resource type="CircleShape2D" id="shape_hurt"]
radius = 6.0

[node name="Dreadhunter" type="CharacterBody2D"]
collision_layer = 2
collision_mask = 1
script = ExtResource("1")
move_speed = 150.0
health_path = NodePath("HealthComponent")
hurtbox_path = NodePath("HurtboxComponent")

[node name="Visual" type="ColorRect" parent="."]
offset_left = -5.0
offset_top = -5.0
offset_right = 5.0
offset_bottom = 5.0
color = Color(0.4, 0.85, 0.95, 1)

[node name="Body" type="CollisionShape2D" parent="."]
shape = SubResource("shape_body")

[node name="HealthComponent" type="Node" parent="."]
script = ExtResource("2")
max_hp = 100

[node name="HurtboxComponent" type="Area2D" parent="."]
collision_layer = 64
collision_mask = 32
script = ExtResource("3")
health_path = NodePath("../HealthComponent")

[node name="HurtShape" type="CollisionShape2D" parent="HurtboxComponent"]
shape = SubResource("shape_hurt")

[node name="Camera2D" type="Camera2D" parent="."]
position_smoothing_enabled = true
position_smoothing_speed = 8.0
```

- [ ] **Step 3: Verify loads**

Use the `tools/_check_scene.gd` pattern from Task 6 against `res://scenes/heroes/dreadhunter.tscn`. Delete helper after.

- [ ] **Step 4: Commit**

```bash
git add scripts/heroes/dreadhunter.gd scenes/heroes/dreadhunter.tscn
git add scripts/heroes/*.uid scenes/heroes/*.uid 2>/dev/null || true
git commit -m "feat: add Dreadhunter scene with Hex-Bolt Salvo"
```

---

## Task 8: Enemy base class

**Files:**
- Create: `scripts/enemies/enemy.gd`

- [ ] **Step 1: Implement**

Create `scripts/enemies/enemy.gd`:

```gdscript
class_name Enemy
extends CharacterBody2D
## Base class for enemies. Composes HealthComponent + HurtboxComponent +
## HitboxComponent. Concrete enemies add AI in _physics_process.

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

func _on_died() -> void:
    EventBus.enemy_died.emit(xp_value)
    _on_pre_free()
    queue_free()

## Override for drop behavior (XP gems handled in MeleeChaser for M1).
func _on_pre_free() -> void:
    pass
```

- [ ] **Step 2: Commit**

```bash
git add scripts/enemies/enemy.gd
git add scripts/enemies/*.uid 2>/dev/null || true
git commit -m "feat: add Enemy base class with death-to-event-bus wiring"
```

---

## Task 9: MeleeChaser enemy

**Files:**
- Create: `scripts/enemies/melee_chaser.gd`
- Create: `scenes/enemies/melee_chaser.tscn`

Straight-line steering toward the hero (looked up via group). Contact damage via a Hitbox on its body.

- [ ] **Step 1: Implement script**

Create `scripts/enemies/melee_chaser.gd`:

```gdscript
class_name MeleeChaser
extends Enemy
## Walks at the hero in a straight line. Deals contact damage on overlap.
## XP gem drop is wired in Task 11.

const XP_GEM_SCENE: PackedScene = preload("res://scenes/pickups/xp_gem.tscn")

var _target_hero: Node2D = null

func _ready() -> void:
    super()
    add_to_group("enemies")

func _physics_process(_delta: float) -> void:
    if _target_hero == null:
        _target_hero = get_tree().get_first_node_in_group("hero")
        if _target_hero == null:
            return
    var toward_hero := (_target_hero.global_position - global_position)
    if toward_hero.length_squared() > 1.0:
        velocity = toward_hero.normalized() * move_speed
    else:
        velocity = Vector2.ZERO
    move_and_slide()

func _on_pre_free() -> void:
    var xp_gem := XP_GEM_SCENE.instantiate()
    xp_gem.global_position = global_position
    get_tree().current_scene.add_child(xp_gem)
```

- [ ] **Step 2: Build the scene**

Create `scenes/enemies/melee_chaser.tscn`:

```
[gd_scene load_steps=7 format=3]

[ext_resource type="Script" path="res://scripts/enemies/melee_chaser.gd" id="1"]
[ext_resource type="Script" path="res://scripts/components/health_component.gd" id="2"]
[ext_resource type="Script" path="res://scripts/components/hurtbox_component.gd" id="3"]
[ext_resource type="Script" path="res://scripts/components/hitbox_component.gd" id="4"]

[sub_resource type="CircleShape2D" id="shape_body"]
radius = 6.0

[sub_resource type="CircleShape2D" id="shape_hurt"]
radius = 6.0

[sub_resource type="CircleShape2D" id="shape_hit"]
radius = 6.0

[node name="MeleeChaser" type="CharacterBody2D"]
collision_layer = 4
collision_mask = 1
script = ExtResource("1")
move_speed = 70.0
health_path = NodePath("HealthComponent")
hurtbox_path = NodePath("HurtboxComponent")
xp_value = 1

[node name="Visual" type="ColorRect" parent="."]
offset_left = -5.0
offset_top = -5.0
offset_right = 5.0
offset_bottom = 5.0
color = Color(0.85, 0.2, 0.2, 1)

[node name="Body" type="CollisionShape2D" parent="."]
shape = SubResource("shape_body")

[node name="HealthComponent" type="Node" parent="."]
script = ExtResource("2")
max_hp = 3

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
damage = 10
script = ExtResource("4")

[node name="HitShape" type="CollisionShape2D" parent="HitboxComponent"]
shape = SubResource("shape_hit")
```

- [ ] **Step 3: Smoke-load**

Run the `_check_scene.gd` helper against `res://scenes/enemies/melee_chaser.tscn`. Expect `OK`. Delete helper.

- [ ] **Step 4: Commit**

```bash
git add scripts/enemies/melee_chaser.gd scenes/enemies/melee_chaser.tscn
git add scripts/enemies/*.uid scenes/enemies/*.uid 2>/dev/null || true
git commit -m "feat: add MeleeChaser enemy with contact damage and XP drop"
```

---

## Task 10: XPCurve resource (TDD)

**Files:**
- Create: `scripts/data/xp_curve.gd`
- Create: `tests/unit/test_xp_curve.gd`
- Create: `resources/xp_curve.tres`

- [ ] **Step 1: Write failing test**

Create `tests/unit/test_xp_curve.gd`:

```gdscript
extends GutTest

func test_threshold_for_level_1_is_10() -> void:
    var curve := XpCurve.new()
    assert_eq(curve.threshold_to_reach(2), 10)

func test_threshold_for_level_3_is_30() -> void:
    var curve := XpCurve.new()
    assert_eq(curve.threshold_to_reach(3), 30)

func test_threshold_for_level_5_is_100() -> void:
    var curve := XpCurve.new()
    # 10 * 4 * 5 / 2 = 100
    assert_eq(curve.threshold_to_reach(5), 100)

func test_level_at_total_xp() -> void:
    var curve := XpCurve.new()
    assert_eq(curve.level_at_total_xp(0), 1)
    assert_eq(curve.level_at_total_xp(9), 1)
    assert_eq(curve.level_at_total_xp(10), 2)
    assert_eq(curve.level_at_total_xp(29), 2)
    assert_eq(curve.level_at_total_xp(30), 3)
```

- [ ] **Step 2: Run red**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_xp_curve.gd -gexit
```

- [ ] **Step 3: Implement**

Create `scripts/data/xp_curve.gd`:

```gdscript
class_name XpCurve
extends Resource
## XP thresholds. Closed-form so we don't need to store per-level arrays.
## Formula: threshold to REACH level N (from level 1) is 10 * (N-1) * N / 2.

@export var base: int = 10

func threshold_to_reach(level: int) -> int:
    if level <= 1:
        return 0
    return base * (level - 1) * level / 2

func level_at_total_xp(total_xp: int) -> int:
    var level := 1
    while threshold_to_reach(level + 1) <= total_xp:
        level += 1
    return level
```

- [ ] **Step 4: Run green**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_xp_curve.gd -gexit
```

Expected: 4/4 passed.

- [ ] **Step 5: Author the .tres**

Create `resources/xp_curve.tres`:

```
[gd_resource type="Resource" script_class="XpCurve" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/data/xp_curve.gd" id="1"]

[resource]
script = ExtResource("1")
base = 10
```

- [ ] **Step 6: Commit**

```bash
git add scripts/data/xp_curve.gd tests/unit/test_xp_curve.gd resources/xp_curve.tres
git add scripts/data/*.uid tests/unit/*.uid 2>/dev/null || true
git commit -m "feat: add XpCurve resource with closed-form threshold formula"
```

---

## Task 11: XPComponent and XPGem (TDD where it makes sense)

**Files:**
- Create: `scripts/components/xp_component.gd`
- Create: `tests/unit/test_xp_component.gd`
- Create: `scripts/pickups/xp_gem.gd`
- Create: `scenes/pickups/xp_gem.tscn`

XPComponent is testable; the gem (Area2D + magnet motion) is integration.

- [ ] **Step 1: Test XPComponent**

Create `tests/unit/test_xp_component.gd`:

```gdscript
extends GutTest

func _make_xp_component() -> XpComponent:
    var xp_component := XpComponent.new()
    xp_component.curve = XpCurve.new()
    return xp_component

func test_starts_level_1_zero_xp() -> void:
    var xp_component := _make_xp_component()
    assert_eq(xp_component.level, 1)
    assert_eq(xp_component.total_xp, 0)

func test_gain_xp_under_threshold_no_levelup() -> void:
    var xp_component := _make_xp_component()
    watch_signals(xp_component)
    xp_component.gain_xp(5)
    assert_eq(xp_component.total_xp, 5)
    assert_eq(xp_component.level, 1)
    assert_signal_emit_count(xp_component, "leveled_up", 0)

func test_gain_xp_crosses_threshold_levels_up() -> void:
    var xp_component := _make_xp_component()
    watch_signals(xp_component)
    xp_component.gain_xp(10)
    assert_eq(xp_component.level, 2)
    assert_signal_emit_count(xp_component, "leveled_up", 1)
    assert_signal_emitted_with_parameters(xp_component, "leveled_up", [2])

func test_gain_xp_can_skip_multiple_levels() -> void:
    var xp_component := _make_xp_component()
    watch_signals(xp_component)
    xp_component.gain_xp(35)  # crosses level 2 (10) and level 3 (30)
    assert_eq(xp_component.level, 3)
    assert_signal_emit_count(xp_component, "leveled_up", 2)
```

- [ ] **Step 2: Run red, then implement**

Create `scripts/components/xp_component.gd`:

```gdscript
class_name XpComponent
extends Node
## Holds total XP and current level. Emits leveled_up(new_level) once per
## level boundary crossed (including multi-level jumps).

signal xp_changed(total_xp: int, current_level: int)
signal leveled_up(new_level: int)

@export var curve: XpCurve
var total_xp: int = 0
var level: int = 1

func gain_xp(amount: int) -> void:
    if amount <= 0:
        return
    total_xp += amount
    xp_changed.emit(total_xp, level)
    var new_level := curve.level_at_total_xp(total_xp)
    while level < new_level:
        level += 1
        leveled_up.emit(level)
```

Run test, expect 4/4 green.

- [ ] **Step 3: Implement XpGem script**

Create `scripts/pickups/xp_gem.gd`:

```gdscript
class_name XpGem
extends Area2D
## Drops at enemy death position. Idle until the hero enters magnet radius,
## then accelerates toward the hero and is consumed on contact.

@export var value: int = 1
@export var magnet_radius: float = 100.0
@export var magnet_speed: float = 200.0

var _target_hero: Node2D = null
var _magnetized: bool = false

func _ready() -> void:
    body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
    if _target_hero == null:
        _target_hero = get_tree().get_first_node_in_group("hero")
        if _target_hero == null:
            return
    var distance_to_hero := global_position.distance_to(_target_hero.global_position)
    if not _magnetized and distance_to_hero <= magnet_radius:
        _magnetized = true
    if _magnetized:
        var direction_to_hero := (_target_hero.global_position - global_position).normalized()
        position += direction_to_hero * magnet_speed * delta

func _on_body_entered(body: Node) -> void:
    if body is Hero:
        var xp_component := body.get_node_or_null("XpComponent") as XpComponent
        if xp_component:
            xp_component.gain_xp(value)
        queue_free()
```

- [ ] **Step 4: Build the gem scene**

Create `scenes/pickups/xp_gem.tscn`:

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/pickups/xp_gem.gd" id="1"]

[sub_resource type="CircleShape2D" id="shape"]
radius = 3.0

[node name="XpGem" type="Area2D"]
collision_layer = 128
collision_mask = 2
script = ExtResource("1")

[node name="Visual" type="ColorRect" parent="."]
offset_left = -2.0
offset_top = -2.0
offset_right = 2.0
offset_bottom = 2.0
color = Color(0.5, 0.95, 0.45, 1)

[node name="Shape" type="CollisionShape2D" parent="."]
shape = SubResource("shape")
```

- [ ] **Step 5: Add XpComponent to Dreadhunter scene**

Edit `scenes/heroes/dreadhunter.tscn`. Add an XpComponent child loaded from `scripts/components/xp_component.gd`, with `curve = preload("res://resources/xp_curve.tres")`.

Insert these blocks into the .tscn:

In the `load_steps` header increment count by 2; in the ext_resources add:
```
[ext_resource type="Script" path="res://scripts/components/xp_component.gd" id="4"]
[ext_resource type="Resource" path="res://resources/xp_curve.tres" id="5"]
```

Add a node:
```
[node name="XpComponent" type="Node" parent="."]
script = ExtResource("4")
curve = ExtResource("5")
```

Also add the hero to the `hero` group. In Dreadhunter script `_ready`, add `add_to_group("hero")` at the top of `_ready` (call `super._ready()` first if you override).

Update `scripts/heroes/dreadhunter.gd` to override `_ready`:

```gdscript
func _ready() -> void:
    super()
    add_to_group("hero")
```

- [ ] **Step 6: Commit**

```bash
git add scripts/components/xp_component.gd tests/unit/test_xp_component.gd \
        scripts/pickups/xp_gem.gd scenes/pickups/xp_gem.tscn \
        scripts/heroes/dreadhunter.gd scenes/heroes/dreadhunter.tscn
git add scripts/components/*.uid scripts/pickups/*.uid scenes/pickups/*.uid tests/unit/*.uid 2>/dev/null || true
git commit -m "feat: add XpComponent, XpGem pickup, and Dreadhunter XP wiring"
```

---

## Task 12: Tetherhook ability

**Files:**
- Create: `scripts/projectiles/tether_chain.gd`
- Create: `scenes/projectiles/tether_chain.tscn`
- Modify: `scripts/heroes/dreadhunter.gd` (handle ability_1 input)

Pulls hit target toward hero; no damage.

- [ ] **Step 1: Implement script**

Create `scripts/projectiles/tether_chain.gd`:

```gdscript
class_name TetherChain
extends Area2D
## Travels in a line until it hits an enemy. On hit, pulls that enemy toward
## the source hero over a brief duration, then despawns.

@export var speed: float = 600.0
@export var max_range: float = 250.0
@export var pull_speed: float = 800.0
@export var pull_target_distance: float = 30.0

enum Phase { FLYING, PULLING, DONE }

var _direction: Vector2 = Vector2.RIGHT
var _origin_position: Vector2
var _source_hero: Node2D = null
var _hooked_enemy: Node2D = null
var _phase: int = Phase.FLYING

func configure(direction: Vector2, source: Node2D) -> void:
    _direction = direction.normalized()
    _source_hero = source
    _origin_position = source.global_position
    rotation = _direction.angle()
    area_entered.connect(_on_area_entered)
    body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
    match _phase:
        Phase.FLYING:
            position += _direction * speed * delta
            if global_position.distance_to(_origin_position) >= max_range:
                queue_free()
        Phase.PULLING:
            if _hooked_enemy == null or _source_hero == null:
                queue_free()
                return
            var toward_source := _source_hero.global_position - _hooked_enemy.global_position
            if toward_source.length() <= pull_target_distance:
                queue_free()
                return
            var pull_direction := toward_source.normalized()
            _hooked_enemy.global_position += pull_direction * pull_speed * delta
            global_position = _hooked_enemy.global_position

func _on_area_entered(area: Area2D) -> void:
    if _phase != Phase.FLYING:
        return
    if area is HurtboxComponent:
        var target := area.get_parent() as Node2D
        if target is Enemy:
            _hooked_enemy = target
            _phase = Phase.PULLING

func _on_body_entered(_body: Node) -> void:
    if _phase == Phase.FLYING:
        queue_free()
```

- [ ] **Step 2: Build the scene**

Create `scenes/projectiles/tether_chain.tscn`:

```
[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/projectiles/tether_chain.gd" id="1"]

[sub_resource type="CircleShape2D" id="shape"]
radius = 4.0

[node name="TetherChain" type="Area2D"]
collision_layer = 8
collision_mask = 17
script = ExtResource("1")

[node name="Visual" type="ColorRect" parent="."]
offset_left = -4.0
offset_top = -1.5
offset_right = 4.0
offset_bottom = 1.5
color = Color(0.8, 0.6, 0.3, 1)

[node name="Shape" type="CollisionShape2D" parent="."]
shape = SubResource("shape")
```

(collision_mask 17 = layer 1 (walls) + layer 16 (enemy hurtbox).)

- [ ] **Step 3: Wire input in Dreadhunter**

Edit `scripts/heroes/dreadhunter.gd`. Add at top:

```gdscript
const TETHER_SCENE: PackedScene = preload("res://scenes/projectiles/tether_chain.tscn")

@export var tether_cooldown: float = 0.4
var _tether_timer: float = 0.0
```

In `_process(delta)`:

```gdscript
    _tether_timer = max(0.0, _tether_timer - delta)
    if Input.is_action_just_pressed("ability_1") and _tether_timer == 0.0:
        _fire_tether()
        _tether_timer = tether_cooldown
```

Add function:

```gdscript
func _fire_tether() -> void:
    var tether := TETHER_SCENE.instantiate() as TetherChain
    get_tree().current_scene.add_child(tether)
    tether.global_position = global_position
    tether.configure(aim_direction(), self)
```

- [ ] **Step 4: Smoke-load tether scene**

Use `_check_scene.gd` helper against `res://scenes/projectiles/tether_chain.tscn`.

- [ ] **Step 5: Commit**

```bash
git add scripts/projectiles/tether_chain.gd scenes/projectiles/tether_chain.tscn scripts/heroes/dreadhunter.gd
git add scripts/projectiles/*.uid scenes/projectiles/*.uid 2>/dev/null || true
git commit -m "feat: add Tetherhook ability that pulls enemies to the hero"
```

---

## Task 13: Upgrade resource and three M1 upgrades (TDD)

**Files:**
- Create: `scripts/data/upgrade.gd`
- Create: `tests/unit/test_upgrade.gd`
- Create: `resources/upgrades/upgrade_hp.tres`
- Create: `resources/upgrades/upgrade_damage.tres`
- Create: `resources/upgrades/upgrade_speed.tres`

- [ ] **Step 1: Write failing test**

Create `tests/unit/test_upgrade.gd`:

```gdscript
extends GutTest

class FakeHero:
    extends Node
    var move_speed: float = 100.0
    var salvo_damage: int = 1
    var health: HealthComponent

func _make_hero() -> FakeHero:
    var hero := FakeHero.new()
    var health := HealthComponent.new()
    health.max_hp = 100
    hero.add_child(health)
    hero.health = health
    add_child_autofree(hero)
    return hero

func test_hp_upgrade_increases_max_hp() -> void:
    var upgrade: Upgrade = load("res://resources/upgrades/upgrade_hp.tres")
    var hero := _make_hero()
    upgrade.apply(hero)
    assert_eq(hero.health.max_hp, 120)

func test_damage_upgrade_increases_salvo_damage() -> void:
    var upgrade: Upgrade = load("res://resources/upgrades/upgrade_damage.tres")
    var hero := _make_hero()
    upgrade.apply(hero)
    assert_eq(hero.salvo_damage, 2)

func test_speed_upgrade_increases_move_speed() -> void:
    var upgrade: Upgrade = load("res://resources/upgrades/upgrade_speed.tres")
    var hero := _make_hero()
    upgrade.apply(hero)
    assert_almost_eq(hero.move_speed, 115.0, 0.01)

func test_unapply_reverses_apply() -> void:
    var upgrade: Upgrade = load("res://resources/upgrades/upgrade_hp.tres")
    var hero := _make_hero()
    upgrade.apply(hero)
    upgrade.unapply(hero)
    assert_eq(hero.health.max_hp, 100)
```

- [ ] **Step 2: Implement Upgrade base**

Create `scripts/data/upgrade.gd`:

```gdscript
class_name Upgrade
extends Resource
## Data-driven upgrade. Each instance carries an id, display fields, and
## the deltas it applies. Designed to be stacked: apply() can be called
## multiple times, unapply() reverses one stack.
##
## M1 supports three stat kinds: max_hp_pct, salvo_damage_flat, move_speed_pct.
## Add new kinds as needed; keep them additive so order-of-application
## doesn't change outcomes.

@export var id: StringName
@export_multiline var description: String
@export var max_hp_pct: float = 0.0       ## e.g. 0.20 = +20% max HP
@export var salvo_damage_flat: int = 0    ## e.g. 1 = +1 damage per bolt
@export var move_speed_pct: float = 0.0   ## e.g. 0.15 = +15% move speed

func apply(hero: Object) -> void:
    if max_hp_pct != 0.0 and hero.health:
        var hp_bonus := int(round(hero.health.max_hp * max_hp_pct))
        hero.health.set_max_hp(hero.health.max_hp + hp_bonus)
        hero.health.heal(hp_bonus)
    if salvo_damage_flat != 0:
        hero.salvo_damage += salvo_damage_flat
    if move_speed_pct != 0.0:
        hero.move_speed *= (1.0 + move_speed_pct)

func unapply(hero: Object) -> void:
    if max_hp_pct != 0.0 and hero.health:
        var hp_bonus := int(round(hero.health.max_hp * max_hp_pct / (1.0 + max_hp_pct)))
        hero.health.set_max_hp(hero.health.max_hp - hp_bonus)
    if salvo_damage_flat != 0:
        hero.salvo_damage -= salvo_damage_flat
    if move_speed_pct != 0.0:
        hero.move_speed /= (1.0 + move_speed_pct)
```

Note: `unapply` is exact for additive int deltas, approximate for percentage deltas. M1 doesn't actually use unapply (no item-swap UI), but the symmetry is required by the test and documents intent.

- [ ] **Step 3: Author the three .tres files**

`resources/upgrades/upgrade_hp.tres`:

```
[gd_resource type="Resource" script_class="Upgrade" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/data/upgrade.gd" id="1"]

[resource]
script = ExtResource("1")
id = &"hp_plus"
description = "+20% Max HP"
max_hp_pct = 0.20
salvo_damage_flat = 0
move_speed_pct = 0.0
```

`resources/upgrades/upgrade_damage.tres`:

```
[gd_resource type="Resource" script_class="Upgrade" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/data/upgrade.gd" id="1"]

[resource]
script = ExtResource("1")
id = &"damage_plus"
description = "+1 damage per Hex-Bolt"
max_hp_pct = 0.0
salvo_damage_flat = 1
move_speed_pct = 0.0
```

`resources/upgrades/upgrade_speed.tres`:

```
[gd_resource type="Resource" script_class="Upgrade" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/data/upgrade.gd" id="1"]

[resource]
script = ExtResource("1")
id = &"speed_plus"
description = "+15% Move Speed"
max_hp_pct = 0.0
salvo_damage_flat = 0
move_speed_pct = 0.15
```

- [ ] **Step 4: Run green**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_upgrade.gd -gexit
```

Expected: 4/4 passed.

- [ ] **Step 5: Commit**

```bash
git add scripts/data/upgrade.gd tests/unit/test_upgrade.gd resources/upgrades/
git add scripts/data/*.uid tests/unit/*.uid 2>/dev/null || true
git commit -m "feat: add Upgrade resource and three M1 stat upgrades"
```

---

## Task 14: Level-Up modal UI

**Files:**
- Create: `scripts/ui/level_up_modal.gd`
- Create: `scenes/ui/level_up_modal.tscn`
- Modify: `translations/oathfall.en.csv` (add upgrade option strings)

The modal opens on `leveled_up`, pauses the game, and presents 3 random upgrade picks. Player click applies one to the hero, then the modal closes.

- [ ] **Step 1: Add translation keys**

Append to `translations/oathfall.en.csv`:

```
UPGRADE_HP_PLUS_NAME,Reinforced Bones
UPGRADE_HP_PLUS_DESC,+20% Max HP
UPGRADE_DAMAGE_PLUS_NAME,Sharpened Bolts
UPGRADE_DAMAGE_PLUS_DESC,+1 damage per Hex-Bolt
UPGRADE_SPEED_PLUS_NAME,Quick Feet
UPGRADE_SPEED_PLUS_DESC,+15% Move Speed
```

(Update Upgrade `.tres` files later if you want to bind descriptions through `tr()`; for M1 the modal can read `description` field directly.)

- [ ] **Step 2: Implement script**

Create `scripts/ui/level_up_modal.gd`:

```gdscript
class_name LevelUpModal
extends CanvasLayer
## Pause-modal upgrade chooser. Three Buttons; clicking one applies the
## chosen Upgrade to the hero and resumes the game.

signal upgrade_chosen(upgrade: Upgrade)

const POOL: Array[String] = [
    "res://resources/upgrades/upgrade_hp.tres",
    "res://resources/upgrades/upgrade_damage.tres",
    "res://resources/upgrades/upgrade_speed.tres",
]

@onready var _title: Label = $Panel/VBox/Title
@onready var _buttons: Array[Button] = [
    $Panel/VBox/Option1,
    $Panel/VBox/Option2,
    $Panel/VBox/Option3,
]

var _options: Array[Upgrade] = []

func _ready() -> void:
    hide()
    process_mode = Node.PROCESS_MODE_ALWAYS
    for button_index in _buttons.size():
        var captured_index := button_index
        _buttons[button_index].pressed.connect(func(): _choose(captured_index))

func open() -> void:
    _title.text = tr("LEVELUP_TITLE")
    _options = _roll_options()
    for button_index in _buttons.size():
        _buttons[button_index].text = _options[button_index].description
    show()
    get_tree().paused = true

func _close() -> void:
    get_tree().paused = false
    hide()

func _roll_options() -> Array[Upgrade]:
    var pool := POOL.duplicate()
    var picked_upgrades: Array[Upgrade] = []
    var pick_count: int = min(3, pool.size())
    for _i in pick_count:
        var random_index := RNG.randi_range(0, pool.size() - 1)
        picked_upgrades.append(load(pool[random_index]) as Upgrade)
        pool.remove_at(random_index)
    return picked_upgrades

func _choose(option_index: int) -> void:
    var chosen_upgrade := _options[option_index]
    upgrade_chosen.emit(chosen_upgrade)
    _close()
```

- [ ] **Step 3: Build the scene**

Create `scenes/ui/level_up_modal.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/level_up_modal.gd" id="1"]

[node name="LevelUpModal" type="CanvasLayer"]
layer = 100
script = ExtResource("1")

[node name="Dim" type="ColorRect" parent="."]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
color = Color(0, 0, 0, 0.6)
mouse_filter = 0

[node name="Panel" type="PanelContainer" parent="."]
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -160.0
offset_top = -90.0
offset_right = 160.0
offset_bottom = 90.0

[node name="VBox" type="VBoxContainer" parent="Panel"]

[node name="Title" type="Label" parent="Panel/VBox"]
text = "Level Up!"
horizontal_alignment = 1

[node name="Option1" type="Button" parent="Panel/VBox"]
text = "Option 1"

[node name="Option2" type="Button" parent="Panel/VBox"]
text = "Option 2"

[node name="Option3" type="Button" parent="Panel/VBox"]
text = "Option 3"
```

- [ ] **Step 4: Commit**

```bash
git add scripts/ui/level_up_modal.gd scenes/ui/level_up_modal.tscn translations/oathfall.en.csv
git add scripts/ui/*.uid scenes/ui/*.uid 2>/dev/null || true
git commit -m "feat: add level-up modal with three random upgrade picks"
```

---

## Task 15: HUD (HP bar, XP bar, level)

**Files:**
- Create: `scripts/ui/hud.gd`
- Create: `scenes/ui/hud.tscn`

- [ ] **Step 1: Implement script**

Create `scripts/ui/hud.gd`:

```gdscript
class_name HUD
extends CanvasLayer
## Wires HP and XP bars to the hero's components. Bind via bind_to().

@onready var _hp_bar: ProgressBar = $Margin/VBox/HPBar
@onready var _xp_bar: ProgressBar = $Margin/VBox/XPBar
@onready var _level_label: Label = $Margin/VBox/LevelLabel

var _xp_component: XpComponent

func bind_to(hero: Hero, xp_component: XpComponent) -> void:
    hero.health.health_changed.connect(_on_health_changed)
    _on_health_changed(hero.health.current_hp, hero.health.max_hp)
    _xp_component = xp_component
    xp_component.xp_changed.connect(_on_xp_changed)
    xp_component.leveled_up.connect(_on_leveled_up)
    _on_xp_changed(xp_component.total_xp, xp_component.level)
    _on_leveled_up(xp_component.level)

func _on_health_changed(current: int, maximum: int) -> void:
    _hp_bar.max_value = maximum
    _hp_bar.value = current

func _on_xp_changed(total_xp: int, level: int) -> void:
    if _xp_component == null:
        return
    var level_floor_xp := _xp_component.curve.threshold_to_reach(level)
    var next_level_xp := _xp_component.curve.threshold_to_reach(level + 1)
    _xp_bar.min_value = level_floor_xp
    _xp_bar.max_value = next_level_xp
    _xp_bar.value = total_xp

func _on_leveled_up(level: int) -> void:
    _level_label.text = "%s %d" % [tr("HUD_LEVEL"), level]
```

- [ ] **Step 2: Build scene**

Create `scenes/ui/hud.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/hud.gd" id="1"]

[node name="HUD" type="CanvasLayer"]
script = ExtResource("1")

[node name="Margin" type="MarginContainer" parent="."]
anchors_preset = 10
anchor_right = 1.0
offset_left = 4.0
offset_top = 4.0
offset_right = -4.0
offset_bottom = 30.0

[node name="VBox" type="VBoxContainer" parent="Margin"]

[node name="LevelLabel" type="Label" parent="Margin/VBox"]
text = "Level 1"

[node name="HPBar" type="ProgressBar" parent="Margin/VBox"]
custom_minimum_size = Vector2(0, 6)
max_value = 100.0
value = 100.0
show_percentage = false

[node name="XPBar" type="ProgressBar" parent="Margin/VBox"]
custom_minimum_size = Vector2(0, 4)
max_value = 10.0
value = 0.0
show_percentage = false
```

- [ ] **Step 3: Commit**

```bash
git add scripts/ui/hud.gd scenes/ui/hud.tscn
git add scripts/ui/*.uid scenes/ui/*.uid 2>/dev/null || true
git commit -m "feat: add HUD with HP and XP bars and level label"
```

---

## Task 16: Arena scene

**Files:**
- Create: `scenes/rooms/arena_m1.tscn`

Square room, ColorRect floor, four StaticBody2D walls forming the boundary, no scripts.

- [ ] **Step 1: Build scene**

Create `scenes/rooms/arena_m1.tscn`:

```
[gd_scene load_steps=2 format=3]

[sub_resource type="RectangleShape2D" id="shape_wall_h"]
size = Vector2(960, 16)

[node name="ArenaM1" type="Node2D"]

[node name="Floor" type="ColorRect" parent="."]
offset_left = -480.0
offset_top = -320.0
offset_right = 480.0
offset_bottom = 320.0
color = Color(0.12, 0.13, 0.16, 1)

[node name="WallTop" type="StaticBody2D" parent="."]
position = Vector2(0, -328)
collision_layer = 1
collision_mask = 0

[node name="Shape" type="CollisionShape2D" parent="WallTop"]
shape = SubResource("shape_wall_h")

[node name="WallBottom" type="StaticBody2D" parent="."]
position = Vector2(0, 328)
collision_layer = 1
collision_mask = 0

[node name="Shape" type="CollisionShape2D" parent="WallBottom"]
shape = SubResource("shape_wall_h")

[node name="WallLeft" type="StaticBody2D" parent="."]
position = Vector2(-488, 0)
collision_layer = 1
collision_mask = 0
rotation = 1.5707963

[node name="Shape" type="CollisionShape2D" parent="WallLeft"]
shape = SubResource("shape_wall_h")

[node name="WallRight" type="StaticBody2D" parent="."]
position = Vector2(488, 0)
collision_layer = 1
collision_mask = 0
rotation = 1.5707963

[node name="Shape" type="CollisionShape2D" parent="WallRight"]
shape = SubResource("shape_wall_h")

[node name="EnemySpawnTimer" type="Timer" parent="."]
wait_time = 1.5
autostart = true

[node name="SpawnPoints" type="Node2D" parent="."]
```

(The Spawner/Timer/SpawnPoints are wired in Task 17's run controller — left as empty hooks here.)

- [ ] **Step 2: Smoke-load**

Use `_check_scene.gd` against `res://scenes/rooms/arena_m1.tscn`. Expect `OK`.

- [ ] **Step 3: Commit**

```bash
git add scenes/rooms/arena_m1.tscn
git add scenes/rooms/*.uid 2>/dev/null || true
git commit -m "feat: add M1 arena with floor and walls"
```

---

## Task 17: Run controller and enemy spawner

**Files:**
- Create: `scripts/world/run.gd`
- Create: `scenes/world/run.tscn`

Run is the top-level scene during a run. It instantiates the arena, the hero, the HUD, and the level-up modal, owns enemy spawning, and listens for run_ended to swap in results.

- [ ] **Step 1: Implement script**

Create `scripts/world/run.gd`:

```gdscript
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
```

- [ ] **Step 2: Build the scene**

Create `scenes/world/run.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/world/run.gd" id="1"]

[node name="Run" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 3: Smoke-load**

`_check_scene.gd` against `res://scenes/world/run.tscn`. Note: this will fail at instantiate time because results_screen.tscn doesn't exist yet (Task 18). Update the helper to just `load()` (not instantiate) for this step, or defer the load-check until after Task 18.

- [ ] **Step 4: Commit**

```bash
git add scripts/world/run.gd scenes/world/run.tscn
git add scripts/world/*.uid scenes/world/*.uid 2>/dev/null || true
git commit -m "feat: add Run controller with enemy spawning and level-up wiring"
```

---

## Task 18: Results screen and restart

**Files:**
- Create: `scripts/ui/results_screen.gd`
- Create: `scenes/ui/results_screen.tscn`
- Modify: `translations/oathfall.en.csv` (already has RESULTS_* keys from M0)

- [ ] **Step 1: Implement script**

Create `scripts/ui/results_screen.gd`:

```gdscript
class_name ResultsScreen
extends CanvasLayer
## Shown after run_ended. One button: restart.

@onready var _title: Label = $Panel/VBox/Title
@onready var _play_again_button: Button = $Panel/VBox/PlayAgain

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    get_tree().paused = true
    _title.text = tr("RESULTS_DEFEAT")
    _play_again_button.text = tr("RESULTS_PLAY_AGAIN")
    _play_again_button.pressed.connect(_restart)

func _restart() -> void:
    get_tree().paused = false
    get_tree().reload_current_scene()
```

- [ ] **Step 2: Build scene**

Create `scenes/ui/results_screen.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/results_screen.gd" id="1"]

[node name="ResultsScreen" type="CanvasLayer"]
layer = 200
script = ExtResource("1")

[node name="Dim" type="ColorRect" parent="."]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
color = Color(0, 0, 0, 0.7)
mouse_filter = 0

[node name="Panel" type="PanelContainer" parent="."]
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -120.0
offset_top = -60.0
offset_right = 120.0
offset_bottom = 60.0

[node name="VBox" type="VBoxContainer" parent="Panel"]

[node name="Title" type="Label" parent="Panel/VBox"]
text = "Defeat"
horizontal_alignment = 1

[node name="PlayAgain" type="Button" parent="Panel/VBox"]
text = "Play Again"
```

- [ ] **Step 3: Commit**

```bash
git add scripts/ui/results_screen.gd scenes/ui/results_screen.tscn
git add scripts/ui/*.uid scenes/ui/*.uid 2>/dev/null || true
git commit -m "feat: add results screen with restart button"
```

---

## Task 19: Wire Run as the main scene

**Files:**
- Modify: `project.godot` (change `run/main_scene` to point at `run.tscn`)
- Modify: `scripts/world/main.gd` (deprecate or delete — see step 2)

Until M1, `main.tscn` was the boot scene printing autoload verification. From M1 onward, the game boots straight into a run.

- [ ] **Step 1: Change main_scene**

Edit `project.godot`. Find the `[application]` section. Change:

```
run/main_scene="res://scenes/world/main.tscn"
```

to:

```
run/main_scene="res://scenes/world/run.tscn"
```

- [ ] **Step 2: Keep main.tscn but rename its purpose**

Don't delete `scenes/world/main.tscn` — it's a useful smoke-boot scene. Update `scripts/world/main.gd` docstring to note it's now a manual debug entry point used by tests, not the runtime main_scene.

Replace `scripts/world/main.gd` contents:

```gdscript
extends Node
## Debug boot scene. Not used as the runtime main_scene anymore (that's
## scenes/world/run.tscn from M1 onward). Kept for autoload smoke-checks
## and CI's boot verification — invoke directly with --main-pack.

func _ready() -> void:
    var all_autoloads_present := _verify_autoloads()
    var title := tr("GAME_TITLE")
    print("Booted: ", title, " | autoloads ok: ", all_autoloads_present)
    # Quit after one frame so this is safe to use in CI
    if OS.has_feature("headless"):
        await get_tree().process_frame
        get_tree().quit()

func _verify_autoloads() -> bool:
    var required_autoloads := ["EventBus", "RNG", "Settings", "SaveManager", "GameState"]
    for autoload_name in required_autoloads:
        if get_node_or_null("/root/" + autoload_name) == null:
            push_error("Missing autoload: " + autoload_name)
            return false
    return true
```

- [ ] **Step 3: Verify the game boots to a run headlessly (won't actually play; just confirm scene loads)**

```bash
godot --headless --path . --main-pack-disabled 2>&1 | head -20
```

If headless complains about Display Server or Camera2D in headless mode, that's expected — what we care about is no script parse errors. Quit with Ctrl+C or it'll keep running.

Safer: write `tools/_check_run.gd`:

```gdscript
extends SceneTree
func _init() -> void:
    var packed_scene := load("res://scenes/world/run.tscn")
    if packed_scene == null:
        printerr("FAIL"); quit(1); return
    print("OK"); quit(0)
```

Run it: `godot --headless --script tools/_check_run.gd`. Expect `OK`. Delete after.

- [ ] **Step 4: Commit**

```bash
git add project.godot scripts/world/main.gd
git commit -m "feat: switch main_scene to run.tscn; main.tscn becomes debug boot"
```

---

## Task 20: Run all tests; manual playthrough verification

This is the milestone-gate task. No new code; verify M1 end-to-end.

- [ ] **Step 1: Run the full test suite**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gdir=res://tests/smoke -gexit
```

Expected: previous M0 30 tests + new M1 tests all green. Approximate new test counts: health 6 + hitbox/hurtbox 4 + xp_curve 4 + xp_component 4 + upgrade 4 = 22 new tests. Total ~52.

- [ ] **Step 2: Open the project and playtest**

```bash
godot --path .
```

Manual checklist (tick each):
- [ ] Game opens to the arena. Hero is centered.
- [ ] WASD moves the hero. Camera follows.
- [ ] Mouse-aim direction works (cursor moves; bolts fire toward cursor).
- [ ] Holding Mouse-Left fires Hex-Bolt Salvo every 0.5s (3 bolts per salvo, slight spread).
- [ ] Shift fires the Tetherhook. Hit a chaser — it gets yanked to you.
- [ ] Enemies spawn around you every 1.5s and walk in.
- [ ] Killing an enemy drops a green XP gem. Walk within ~100px of the gem; it vacuums toward you and is consumed.
- [ ] At 10 XP, the modal opens, the game pauses, three random upgrades are listed.
- [ ] Clicking an upgrade applies it (visible: HP bar gets longer for HP upgrade; salvo hits harder for damage upgrade; you feel faster for speed upgrade).
- [ ] After choosing, the game unpauses, run continues.
- [ ] Taking 10 contact hits kills the hero. Results screen appears.
- [ ] "Play Again" restarts the run; HP and XP reset; arena reloads.
- [ ] No errors in the Godot output panel.

If anything in the checklist fails, **fix it** before the milestone tag. Don't push through.

- [ ] **Step 3: Commit any fixes from manual testing**

If you patched anything, commit per the same conventions: `fix: ...` or `feat: ...` with one focused commit per fix.

---

## Task 21: Document collision layers

**Files:**
- Create: `docs/collision-layers.md`

Until now the collision layer numbers have been spread across .tscn files. Document them so future enemies/items wire in correctly.

- [ ] **Step 1: Write the doc**

Create `docs/collision-layers.md`:

```markdown
# Collision Layers

These map directly to Godot's `collision_layer` and `collision_mask` bitfields.
Keep this doc in sync with all `.tscn` collision_layer / collision_mask values.

| Bit | Layer | Used by |
|---|---|---|
| 1 | 1 | World / walls (StaticBody2D in arena) |
| 2 | 2 | Hero body (CharacterBody2D) |
| 3 | 4 | Enemy body (CharacterBody2D) |
| 4 | 8 | Hero hitbox (Hex-Bolt, Tetherhook) |
| 5 | 16 | Enemy hurtbox |
| 6 | 32 | Enemy hitbox (contact damage) |
| 7 | 64 | Hero hurtbox |
| 8 | 128 | Pickups (XP gems) |

## Common mask combinations

- **Hero body** mask = 1 (collides with walls)
- **Enemy body** mask = 1 (collides with walls)
- **Hero hitbox** mask = 16 (sees enemy hurtboxes)
- **Enemy hitbox** mask = 64 (sees hero hurtbox)
- **XP gem** mask = 2 (sees hero body)
- **Tetherhook** mask = 17 (walls + enemy hurtbox)

Adding a new entity? Pick the right body layer, then set the mask to whatever the body should physically collide with. Hitboxes/Hurtboxes live on their own layers and are masked separately from body collision.
```

- [ ] **Step 2: Commit**

```bash
git add docs/collision-layers.md
git commit -m "docs: document collision layer and mask conventions"
```

---

## Task 22: Final verification, tag, and merge prep

- [ ] **Step 1: Full test sweep**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gdir=res://tests/smoke -gexit 2>&1 | tail -10
```

Expected: all green.

- [ ] **Step 2: Clean working tree**

```bash
git status
```

Expected: "nothing to commit, working tree clean".

- [ ] **Step 3: Tag the milestone**

```bash
git tag -a m1-prototype-core -m "M1 Prototype Core complete: Dreadhunter, melee chaser, XP/level loop, 3 upgrades, arena"
```

- [ ] **Step 4: Report state**

Print a one-page summary:
- Test count vs M0
- Total commits this branch
- Lines of GDScript added (`git diff --stat m0-foundations..HEAD -- '*.gd'`)
- Anything you noted as deferred

---

## Self-Review

**Spec coverage** (against M1 spec in `docs/specs/2026-05-04-oathfall-tech-stack-design.md` §10 M1):

| Spec line | Plan task |
|---|---|
| "Dreadhunter scene (movement, base attack, one signature ability)" | Tasks 5, 7, 12 |
| "One enemy type" | Tasks 8, 9 |
| "Hardcoded single arena" | Task 16 |
| "XP + level-up modal + 3 stat upgrades" | Tasks 10, 11, 13, 14 |
| "Local save backend only" | Task 17 increments `SaveManager.data.run_count` and calls `save()` |

Architecture conformance (against `docs/specs/...` §4):
- Hero kit = CharacterBody2D scene per hero ✓ (Task 7)
- AbilityComponent referencing Resources — partially: M1 hardcodes abilities in `dreadhunter.gd` (salvo + tether). Full AbilityComponent pattern with Ability Resources is deferred to M2/Oathbreaker where the stance system makes data-driven abilities essential. Noted, not a regression.
- HitboxComponent / HurtboxComponent ✓ (Task 3)
- Damage events through EventBus — partial: damage goes through Hurtbox→Health directly; EventBus carries `enemy_died(xp)` and `run_ended(won)` only. The spec language was aspirational; bypassing EventBus for damage is faster and simpler at this scale.
- `get_tree().paused = true` during modal ✓ (Task 14, 18)
- Upgrade Resource with `apply(hero)` / `unapply(hero)` ✓ (Task 13)
- All strings via `tr()` ✓ (HUD, modal title, results)

**Placeholder scan:** every code step has a complete code block. No "TBD", no "handle edge cases", no "similar to Task N".

**Type consistency:** `XpComponent` is used in `Hero._on_died`, `Dreadhunter`, `LevelUpModal`, `HUD`, `Run` — all spell it the same. `Upgrade.apply(hero)` is consistently typed `Object` since the hero base doesn't expose `salvo_damage` (that's Dreadhunter-specific); the test uses a FakeHero with the same surface.

**Deferred to M2 (intentional):**
- Wave system with multiple enemy types (M1 = single chaser on a fixed-interval timer)
- Boss
- Full Dreadhunter upgrade pool (10–15 upgrades — M1 ships 3)
- Dread Marks resource mechanic
- AbilityComponent/Ability Resource pattern
- Steam integration / Cloud save (still M2)

**Deferred to M3 (intentional):**
- VirtualStickAimProvider
- Audio
- Particle/screen-shake polish
- Mobile build validation

---

## Execution Handoff

Plan complete and saved to `docs/plans/2026-05-13-m1-prototype-core.md`. Two execution paths:

**1. Subagent-Driven (recommended)** — fresh subagent per task, review between tasks, same as M0 cadence.

**2. Inline Execution** — batch with checkpoints.

Which?
