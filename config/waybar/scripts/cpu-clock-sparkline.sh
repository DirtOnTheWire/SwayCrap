#!/usr/bin/env bash
set -euo pipefail

mode="${1:-avg}"          # avg | max
points="${POINTS:-5}"
state_dir="${XDG_CACHE_HOME:-$HOME/.cache}/waybar-spark"
mkdir -p "$state_dir"

series_file="$state_dir/cpu-clock-${mode}.series"

read_current_freqs() {
  local f v found=0

  # Preferred: cpufreq sysfs, kHz
  for f in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_cur_freq; do
    [[ -r "$f" ]] || continue
    v="$(cat "$f" 2>/dev/null | tr -dc '0-9' || true)"
    [[ "$v" =~ ^[0-9]+$ ]] || continue
    echo "$v"
    found=1
  done

  # Fallback: /proc/cpuinfo, MHz -> kHz
  if (( found == 0 )); then
    awk -F: '/cpu MHz/ {
      gsub(/^[ \t]+/, "", $2)
      printf "%.0f\n", $2 * 1000
    }' /proc/cpuinfo
  fi
}

read_max_possible_freq() {
  local f v max=0

  for f in /sys/devices/system/cpu/cpu[0-9]*/cpufreq/cpuinfo_max_freq; do
    [[ -r "$f" ]] || continue
    v="$(cat "$f" 2>/dev/null | tr -dc '0-9' || true)"
    [[ "$v" =~ ^[0-9]+$ ]] || continue
    (( v > max )) && max="$v"
  done

  echo "$max"
}

fmt_freq() {
  local khz="$1"

  if (( khz >= 1000000 )); then
    awk -v k="$khz" 'BEGIN { printf "%.2fG", k / 1000000 }'
  else
    awk -v k="$khz" 'BEGIN { printf "%.0fM", k / 1000 }'
  fi
}

mapfile -t freqs < <(read_current_freqs)

if ((${#freqs[@]} == 0)); then
  printf '{"text":"N/A","tooltip":"CPU clock unavailable","percentage":0}\n'
  exit 0
fi

sum=0
max_cur=0

for f in "${freqs[@]}"; do
  [[ "$f" =~ ^[0-9]+$ ]] || continue
  sum=$((sum + f))
  (( f > max_cur )) && max_cur="$f"
done

avg_cur=$((sum / ${#freqs[@]}))

case "$mode" in
  avg) value="$avg_cur"; label="CPU average clock" ;;
  max) value="$max_cur"; label="CPU max clock" ;;
  *) exit 1 ;;
esac

max_possible="$(read_max_possible_freq)"
if [[ ! "$max_possible" =~ ^[0-9]+$ || "$max_possible" -le 0 ]]; then
  max_possible="$max_cur"
fi

pct=0
if (( max_possible > 0 )); then
  pct=$(( value * 100 / max_possible ))
fi

(( pct < 0 )) && pct=0
(( pct > 100 )) && pct=100

old="$(cat "$series_file" 2>/dev/null || true)"
arr=($old $pct)

if ((${#arr[@]} > points)); then
  arr=("${arr[@]: -$points}")
fi

printf "%s " "${arr[@]}" > "$series_file"

levels=(▁ ▂ ▃ ▅ █)
spark=""

for v in "${arr[@]}"; do
  idx=$(( v * 4 / 100 ))
  spark+="${levels[$idx]}"
done

freq_text="$(fmt_freq "$value")"
max_text="$(fmt_freq "$max_possible")"

printf '{"text":"%s %s","tooltip":"%s: %s / max possible %s","percentage":%d}\n' \
  "$spark" "$freq_text" "$label" "$freq_text" "$max_text" "$pct"