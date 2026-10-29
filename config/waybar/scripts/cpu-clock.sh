#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   cpu-clock.sh avg
#   cpu-clock.sh max
#
# Output is compact text for Waybar, for example:
#   2.31G
#   940M

mode="${1:-avg}"
NODATA_OUTPUT="${NODATA_OUTPUT:-N/A}"

read_current_freqs_khz() {
  local f v found=0

  # Preferred source: cpufreq sysfs. Values are kHz.
  for f in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_cur_freq; do
    [[ -r "$f" ]] || continue
    v="$(cat "$f" 2>/dev/null | tr -dc '0-9' || true)"
    [[ "$v" =~ ^[0-9]+$ ]] || continue
    echo "$v"
    found=1
  done

  # Fallback: /proc/cpuinfo reports MHz. Convert to kHz.
  if (( found == 0 )); then
    awk -F: '/cpu MHz/ {
      gsub(/^[ \t]+/, "", $2)
      printf "%.0f\n", $2 * 1000
    }' /proc/cpuinfo
  fi
}

fmt_freq() {
  local khz="$1"

  [[ "$khz" =~ ^[0-9]+$ ]] || {
    echo "$NODATA_OUTPUT"
    return 0
  }

  if (( khz >= 1000000 )); then
    awk -v k="$khz" 'BEGIN { printf "%.2fG", k / 1000000 }'
  else
    awk -v k="$khz" 'BEGIN { printf "%.0fM", k / 1000 }'
  fi
}

mapfile -t freqs < <(read_current_freqs_khz)

if ((${#freqs[@]} == 0)); then
  echo "$NODATA_OUTPUT"
  exit 0
fi

sum=0
max_cur=0
count=0

for f in "${freqs[@]}"; do
  [[ "$f" =~ ^[0-9]+$ ]] || continue
  sum=$((sum + f))
  count=$((count + 1))
  (( f > max_cur )) && max_cur="$f"
done

if (( count == 0 )); then
  echo "$NODATA_OUTPUT"
  exit 0
fi

avg_cur=$((sum / count))

case "$mode" in
  avg) fmt_freq "$avg_cur" ;;
  max) fmt_freq "$max_cur" ;;
  *) echo "$NODATA_OUTPUT"; exit 1 ;;
esac
