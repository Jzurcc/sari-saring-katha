# Sari-Saring Katha — Automated Tests

## Framework: GdUnit4

Tests use [GdUnit4](https://github.com/MikeSchulze/gdUnit4), the standard Godot 4 unit test framework.

### Setup (one-time)

1. Open Godot → AssetLib → search **GdUnit4** → Install
2. Or: download the latest release from https://github.com/MikeSchulze/gdUnit4/releases
   and extract into `addons/gdUnit4/`
3. Enable plugin: Project → Project Settings → Plugins → GdUnit4 ✅

### Running Tests

- In Godot editor: bottom panel → **GdUnit4** tab → Run All
- CLI: `godot --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd`

### Test File Conventions

| Location | What's tested |
|---|---|
| `Tests/Unit/` | Pure logic — no scene tree required |
| `Tests/Integration/` | Tests that need a minimal scene |

### Current Test Coverage

| File | What it covers |
|---|---|
| `Tests/Unit/test_transaction_context.gd` | `from_dict`/`to_dict` round-trip, null-safe item loading |
| `Tests/Unit/test_story_manager_cooldown.gd` | `_process_story_cooldown` single-advance guard |
| `Tests/Unit/test_customer_spawner_race.gd` | `_is_spawning` guard before await — no double-spawn |
