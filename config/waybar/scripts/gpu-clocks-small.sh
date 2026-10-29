#!/usr/bin/env bash
set -euo pipefail

NODATA_OUTPUT="${NODATA_OUTPUT:-N/A}"
CLOCK_FORMAT="${CLOCK_FORMAT:-core+mem}" # core | mem | core+mem

pick_card_dir() {
    local card="${GPU_CARD:-}"
    [[ -n "$card" ]] && [[ -d "/sys/class/drm/card$card" ]] && echo "/sys/class/drm/card$card" && return
    # fallback to first DRM card
    for d in /sys/class/drm/card*; do
        [[ -d "$d/device" ]] && echo "$d" && return
    done
}

card_dir="$(pick_card_dir)"
[[ -z "$card_dir" ]] && { echo "$NODATA_OUTPUT"; exit 1; }

vendor_file="$card_dir/device/vendor"
[[ ! -r "$vendor_file" ]] && { echo "$NODATA_OUTPUT"; exit 1; }

vendor_hex=$(<"$vendor_file")
vendor_hex=$(echo "$vendor_hex" | tr '[:upper:]' '[:lower:]')  # lowercase

core=""
mem=""

if [[ "$vendor_hex" == "0x8086" ]]; then
    # Intel
    [[ -r "$card_dir/gt_cur_freq_mhz" ]] && core=$(<"$card_dir/gt_cur_freq_mhz")
    [[ -r "$card_dir/mem_freq_mhz" ]] && mem=$(<"$card_dir/mem_freq_mhz")
elif [[ "$vendor_hex" == "0x1002" ]]; then
    # AMD
# For AMD core clock
if [[ -r "$card_dir/device/pp_dpm_sclk" ]]; then
    core=$(awk '/\*/{gsub(/Mhz/,"",$2); print $2}' "$card_dir/device/pp_dpm_sclk")
fi

# For AMD memory clock
if [[ -r "$card_dir/device/pp_dpm_mclk" ]]; then
    mem=$(awk '/\*/{gsub(/Mhz/,"",$2); print $2}' "$card_dir/device/pp_dpm_mclk")
fi
elif [[ "$vendor_hex" == "0x10de" ]]; then
    # NVIDIA
    if command -v nvidia-smi &>/dev/null; then
        core=$(nvidia-smi --query-gpu=clocks.gr --format=csv,noheader,nounits | head -n1)
        mem=$(nvidia-smi --query-gpu=clocks.mem --format=csv,noheader,nounits | head -n1)
    fi
fi

# fallback for empty values
[[ -z "$core" ]] && core="$NODATA_OUTPUT"
[[ -z "$mem" ]] && mem="$NODATA_OUTPUT"

case "$CLOCK_FORMAT" in
    core) echo "$core" ;;
    mem) echo "$mem" ;;
    core+mem) echo "$core/$mem" ;;
    *) echo "$core/$mem" ;;
esac