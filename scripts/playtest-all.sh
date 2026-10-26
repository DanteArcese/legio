#!/usr/bin/env bash
# Run every playtest scenario headlessly. Exits non-zero if any fail.
# Usage: scripts/playtest-all.sh [--shard <i>/<n>]
#   --shard  Run only shard i (1-based) of n, balanced by the runtimes in
#            scripts/playtest-times.tsv, so CI can split the work across jobs.
set -uo pipefail
dir="$(dirname "$0")"
shard=1/1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --shard) shard="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done
index="${shard%/*}"; count="${shard#*/}"

# Longest first, each onto the shard with the least time so far.
names=()
for f in "$dir"/../game/tools/playtest/scenarios/*.gd; do names+=("$(basename "$f" .gd)"); done
mapfile -t mine < <(printf '%s\n' "${names[@]}" | awk -v times="$dir/playtest-times.tsv" '
  BEGIN { while ((getline line < times) > 0) if (line !~ /^#/) { split(line, f, "\t"); t[f[1]] = f[2] } }
  { print (($0 in t) ? t[$0] : 15) "\t" $0 }' | sort -t$'\t' -k1,1nr -k2,2 | awk -v index_="$index" -v count="$count" '
  BEGIN { FS = "\t" }
  { best = 1; for (s = 2; s <= count; s++) if (load[s] < load[best]) best = s
    load[best] += $1; if (best == index_) print $2 }')

godot="${GODOT:-godot}"
"$godot" --headless --path "$dir/../game" --import >/dev/null 2>&1
export PLAYTEST_SKIP_IMPORT=1
failed=0
for name in "${mine[@]}"; do
  if "$dir/playtest.sh" "$name" > /tmp/playtest-"$name".log 2>&1; then
    echo "PASS $name"
  else
    echo "FAIL $name"; cat /tmp/playtest-"$name".log; failed=1
  fi
done
exit $failed
