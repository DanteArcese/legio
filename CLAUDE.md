# CLAUDE.md

This file provides guidance to Claude Code when working in this repository.

## Project

legio: a single-player RPG (MMO later) inspired by Old School RuneScape, set in a low-fantasy Roman world, with controller support. The client is Godot 4. Python/uv tooling validates game content data. The design lives in `docs/design.md`.

- Keep game logic tick-based and separate from rendering, so it could later run on a server.
- Don't use OSRS names, art, music, or exact numbers. See "IP guardrails" in `docs/design.md`.

## Commands

```bash
uv sync              # Install dependencies
uv add <package>     # Add a dependency
uv run pytest        # Run Python tests, including content validation
uv run python tools/content_validator.py   # Validate game/content/*.json
scripts/godot-tests.sh   # Run Godot tests headlessly (needs godot 4.7 on PATH, or set GODOT)
scripts/playtest.sh <scenario> [--render] [--out <dir>]   # Scripted playtest; --render saves screenshots
scripts/playtest-all.sh   # Run every scenario headlessly (run before pushing gameplay changes)
godot --path game    # Play the game
godot -e --path game # Open the editor
uv run --env-file .env <command>   # Run with local secrets
```

## Standards

- Python with `uv` only. No `pip install` or `python -m venv`.
- Track work in GitHub issues. Reference the issue in commits and PRs.
- Add or update tests with every feature. Keep the suite passing.
- Secrets live in `.env` (gitignored). Document variable names in `.env.example`. Do not read `.env`.

## Godot layout

- `game/` is the Godot project. `game/.godot/` is generated and gitignored. Commit `*.uid` files.
- Tests are `game/tests/test_*.gd` and extend `res://tests/test_case.gd`. Methods named `test_*` run in the headless runner (`game/tests/run_tests.gd`).
- Input bindings are defined in code in `game/scripts/input/bindings.gd`, not in project.godot. Every action needs a keyboard/mouse binding and a gamepad binding.
- Use `preload` instead of `class_name`, so scripts resolve in a fresh checkout without an editor import.
- Playtest scenarios live in `game/tools/playtest/scenarios/`, extend `scenario.gd`, and drive the real scene (walk_to, route_to, press, seconds, shot, metric, expect). Use `route_to` for trips that cross the Castra Ferrea walls; it goes through the nearest gate. CI runs them all headlessly. Use `--render --out <dir>` to get screenshots for visual review.

## Content

- Items, monsters, drop tables, and Slayer tasks live in `game/content/*.json`, keyed by snake_case id. Add content there, not in code.
- `tools/content_validator.py` checks structure and cross-references. Extend it when adding new fields. Unknown fields are errors.
- GDScript reads content through `scripts/content/content_db.gd`, which converts JSON floats to ints. When exporting builds, include `content/*.json` in the export filter.

## World

- `game/scenes/castra_ferrea.tscn` holds the town's static greybox geometry (walls, buildings, woods, hills, bounds). Interactive things (NPCs, stations, rocks, monsters) live in `main.tscn`.
- Navigation: `scripts/world/navigation.gd` bakes a navmesh at startup from static bodies in the `navigation_source` group (layers 1 and 4). Add new static obstacles to that group. Player auto-approach, click-to-move, and monster movement path with `Navigation.next_waypoint`.
- Collision layers: 1 = terrain and buildings (the camera collides with these), 2 = player, 3 = monsters, 4 = props and NPCs. The player and monsters collide with layers 1 and 4.
