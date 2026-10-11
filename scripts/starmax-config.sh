#!/bin/bash
# starmax-config.sh — shared config loader
# ~/.starmax.toml or ~/.starmax.conf (key=value)

load_starmax_config() {
  local conf="${STARMAX_CONFIG:-$HOME/.starmax.toml}"
  [[ -f "$HOME/.starmax.conf" ]] && conf="$HOME/.starmax.conf"
  [[ -f "$conf" ]] || return 0
  while IFS='=' read -r key value; do
    key=$(echo "$key" | tr -d '[:space:]')
    value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/^"//;s/"$//')
    [[ -z "$key" || "$key" == \#* ]] && continue
    case "$key" in
      preferred_device) STARMAX_DEVICE="$value" ;;
      keep_patterns) STARMAX_KEEP_PATTERNS="$value" ;;
      junk_names) STARMAX_JUNK="$value" ;;
      qxd_threshold) STARMAX_QXD_THRESHOLD="$value" ;;
      image_threshold) STARMAX_IMAGE_THRESHOLD="$value" ;;
      font_threshold) STARMAX_FONT_THRESHOLD="$value" ;;
      notify) STARMAX_NOTIFY="$value" ;;
      *) ;;
    esac
  done < "$conf"
}

STARMAX_DEVICE=""
STARMAX_KEEP_PATTERNS=""
STARMAX_JUNK=""
STARMAX_QXD_THRESHOLD=1
STARMAX_IMAGE_THRESHOLD=5
STARMAX_FONT_THRESHOLD=2
STARMAX_NOTIFY=0

load_starmax_config

# Simple validation
[[ "$STARMAX_QXD_THRESHOLD" =~ ^[0-9]+$ ]] || STARMAX_QXD_THRESHOLD=1
[[ "$STARMAX_IMAGE_THRESHOLD" =~ ^[0-9]+$ ]] || STARMAX_IMAGE_THRESHOLD=5
[[ "$STARMAX_FONT_THRESHOLD" =~ ^[0-9]+$ ]] || STARMAX_FONT_THRESHOLD=2
