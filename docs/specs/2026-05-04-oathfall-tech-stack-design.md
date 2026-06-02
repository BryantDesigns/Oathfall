# Oathfall — Tech Stack & Foundational Architecture Design

**Date:** 2026-05-04
**Status:** Draft for review
**Authors:** Tyler Bryant + Claude (brainstorming session)

## 1. Context

Oathfall is a top-down action roguelite, dark fantasy genre, with six planned heroes, procedurally generated maps, level-up upgrade drafts, boss fights, and light meta progression. Target session length is 5–10 minutes per run. See the existing concept and PRD documents in the design vault for game-design detail.

**Platform targets:** Steam (PC) primary, iOS/Android secondary (port within ~6 months of Steam launch, not a co-launch).

**Team:** Two-person part-time team. Primary developer is a TypeScript/Node fullstack engineer with no prior game-development experience and light C# exposure.

**This document covers** the engineering foundation — engine, language, project architecture, core-system mapping, mobile-readiness strategy, persistence, localization, tooling, learning path, and milestone plan. It does not specify game design (covered in the PRD) or art direction beyond the chosen pixel-art style.

## 2. Stack Decision

### 2.1 Recommended Stack

| Layer | Choice |
|---|---|
| Engine | **Godot 4** (current stable 4.x; pinned per milestone) |
| Primary language | **GDScript** |
| Escape-hatch language | **C#** for any single performance-critical system |
| Art tool | **Aseprite** (sprite sheets + JSON, imported via Aseprite Wizard plugin) |
| Steam integration | **GodotSteam** (community module) |
| Mobile renderer | **Compatibility (GLES3)** for Android/iOS exports |
| Desktop renderer | **Forward+** for Steam exports |
| Source control | **Git + Git LFS** |
| Testing | **GUT (Godot Unit Test)** for systems-level tests |
| CI | **GitHub Actions** with a headless Godot export action |

### 2.2 Rationale

Godot 4 is the validated choice for indie 2D pixel-art roguelites in this team-size/scope range. Brotato, Dome Keeper, Buckshot Roulette, Backpack Battles, and Halls of Torment are all shipped commercial successes on Godot in this exact genre. Godot's 2D pipeline is class-leading, integer scaling for pixel art is built in (4.3+), and the engine carries no licensing risk as the project matures.

GDScript is chosen as primary because it offers the smoothest onboarding for a TypeScript developer (Python-ish syntax, optional static typing), tightest engine integration, the largest body of tutorials and community examples, and the best mobile export story (no .NET runtime overhead). C# remains available for any system that benchmarks slowly enough in GDScript to justify the marshalling cost.

The Compatibility renderer is selected for mobile to avoid documented Vulkan-driver issues on Android and to maximize older-device coverage. Forward+ on desktop preserves the full feature set (lighting, shaders) on Steam.

### 2.3 Alternatives Considered

- **Unity** — stronger for 3D and mobile-first projects, but heavier mental model, recent licensing instability, and a 2D pipeline that is bolted on top of 3D rather than first-class. Not justified given the project profile.
- **Phaser / PixiJS + Tauri/Capacitor** — would leverage existing TypeScript skills, but Steamworks integration, mobile feel, performance ceiling, and shipping-game tooling are materially worse than Godot. Rejected.
- **GameMaker, Defold, LÖVE** — all viable for the genre but smaller communities and weaker Steam/mobile tooling than Godot. Rejected.

## 3. Project Architecture

### 3.1 Repository Layout

```
oathfall/
├── project.godot
├── addons/                    # GodotSteam, Aseprite Wizard, GUT
├── assets/
│   ├── aseprite/              # Source .aseprite files (LFS)
│   ├── sprites/               # Exported sprite sheets
│   ├── audio/
│   └── fonts/
├── scenes/
│   ├── heroes/
│   ├── enemies/
│   ├── projectiles/
│   ├── pickups/
│   ├── rooms/
│   ├── ui/
│   └── world/
├── scripts/
│   ├── autoloads/
│   ├── systems/               # Combat, XP, upgrades, mapgen
│   ├── data/                  # Resource definitions
│   └── platform/              # Steam, mobile, save backends
├── resources/                 # .tres files
├── translations/              # CSV locale files
└── tests/                     # GUT test scenes
```

### 3.2 Autoload Singletons

Used sparingly. All five are present from the foundations milestone, even if empty.

- **GameState** — the in-flight run: hero, seed, current upgrades, XP/level
- **EventBus** — global signals (`enemy_died`, `level_up`, `run_ended`)
- **SaveManager** — abstracts the backend (Steam Cloud / iCloud / Google Play / local file)
- **Settings** — audio, controls, accessibility, locale
- **RNG** — wraps a seeded `RandomNumberGenerator` for determinism

### 3.3 Data-Driven Design

Heroes, upgrades, enemies, weapons, and boss telegraphs are defined as Godot Resources (`.tres` files) edited in the inspector — not hardcoded. Adding hero #2 means dropping a new scene and a new Resource, not refactoring code. This pattern also enables non-programmer designer iteration.

## 4. Core System Mapping

| System | Implementation |
|---|---|
| Hero kit | `CharacterBody2D` scene per hero, abilities as `AbilityComponent` nodes referencing ability Resources |
| Combat | `HitboxComponent` / `HurtboxComponent` pattern, damage events through `EventBus` |
| XP & level-up | XP component on hero, threshold curve as Resource, `get_tree().paused = true` during modal |
| Upgrade draft | Upgrade is a Resource with `apply(hero)` / `unapply(hero)`; pool filtered by tags; stacking via integer counter on per-run instance |
| Procedural map (MVP) | Single-arena wave survival (PRD Option C) — simplest, mobile-friendly, matches Brotato/Halls of Torment pattern |
| Procedural map (post-MVP) | Arena-segment sequences and room graphs |
| Boss | `BossController` state machine with telegraph timings as exported variables for fast tuning |
| Meta progression | Versioned `MetaSave` Resource: unlocked upgrades, hero unlocks, run history |
| HUD/UI | `Control` nodes; all strings via `tr()`; bind to `EventBus` signals |

## 5. Mobile-Readiness Architecture

Mobile is a port, not a co-launch, but the architecture is laid down from commit one so the port is weeks of work, not months.

### 5.1 Input Abstraction

Gameplay code never reads keyboard or mouse directly. All input flows through Godot's Input Map actions (`move_up`, `attack`, `dash`, etc.). Mobile adds touch bindings to the same actions; hero scripts do not change.

For aiming, an `AimProvider` interface has two implementations:
- `MouseAimProvider` — desktop
- `VirtualStickAimProvider` — mobile

The active hero asks the provider for an aim vector and is agnostic to which is bound.

### 5.2 Renderer Per-Platform

Forward+ for desktop exports, Compatibility (GLES3) for Android/iOS exports. Same project; different export presets. This avoids documented Vulkan driver issues on Android and broadens device coverage.

### 5.3 UI Scaling and Touch Targets

- Stretch Mode: `viewport`, aspect: `keep`
- Base resolution: 480×270 or 640×360 (TBD during prototype)
- Minimum interactive UI element size: 44×44 px (touch-target rule applied to all platforms from the start, not retrofitted)

## 6. Persistence and Localization

### 6.1 Save Architecture

```
SaveManager (autoload)
  ├── SaveBackend (interface)
  │   ├── LocalFileBackend       # always available, fallback
  │   ├── SteamCloudBackend      # desktop, when GodotSteam initialized
  │   ├── iCloudBackend          # iOS
  │   └── GooglePlayBackend      # Android
  ├── SaveData (versioned Resource)
  └── Migrations (v1 → v2 → v3 ...)
```

Save files are versioned (`save_version: int`) from the first commit. Every content update that changes save shape ships with a migration function. This protects post-launch updates that add heroes, upgrades, or unlock categories.

### 6.2 Localization

- All player-facing strings — including debug strings — go through `tr("KEY_NAME")` from the first commit.
- Translation table is a CSV in `translations/`, editable by external translators without programmer involvement.
- MVP ships English only; the architecture is in place for additional locales as a CSV drop.
- UI layouts reserve space for ~1.5× English string length to accommodate German/Russian.

### 6.3 Determinism

- Single autoload `RNG` wraps a seeded `RandomNumberGenerator`.
- All systems requiring randomness call `RNG`. The global `randi()` is forbidden in gameplay code.
- Run seed is logged at run start to enable bug reproduction from player reports.

## 7. Tooling and Workflow

- **Source control:** Git with Git LFS for `*.aseprite`, large `*.png` assets, and audio.
- **Aseprite pipeline:** Aseprite Wizard plugin for auto-import as `SpriteFrames`. Set up in foundations milestone.
- **Godot version pinning:** A `GODOT_VERSION` file in the repo locks the engine version per milestone. No auto-upgrades. The Android performance regression in 4.4dev4–4.5 is the concrete reason.
- **Steamworks:** GodotSteam as a Godot addon. Achievement and Cloud configuration created in the Steamworks partner portal during MVP M2.
- **Code signing:** EV certificate for Windows (~$200–400/yr) before Steam launch. Apple Developer account ($99/yr) before iOS TestFlight.
- **Testing:** GUT for upgrade application, RNG determinism, save migration, and any pure-data systems. Visual rendering and animation are not unit-tested.
- **CI:** GitHub Actions builds desktop (and later, mobile) export artifacts on every PR to main. The "exports broke" failure mode is caught before launch.

## 8. Risks and Mitigations

| Risk | Mitigation |
|---|---|
| Godot 4.4dev4–4.5 Android FPS regression | Pin engine version per milestone; benchmark on a target Android device before adopting any new stable. |
| GodotSteam single-maintainer bus factor | Use it for Steam-only integration; do not rely on it for additional storefronts. |
| Windows Smart App Control flagging unsigned binaries | Budget for EV code signing before Steam launch. |
| Editor stability during heavy iteration | Commit frequently in small increments. |
| Commercial polish (multi-store entitlements, leaderboards) is "roll your own" in Godot | Accept this; ship Steam-first with Steam-only services. |
| Save format breakage on content updates | Versioned saves and migration functions from the first commit. |
| C# debugging requires external IDE setup | GDScript primary keeps the in-editor debugger sufficient. C# adopted only when justified, with Rider or VS Code C# Dev Kit set up at that time. |

## 9. Learning Path

A roughly 4–6 week onboarding for the primary developer, evenings only.

- **Week 1–2:** GDQuest "Learn GDScript From Zero" + Godot official step-by-step 2D tutorial. Build and discard a top-down character that moves, shoots, and kills one enemy.
- **Week 3–4:** Heartbeast Action RPG YouTube series for hitbox/hurtbox patterns. Godot docs deep dive on Resources, Signals, and Autoloads. Read source of one open-source Godot game.
- **Week 5–6:** Watch shipped-game postmortem talks (Brotato, Halls of Torment). Build the first real Oathfall code: hero + 1 enemy + XP + 1 upgrade choice.

Skipped during onboarding: shaders, lighting, 3D, physics joints, animation trees. None are required for MVP.

## 10. Milestones

Aligned with the PRD with engineering additions.

### Milestone 0 — Foundations (1–2 weeks after onboarding)

- Repo + Godot version pinned + Git LFS + Aseprite Wizard + GUT
- Autoloads scaffolded (`GameState`, `EventBus`, `SaveManager`, `RNG`, `Settings`)
- Input Map with all PC actions defined
- `tr()` localization scaffolding in place
- CI building desktop export on every PR

### Milestone 1 — Prototype Core (~2 weeks)

- Dreadhunter scene (movement, base attack, one signature ability) — chosen as M1 vehicle over the protagonist Oathbreaker because his mark+execute kit is the simplest in the roster; Oathbreaker's stance system + Oath Shards lands in M2 alongside the boss work.
- One enemy type
- Hardcoded single arena (no procedural variation yet)
- XP + level-up modal + 3 stat upgrades
- Local save backend only

### Milestone 2 — MVP Vertical Slice (~3–4 weeks)

- Wave spawner, 3 enemy types, escalating waves
- Boss fight: 1 boss, 2–3 telegraphed attacks
- Dreadhunter full upgrade pool (10–15 upgrades)
- Results screen + persistent meta unlock
- GodotSteam integrated, basic achievements
- Steam Cloud save backend

### Milestone 3 — Polish & Mobile-Ready (~3–4 weeks)

- Audio + VFX pass
- Touch input adapter built and tested in editor
- Compatibility renderer export tested on Android emulator
- Localization verified by swapping to a placeholder locale
- Steam store page + capsule art

### Post-MVP (out of scope for this spec)

- Additional heroes beyond Dreadhunter (M1) and Oathbreaker (M2): Ash Warden, Gravebound, Pale Inquisitor, Thorn Saint
- Additional biomes and enemy factions
- Mini-bosses and procedural map variants
- Mobile launch
- Monetization and cosmetics

## 11. Open Questions

- Base pixel-art resolution: 480×270 vs 640×360 — defer to prototype testing.
- Mobile aim model: virtual stick vs auto-aim with manual override — defer to mobile readiness milestone.
- Whether C# will actually be needed anywhere — defer until a benchmark proves it.

## 12. Out of Scope

- Game design decisions covered by the PRD (combat tuning, hero balance, monetization model)
- Marketing, community management, and Steam store strategy
- Multiplayer or networking of any kind
