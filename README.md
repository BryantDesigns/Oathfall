# Oathfall

A dark fantasy top-down action roguelite. Built with Godot 4 (GDScript), targeting Steam first and iOS/Android second.

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
target devices first — there is a known Android FPS regression in Godot 4.4dev4–4.5.

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
