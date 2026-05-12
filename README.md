# Oathfall

A dark fantasy top-down action roguelite. Built with Godot 4 (GDScript), targeting Steam first and iOS/Android second.

See [`docs/specs/2026-05-04-oathfall-tech-stack-design.md`](docs/specs/2026-05-04-oathfall-tech-stack-design.md) for the engineering spec and [`docs/plans/2026-05-04-m0-foundations.md`](docs/plans/2026-05-04-m0-foundations.md) for the M0 implementation plan.

## Quick Start

```bash
# Pinned engine version
cat GODOT_VERSION

# Run the project
godot --path .

# Run all unit + smoke tests headlessly
godot --headless --path . -s res://addons/gut/gut_cmdln.gd \
    -gdir=res://tests/unit -gdir=res://tests/smoke -gexit
```

## Export Presets

This project uses four export presets. Each developer must configure them locally
(via Project → Export in the editor) since `export_presets.cfg` is gitignored
(it contains machine-specific paths and signing keys).

| Preset | Renderer | Notes |
|---|---|---|
| Linux/X11 or Windows Desktop | Forward+ | Steam target (desktop) |
| macOS | Forward+ | Steam target (macOS) |
| Android | Compatibility (GLES3) | Mobile target; avoids Vulkan driver issues |
| iOS | Compatibility (GLES3) | Mobile target |

Engine version is pinned in `GODOT_VERSION`. Do not upgrade without benchmarking on
target devices first — the M0 spec documents a known Android FPS regression in 4.4dev4–4.5.

## Project Layout

- `scenes/` — Godot scene files
- `scripts/autoloads/` — singleton services (EventBus, RNG, Settings, SaveManager, GameState)
- `scripts/data/` — Resource definitions (SaveData, etc.)
- `scripts/platform/` — pluggable backends (LocalFileBackend, future SteamCloudBackend)
- `scripts/world/` — world/scene controller scripts
- `tests/unit/` — GUT unit tests
- `tests/smoke/` — GUT smoke tests
- `translations/` — CSV locale files (en first, others added by drop-in)
- `addons/` — vendored Godot plugins (GUT, AsepriteWizard)
- `tools/` — one-shot helper scripts (e.g. input-map setup)
