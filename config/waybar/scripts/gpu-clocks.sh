#!/usr/bin/env bash
set -euo pipefail

# Output when no data is available
NODATA_OUTPUT="${NODATA_OUTPUT:-N/A}"
# Options: core | mem | core+mem
CLOCK_FORMAT="${CLOCK_FORMAT:-core+mem}"

# Pad numeric clock values to 4 digits
pad_clock() {
    local val="$1"
    if [[ "$val" == "N/A" ]]; then
        printf "%4s" "$val"
    else
        printf "%04d" "$val"
    fi
}

# Pick DRM card directory
pick_card_dir() {
    local card="${GPU_CARD:-}"
    [[ -n "$card" ]] && [[ -d "/sys/class/drm/card$card" ]] && echo "/sys/class/drm/card$card" && return
    # fallback to first DRM card
    for d in /sys/class/drm/card*; do
        [[ -d "$d/device" ]] && echo "$d" && return
    done
}

card_dir="$(pick_card_dir)"
[[ -z "$card_dir" ]] && { echo "$NODATA_OUTPUT"; exit 0; }

# Detect vendor
vendor_file="$card_dir/device/vendor"
[[ ! -r "$vendor_file" ]] && { echo "$NODATA_OUTPUT"; exit 0; }

vendor_hex=$(<"$vendor_file")
vendor_hex=$(echo "$vendor_hex" | tr '[:upper:]' '[:lower:]')  # lowercase

core="$NODATA_OUTPUT"
mem="$NODATA_OUTPUT"

# Intel GPUs
if [[ "$vendor_hex" == "0x8086" ]]; then
    if [[ -r "$card_dir/gt_cur_freq_mhz" ]]; then
        core="$(pad_clock "$(cat "$card_dir/gt_cur_freq_mhz")")Mhz"
    fi
    if [[ -r "$card_dir/mem_freq_mhz" ]]; then
        mem="$(pad_clock "$(cat "$card_dir/mem_freq_mhz")")Mhz"
    fi

# AMD GPUs
elif [[ "$vendor_hex" == "0x1002" ]]; then
    if [[ -r "$card_dir/device/pp_dpm_sclk" ]]; then
        raw_core=$(awk '/\*/{gsub(/Mhz/,"",$2); print $2}' "$card_dir/device/pp_dpm_sclk")
        core="$(pad_clock "$raw_core")Mhz"
    fi
    if [[ -r "$card_dir/device/pp_dpm_mclk" ]]; then
        raw_mem=$(awk '/\*/{gsub(/Mhz/,"",$2); print $2}' "$card_dir/device/pp_dpm_mclk")
        mem="$(pad_clock "$raw_mem")Mhz"
    fi

# NVIDIA GPUs
elif [[ "$vendor_hex" == "0x10de" ]]; then
    if command -v nvidia-smi &>/dev/null; then
        raw_core=$(nvidia-smi --query-gpu=clocks.gr --format=csv,noheader,nounits | head -n1)
        raw_mem=$(nvidia-smi --query-gpu=clocks.mem --format=csv,noheader,nounits | head -n1)
        core="$(pad_clock "${raw_core:-N/A}")Mhz"
        mem="$(pad_clock "${raw_mem:-N/A}")Mhz"
    fi
fi

# Ensure we never have empty values
[[ -z "$core" ]] && core="$NODATA_OUTPUT"
[[ -z "$mem" ]] && mem="$NODATA_OUTPUT"

# Output according to CLOCK_FORMAT
case "$CLOCK_FORMAT" in
    core) echo "core:$core" ;;
    mem) echo "mem:$mem" ;;
    core+mem) echo "core:$core mem:$mem" ;;
    *) echo "core:$core mem:$mem" ;;
esac