#!/usr/bin/env bash
set -euo pipefail

NODATA_OUTPUT="${NODATA_OUTPUT:-N/A}"

read_millic() {
  local f="$1"
  [[ -r "$f" ]] || return 1
  cat "$f" 2>/dev/null | tr -dc '0-9'
}

fmt_millic() {
  local v="$1"
  [[ "$v" =~ ^[0-9]+$ ]] || return 1
  if (( v > 1000 )); then
    printf "%3d°C\n" "$(( v / 1000 ))"
  else
    printf "%3d°C\n" "$v"
  fi
}

# Fast path: hwmon
# Intel: coretemp -> "Package id 0" label
# AMD:   k10temp  -> Tctl/Tdie (varies)
hwmon_temp() {
  local h name
  for h in /sys/class/hwmon/hwmon*; do
    [[ -r "$h/name" ]] || continue
    name="$(cat "$h/name" 2>/dev/null || true)"

    # Intel coretemp: prefer "Package id 0"
    if [[ "$name" == "coretemp" ]]; then
      local lbl inp tbase
      for lbl in "$h"/temp*_label; do
        [[ -r "$lbl" ]] || continue
        if grep -qi '^Package id 0' "$lbl"; then
          tbase="${lbl%_label}"
          inp="${tbase}_input"
          if [[ -r "$inp" ]]; then
            fmt_millic "$(read_millic "$inp" || true)" && return 0
          fi
        fi
      done
      # fallback: first temp*_input
      local first
      first="$(ls "$h"/temp*_input 2>/dev/null | head -n1 || true)"
      [[ -n "$first" ]] && fmt_millic "$(read_millic "$first" || true)" && return 0
    fi

    # AMD k10temp: take first temp*_input
    if [[ "$name" == "k10temp" ]]; then
      local first
      first="$(ls "$h"/temp*_input 2>/dev/null | head -n1 || true)"
      [[ -n "$first" ]] && fmt_millic "$(read_millic "$first" || true)" && return 0
    fi
  done
  return 1
}

# Next: thermal zones (often x86_pkg_temp / acpitz / etc.)
thermal_zone_temp() {
  local z t type v
  for z in /sys/class/thermal/thermal_zone*; do
    [[ -r "$z/type" && -r "$z/temp" ]] || continue
    type="$(cat "$z/type" 2>/dev/null || true)"
    # Prefer package temp if present
    if echo "$type" | grep -Eqi 'x86_pkg_temp|cpu|package|acpitz'; then
      v="$(read_millic "$z/temp" || true)"
      [[ -n "$v" ]] && fmt_millic "$v" && return 0
    fi
  done
  # fallback: first readable temp
  for t in /sys/class/thermal/thermal_zone*/temp; do
    [[ -r "$t" ]] || continue
    v="$(read_millic "$t" || true)"
    [[ -n "$v" ]] && fmt_millic "$v" && return 0
  done
  return 1
}

# Last resort: sensors, but timeboxed
sensors_temp() {
  command -v sensors >/dev/null 2>&1 || return 1

  local out=""
  if command -v timeout >/dev/null 2>&1; then
    out="$(timeout 0.25 sensors 2>/dev/null || true)"
  else
    out="$(sensors 2>/dev/null || true)"
  fi
  [[ -n "$out" ]] || return 1

  # Priority patterns (your original list)
  local pat t
  for pat in \
    'Tdie:' \
    'Tctl:' \
    'Package id 0:' \
    'CPU Temperature:' \
    'Core 0:' \
    'temp1:' \
  ; do
    t="$(printf "%s\n" "$out" | awk -v pat="$pat" '$0 ~ pat {print; exit}' \
      | awk '{
          s=$0; sub(/.*:/,"",s);
          if (match(s, /[-+]?[0-9]+(\.[0-9]+)?/)) {print substr(s,RSTART,RLENGTH); exit}
        }' || true)"
    if [[ -n "${t:-}" ]]; then
      printf "%.0f°C\n" "$t"
      return 0
    fi
  done

  return 1
}

main() {
  hwmon_temp && exit 0
  thermal_zone_temp && exit 0
  sensors_temp && exit 0
  echo "$NODATA_OUTPUT"
}

main "$@"

