#!/usr/bin/env bash
# Run every playtest scenario headlessly. Exits non-zero if any fail.
set -uo pipefail
dir="$(dirname "$0")"
failed=0
for f in "$dir"/../game/tools/playtest/scenarios/*.gd; do
  name="$(basename "$f" .gd)"
  if "$dir/playtest.sh" "$name" > /tmp/playtest-"$name".log 2>&1; then
    echo "PASS $name"
  else
    echo "FAIL $name"; cat /tmp/playtest-"$name".log; failed=1
  fi
done
exit $failed
