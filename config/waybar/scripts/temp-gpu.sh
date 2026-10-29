#!/usr/bin/env bash
set -euo pipefail

NODATA_OUTPUT="${NODATA_OUTPUT:-N/A}"

pick_card_dir() {
  local card="${GPU_CARD:-0}"
  local d="/sys/class/drm/card${card}"
  [[ -d "$d" ]] && { echo "$d"; return 0; }
  echo "/sys/class/drm/card0"
}

read_millic() {
  local f="$1"
  [[ -r "$f" ]] || return 1
  cat "$f" 2>/dev/null | tr -dc '0-9'
}

thermal_zone_temp() {
  local want_type_regex="$1"
  local z type t
  for z in /sys/class/thermal/thermal_zone*; do
    [[ -r "$z/type" && -r "$z/temp" ]] || continue
    type="$(cat "$z/type" 2>/dev/null || true)"
    if echo "$type" | grep -Eqi -- "$want_type_regex"; then
      t="$(read_millic "$z/temp" || true)"
      [[ -n "$t" ]] && { echo "$t"; return 0; }
    fi
  done
  return 1
}

main() {
  local card_dir
  card_dir="$(pick_card_dir)"

  # 1) Preferred: GPU device hwmon (common on AMD; sometimes on others)
  local temp_path
  temp_path="$(ls "$card_dir/device/hwmon"/hwmon*/temp*_input 2>/dev/null | head -n1 || true)"
  if [[ -n "$temp_path" ]]; then
    local raw
    raw="$(read_millic "$temp_path" || true)"
    if [[ -n "$raw" ]]; then
      printf "%3d°C\n" "$(( raw / 1000 ))"
      return 0
    fi
  fi

  # 2) Intel iGPU: often no dedicated hwmon; fall back to thermal zones (CPU/PCH)
  # Kernel thermal zones are the standard sysfs interface. :contentReference[oaicite:4]{index=4}
  local raw
  raw="$(thermal_zone_temp '^i915$' || true)"
  if [[ -n "$raw" ]]; then
    printf "%3d°C\n" "$(( raw / 1000 ))"
    return 0
  fi

  raw="$(thermal_zone_temp '^x86_pkg_temp$' || true)"
  if [[ -n "$raw" ]]; then
    printf "%3d°C\n" "$(( raw / 1000 ))"
    return 0
  fi

  raw="$(thermal_zone_temp 'acpitz|pch|skylake|cpu' || true)"
  if [[ -n "$raw" ]]; then
    printf "%3d°C\n" "$(( raw / 1000 ))"
    return 0
  fi

  echo "$NODATA_OUTPUT"
}

main "$@"

