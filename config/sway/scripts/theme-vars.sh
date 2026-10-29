#!/usr/bin/env bash
set -euo pipefail

THEME_FILE="${HOME}/.config/sway/themes/current.conf"

theme_get() {
  local name="${1:?var name}"
  awk -v n="$name" '
    $1=="set" && $2=="$"n { print $3; found=1; exit }
    END { if (!found) exit 1 }
  ' "$THEME_FILE"
}

theme_load_bar() {
  BAR_BG="$(theme_get bar_bg)"
  BAR_FG="$(theme_get bar_text)"
  BAR_DIM="$(theme_get bar_sep)"
  BAR_ACCENT="$(theme_get sway_color4)"   # your accent slot
  BAR_URGENT="$(theme_get sway_color7)"
  SWAY_8="$(theme_get sway_color8)"
}
