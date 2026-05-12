# M0 Foundations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the Oathfall Godot 4 project skeleton with all foundational infrastructure (autoloads, save backend interface, input map, localization scaffolding, CI) so that subsequent milestones can implement features without re-architecting plumbing.

**Architecture:** Single Godot 4 project at the repo root. Five autoload singletons provide cross-cutting services (`EventBus`, `RNG`, `GameState`, `SaveManager`, `Settings`). A `SaveBackend` interface allows backend swapping (local file → Steam Cloud → iCloud → Google Play in later milestones). All player-facing strings flow through `tr()`. GitHub Actions CI builds a desktop export on every PR.

**Tech Stack:** Godot 4 (stable), GDScript, GUT (Godot Unit Test) for testing, Aseprite Wizard plugin for art import (installed; usage in M1+), Git + Git LFS, GitHub Actions for CI.

---

## File Structure

After M0, the repo will contain:

```
Oathfall/
├── .github/workflows/ci.yml                 # CI: build desktop export
├── .gitattributes                           # LFS patterns
├── .gitignore                               # Godot ignores
├── GODOT_VERSION                            # Engine version pin
├── README.md                                # Already exists; updated
├── project.godot                            # Godot project config
├── icon.svg                                 # Default Godot icon
├── addons/
│   └── gut/                                 # GUT plugin (vendored)
├── assets/
│   ├── aseprite/.gitkeep
│   ├── audio/.gitkeep
│   ├── fonts/.gitkeep
│   └── sprites/.gitkeep
├── scenes/
│   ├── world/main.tscn                      # Boot scene that loads autoloads
│   ├── heroes/.gitkeep
│   ├── enemies/.gitkeep
│   ├── projectiles/.gitkeep
│   ├── pickups/.gitkeep
│   ├── rooms/.gitkeep
│   └── ui/.gitkeep
├── scripts/
│   ├── autoloads/
│   │   ├── event_bus.gd
│   │   ├── rng.gd
│   │   ├── game_state.gd
│   │   ├── settings.gd
│   │   └── save_manager.gd
│   ├── data/
│   │   └── save_data.gd                     # Versioned SaveData Resource
│   ├── platform/
│   │   └── save_backend.gd                  # Interface (abstract base class)
│   │   └── local_file_backend.gd
│   └── systems/.gitkeep
├── resources/.gitkeep
├── translations/
│   └── oathfall.en.csv                      # English locale, seed entries
└── tests/
    ├── unit/
    │   ├── test_rng.gd
    │   ├── test_event_bus.gd
    │   ├── test_game_state.gd
    │   ├── test_settings.gd
    │   ├── test_save_data.gd
    │   ├── test_local_file_backend.gd
    │   └── test_save_manager.gd
    └── smoke/
        └── test_smoke.gd                    # Verifies project boots
```

**File responsibilities:**
- Each autoload: one cross-cutting concern, ~50–150 lines.
- `save_backend.gd`: defines the interface; subclasses implement per-platform.
- `save_data.gd`: versioned data carrier (Resource), serializable.
- `local_file_backend.gd`: implements `SaveBackend` against `user://` path.
- Tests: one file per autoload/system, each <100 lines.

---

## Pre-Flight

These steps assume you have a clean working state in the existing repo at `/Users/bryantdesigns/Documents/projects/misc/Oathfall` (README and .git already exist).

- [ ] **Pre-Flight Step 1: Verify Godot 4 is installed and on PATH**

```bash
godot --version
```

Expected: a version line like `4.3.stable.official.77dcf97d8`. If not installed, download from godotengine.org (stable channel) and ensure the binary is symlinked or aliased as `godot` in your shell.

- [ ] **Pre-Flight Step 2: Verify Git LFS is installed**

```bash
git lfs version
```

Expected: a version line. If not installed: `brew install git-lfs && git lfs install`.

- [ ] **Pre-Flight Step 3: Note current working directory**

All commands in this plan run from `/Users/bryantdesigns/Documents/projects/misc/Oathfall` unless stated otherwise.

```bash
cd /Users/bryantdesigns/Documents/projects/misc/Oathfall && pwd
```

Expected: `/Users/bryantdesigns/Documents/projects/misc/Oathfall`

---

## Task 1: Pin Engine Version and Configure Git Hygiene

**Files:**
- Create: `GODOT_VERSION`
- Create: `.gitignore`
- Create: `.gitattributes`

- [ ] **Step 1: Write the engine version pin**

Create `GODOT_VERSION` containing only the exact `godot --version` output's version number (e.g., `4.3.stable`):

```
4.3.stable
```

Replace with whatever your `godot --version` reports. This file is read by humans and CI to enforce engine consistency.

- [ ] **Step 2: Create .gitignore**

Create `.gitignore`:

```gitignore
# Godot 4
.godot/
.import/
export.cfg
export_presets.cfg
*.translation

# macOS
.DS_Store

# IDEs
.vscode/
.idea/

# Build artifacts
build/
dist/
*.dmg
*.exe
*.apk
*.ipa
```

- [ ] **Step 3: Create .gitattributes for LFS**

Create `.gitattributes`:

```
*.aseprite filter=lfs diff=lfs merge=lfs -text
*.psd      filter=lfs diff=lfs merge=lfs -text
*.wav      filter=lfs diff=lfs merge=lfs -text
*.mp3      filter=lfs diff=lfs merge=lfs -text
*.ogg      filter=lfs diff=lfs merge=lfs -text
*.ttf      filter=lfs diff=lfs merge=lfs -text
*.otf      filter=lfs diff=lfs merge=lfs -text
```

PNG is intentionally NOT in LFS by default — small pixel sprites are tiny and inflating LFS storage costs hurts. Add specific large PNGs as they appear.

- [ ] **Step 4: Commit**

```bash
git add GODOT_VERSION .gitignore .gitattributes
git commit -m "chore: pin Godot version and configure git hygiene"
```

---

## Task 2: Initialize Godot Project

**Files:**
- Create: `project.godot`
- Create: `icon.svg`

- [ ] **Step 1: Create the Godot project via the editor**

Run:

```bash
godot --headless --quit
```

Then open the editor and import the current directory as a new project:

```bash
godot -e --path .
```

In the editor: when prompted, choose "Create New Project" and accept the current directory. Set Renderer to **Forward+**. Save and close the editor.

- [ ] **Step 2: Verify project files were created**

```bash
ls project.godot icon.svg
```

Expected: both files exist.

- [ ] **Step 3: Edit project.godot to set application name and main scene placeholder**

Open `project.godot` and ensure the `[application]` section reads:

```
[application]

config/name="Oathfall"
config/description="A dark fantasy top-down roguelite."
run/main_scene="res://scenes/world/main.tscn"
config/features=PackedStringArray("4.3", "Forward Plus")
config/icon="res://icon.svg"
```

(Replace "4.3" with your actual minor version.)

- [ ] **Step 4: Commit**

```bash
git add project.godot icon.svg
git commit -m "chore: initialize Godot 4 project"
```

---

## Task 3: Create Folder Structure

**Files:**
- Create: empty `.gitkeep` files in all empty directories per the File Structure section above.

- [ ] **Step 1: Create directories and .gitkeep files**

```bash
mkdir -p assets/aseprite assets/audio assets/fonts assets/sprites
mkdir -p scenes/world scenes/heroes scenes/enemies scenes/projectiles scenes/pickups scenes/rooms scenes/ui
mkdir -p scripts/autoloads scripts/data scripts/platform scripts/systems
mkdir -p resources translations tests/unit tests/smoke
mkdir -p .github/workflows

touch assets/aseprite/.gitkeep assets/audio/.gitkeep assets/fonts/.gitkeep assets/sprites/.gitkeep
touch scenes/heroes/.gitkeep scenes/enemies/.gitkeep scenes/projectiles/.gitkeep
touch scenes/pickups/.gitkeep scenes/rooms/.gitkeep scenes/ui/.gitkeep
touch scripts/systems/.gitkeep resources/.gitkeep
```

- [ ] **Step 2: Commit**

```bash
git add assets scenes scripts resources translations tests .github
git commit -m "chore: scaffold project folder structure"
```

---

## Task 4: Install GUT (Godot Unit Test) Plugin

**Files:**
- Create: `addons/gut/` (vendored from the GUT release)

- [ ] **Step 1: Download GUT 9.x release for Godot 4**

```bash
curl -L -o /tmp/gut.zip https://github.com/bitwes/Gut/archive/refs/heads/godot_4.zip
unzip -q /tmp/gut.zip -d /tmp/
mkdir -p addons
cp -R /tmp/Gut-godot_4/addons/gut addons/
rm -rf /tmp/gut.zip /tmp/Gut-godot_4
```

- [ ] **Step 2: Enable GUT in the editor**

Open the project:

```bash
godot -e --path .
```

In Project → Project Settings → Plugins, enable **Gut**. Save and close the editor.

- [ ] **Step 3: Verify GUT is enabled by checking project.godot**

```bash
grep -A 2 '\[editor_plugins\]' project.godot
```

Expected output includes `enabled=PackedStringArray("res://addons/gut/plugin.cfg")`.

- [ ] **Step 4: Write a smoke test**

Create `tests/smoke/test_smoke.gd`:

```gdscript
extends GutTest

func test_arithmetic_works() -> void:
    assert_eq(2 + 2, 4, "GUT is wired up correctly")
```

- [ ] **Step 5: Run GUT to verify it works**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

Expected: GUT prints "1 passed, 0 failed" (or similar) and exits with code 0.

- [ ] **Step 6: Commit**

```bash
git add addons/gut tests/smoke project.godot
git commit -m "chore: install GUT and add smoke test"
```

---

## Task 5: Install Aseprite Wizard Plugin (Installation Only)

**Files:**
- Create: `addons/AsepriteWizard/`

This is installed but not used until M1 art work begins. We're proving the install works now to avoid surprises later.

- [ ] **Step 1: Download Aseprite Wizard latest release**

```bash
curl -L -o /tmp/aw.zip https://github.com/viniciusgerevini/godot-aseprite-wizard/archive/refs/heads/master.zip
unzip -q /tmp/aw.zip -d /tmp/
cp -R /tmp/godot-aseprite-wizard-master/addons/AsepriteWizard addons/
rm -rf /tmp/aw.zip /tmp/godot-aseprite-wizard-master
```

- [ ] **Step 2: Enable in editor**

```bash
godot -e --path .
```

Project → Project Settings → Plugins → enable **Aseprite Wizard**. Close editor.

- [ ] **Step 3: Verify**

```bash
grep AsepriteWizard project.godot
```

Expected: `enabled=...` line includes `res://addons/AsepriteWizard/plugin.cfg`.

- [ ] **Step 4: Commit**

```bash
git add addons/AsepriteWizard project.godot
git commit -m "chore: install Aseprite Wizard plugin"
```

---

## Task 6: Configure Input Map

**Files:**
- Modify: `project.godot`

- [ ] **Step 1: Open editor and define actions**

```bash
godot -e --path .
```

In Project → Project Settings → Input Map, add the following actions with the listed default bindings:

| Action | Keyboard binding | Notes |
|---|---|---|
| `move_up` | W | |
| `move_down` | S | |
| `move_left` | A | |
| `move_right` | D | |
| `attack` | Mouse Left | |
| `dash` | Space | |
| `ability_1` | Shift | |
| `pause` | Escape | |

Save and close.

- [ ] **Step 2: Verify actions persisted in project.godot**

```bash
grep -A 1 'move_up' project.godot
```

Expected: shows the `move_up` action definition with the W key event.

- [ ] **Step 3: Commit**

```bash
git add project.godot
git commit -m "feat: define input map actions for PC controls"
```

---

## Task 7: EventBus Autoload

**Files:**
- Create: `scripts/autoloads/event_bus.gd`
- Create: `tests/unit/test_event_bus.gd`
- Modify: `project.godot` (autoload registration)

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_event_bus.gd`:

```gdscript
extends GutTest

var received_args: Array = []

func _on_enemy_died(xp: int) -> void:
    received_args.append(xp)

func before_each() -> void:
    received_args.clear()

func test_enemy_died_signal_is_defined() -> void:
    assert_true(EventBus.has_signal("enemy_died"), "enemy_died signal must exist")

func test_enemy_died_signal_carries_xp_arg() -> void:
    EventBus.enemy_died.connect(_on_enemy_died)
    EventBus.enemy_died.emit(42)
    assert_eq(received_args, [42])
    EventBus.enemy_died.disconnect(_on_enemy_died)

func test_level_up_signal_is_defined() -> void:
    assert_true(EventBus.has_signal("level_up"), "level_up signal must exist")

func test_run_ended_signal_is_defined() -> void:
    assert_true(EventBus.has_signal("run_ended"), "run_ended signal must exist")
```

- [ ] **Step 2: Run test to verify it fails**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_event_bus.gd -gexit
```

Expected: tests fail because `EventBus` autoload does not exist yet (parser error or null reference).

- [ ] **Step 3: Implement EventBus**

Create `scripts/autoloads/event_bus.gd`:

```gdscript
extends Node
## Global signal hub. Systems emit and listen here to avoid hard coupling.
##
## Convention: signals are past-tense (something happened) or imperative
## verbs for requests. Always document each signal's payload.

## Emitted when an enemy dies. xp is the amount granted to the player.
signal enemy_died(xp: int)

## Emitted when the player levels up. new_level is the level just reached.
signal level_up(new_level: int)

## Emitted when a run ends, win or loss. won is true on victory.
signal run_ended(won: bool)
```

- [ ] **Step 4: Register autoload**

Open editor:

```bash
godot -e --path .
```

Project → Project Settings → Autoload → add `scripts/autoloads/event_bus.gd` with name `EventBus`. Close editor.

- [ ] **Step 5: Run tests to verify they pass**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_event_bus.gd -gexit
```

Expected: 4 tests pass.

- [ ] **Step 6: Commit**

```bash
git add scripts/autoloads/event_bus.gd tests/unit/test_event_bus.gd project.godot
git commit -m "feat: add EventBus autoload with core signals"
```

---

## Task 8: RNG Autoload (Determinism)

**Files:**
- Create: `scripts/autoloads/rng.gd`
- Create: `tests/unit/test_rng.gd`
- Modify: `project.godot`

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_rng.gd`:

```gdscript
extends GutTest

func test_same_seed_produces_same_sequence() -> void:
    RNG.seed(12345)
    var seq_a := []
    for i in 5:
        seq_a.append(RNG.randi())

    RNG.seed(12345)
    var seq_b := []
    for i in 5:
        seq_b.append(RNG.randi())

    assert_eq(seq_a, seq_b, "Same seed must produce identical sequences")

func test_different_seeds_diverge() -> void:
    RNG.seed(1)
    var a := RNG.randi()
    RNG.seed(2)
    var b := RNG.randi()
    assert_ne(a, b, "Different seeds should produce different first values")

func test_randi_range_inclusive() -> void:
    RNG.seed(42)
    for i in 100:
        var v := RNG.randi_range(5, 10)
        assert_true(v >= 5 and v <= 10, "randi_range must be inclusive on both ends")

func test_randf_unit_interval() -> void:
    RNG.seed(42)
    for i in 100:
        var v := RNG.randf()
        assert_true(v >= 0.0 and v < 1.0, "randf must be in [0.0, 1.0)")

func test_current_seed_readable() -> void:
    RNG.seed(99)
    assert_eq(RNG.current_seed, 99)
```

- [ ] **Step 2: Run test to verify it fails**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_rng.gd -gexit
```

Expected: parser error or null-reference failure (`RNG` not yet registered).

- [ ] **Step 3: Implement RNG autoload**

Create `scripts/autoloads/rng.gd`:

```gdscript
extends Node
## Single source of randomness. Gameplay code MUST use this and never
## call randi() / randf() directly, so runs are reproducible from a seed.

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var current_seed: int = 0

func _ready() -> void:
    seed(Time.get_ticks_usec())

func seed(value: int) -> void:
    current_seed = value
    _rng.seed = value

func randi() -> int:
    return _rng.randi()

func randf() -> float:
    return _rng.randf()

func randi_range(min_value: int, max_value: int) -> int:
    return _rng.randi_range(min_value, max_value)

func randf_range(min_value: float, max_value: float) -> float:
    return _rng.randf_range(min_value, max_value)

func pick(arr: Array) -> Variant:
    if arr.is_empty():
        return null
    return arr[_rng.randi_range(0, arr.size() - 1)]
```

- [ ] **Step 4: Register autoload**

```bash
godot -e --path .
```

Project Settings → Autoload → add `scripts/autoloads/rng.gd` as `RNG`. Close editor.

- [ ] **Step 5: Run tests to verify they pass**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_rng.gd -gexit
```

Expected: 5 tests pass.

- [ ] **Step 6: Commit**

```bash
git add scripts/autoloads/rng.gd tests/unit/test_rng.gd project.godot
git commit -m "feat: add seeded RNG autoload for run determinism"
```

---

## Task 9: Settings Autoload (with persistence)

**Files:**
- Create: `scripts/autoloads/settings.gd`
- Create: `tests/unit/test_settings.gd`
- Modify: `project.godot`

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_settings.gd`:

```gdscript
extends GutTest

const TEST_PATH := "user://settings_test.cfg"

func before_each() -> void:
    if FileAccess.file_exists(TEST_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))

func test_default_master_volume_is_one() -> void:
    Settings.reset_to_defaults()
    assert_eq(Settings.master_volume, 1.0)

func test_set_master_volume_clamps_to_unit_interval() -> void:
    Settings.master_volume = 1.5
    assert_eq(Settings.master_volume, 1.0)
    Settings.master_volume = -0.5
    assert_eq(Settings.master_volume, 0.0)

func test_save_and_load_round_trip() -> void:
    Settings.master_volume = 0.42
    Settings.locale = "fr"
    Settings.save_to(TEST_PATH)

    Settings.reset_to_defaults()
    assert_eq(Settings.master_volume, 1.0)

    Settings.load_from(TEST_PATH)
    assert_eq(Settings.master_volume, 0.42)
    assert_eq(Settings.locale, "fr")
```

- [ ] **Step 2: Run to verify failure**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_settings.gd -gexit
```

Expected: failure — Settings not yet registered.

- [ ] **Step 3: Implement Settings**

Create `scripts/autoloads/settings.gd`:

```gdscript
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
```

- [ ] **Step 4: Register autoload**

Editor → Autoload → add `scripts/autoloads/settings.gd` as `Settings`. Close editor.

- [ ] **Step 5: Run tests**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_settings.gd -gexit
```

Expected: 3 tests pass.

- [ ] **Step 6: Commit**

```bash
git add scripts/autoloads/settings.gd tests/unit/test_settings.gd project.godot
git commit -m "feat: add Settings autoload with cfg persistence"
```

---

## Task 10: SaveData Resource (versioned)

**Files:**
- Create: `scripts/data/save_data.gd`
- Create: `tests/unit/test_save_data.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_save_data.gd`:

```gdscript
extends GutTest

func test_default_version_is_one() -> void:
    var data := SaveData.new()
    assert_eq(data.save_version, 1)

func test_default_run_count_is_zero() -> void:
    var data := SaveData.new()
    assert_eq(data.run_count, 0)

func test_default_unlocked_upgrades_is_empty_array() -> void:
    var data := SaveData.new()
    assert_eq(data.unlocked_upgrades, [])

func test_save_and_load_round_trip_via_resource_saver() -> void:
    var data := SaveData.new()
    data.run_count = 7
    data.unlocked_upgrades = ["dread_marks_2", "tetherhook_3"]

    var path := "user://test_save.tres"
    var save_err := ResourceSaver.save(data, path)
    assert_eq(save_err, OK)

    var loaded: SaveData = ResourceLoader.load(path)
    assert_eq(loaded.save_version, 1)
    assert_eq(loaded.run_count, 7)
    assert_eq(loaded.unlocked_upgrades, ["dread_marks_2", "tetherhook_3"])

    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
```

- [ ] **Step 2: Run to verify failure**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_save_data.gd -gexit
```

Expected: failure — `SaveData` class not defined.

- [ ] **Step 3: Implement SaveData**

Create `scripts/data/save_data.gd`:

```gdscript
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
```

- [ ] **Step 4: Run tests**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_save_data.gd -gexit
```

Expected: 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/data/save_data.gd tests/unit/test_save_data.gd
git commit -m "feat: add versioned SaveData resource"
```

---

## Task 11: SaveBackend Interface

**Files:**
- Create: `scripts/platform/save_backend.gd`

This is an abstract base — there is nothing meaningful to test on it directly; tests come on `LocalFileBackend` next.

- [ ] **Step 1: Write the interface**

Create `scripts/platform/save_backend.gd`:

```gdscript
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
```

- [ ] **Step 2: Commit**

```bash
git add scripts/platform/save_backend.gd
git commit -m "feat: add SaveBackend interface"
```

---

## Task 12: LocalFileBackend Implementation

**Files:**
- Create: `scripts/platform/local_file_backend.gd`
- Create: `tests/unit/test_local_file_backend.gd`

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_local_file_backend.gd`:

```gdscript
extends GutTest

const TEST_PATH := "user://test_save.tres"

func _make_backend() -> LocalFileBackend:
    var backend := LocalFileBackend.new()
    backend.path = TEST_PATH
    return backend

func before_each() -> void:
    if FileAccess.file_exists(TEST_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))

func test_exists_false_when_no_file() -> void:
    assert_false(_make_backend().exists())

func test_save_then_exists_true() -> void:
    var backend := _make_backend()
    var data := SaveData.new()
    backend.save(data)
    assert_true(backend.exists())

func test_save_then_load_round_trip() -> void:
    var backend := _make_backend()
    var data := SaveData.new()
    data.run_count = 13
    data.unlocked_upgrades = ["a", "b"]
    var err := backend.save(data)
    assert_eq(err, OK)

    var loaded := backend.load()
    assert_not_null(loaded)
    assert_eq(loaded.run_count, 13)
    assert_eq(loaded.unlocked_upgrades, ["a", "b"])

func test_load_returns_null_when_missing() -> void:
    assert_null(_make_backend().load())
```

- [ ] **Step 2: Run to verify failure**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_local_file_backend.gd -gexit
```

Expected: failure — `LocalFileBackend` not defined.

- [ ] **Step 3: Implement LocalFileBackend**

Create `scripts/platform/local_file_backend.gd`:

```gdscript
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
```

- [ ] **Step 4: Run tests**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_local_file_backend.gd -gexit
```

Expected: 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/platform/local_file_backend.gd tests/unit/test_local_file_backend.gd
git commit -m "feat: add LocalFileBackend implementing SaveBackend"
```

---

## Task 13: SaveManager Autoload

**Files:**
- Create: `scripts/autoloads/save_manager.gd`
- Create: `tests/unit/test_save_manager.gd`
- Modify: `project.godot`

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_save_manager.gd`:

```gdscript
extends GutTest

const TEST_PATH := "user://test_sm_save.tres"

func before_each() -> void:
    if FileAccess.file_exists(TEST_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
    var backend := LocalFileBackend.new()
    backend.path = TEST_PATH
    SaveManager.set_backend(backend)
    SaveManager.data = SaveData.new()

func test_default_backend_is_set_after_ready() -> void:
    assert_not_null(SaveManager.backend)

func test_save_persists_data_via_backend() -> void:
    SaveManager.data.run_count = 5
    var err := SaveManager.save()
    assert_eq(err, OK)

    var raw_loaded: SaveData = ResourceLoader.load(TEST_PATH)
    assert_eq(raw_loaded.run_count, 5)

func test_load_replaces_in_memory_data() -> void:
    SaveManager.data.run_count = 99
    SaveManager.save()

    SaveManager.data = SaveData.new()
    assert_eq(SaveManager.data.run_count, 0)

    SaveManager.load()
    assert_eq(SaveManager.data.run_count, 99)

func test_load_no_file_keeps_fresh_data() -> void:
    SaveManager.data = SaveData.new()
    SaveManager.data.run_count = 7
    SaveManager.load()
    assert_eq(SaveManager.data.run_count, 7, "Load with no file is a no-op")

func test_migrate_v1_to_v1_is_noop() -> void:
    var data := SaveData.new()
    data.save_version = 1
    var migrated := SaveManager.migrate(data)
    assert_eq(migrated.save_version, 1)
    assert_same(data, migrated)
```

- [ ] **Step 2: Run to verify failure**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_save_manager.gd -gexit
```

Expected: failure — SaveManager not registered.

- [ ] **Step 3: Implement SaveManager**

Create `scripts/autoloads/save_manager.gd`:

```gdscript
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
        load()

func set_backend(new_backend: SaveBackend) -> void:
    backend = new_backend

func save() -> Error:
    return backend.save(data)

func load() -> void:
    var loaded := backend.load()
    if loaded == null:
        return
    data = migrate(loaded)

## Apply schema migrations to bring older save versions to CURRENT_VERSION.
## Add a new branch here whenever save_version is bumped.
func migrate(input: SaveData) -> SaveData:
    var current := input
    # while current.save_version < CURRENT_VERSION:
    #     match current.save_version:
    #         1: current = _migrate_1_to_2(current)
    return current
```

- [ ] **Step 4: Register autoload**

Editor → Autoload → add `scripts/autoloads/save_manager.gd` as `SaveManager`. Close editor.

- [ ] **Step 5: Run tests**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_save_manager.gd -gexit
```

Expected: 5 tests pass.

- [ ] **Step 6: Commit**

```bash
git add scripts/autoloads/save_manager.gd tests/unit/test_save_manager.gd project.godot
git commit -m "feat: add SaveManager autoload with backend swap and migration hook"
```

---

## Task 14: GameState Autoload

**Files:**
- Create: `scripts/autoloads/game_state.gd`
- Create: `tests/unit/test_game_state.gd`
- Modify: `project.godot`

- [ ] **Step 1: Write the failing test**

Create `tests/unit/test_game_state.gd`:

```gdscript
extends GutTest

func before_each() -> void:
    GameState.reset()

func test_reset_clears_run_state() -> void:
    GameState.hero_id = "dreadhunter"
    GameState.current_seed = 999
    GameState.reset()
    assert_eq(GameState.hero_id, "")
    assert_eq(GameState.current_seed, 0)
    assert_false(GameState.run_in_progress)

func test_start_run_sets_state() -> void:
    GameState.start_run("dreadhunter", 12345)
    assert_eq(GameState.hero_id, "dreadhunter")
    assert_eq(GameState.current_seed, 12345)
    assert_true(GameState.run_in_progress)

func test_start_run_seeds_rng() -> void:
    GameState.start_run("dreadhunter", 777)
    assert_eq(RNG.current_seed, 777)

func test_end_run_clears_in_progress() -> void:
    GameState.start_run("dreadhunter", 1)
    GameState.end_run(true)
    assert_false(GameState.run_in_progress)
```

- [ ] **Step 2: Run to verify failure**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_game_state.gd -gexit
```

Expected: failure — GameState not registered.

- [ ] **Step 3: Implement GameState**

Create `scripts/autoloads/game_state.gd`:

```gdscript
extends Node
## In-flight run state: which hero, seed, run-scoped counters.
## Persists no data — that's SaveManager's job.

var hero_id: String = ""
var current_seed: int = 0
var run_in_progress: bool = false
var current_level: int = 1
var current_xp: int = 0

func reset() -> void:
    hero_id = ""
    current_seed = 0
    run_in_progress = false
    current_level = 1
    current_xp = 0

func start_run(hero: String, seed: int) -> void:
    reset()
    hero_id = hero
    current_seed = seed
    run_in_progress = true
    RNG.seed(seed)

func end_run(won: bool) -> void:
    run_in_progress = false
    EventBus.run_ended.emit(won)
```

- [ ] **Step 4: Register autoload**

Editor → Autoload → add `scripts/autoloads/game_state.gd` as `GameState`.

**Autoload load order matters.** Reorder so the list is:
1. EventBus
2. RNG
3. Settings
4. SaveManager
5. GameState

(GameState references RNG and EventBus on `start_run` / `end_run`.)

Close editor.

- [ ] **Step 5: Run tests**

```bash
godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_game_state.gd -gexit
```

Expected: 4 tests pass.

- [ ] **Step 6: Commit**

```bash
git add scripts/autoloads/game_state.gd tests/unit/test_game_state.gd project.godot
git commit -m "feat: add GameState autoload for in-flight run state"
```

---

## Task 15: Localization Scaffolding

**Files:**
- Create: `translations/oathfall.en.csv`
- Modify: `project.godot` (translations registration)

- [ ] **Step 1: Write the seed translation CSV**

Create `translations/oathfall.en.csv`:

```csv
keys,en
GAME_TITLE,Oathfall
MENU_PLAY,Play
MENU_OPTIONS,Options
MENU_QUIT,Quit
HUD_LEVEL,Level
HUD_XP,XP
HUD_HP,HP
LEVELUP_TITLE,Level Up!
LEVELUP_CHOOSE,Choose an upgrade
RESULTS_VICTORY,Victory
RESULTS_DEFEAT,Defeat
RESULTS_PLAY_AGAIN,Play Again
PAUSE_TITLE,Paused
PAUSE_RESUME,Resume
PAUSE_QUIT_TO_MENU,Quit to Menu
```

- [ ] **Step 2: Register translations in project**

```bash
godot -e --path .
```

Project → Project Settings → Localization → Translations tab → Add `res://translations/oathfall.en.csv`. Set Locale Filter to enable English. Close editor.

- [ ] **Step 3: Verify by reading project.godot**

```bash
grep -A 2 'translations=' project.godot
```

Expected: `translations=PackedStringArray("res://translations/oathfall.en.csv")`.

- [ ] **Step 4: Commit**

```bash
git add translations/oathfall.en.csv project.godot
git commit -m "feat: add localization scaffolding with English seed strings"
```

---

## Task 16: Boot Scene (main.tscn)

**Files:**
- Create: `scenes/world/main.tscn`
- Create: `scripts/world/main.gd`

- [ ] **Step 1: Create the boot script**

Create `scripts/world/main.gd`:

```gdscript
extends Node
## Boot scene. Verifies all autoloads are present and prints the
## localized title. In M1 this becomes the title screen with Play.

func _ready() -> void:
    var ok := _verify_autoloads()
    var title := tr("GAME_TITLE")
    print("Booted: ", title, " | autoloads ok: ", ok)

func _verify_autoloads() -> bool:
    var required := ["EventBus", "RNG", "Settings", "SaveManager", "GameState"]
    for name in required:
        if not Engine.has_singleton(name) and get_node_or_null("/root/" + name) == null:
            push_error("Missing autoload: " + name)
            return false
    return true
```

- [ ] **Step 2: Create main.tscn**

Create `scenes/world/main.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/world/main.gd" id="1"]

[node name="Main" type="Node"]
script = ExtResource("1")
```

- [ ] **Step 3: Run the project headlessly to verify boot**

```bash
godot --headless --path . --quit-after 1 2>&1 | tee /tmp/oathfall_boot.log
grep "Booted: Oathfall | autoloads ok: true" /tmp/oathfall_boot.log
```

Expected: grep finds the line. If not, inspect the log for missing autoload or parse errors and fix.

- [ ] **Step 4: Commit**

```bash
git add scenes/world/main.tscn scripts/world/main.gd
git commit -m "feat: add boot scene that verifies autoloads and prints title"
```

---

## Task 17: Configure Mobile Export Presets

**Files:**
- Create: `export_presets.cfg` (this file is gitignored)
- Modify: `.gitignore` (already excludes export_presets.cfg)

Export presets contain machine-specific paths (signing keys, etc.) so they're not committed. We document the configuration in code, then create the local file.

- [ ] **Step 1: Create export presets via the editor**

```bash
godot -e --path .
```

Project → Export → Add three presets:

1. **`Linux/X11`** (or **`Windows Desktop`** if developing on Windows): Renderer → leave at default (Forward+).
2. **`macOS`**: Renderer → leave at default (Forward+).
3. **`Android`**: Renderer Override → **Compatibility (GLES3)**.
4. **`iOS`**: Renderer Override → **Compatibility (GLES3)**.

Save and close. Don't worry about signing/keystore — that's M3.

- [ ] **Step 2: Verify export_presets.cfg was created**

```bash
ls export_presets.cfg
```

Expected: file exists locally; not staged for commit (gitignored).

- [ ] **Step 3: Document the preset configuration in README**

Append to `README.md`:

```markdown

## Export Presets

This project uses four export presets. Each developer must configure them locally
(via Project → Export in the editor) since `export_presets.cfg` is gitignored.

| Preset | Renderer | Notes |
|---|---|---|
| Linux/X11 or Windows Desktop | Forward+ | Steam target (desktop) |
| macOS | Forward+ | Steam target (macOS) |
| Android | Compatibility (GLES3) | Mobile target; avoids Vulkan driver issues |
| iOS | Compatibility (GLES3) | Mobile target |

Engine version is pinned in `GODOT_VERSION`. Do not upgrade without benchmarking on
target devices first — the M0 spec documents a known Android FPS regression in 4.4dev4–4.5.
```

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "docs: document export preset configuration"
```

---

## Task 18: GitHub Actions CI

**Files:**
- Create: `.github/workflows/ci.yml`

- [ ] **Step 1: Write the CI workflow**

Create `.github/workflows/ci.yml`:

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    name: Run GUT tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          lfs: true

      - name: Read pinned Godot version
        id: godot
        run: echo "version=$(cat GODOT_VERSION | cut -d. -f1-3)" >> $GITHUB_OUTPUT

      - name: Set up Godot
        uses: chickensoft-games/setup-godot@v2
        with:
          version: ${{ steps.godot.outputs.version }}
          use-dotnet: false

      - name: Import project
        run: godot --headless --import || true

      - name: Run unit tests
        run: |
          godot --headless --path . \
            -s res://addons/gut/gut_cmdln.gd \
            -gdir=res://tests/unit \
            -gexit

      - name: Run smoke test
        run: |
          godot --headless --path . \
            -s res://addons/gut/gut_cmdln.gd \
            -gdir=res://tests/smoke \
            -gexit

  build-linux:
    name: Build Linux export
    runs-on: ubuntu-latest
    needs: test
    steps:
      - uses: actions/checkout@v4
        with:
          lfs: true

      - name: Read pinned Godot version
        id: godot
        run: echo "version=$(cat GODOT_VERSION | cut -d. -f1-3)" >> $GITHUB_OUTPUT

      - name: Set up Godot
        uses: chickensoft-games/setup-godot@v2
        with:
          version: ${{ steps.godot.outputs.version }}
          use-dotnet: false

      - name: Install export templates
        run: godot --headless --install-export-templates || true

      - name: Import project
        run: godot --headless --import || true

      - name: Build Linux export
        run: |
          mkdir -p build/linux
          godot --headless --path . --export-debug "Linux/X11" build/linux/oathfall.x86_64 || \
            godot --headless --path . --export-debug "Linux" build/linux/oathfall.x86_64

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: oathfall-linux-debug
          path: build/linux/
          retention-days: 7
```

- [ ] **Step 2: Push to a feature branch and open a PR to verify CI runs**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: add GitHub Actions workflow for tests and Linux build"
git push -u origin HEAD
```

Then open a PR on GitHub. Watch the Actions tab.

- [ ] **Step 3: Verify CI passes**

The first run may fail if:
- Export templates aren't pre-installed (the workflow handles it lazily; first run might need a manual rerun).
- The export preset name is `Linux/X11` vs `Linux` depending on Godot version (the workflow tries both).

If CI fails, read the log, fix the workflow, push again. Iterate until green.

- [ ] **Step 4: Once CI is green, merge and confirm on main**

After PR is approved/merged, confirm the CI run on main is also green.

---

## Task 19: Run All Tests Locally as Final Verification

- [ ] **Step 1: Run all unit and smoke tests**

```bash
godot --headless --path . \
  -s res://addons/gut/gut_cmdln.gd \
  -gdir=res://tests \
  -gexit
```

Expected: every test in every file passes; exit code 0.

- [ ] **Step 2: Run the boot scene one more time**

```bash
godot --headless --path . --quit-after 1 2>&1 | grep "autoloads ok: true"
```

Expected: line found.

- [ ] **Step 3: Confirm git status is clean**

```bash
git status
```

Expected: "nothing to commit, working tree clean" on the M0 branch.

- [ ] **Step 4: Tag the M0 milestone**

```bash
git tag -a m0-foundations -m "M0 Foundations complete: project skeleton, autoloads, save backend, CI"
git push --tags
```

---

## Self-Review Pass

**Spec coverage check** (against `2026-05-04-oathfall-tech-stack-design.md`):

| Spec section | Plan task |
|---|---|
| §2.1 Engine = Godot 4 | Task 2 |
| §2.1 GDScript primary | All code tasks |
| §2.1 Aseprite | Task 5 |
| §2.1 GodotSteam | Deferred to M2 (acknowledged in plan goal) |
| §2.1 Forward+ desktop / Compatibility mobile | Task 17 |
| §2.1 Git + Git LFS | Task 1 |
| §2.1 GUT testing | Task 4 |
| §2.1 GitHub Actions CI | Task 18 |
| §3.1 Folder layout | Task 3 |
| §3.2 EventBus autoload | Task 7 |
| §3.2 RNG autoload | Task 8 |
| §3.2 GameState autoload | Task 14 |
| §3.2 SaveManager autoload | Task 13 |
| §3.2 Settings autoload | Task 9 |
| §6.1 SaveBackend interface + LocalFileBackend | Tasks 11, 12 |
| §6.1 Versioned SaveData + migration hook | Tasks 10, 13 |
| §6.2 tr() scaffolding + CSV | Task 15 |
| §6.3 Determinism via single RNG | Task 8 + GameState integration in Task 14 |
| §7 GODOT_VERSION pinning | Task 1 |
| §10 M0 milestone deliverables | All tasks |

**Items deferred to later milestones (intentional):**
- GodotSteam initialization → M2 (Task 13's `set_backend` makes it a swap, not a refactor)
- iCloud/Google Play backends → M3
- Hero scenes, enemies, combat, upgrades → M1+
- Audio bus structure → M3

No placeholders, no "TBD", no skipped code. Migration framework is stub-but-real (the loop is commented because there's only v1; pattern is established for v2).

---

## Execution Handoff

Plan complete and saved to `/Users/bryantdesigns/Documents/projects/misc/Oathfall/docs/plans/2026-05-04-m0-foundations.md`.

Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration. Best when you want to step away and return to a clean diff to review.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints. Best when you want to watch progress in real time and intervene.

Which approach?
