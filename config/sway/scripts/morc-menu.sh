#!/usr/bin/env bash
set -euo pipefail

DMENU_LINES="${DMENU_LINES:-20}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/morc-menu"
CACHE_FILE="$CACHE_DIR/apps.tsv"
CACHE_MAX_AGE="${CACHE_MAX_AGE:-300}" # seconds

# Make Snap/Flatpak desktop entries visible even if the session missed them.
export XDG_DATA_DIRS="$HOME/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:/var/lib/snapd/desktop:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

menu() {
  dmenu -i -l "$DMENU_LINES" -p "$1"
}

category_for() {
  local cats="$1"

  case "$cats" in
    *Game*) echo "Games" ;;
    *AudioVideo*|*Audio*|*Video*) echo "Multimedia" ;;
    *Graphics*) echo "Graphics" ;;
    *Network*) echo "Internet" ;;
    *Office*) echo "Office" ;;
    *Development*) echo "Development" ;;
    *Education*) echo "Education" ;;
    *Science*) echo "Science" ;;
    *Settings*) echo "Settings" ;;
    *System*) echo "System" ;;
    *Utility*) echo "Accessories" ;;
    *) echo "Other" ;;
  esac
}

read_desktop_file() {
  local file="$1"
  local in_entry=0
  local type="" name="" nodisplay="" hidden="" cats=""

  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in
      "[Desktop Entry]") in_entry=1; continue ;;
      "["*) in_entry=0; continue ;;
    esac

    (( in_entry == 1 )) || continue

    case "$line" in
      Type=*) type="${line#Type=}" ;;
      Name=*) [[ -z "$name" ]] && name="${line#Name=}" ;;
      NoDisplay=*) nodisplay="${line#NoDisplay=}" ;;
      Hidden=*) hidden="${line#Hidden=}" ;;
      Categories=*) cats="${line#Categories=}" ;;
    esac
  done < "$file"

  [[ "$type" == "Application" ]] || return 0
  [[ "$nodisplay" == "true" ]] && return 0
  [[ "$hidden" == "true" ]] && return 0
  [[ -n "$name" ]] || return 0

  local cat
  cat="$(category_for "$cats")"

  printf '%s\t%s\t%s\n' "$cat" "$name" "$file"
}

build_app_list() {
  local tmp="$1"
  local -A seen=()

  local dirs=(
    "$HOME/.local/share/applications"
    "/usr/local/share/applications"
    "/usr/share/applications"
    "/var/lib/snapd/desktop/applications"
    "/var/lib/flatpak/exports/share/applications"
    "$HOME/.local/share/flatpak/exports/share/applications"
  )

  local dir file base

  for dir in "${dirs[@]}"; do
    [[ -d "$dir" ]] || continue

    while IFS= read -r -d '' file; do
      base="$(basename "$file")"

      # User/local entries override system ones.
      [[ -n "${seen[$base]:-}" ]] && continue
      seen[$base]=1

      read_desktop_file "$file" >> "$tmp"
    done < <(find "$dir" -maxdepth 1 -type f -name '*.desktop' -print0 2>/dev/null)
  done
}

launch_desktop_file() {
  local file="$1"

  if have_cmd gio; then
    gio launch "$file" >/dev/null 2>&1 &
    disown
    exit 0
  fi

  # Fallback if gio is missing.
  local desktop_id
  desktop_id="$(basename "$file" .desktop)"

  if have_cmd gtk-launch; then
    gtk-launch "$desktop_id" >/dev/null 2>&1 &
    disown
    exit 0
  fi

  notify-send "Menu error" "No launcher found: install gio or gtk-launch" 2>/dev/null || true
  exit 1
}

main() {
  have_cmd dmenu || {
    echo "dmenu not found" >&2
    exit 1
  }

local apps
mkdir -p "$CACHE_DIR"
apps="$CACHE_FILE"

if [[ ! -s "$apps" ]] || (( $(date +%s) - $(stat -c %Y "$apps" 2>/dev/null || echo 0) > CACHE_MAX_AGE )); then
  tmp_apps="$(mktemp)"
  build_app_list "$tmp_apps"
  sort -f "$tmp_apps" > "$apps"
  rm -f "$tmp_apps"
fi

  [[ -s "$apps" ]] || {
    notify-send "Menu" "No .desktop applications found" 2>/dev/null || true
    exit 0
  }

  local category
  category="$(
    {
      echo "All"
      cut -f1 "$apps" | sort -u
    } | menu "Category:"
  )"

  [[ -n "${category:-}" ]] || exit 0

  local app
  if [[ "$category" == "All" ]]; then
    app="$(cut -f2 "$apps" | sort -f | menu "Application:")"
  else
    app="$(awk -F'\t' -v c="$category" '$1 == c {print $2}' "$apps" | sort -f | menu "$category:")"
  fi

  [[ -n "${app:-}" ]] || exit 0

  local file
  if [[ "$category" == "All" ]]; then
    file="$(awk -F'\t' -v a="$app" '$2 == a {print $3; exit}' "$apps")"
  else
    file="$(awk -F'\t' -v c="$category" -v a="$app" '$1 == c && $2 == a {print $3; exit}' "$apps")"
  fi

  [[ -n "$file" && -f "$file" ]] || exit 0

  launch_desktop_file "$file"
}

main "$@"
