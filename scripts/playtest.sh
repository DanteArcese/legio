#!/usr/bin/env bash
# Run a playtest scenario from game/tools/playtest/scenarios/.
# Usage: scripts/playtest.sh <scenario> [--render] [--out <dir>]
#   --render  Open a window and save screenshots (needs a display)
#   --out     Directory for result.json and screenshots
# Without --render the run is headless and as fast as possible (fixed 60 fps).
set -euo pipefail
godot="${GODOT:-godot}"
project="$(dirname "$0")/../game"
scenario="${1:?scenario name required}"; shift
mode=(--headless)
out=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --render) mode=(); shift ;;
    --out) out="$(realpath -m "$2")"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done
"$godot" --headless --path "$project" --import >/dev/null 2>&1
"$godot" "${mode[@]}" --fixed-fps 60 --path "$project" --script res://tools/playtest/run.gd \
  -- --scenario="$scenario" ${out:+--out="$out"}
