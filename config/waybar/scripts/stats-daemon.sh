#!/usr/bin/env bash
set -euo pipefail

# Central Waybar stats sampler.
#
# One long-running process samples CPU, RAM and every detected DRM GPU once per
# tick, then publishes atomic JSON cache files for any number of Waybar bars.
# GPU collection is delegated to sourceable per-vendor backends.
#
# Files:
#   $OUT_DIR/cpu.json
#   $OUT_DIR/memory.json
#   $OUT_DIR/cpu-clock-avg.json
#   $OUT_DIR/cpu-clock-max.json
#   $OUT_DIR/gpus.json
#   $OUT_DIR/gpu/<pci-id>/{usage,temp,power,core-clock,vram-clock,vram-usage}.json
#
# Compatibility aliases for the selected primary GPU are also written:
#   $OUT_DIR/gpu-usage.json
#   $OUT_DIR/gpu-temp.json
#   $OUT_DIR/gpu-power.json
#   $OUT_DIR/gpu-core-clock.json
#   $OUT_DIR/gpu-vram-clock.json
#   $OUT_DIR/gpu-vram-usage.json
#
# Environment overrides:
#   WAYBAR_STATS_INTERVAL=2
#   WAYBAR_STATS_POINTS=5
#   WAYBAR_SCRIPT_DIR=$HOME/.config/waybar/scripts
#   WAYBAR_STATS_DIR=$XDG_RUNTIME_DIR/waybar-stats
#   WAYBAR_PRIMARY_GPU=card1            # or PCI id / vendor name / generated id
#   WAYBAR_INTEL_GPU_TOP_FALLBACK=1     # 0 disables the expensive fallback
#
# Usage:
#   stats-daemon.sh
#   stats-daemon.sh --once

INTERVAL="${WAYBAR_STATS_INTERVAL:-2}"
POINTS="${WAYBAR_STATS_POINTS:-5}"
SCRIPT_DIR="${WAYBAR_SCRIPT_DIR:-$HOME/.config/waybar/scripts}"
PRIMARY_GPU_SELECTOR="${WAYBAR_PRIMARY_GPU:-}"
DRM_ROOT="${WAYBAR_DRM_ROOT:-/sys/class/drm}"

if [[ -n "${WAYBAR_STATS_DIR:-}" ]]; then
  OUT_DIR="$WAYBAR_STATS_DIR"
elif [[ -n "${XDG_RUNTIME_DIR:-}" ]]; then
  OUT_DIR="$XDG_RUNTIME_DIR/waybar-stats"
else
  OUT_DIR="/tmp/waybar-stats-$UID"
fi

mkdir -p "$OUT_DIR/gpu"
chmod 700 "$OUT_DIR" 2>/dev/null || true

exec 9>"$OUT_DIR/.lock"
if command -v flock >/dev/null 2>&1; then
  flock -n 9 || exit 0
fi

for backend in gpu-amd.sh gpu-intel.sh gpu-nvidia.sh; do
  if [[ -r "$SCRIPT_DIR/$backend" ]]; then
    # shellcheck disable=SC1090
    source "$SCRIPT_DIR/$backend"
  fi
done

prev_cpu_total=""
prev_cpu_idle=""
cpu_history=()
mem_history=()

clamp_pct() {
  local v="${1:-0}"
  [[ "$v" =~ ^-?[0-9]+$ ]] || v=0
  (( v < 0 )) && v=0
  (( v > 100 )) && v=100
  printf '%d\n' "$v"
}

json_escape() {
  local s="${1-}"
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\r'/\\r}
  s=${s//$'\t'/\\t}
  printf '%s' "$s"
}

json_number_or_null() {
  local v="${1-}"
  if [[ "$v" =~ ^-?[0-9]+([.][0-9]+)?$ ]]; then
    printf '%s' "$v"
  else
    printf 'null'
  fi
}

atomic_write() {
  local path="$1" value="$2" tmp
  mkdir -p "$(dirname "$path")"
  tmp="${path}.tmp.$$"
  printf '%s\n' "$value" > "$tmp"
  mv -f -- "$tmp" "$path"
}

spark_char() {
  local v
  v="$(clamp_pct "${1:-0}")"

  if (( v > 95 )); then
    printf '█'
    return
  fi

  local levels=("_" "▁" "▂" "▃" "▄" "▆" "▇")
  local count="${#levels[@]}"
  local idx=$(( v * count / 96 ))
  (( idx >= count )) && idx=$((count - 1))
  printf '%s' "${levels[$idx]}"
}

sparkline() {
  local -n values_ref="$1"
  local out="" v
  for v in "${values_ref[@]}"; do out+="$(spark_char "$v")"; done
  printf '%s' "$out"
}

push_history() {
  local -n arr_ref="$1"
  local value="$2"
  arr_ref+=("$value")
  if ((${#arr_ref[@]} > POINTS)); then
    arr_ref=("${arr_ref[@]: -$POINTS}")
  fi
}

publish_metric_path() {
  local path="$1" text="$2" tooltip="$3" value="${4:-}" unit="${5:-}" percentage="${6:-}" extra="${7:-}"
  local json

  printf -v json '{"text":"%s","tooltip":"%s","value":%s' \
    "$(json_escape "$text")" \
    "$(json_escape "$tooltip")" \
    "$(json_number_or_null "$value")"

  [[ -n "$unit" ]] && json+=',"unit":"'"$(json_escape "$unit")"'"'
  if [[ "$percentage" =~ ^[0-9]+$ ]]; then
    json+=',"percentage":'"$(clamp_pct "$percentage")"
  fi
  [[ -n "$extra" ]] && json+=','"$extra"
  json+='}'

  atomic_write "$path" "$json"
}

read_cpu_usage() {
  local _ user nice system idle iowait irq softirq steal guest guest_nice
  local total idle_all d_total d_idle pct=0

  read -r _ user nice system idle iowait irq softirq steal guest guest_nice < /proc/stat
  total=$((user + nice + system + idle + iowait + irq + softirq + steal))
  idle_all=$((idle + iowait))

  if [[ -n "$prev_cpu_total" && -n "$prev_cpu_idle" ]]; then
    d_total=$((total - prev_cpu_total))
    d_idle=$((idle_all - prev_cpu_idle))
    (( d_total > 0 )) && pct=$((100 * (d_total - d_idle) / d_total))
  fi

  prev_cpu_total="$total"
  prev_cpu_idle="$idle_all"
  CPU_PCT="$(clamp_pct "$pct")"
}

read_mem_usage() {
  local key value unit mem_total=0 mem_avail=0
  while read -r key value unit; do
    case "$key" in
      MemTotal:) mem_total="${value:-0}" ;;
      MemAvailable:) mem_avail="${value:-0}" ;;
    esac
    (( mem_total > 0 && mem_avail > 0 )) && break
  done < /proc/meminfo

  (( mem_total > 0 )) || { printf '0\n'; return; }
  clamp_pct "$((100 * (mem_total - mem_avail) / mem_total))"
}

read_cpu_freqs() {
  local f v found=0
  shopt -s nullglob
  local files=(/sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_cur_freq)
  shopt -u nullglob

  for f in "${files[@]}"; do
    [[ -r "$f" ]] || continue
    IFS= read -r v < "$f" || true
    v="${v//[^0-9]/}"
    [[ "$v" =~ ^[0-9]+$ ]] || continue
    printf '%s\n' "$v"
    found=1
  done

  if (( found == 0 )); then
    awk -F: '/cpu MHz/ {gsub(/^[ \t]+/, "", $2); printf "%.0f\n", $2 * 1000}' /proc/cpuinfo
  fi
}

fmt_freq_khz() {
  local khz="${1:-0}" hundredths mhz
  if [[ ! "$khz" =~ ^[0-9]+$ ]] || (( khz <= 0 )); then printf 'N/A'; return; fi
  if (( khz >= 1000000 )); then
    hundredths=$(( (khz + 5000) / 10000 ))
    printf '%d.%02dG' "$((hundredths / 100))" "$((hundredths % 100))"
  else
    mhz=$(( (khz + 500) / 1000 ))
    printf '%dM' "$mhz"
  fi
}

read_cpu_clocks() {
  local f sum=0 max_cur=0 count=0
  while IFS= read -r f; do
    [[ "$f" =~ ^[0-9]+$ ]] || continue
    sum=$((sum + f)); count=$((count + 1)); (( f > max_cur )) && max_cur="$f"
  done < <(read_cpu_freqs)

  if (( count == 0 )); then
    CPU_AVG_KHZ=""; CPU_MAX_KHZ=""; CPU_AVG_TEXT="N/A"; CPU_MAX_TEXT="N/A"
    return
  fi

  CPU_AVG_KHZ=$((sum / count))
  CPU_MAX_KHZ="$max_cur"
  CPU_AVG_TEXT="$(fmt_freq_khz "$CPU_AVG_KHZ")"
  CPU_MAX_TEXT="$(fmt_freq_khz "$CPU_MAX_KHZ")"
}

publish_cpu_and_mem() {
  local cpu_pct="$1" mem_pct="$2" cpu_spark mem_spark
  push_history cpu_history "$cpu_pct"
  push_history mem_history "$mem_pct"
  cpu_spark="$(sparkline cpu_history)"
  mem_spark="$(sparkline mem_history)"

  publish_metric_path "$OUT_DIR/cpu.json" \
    "$cpu_spark $(printf '%3d%%' "$cpu_pct")" \
    "CPU usage: ${cpu_pct}%" "$cpu_pct" "%" "$cpu_pct" '"metric":"cpu_usage","available":true'

  publish_metric_path "$OUT_DIR/memory.json" \
    "$mem_spark $(printf '%3d%%' "$mem_pct")" \
    "Memory usage: ${mem_pct}%" "$mem_pct" "%" "$mem_pct" '"metric":"memory_usage","available":true'
}

publish_cpu_clocks() {
  publish_metric_path "$OUT_DIR/cpu-clock-avg.json" "$CPU_AVG_TEXT" \
    "Average CPU clock: $CPU_AVG_TEXT" "${CPU_AVG_KHZ:-}" "kHz" "" '"metric":"cpu_clock_avg"'
  publish_metric_path "$OUT_DIR/cpu-clock-max.json" "$CPU_MAX_TEXT" \
    "Maximum current CPU clock: $CPU_MAX_TEXT" "${CPU_MAX_KHZ:-}" "kHz" "" '"metric":"cpu_clock_max"'
}

normalize_pci() {
  local s="${1:-}"
  if [[ "$s" =~ ^[0-9a-fA-F]{8}: ]]; then printf '%s\n' "${s:4}"; else printf '%s\n' "$s"; fi
}

vendor_name() {
  case "${1,,}" in
    0x8086) printf 'intel\n' ;;
    0x1002) printf 'amd\n' ;;
    0x10de) printf 'nvidia\n' ;;
    *) printf 'unknown\n' ;;
  esac
}

vendor_label() {
  case "${1,,}" in
    intel) printf 'Intel\n' ;;
    amd) printf 'AMD\n' ;;
    nvidia) printf 'NVIDIA\n' ;;
    *) printf 'GPU\n' ;;
  esac
}

reset_gpu_metrics() {
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

GPU_CARDS=()
GPU_IDS=()
GPU_PCIS=()
GPU_VENDORS=()
GPU_DRIVERS=()
PRIMARY_GPU_INDEX=-1

discover_gpus() {
  GPU_CARDS=(); GPU_IDS=(); GPU_PCIS=(); GPU_VENDORS=(); GPU_DRIVERS=()
  PRIMARY_GPU_INDEX=-1

  local card base vendor_hex vendor pci id driver selector_lc="${PRIMARY_GPU_SELECTOR,,}"
  shopt -s nullglob
  for card in "$DRM_ROOT"/card*; do
    base="$(basename "$card")"
    [[ "$base" =~ ^card[0-9]+$ ]] || continue
    [[ -r "$card/device/vendor" ]] || continue

    IFS= read -r vendor_hex < "$card/device/vendor" || continue
    vendor="$(vendor_name "$vendor_hex")"
    pci="$(awk -F= '/PCI_SLOT_NAME=/{print $2; exit}' "$card/device/uevent" 2>/dev/null || true)"
    pci="$(normalize_pci "$pci")"
    [[ -n "$pci" ]] || pci="$base"
    id="${pci//[:.]/_}"

    driver=""
    [[ -L "$card/device/driver" ]] && driver="$(basename "$(readlink -f "$card/device/driver" 2>/dev/null || true)")"

    GPU_CARDS+=("$card")
    GPU_IDS+=("$id")
    GPU_PCIS+=("$pci")
    GPU_VENDORS+=("$vendor")
    GPU_DRIVERS+=("$driver")

    if [[ -n "$selector_lc" && $PRIMARY_GPU_INDEX -lt 0 ]]; then
      if [[ "${base,,}" == "$selector_lc" || "${pci,,}" == "$selector_lc" || "${id,,}" == "$selector_lc" || "${vendor,,}" == "$selector_lc" ]]; then
        PRIMARY_GPU_INDEX=$((${#GPU_CARDS[@]} - 1))
      fi
    fi
  done
  shopt -u nullglob

  if (( PRIMARY_GPU_INDEX < 0 && ${#GPU_CARDS[@]} > 0 )); then PRIMARY_GPU_INDEX=0; fi
}

publish_gpu_index() {
  local json='{"gpus":[' i
  for ((i=0; i<${#GPU_CARDS[@]}; i++)); do
    (( i > 0 )) && json+=','
    json+='{'
    json+='"id":"'"$(json_escape "${GPU_IDS[$i]}")"'",'
    json+='"card":"'"$(json_escape "$(basename "${GPU_CARDS[$i]}")")"'",'
    json+='"pci":"'"$(json_escape "${GPU_PCIS[$i]}")"'",'
    json+='"vendor":"'"$(json_escape "${GPU_VENDORS[$i]}")"'",'
    json+='"driver":"'"$(json_escape "${GPU_DRIVERS[$i]}")"'"'
    (( i == PRIMARY_GPU_INDEX )) && json+=',"primary":true'
    json+='}'
  done
  json+=']}'
  atomic_write "$OUT_DIR/gpus.json" "$json"
}

format_bytes() {
  local bytes="${1:-}"
  [[ "$bytes" =~ ^[0-9]+$ ]] || { printf 'N/A'; return; }
  if (( bytes >= 1073741824 )); then
    awk -v b="$bytes" 'BEGIN { printf "%.1fGiB", b / 1073741824 }'
  else
    awk -v b="$bytes" 'BEGIN { printf "%.0fMiB", b / 1048576 }'
  fi
}

gpu_extra_json() {
  local metric="$1" vendor="$2" pci="$3" card="$4" driver="$5" available="$6"
  printf '"metric":"%s","vendor":"%s","pci":"%s","card":"%s","driver":"%s","available":%s' \
    "$(json_escape "$metric")" "$(json_escape "$vendor")" "$(json_escape "$pci")" \
    "$(json_escape "$card")" "$(json_escape "$driver")" "$available"
}

publish_one_gpu_metric() {
  local gpu_dir="$1" filename="$2" metric="$3" label="$4" vendor="$5" pci="$6" card="$7" driver="$8"
  local text="$9" value="${10}" unit="${11}" percentage="${12:-}" unavailable_reason="${13:-unavailable}" append_unit="${14:-1}"
  local available=true tooltip extra vendor_pretty
  vendor_pretty="$(vendor_label "$vendor")"

  if [[ "$text" == "N/A" || ! "$value" =~ ^-?[0-9]+([.][0-9]+)?$ ]]; then
    text="N/A"; value=""; percentage=""; available=false
    tooltip="$vendor_pretty $label ($pci): $unavailable_reason"
  else
    tooltip="$vendor_pretty $label ($pci): $text"
    if [[ "$append_unit" == "1" && -n "$unit" && "$text" != *"$unit" ]]; then tooltip+=" $unit"; fi
  fi

  extra="$(gpu_extra_json "$metric" "$vendor" "$pci" "$card" "$driver" "$available")"
  publish_metric_path "$gpu_dir/$filename" "$text" "$tooltip" "$value" "$unit" "$percentage" "$extra"
}

copy_primary_alias() {
  local source="$1" alias="$2" tmp
  [[ -r "$source" ]] || return 0
  tmp="$OUT_DIR/${alias}.tmp.$$"
  cp -- "$source" "$tmp"
  mv -f -- "$tmp" "$OUT_DIR/$alias"
}

sample_gpu_backend() {
  local vendor="$1" card_dir="$2"
  reset_gpu_metrics

  case "$vendor" in
    amd)
      if declare -F sample_amd_gpu >/dev/null 2>&1; then sample_amd_gpu "$card_dir" || reset_gpu_metrics; fi
      ;;
    intel)
      if declare -F sample_intel_gpu >/dev/null 2>&1; then sample_intel_gpu "$card_dir" || reset_gpu_metrics; fi
      ;;
    nvidia)
      if declare -F sample_nvidia_gpu >/dev/null 2>&1; then sample_nvidia_gpu "$card_dir" || reset_gpu_metrics; fi
      ;;
    *) reset_gpu_metrics ;;
  esac
}

publish_gpu() {
  local index="$1" card_dir="${GPU_CARDS[$1]}" id="${GPU_IDS[$1]}" pci="${GPU_PCIS[$1]}"
  local vendor="${GPU_VENDORS[$1]}" driver="${GPU_DRIVERS[$1]}" card gpu_dir reason="unavailable"
  local vram_pct="" vram_text="N/A" used_text total_text
  card="$(basename "$card_dir")"
  gpu_dir="$OUT_DIR/gpu/$id"
  mkdir -p "$gpu_dir"

  sample_gpu_backend "$vendor" "$card_dir"
  [[ "$vendor" == "nvidia" ]] && reason="NVIDIA temperature unavailable (nvidia-smi/driver)"
  [[ "$vendor" == "unknown" ]] && reason="unsupported GPU vendor"

  local usage_text="N/A" temp_text="N/A" power_text="N/A" core_text="N/A" vram_clock_text="N/A"
  [[ "$GPU_USAGE_PCT" =~ ^[0-9]+([.][0-9]+)?$ ]] && usage_text="${GPU_USAGE_PCT}%"
  [[ "$GPU_TEMP_C" =~ ^[0-9]+([.][0-9]+)?$ ]] && temp_text="${GPU_TEMP_C}°C"
  [[ "$GPU_POWER_W" =~ ^[0-9]+([.][0-9]+)?$ ]] && power_text="${GPU_POWER_W}W"
  [[ "$GPU_CORE_CLOCK_MHZ" =~ ^[0-9]+([.][0-9]+)?$ ]] && core_text="${GPU_CORE_CLOCK_MHZ}MHz"
  [[ "$GPU_VRAM_CLOCK_MHZ" =~ ^[0-9]+([.][0-9]+)?$ ]] && vram_clock_text="${GPU_VRAM_CLOCK_MHZ}MHz"

  if [[ "$GPU_VRAM_USED_BYTES" =~ ^[0-9]+$ && "$GPU_VRAM_TOTAL_BYTES" =~ ^[0-9]+$ && "$GPU_VRAM_TOTAL_BYTES" -gt 0 ]]; then
    vram_pct=$(( (100 * GPU_VRAM_USED_BYTES + GPU_VRAM_TOTAL_BYTES / 2) / GPU_VRAM_TOTAL_BYTES ))
    vram_pct="$(clamp_pct "$vram_pct")"
    used_text="$(format_bytes "$GPU_VRAM_USED_BYTES")"
    total_text="$(format_bytes "$GPU_VRAM_TOTAL_BYTES")"
    vram_text="${used_text}/${total_text}"
  fi

  publish_one_gpu_metric "$gpu_dir" usage.json gpu_usage "GPU usage" "$vendor" "$pci" "$card" "$driver" \
    "$usage_text" "$GPU_USAGE_PCT" "%" "${GPU_USAGE_PCT//N\/A/}" "$reason"
  publish_one_gpu_metric "$gpu_dir" temp.json gpu_temperature "GPU temperature" "$vendor" "$pci" "$card" "$driver" \
    "$temp_text" "$GPU_TEMP_C" "°C" "${GPU_TEMP_C//N\/A/}" "$reason"
  # Replace only the temperature tooltip, retaining the same numeric value
  # and JSON schema used by the existing sparkline and click-toggle helper.
  local temp_tooltip temp_json temp_extra
  temp_tooltip="Displaying: ${GPU_TEMP_SOURCE:-Unavailable}\nHotspot: ${GPU_TEMP_HOTSPOT_C:-N/A}\nCore / Edge: ${GPU_TEMP_EDGE_C:-N/A}\nVRAM: ${GPU_TEMP_VRAM_C:-N/A}"
  temp_tooltip="${temp_tooltip//\\n/$'\n'}"
  temp_json="$(cat "$gpu_dir/temp.json")"
  temp_json="$(jq -c --arg tip "$temp_tooltip" --arg source "${GPU_TEMP_SOURCE:-Unavailable}" '.tooltip=$tip | .temperature_source=$source' <<< "$temp_json")"
  atomic_write "$gpu_dir/temp.json" "$temp_json"
  publish_one_gpu_metric "$gpu_dir" power.json gpu_power "GPU power" "$vendor" "$pci" "$card" "$driver" \
    "$power_text" "$GPU_POWER_W" "W" "" "$reason"
  publish_one_gpu_metric "$gpu_dir" core-clock.json gpu_core_clock "GPU core clock" "$vendor" "$pci" "$card" "$driver" \
    "$core_text" "$GPU_CORE_CLOCK_MHZ" "MHz" "" "$reason"
  publish_one_gpu_metric "$gpu_dir" vram-clock.json gpu_vram_clock "GPU VRAM clock" "$vendor" "$pci" "$card" "$driver" \
    "$vram_clock_text" "$GPU_VRAM_CLOCK_MHZ" "MHz" "" "$reason"
  publish_one_gpu_metric "$gpu_dir" vram-usage.json gpu_vram_usage "GPU VRAM usage" "$vendor" "$pci" "$card" "$driver" \
    "$vram_text" "$GPU_VRAM_USED_BYTES" "bytes" "$vram_pct" "$reason" 0

  local meta
  printf -v meta '{"id":"%s","card":"%s","pci":"%s","vendor":"%s","driver":"%s"}' \
    "$(json_escape "$id")" "$(json_escape "$card")" "$(json_escape "$pci")" \
    "$(json_escape "$vendor")" "$(json_escape "$driver")"
  atomic_write "$gpu_dir/metadata.json" "$meta"

  if (( index == PRIMARY_GPU_INDEX )); then
    copy_primary_alias "$gpu_dir/usage.json" gpu-usage.json
    copy_primary_alias "$gpu_dir/temp.json" gpu-temp.json
    copy_primary_alias "$gpu_dir/power.json" gpu-power.json
    copy_primary_alias "$gpu_dir/core-clock.json" gpu-core-clock.json
    copy_primary_alias "$gpu_dir/vram-clock.json" gpu-vram-clock.json
    copy_primary_alias "$gpu_dir/vram-usage.json" gpu-vram-usage.json
  fi
}

sample_all_gpus() {
  discover_gpus
  publish_gpu_index
  local i
  for ((i=0; i<${#GPU_CARDS[@]}; i++)); do publish_gpu "$i"; done

  if ((${#GPU_CARDS[@]} == 0)); then
    local extra='"metric":"gpu","available":false'
    publish_metric_path "$OUT_DIR/gpu-usage.json" "N/A" "GPU usage: no DRM GPU detected" "" "%" "" "$extra"
    publish_metric_path "$OUT_DIR/gpu-temp.json" "N/A" "GPU temperature: no DRM GPU detected" "" "°C" "" "$extra"
    publish_metric_path "$OUT_DIR/gpu-power.json" "N/A" "GPU power: no DRM GPU detected" "" "W" "" "$extra"
    publish_metric_path "$OUT_DIR/gpu-core-clock.json" "N/A" "GPU core clock: no DRM GPU detected" "" "MHz" "" "$extra"
    publish_metric_path "$OUT_DIR/gpu-vram-clock.json" "N/A" "GPU VRAM clock: no DRM GPU detected" "" "MHz" "" "$extra"
    publish_metric_path "$OUT_DIR/gpu-vram-usage.json" "N/A" "GPU VRAM usage: no DRM GPU detected" "" "bytes" "" "$extra"
  fi
}

sample_once() {
  local cpu_pct mem_pct now
  read_cpu_usage
  cpu_pct="$CPU_PCT"
  mem_pct="$(read_mem_usage)"
  read_cpu_clocks

  publish_cpu_and_mem "$cpu_pct" "$mem_pct"
  publish_cpu_clocks
  sample_all_gpus

  now="$(date +%s)"
  atomic_write "$OUT_DIR/last-update.json" "{\"timestamp\":$now}"
}

case "${1:-}" in
  --once) sample_once; exit 0 ;;
  "") ;;
  *) echo "Usage: $0 [--once]" >&2; exit 2 ;;
esac

trap 'exit 0' INT TERM HUP
while true; do
  sample_once
  sleep "$INTERVAL"
done
