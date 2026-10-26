#!/usr/bin/env bash
# Build a standalone Windows executable (the game data is embedded in it).
# Usage: scripts/export-windows.sh [output.exe]   (default: build/windows/Legio.exe)
# Needs Godot's Windows export templates for the installed version; they are
# downloaded (about 1.3 GB, once) if missing.
set -euo pipefail
godot="${GODOT:-godot}"
root="$(cd "$(dirname "$0")/.." && pwd)"
out="$(realpath -m "${1:-$root/build/windows/Legio.exe}")"

version="$("$godot" --version | sed -E 's/^([0-9.]+)\.([a-z]+[0-9]*)\..*/\1.\2/')"
templates="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$version"
if [[ ! -f "$templates/windows_release_x86_64.exe" ]]; then
  tag="${version%.*}-${version##*.}"
  echo "Downloading Godot $tag export templates..."
  tmp="$(mktemp -d)"
  curl -sSLo "$tmp/templates.tpz" "https://github.com/godotengine/godot/releases/download/$tag/Godot_v${tag}_export_templates.tpz"
  mkdir -p "$templates"
  python3 -I - "$tmp/templates.tpz" "$templates" <<'PY'
import os, sys, zipfile
with zipfile.ZipFile(sys.argv[1]) as z:
    for name in z.namelist():
        base = os.path.basename(name)
        if base.startswith("windows_") or base == "version.txt":
            with open(os.path.join(sys.argv[2], base), "wb") as f:
                f.write(z.read(name))
PY
  rm -rf "$tmp"
fi

mkdir -p "$(dirname "$out")"
"$godot" --headless --path "$root/game" --import >/dev/null 2>&1
"$godot" --headless --path "$root/game" --export-release "Windows Desktop" "$out"
echo "Built $out"
