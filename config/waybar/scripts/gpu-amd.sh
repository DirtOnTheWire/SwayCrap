#!/usr/bin/env bash
# AMD GPU backend for stats-daemon.sh.
# Source this file and call sample_amd_gpu CARD_DIR, or run it directly.

reset_amd_metrics() {
  GPU_USAGE_PCT="N/A"
  GPU_TEMP_C="N/A"
  GPU_TEMP_HOTSPOT_C="N/A"
  GPU_TEMP_EDGE_C="N/A"
  GPU_TEMP_VRAM_C="N/A"
  GPU_TEMP_SOURCE="Unavailable"
  GPU_POWER_W="N/A"
  GPU_CORE_CLOCK_MHZ="N/A"
  GPU_VRAM_CLOCK_MHZ="N/A"
  GPU_VRAM_USED_BYTES="N/A"
  GPU_VRAM_TOTAL_BYTES="N/A"
}

amd_read_uint() {
  local f="$1" v
  [[ -r "$f" ]] || return 1
  IFS= read -r v < "$f" || return 1
  v="${v//[^0-9]/}"
  [[ "$v" =~ ^[0-9]+$ ]] || return 1
  printf '%s\n' "$v"
}

amd_hwmon_dir() {
  local card_dir="$1" d
  shopt -s nullglob
  for d in "$card_dir/device/hwmon"/hwmon*; do
    [[ -d "$d" ]] && { printf '%s\n' "$d"; shopt -u nullglob; return 0; }
  done
  shopt -u nullglob
  return 1
}

amd_dpm_clock_mhz() {
  local f="$1"
  [[ -r "$f" ]] || return 1
  awk '
    /\*/ {
      for (i=1; i<=NF; i++) {
        if ($i ~ /^[0-9]+([.][0-9]+)?[Mm][Hh][Zz]$/) {
          gsub(/[Mm][Hh][Zz]/, "", $i)
          printf "%.0f\n", $i
          exit
        }
      }
    }
  ' "$f"
}

sample_amd_gpu() {
  local card_dir="${1:?card directory required}"
  local hwmon="" raw=""
  reset_amd_metrics

  GPU_USAGE_PCT="$(amd_read_uint "$card_dir/device/gpu_busy_percent" 2>/dev/null || printf 'N/A')"

  hwmon="$(amd_hwmon_dir "$card_dir" 2>/dev/null || true)"
  if [[ -n "$hwmon" ]]; then
    # AMDGPU documents temp*_input in millidegrees C, power*_input/average in uW,
    # freq1_input as gfx clock Hz and freq2_input as memory clock Hz.
    # Prefer hwmon labels, which are more reliable than channel numbering.
    # Some drivers omit labels; temp1 is a fallback for the edge reading only.
    local tf label celsius
    shopt -s nullglob
    for tf in "$hwmon"/temp*_input; do
      raw="$(amd_read_uint "$tf" 2>/dev/null || true)"
      [[ "$raw" =~ ^[0-9]+$ ]] || continue
      celsius=$((raw / 1000))
      label=""
      [[ -r "${tf%_input}_label" ]] && IFS= read -r label < "${tf%_input}_label"
      label="${label,,}"
      case "$label" in
        *junction*|*hotspot*|*hot\ spot*) GPU_TEMP_HOTSPOT_C="$celsius" ;;
        *edge*|*core*|*gpu*) GPU_TEMP_EDGE_C="$celsius" ;;
        *mem*|*vram*) GPU_TEMP_VRAM_C="$celsius" ;;
        "")
          # Standard AMD numbering, only when labels are unavailable.
          case "${tf##*/}" in
            temp1_input) GPU_TEMP_EDGE_C="$celsius" ;;
            temp2_input) GPU_TEMP_HOTSPOT_C="$celsius" ;;
            temp3_input) GPU_TEMP_VRAM_C="$celsius" ;;
          esac ;;
      esac
    done
    shopt -u nullglob
    if [[ "$GPU_TEMP_HOTSPOT_C" != N/A ]]; then
      GPU_TEMP_C="$GPU_TEMP_HOTSPOT_C"; GPU_TEMP_SOURCE="Hotspot"
    elif [[ "$GPU_TEMP_EDGE_C" != N/A ]]; then
      GPU_TEMP_C="$GPU_TEMP_EDGE_C"; GPU_TEMP_SOURCE="Core / Edge"
    fi

    raw="$(amd_read_uint "$hwmon/power1_average" 2>/dev/null || amd_read_uint "$hwmon/power1_input" 2>/dev/null || true)"
    if [[ "$raw" =~ ^[0-9]+$ ]]; then
      # hwmon power is normally microwatts. Keep one decimal place in watts.
      GPU_POWER_W="$(awk -v p="$raw" 'BEGIN { printf "%.1f", p / 1000000 }')"
    fi

    raw="$(amd_read_uint "$hwmon/freq1_input" 2>/dev/null || true)"
    [[ "$raw" =~ ^[0-9]+$ ]] && GPU_CORE_CLOCK_MHZ=$((raw / 1000000))

    raw="$(amd_read_uint "$hwmon/freq2_input" 2>/dev/null || true)"
    [[ "$raw" =~ ^[0-9]+$ ]] && GPU_VRAM_CLOCK_MHZ=$((raw / 1000000))
  fi

  if [[ "$GPU_CORE_CLOCK_MHZ" == "N/A" ]]; then
    raw="$(amd_dpm_clock_mhz "$card_dir/device/pp_dpm_sclk" 2>/dev/null || true)"
    [[ "$raw" =~ ^[0-9]+$ ]] && GPU_CORE_CLOCK_MHZ="$raw"
  fi

  if [[ "$GPU_VRAM_CLOCK_MHZ" == "N/A" ]]; then
    raw="$(amd_dpm_clock_mhz "$card_dir/device/pp_dpm_mclk" 2>/dev/null || true)"
    [[ "$raw" =~ ^[0-9]+$ ]] && GPU_VRAM_CLOCK_MHZ="$raw"
  fi

  raw="$(amd_read_uint "$card_dir/device/mem_info_vram_used" 2>/dev/null || true)"
  [[ "$raw" =~ ^[0-9]+$ ]] && GPU_VRAM_USED_BYTES="$raw"

  raw="$(amd_read_uint "$card_dir/device/mem_info_vram_total" 2>/dev/null || true)"
  [[ "$raw" =~ ^[0-9]+$ ]] && GPU_VRAM_TOTAL_BYTES="$raw"
}

amd_json_value() {
  local v="$1"
  if [[ "$v" =~ ^-?[0-9]+([.][0-9]+)?$ ]]; then printf '%s' "$v"; else printf 'null'; fi
}

amd_standalone() {
  local card_dir="${1:-}"
  [[ -n "$card_dir" && -d "$card_dir/device" ]] || { echo 'Usage: gpu-amd.sh /sys/class/drm/cardN' >&2; exit 2; }
  sample_amd_gpu "$card_dir"
  printf '{"vendor":"amd","usage_pct":%s,"temp_c":%s,"power_w":%s,"core_clock_mhz":%s,"vram_clock_mhz":%s,"vram_used_bytes":%s,"vram_total_bytes":%s}\n' \
    "$(amd_json_value "$GPU_USAGE_PCT")" \
    "$(amd_json_value "$GPU_TEMP_C")" \
    "$(amd_json_value "$GPU_POWER_W")" \
    "$(amd_json_value "$GPU_CORE_CLOCK_MHZ")" \
    "$(amd_json_value "$GPU_VRAM_CLOCK_MHZ")" \
    "$(amd_json_value "$GPU_VRAM_USED_BYTES")" \
    "$(amd_json_value "$GPU_VRAM_TOTAL_BYTES")"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  set -euo pipefail
  amd_standalone "$@"
fi
