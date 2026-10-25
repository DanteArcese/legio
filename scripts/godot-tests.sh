#!/usr/bin/env bash
# Run the Godot test suite headlessly. Set GODOT to override the binary.
set -euo pipefail
godot="${GODOT:-godot}"
project="$(dirname "$0")/../game"
"$godot" --headless --path "$project" --import >/dev/null 2>&1
"$godot" --headless --path "$project" --script res://tests/run_tests.gd
