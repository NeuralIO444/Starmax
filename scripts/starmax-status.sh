#!/bin/bash
# starmax-status.sh — one-screen summary of CD-Archive
set -euo pipefail
ARCHIVE="${1:-$HOME/Desktop/CD-Archive}"
[[ -d "$ARCHIVE" ]] || { echo "No archive at $ARCHIVE"; exit 1; }

echo "Starmax status — $ARCHIVE"
echo "================================"
printf "%-40s %8s %6s %6s %6s\n" "Name" "Keepers" "Modern" "Fonts" "Last"
for d in "$ARCHIVE"/*/; do
  [[ -d "$d" ]] || continue
  name=$(basename "$d")
  keepers=$(find "$d/keepers" -type f 2>/dev/null | wc -l | tr -d ' ')
  modern="no"
  [[ -d "$d/modern" ]] && modern="yes"
  fonts=0
  [[ -f "$d/fonts.json" ]] && fonts=$(python3 -c "import json; print(json.load(open('$d/fonts.json')).get('count',0))" 2>/dev/null || echo 0)
  last=""
  [[ -f "$d/state.json" ]] && last=$(python3 -c "import json,time; print(time.strftime('%Y-%m-%d', time.localtime(json.load(open('$d/state.json')).get('completed',0))))" 2>/dev/null || echo "")
  printf "%-40s %8s %6s %6s %6s\n" "$name" "$keepers" "$modern" "$fonts" "$last"
done
