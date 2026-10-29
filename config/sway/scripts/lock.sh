#!/usr/bin/env bash
set -euo pipefail

theme_vars="$HOME/.config/sway/scripts/theme-vars.sh"

bg="#111318"
fg="#e6e6e6"
accent="#3b82f6"
urgent="#fb7185"

if [[ -r "$theme_vars" ]]; then
  # shellcheck source=/dev/null
  source "$theme_vars"
  bg="$(theme_get sway_background 2>/dev/null || true)"
  fg="$(theme_get sway_text 2>/dev/null || true)"
  accent="$(theme_get sway_color4 2>/dev/null || true)"
  urgent="$(theme_get sway_color7 2>/dev/null || true)"
fi

bg="${bg:-#111318}"
fg="${fg:-#e6e6e6}"
accent="${accent:-#3b82f6}"
urgent="${urgent:-#fb7185}"

# swaylock wants colors without #
bg="${bg#\#}"
fg="${fg#\#}"
accent="${accent#\#}"
urgent="${urgent#\#}"

exec swaylock -f\
  --color "$bg" \
  --inside-color "${bg}cc" \
  --ring-color "$accent" \
  --line-color "$bg" \
  --key-hl-color "$fg" \
  --bs-hl-color "$urgent" \
  --separator-color "$accent" \
  --inside-ver-color "${accent}33" \
  --ring-ver-color "$accent" \
  --inside-wrong-color "${urgent}33" \
  --ring-wrong-color "$urgent" \
  --text-color "$fg" \
  --text-ver-color "$fg" \
  --text-wrong-color "$fg"
