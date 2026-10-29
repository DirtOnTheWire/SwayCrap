#!/usr/bin/env bash
set -euo pipefail

mode="${1:-cpu}"
points="${POINTS:-5}"
state_dir="${XDG_CACHE_HOME:-$HOME/.cache}/waybar-spark"
mkdir -p "$state_dir"

series_file="$state_dir/${mode}.series"
prev_file="$state_dir/${mode}.prev"

if [[ "$mode" == "cpu" ]]; then
  read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat
  total=$((user + nice + system + idle + iowait + irq + softirq + steal))
  idle_all=$((idle + iowait))

  if [[ -f "$prev_file" ]]; then
    read -r p_total p_idle < "$prev_file" || true
  else
    p_total=$total
    p_idle=$idle_all
  fi

  d_total=$((total - p_total))
  d_idle=$((idle_all - p_idle))

  pct=0
  if (( d_total > 0 )); then
    pct=$(( (100 * (d_total - d_idle)) / d_total ))
  fi

  printf "%s %s\n" "$total" "$idle_all" > "$prev_file"

elif [[ "$mode" == "mem" ]]; then
  mem_total=$(awk '/MemTotal:/ {print $2}' /proc/meminfo)
  mem_avail=$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)
  used=$((mem_total - mem_avail))
  pct=$(( (100 * used) / mem_total ))
else
  exit 1
fi

if (( pct < 0 )); then
  pct=0
elif (( pct > 100 )); then
  pct=100
fi

old="$(cat "$series_file" 2>/dev/null || true)"
arr=($old $pct)

if ((${#arr[@]} > points)); then
  arr=("${arr[@]: -$points}")
fi

printf "%s " "${arr[@]}" > "$series_file"

levels=(▁ ▂ ▃ ▅ █)
out=""
for v in "${arr[@]}"; do
  idx=$(( v * 4 / 100 ))
  out+="${levels[$idx]}"
done

printf '{"text":"%s %3d%%","tooltip":"%s usage: %d%%","percentage":%d}\n' \
  "$out" "$pct" "$(printf '%s' "$mode" | tr '[:lower:]' '[:upper:]')" "$pct" "$pct"
