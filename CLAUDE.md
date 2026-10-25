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
uv run pytest        # Run tests
uv run --env-file .env <command>   # Run with local secrets
```

## Standards

- Python with `uv` only. No `pip install` or `python -m venv`.
- Track work in GitHub issues. Reference the issue in commits and PRs.
- Add or update tests with every feature. Keep the suite passing.
- Secrets live in `.env` (gitignored). Document variable names in `.env.example`. Do not read `.env`.
