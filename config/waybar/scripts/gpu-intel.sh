#!/usr/bin/env bash
# Intel GPU backend for stats-daemon.sh.
# Supports cheap sysfs paths first; intel_gpu_top is an optional last resort.

reset_intel_metrics() {
  GPU_USAGE_PCT="N/A"
  GPU_TEMP_C="N/A"
  GPU_POWER_W="N/A"
  GPU_CORE_CLOCK_MHZ="N/A"
  GPU_VRAM_CLOCK_MHZ="N/A"
  GPU_VRAM_USED_BYTES="N/A"
  GPU_VRAM_TOTAL_BYTES="N/A"
}

intel_read_uint() {
  local f="$1" v
  [[ -r "$f" ]] || return 1
  IFS= read -r v < "$f" || return 1
  v="${v//[^0-9]/}"
  [[ "$v" =~ ^[0-9]+$ ]] || return 1
  printf '%s\n' "$v"
}

intel_driver() {
  local card_dir="$1"
  [[ -L "$card_dir/device/driver" ]] || return 1
  basename "$(readlink -f "$card_dir/device/driver")"
}

intel_hwmon_dir() {
  local card_dir="$1" d
  shopt -s nullglob
  for d in "$card_dir/device/hwmon"/hwmon*; do
    [[ -d "$d" ]] && { printf '%s\n' "$d"; shopt -u nullglob; return 0; }
  done
  shopt -u nullglob
  return 1
}

intel_thermal_zone_temp() {
  local z type raw
  for z in /sys/class/thermal/thermal_zone*; do
    [[ -r "$z/type" && -r "$z/temp" ]] || continue
    IFS= read -r type < "$z/type" || continue
    case "${type,,}" in
      *i915*|*xe*|*gpu*|*x86_pkg_temp*|*pch*)
        raw="$(intel_read_uint "$z/temp" 2>/dev/null || true)"
        [[ "$raw" =~ ^[0-9]+$ ]] && { printf '%d\n' "$((raw / 1000))"; return 0; }
        ;;
    esac
  done
  return 1
}

intel_gpu_top_usage() {
  local card_dir="$1" driver sysdev dev_arg="" out json
  [[ "${WAYBAR_INTEL_GPU_TOP_FALLBACK:-1}" == "1" ]] || return 1
  command -v intel_gpu_top >/dev/null 2>&1 || return 1
  command -v jq >/dev/null 2>&1 || return 1

  driver="$(intel_driver "$card_dir" 2>/dev/null || true)"
  # intel_gpu_top currently targets i915; Xe has separate tooling.
  [[ "$driver" == "i915" ]] || return 1

  # Use the documented sysfs device selector so multi-Intel-GPU systems sample
  # the intended card instead of whichever GPU intel_gpu_top picks by default.
  sysdev="$(readlink -f "$card_dir/device" 2>/dev/null || true)"
  [[ -n "$sysdev" ]] && dev_arg="sys:$sysdev"

  if command -v timeout >/dev/null 2>&1; then
    if [[ -n "$dev_arg" ]]; then
      out="$(timeout 1.3 intel_gpu_top -J -s 300 -d "$dev_arg" -o - 2>/dev/null || true)"
    fi
    [[ -n "$out" ]] || out="$(timeout 1.3 intel_gpu_top -J -s 300 -o - 2>/dev/null || true)"
  else
    return 1
  fi

  json="$(printf '%s\n' "$out" | awk 'NF{last=$0} END{print last}')"
  [[ -n "$json" ]] || return 1

  jq -r '
    if .engines then
      ([.engines | to_entries[] | .value.busy // empty] | max) // empty
    else empty end
  ' <<<"$json" 2>/dev/null | awk '/^[0-9]+([.][0-9]+)?$/ {printf "%d\n", ($1+0.5); exit}'
}

sample_intel_gpu() {
  local card_dir="${1:?card directory required}"
  local hwmon="" raw="" f
  reset_intel_metrics

  # Some kernels expose a direct busy percentage. Prefer it because it is cheap.
  for f in \
    "$card_dir/device/gpu_busy_percent" \
    "$card_dir/device/gt_busy_percent" \
    "$card_dir/device/gt0_busy_percent" \
    "$card_dir/device/gt1_busy_percent"; do
    raw="$(intel_read_uint "$f" 2>/dev/null || true)"
    if [[ "$raw" =~ ^[0-9]+$ ]]; then GPU_USAGE_PCT="$raw"; break; fi
  done

  if [[ "$GPU_USAGE_PCT" == "N/A" ]]; then
    raw="$(intel_gpu_top_usage "$card_dir" 2>/dev/null || true)"
    [[ "$raw" =~ ^[0-9]+$ ]] && GPU_USAGE_PCT="$raw"
  fi

  hwmon="$(intel_hwmon_dir "$card_dir" 2>/dev/null || true)"
  if [[ -n "$hwmon" ]]; then
    raw="$(intel_read_uint "$hwmon/temp1_input" 2>/dev/null || true)"
    if [[ "$raw" =~ ^[0-9]+$ ]]; then
      GPU_TEMP_C=$((raw / 1000)); GPU_TEMP_EDGE_C="$GPU_TEMP_C"; GPU_TEMP_SOURCE="Core"
    fi

    raw="$(intel_read_uint "$hwmon/power1_average" 2>/dev/null || intel_read_uint "$hwmon/power1_input" 2>/dev/null || true)"
    if [[ "$raw" =~ ^[0-9]+$ ]]; then
      GPU_POWER_W="$(awk -v p="$raw" 'BEGIN { printf "%.1f", p / 1000000 }')"
    fi
  fi

  if [[ "$GPU_TEMP_C" == "N/A" ]]; then
    raw="$(intel_thermal_zone_temp 2>/dev/null || true)"
    if [[ "$raw" =~ ^[0-9]+$ ]]; then
      GPU_TEMP_C="$raw"; GPU_TEMP_EDGE_C="$raw"; GPU_TEMP_SOURCE="Thermal zone (approx.)"
    fi
  fi

  # i915 legacy paths.
  for f in \
    "$card_dir/gt_cur_freq_mhz" \
    "$card_dir/device/gt_cur_freq_mhz"; do
    raw="$(intel_read_uint "$f" 2>/dev/null || true)"
    if [[ "$raw" =~ ^[0-9]+$ ]]; then GPU_CORE_CLOCK_MHZ="$raw"; break; fi
  done

  # Xe exposes frequencies below device/tile#/gt#/freq0/{act,cur}_freq.
  if [[ "$GPU_CORE_CLOCK_MHZ" == "N/A" ]]; then
    shopt -s nullglob
    local freq_paths=("$card_dir/device"/tile*/gt*/freq0/act_freq "$card_dir/device"/tile*/gt*/freq0/cur_freq)
    shopt -u nullglob
    for f in "${freq_paths[@]}"; do
      raw="$(intel_read_uint "$f" 2>/dev/null || true)"
      if [[ "$raw" =~ ^[0-9]+$ ]]; then GPU_CORE_CLOCK_MHZ="$raw"; break; fi
    done
  fi

  # Dedicated VRAM clock/memory are not generally meaningful for Intel iGPUs.
  # If a platform exposes a memory clock, accept it; otherwise leave N/A.
  for f in "$card_dir/mem_freq_mhz" "$card_dir/device/mem_freq_mhz"; do
    raw="$(intel_read_uint "$f" 2>/dev/null || true)"
    if [[ "$raw" =~ ^[0-9]+$ ]]; then GPU_VRAM_CLOCK_MHZ="$raw"; break; fi
  done
}

intel_json_value() {
  local v="$1"
  if [[ "$v" =~ ^-?[0-9]+([.][0-9]+)?$ ]]; then printf '%s' "$v"; else printf 'null'; fi
}

intel_standalone() {
  local card_dir="${1:-}"
  [[ -n "$card_dir" && -d "$card_dir/device" ]] || { echo 'Usage: gpu-intel.sh /sys/class/drm/cardN' >&2; exit 2; }
  sample_intel_gpu "$card_dir"
  printf '{"vendor":"intel","usage_pct":%s,"temp_c":%s,"power_w":%s,"core_clock_mhz":%s,"vram_clock_mhz":%s,"vram_used_bytes":null,"vram_total_bytes":null}\n' \
    "$(intel_json_value "$GPU_USAGE_PCT")" \
    "$(intel_json_value "$GPU_TEMP_C")" \
    "$(intel_json_value "$GPU_POWER_W")" \
    "$(intel_json_value "$GPU_CORE_CLOCK_MHZ")" \
    "$(intel_json_value "$GPU_VRAM_CLOCK_MHZ")"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  set -euo pipefail
  intel_standalone "$@"
fi
