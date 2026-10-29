
#!/usr/bin/env bash
# Toggle persistent, per-metric Waybar sparkline visibility.
set -euo pipefail

metric="${1:-}"
action="${2:-watch}"

case "$metric" in
  cpu|memory|cpu-clock-avg|cpu-clock-max|cpu-temp|gpu-core-clock|gpu-vram-clock|gpu-vram-usage|gpu-power|gpu-temp|gpu-usage) ;;
  *) echo 'Unknown metric' >&2; exit 2 ;;
esac

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/waybar/graph-toggles"
mkdir -p "$state_dir"
state="$state_dir/$metric.hidden"

# A separate, persistent visibility switch for the complete CPU/GPU group.
# This does not alter per-stat graph preferences or the stats daemon.
pill_state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/waybar/pill-visibility"

case "$metric" in
  cpu|memory|cpu-*) pill=cpu ;;
  gpu-*) pill=gpu ;;
esac

case "$metric" in
  cpu) label='CPU' ;;
  memory) label='RAM' ;;
  cpu-clock-avg) label='AVG' ;;
  cpu-clock-max) label='MAX' ;;
  cpu-temp|gpu-temp) label='TEMP' ;;
  gpu-usage) label='GPU' ;;
  gpu-core-clock|gpu-vram-clock) label='CLK' ;;
  gpu-vram-usage) label='VRAM' ;;
  gpu-power) label='PWR' ;;
esac

if [[ "$action" == toggle ]]; then
  if [[ -e "$state" ]]; then
    rm -f -- "$state"
  else
    : > "$state"
  fi
  exit 0
fi

[[ "$action" == watch ]] || exit 2

command -v jq >/dev/null || {
  echo 'jq is required' >&2
  exit 1
}

if [[ -n "${WAYBAR_STATS_DIR:-}" ]]; then
  runtime="$WAYBAR_STATS_DIR"
elif [[ -n "${XDG_RUNTIME_DIR:-}" ]]; then
  runtime="$XDG_RUNTIME_DIR/waybar-stats"
else
  runtime="/tmp/waybar-stats-$UID"
fi

# ============================================================
# Graph configuration
# ============================================================

# Fixed temperature graph range, in Celsius.
TEMP_GRAPH_MIN=25
TEMP_GRAPH_MAX=100

# Number of displayed historical samples.
POINTS="${WAYBAR_STATS_POINTS:-5}"

# History exists only while Waybar runs;
# show/hide preferences persist separately.
values=()

# Sticky observed frequency boundaries.
# Each running clock module tracks its own extremes.
# They reset when that module process restarts.
observed_min=""
observed_max=""

# ============================================================
# Graph helpers
# ============================================================

is_clock_metric() {
  case "$metric" in
    cpu-clock-avg|cpu-clock-max|gpu-core-clock|gpu-vram-clock)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# Return success for numeric values greater than zero.
# Zero/invalid clock readings do not become frequency minima.
positive_number() {
  [[ "${1:-}" =~ ^[0-9]+([.][0-9]+)?$ ]] || return 1
  awk -v v="$1" 'BEGIN { exit !(v > 0) }'
}

# Update sticky min/max for clock metrics.
update_clock_limits() {
  local v="$1"

  is_clock_metric || return 0
  positive_number "$v" || return 0

  if [[ -z "$observed_min" ]] ||
     awk -v v="$v" -v m="$observed_min" \
       'BEGIN { exit !(v < m) }'; then
    observed_min="$v"
  fi

  if [[ -z "$observed_max" ]] ||
     awk -v v="$v" -v m="$observed_max" \
       'BEGIN { exit !(v > m) }'; then
    observed_max="$v"
  fi
}

# Build a sparkline using either:
#   - Fixed 25-100 C temperature range
#   - Sticky observed clock range
#   - Recent min/max for other GPU metrics
make_graph() {
  local lo="" hi=""

  case "$metric" in
    cpu-temp|gpu-temp)
      lo="$TEMP_GRAPH_MIN"
      hi="$TEMP_GRAPH_MAX"
      ;;

    cpu-clock-avg|cpu-clock-max|gpu-core-clock|gpu-vram-clock)
      lo="${observed_min:-}"
      hi="${observed_max:-}"
      ;;
  esac

  printf '%s\n' "${values[@]}" |
    awk -v fixed_lo="$lo" -v fixed_hi="$hi" '
      {
        x[NR] = $1

        if (NR == 1 || $1 < recent_lo)
          recent_lo = $1

        if (NR == 1 || $1 > recent_hi)
          recent_hi = $1
      }

      END {
        split("▁ ▂ ▃ ▄ ▅ ▆ ▇ █", ch, " ")

        lo = recent_lo
        hi = recent_hi

        # Fixed temperature range or sticky clock range.
        if (fixed_lo != "" && fixed_hi != "") {
          lo = fixed_lo
          hi = fixed_hi
        }

        span = hi - lo

        # Avoid division by zero when all readings match.
        if (span < 1)
          span = 1

        for (i = 1; i <= NR; i++) {
          j = int((x[i] - lo) * 7 / span) + 1

          if (j < 1)
            j = 1

          if (j > 8)
            j = 8

          printf "%s", ch[j]
        }
      }
    '
}

# ============================================================
# Text formatting
# ============================================================

# Reserve only the expected maximum display width.
# The bar uses a monospace font.
format_reading() {
  local raw="$1" width=0

  case "$metric" in
    cpu|gpu-usage)
      width=4
      ;;
    memory|gpu-vram-usage)
      width=5
      ;;
    cpu-temp|gpu-temp)
      width=5
      ;;
    cpu-clock-avg|cpu-clock-max)
      width=5
      ;;
    gpu-core-clock|gpu-vram-clock)
      width=5
      ;;
    gpu-power)
      width=4
      ;;
  esac

  printf '%*s' "$width" "$raw"
}

# Human-readable used memory amount; 1024-based.
compact_bytes() {
  awk -v b="$1" 'BEGIN {
    if (b < 0 || b == "") {
      print "N/A"
      exit
    }

    mib = b / 1048576

    if (mib < 1000) {
      printf "%.0fM", mib
      exit
    }

    gib = b / 1073741824

    if (gib < 10)
      printf "%.2fG", gib
    else if (gib < 100)
      printf "%.1fG", gib
    else
      printf "%.0fG", gib
  }'
}

read_ram_used_bytes() {
  awk '
    /^MemTotal:/     { total = $2 }
    /^MemAvailable:/ { available = $2 }

    END {
      if (total > 0)
        printf "%.0f", (total - available) * 1024
      else
        print ""
    }
  ' /proc/meminfo
}

# Read current theme color on every sample so changing themes
# does not require restarting the graph scripts.
get_cyan() {
  local css="${XDG_CONFIG_HOME:-$HOME/.config}/waybar/colors.css"
  local color

  color="$(
    sed -nE \
      's/^[[:space:]]*@define-color[[:space:]]+cyan[[:space:]]+(#[[:xdigit:]]{6,8})[[:space:]]*;.*/\1/p' \
      "$css" 2>/dev/null | head -n 1
  )"

  [[ "$color" =~ ^#[[:xdigit:]]{6}([[:xdigit:]]{2})?$ ]] ||
    color='#ce52e0'

  printf '%s' "$color"
}

pango_escape() {
  local s="$1"

  s="${s//&/\&amp;}"
  s="${s//</\&lt;}"
  s="${s//>/\&gt;}"

  printf '%s' "$s"
}

emit_reading() {
  local line="$1"
  local shown="$2"
  local cyan formatted

  cyan="$(get_cyan)"

  formatted="$label <span foreground=\"$cyan\">$(pango_escape "$shown")</span>"

  jq -c --arg t "$formatted" '.text = $t' <<< "$line"
}

# ============================================================
# Main graph renderer
# ============================================================

render() {
  local line="$1"
  local val text graph=''

  # Completely hide widgets when their CPU/GPU pill is disabled.
  if [[ -f "$pill_state_dir/$pill.hidden" ]]; then
    printf '{"text":""}\n'
    return 0
  fi

  val="$(
    jq -r \
      'if (.value | type) == "number"
       then (.value | tostring)
       else ""
       end' <<< "$line"
  )" || return 0

  text="$(jq -r '.text // "N/A"' <<< "$line")"

  # ----------------------------------------------------------
  # CPU and RAM utilization
  #
  # Their graphs are already generated by stats-daemon.sh
  # using a fixed 0-100% scale.
  # ----------------------------------------------------------

  if [[ "$metric" == cpu || "$metric" == memory ]]; then

    local reading="${text##* }"

    if [[ "$metric" == memory ]]; then
      local ram_bytes
      ram_bytes="$(read_ram_used_bytes)"

      if [[ -n "$ram_bytes" ]]; then
        reading="$(compact_bytes "$ram_bytes")"
      else
        reading="N/A"
      fi
    fi

    reading="$(format_reading "$reading")"

    if [[ -e "$state" ]]; then
      emit_reading "$line" "$reading"
    else
      local spark="${text%% *}"

      # Reserve full sparkline width while history warms up.
      while ((${#spark} < POINTS)); do
        spark="▁$spark"
      done

      emit_reading "$line" "$spark $reading"
    fi

    return 0
  fi

  # ----------------------------------------------------------
  # Format GPU readings.
  # Raw JSON values and tooltips remain unchanged.
  # ----------------------------------------------------------

  if [[ "$val" =~ ^-?[0-9]+([.][0-9]+)?$ ]]; then
    case "$metric" in

      gpu-core-clock|gpu-vram-clock)
        text="$(
          awk -v mhz="$val" 'BEGIN {
            if (mhz >= 1000)
              printf "%.2fG", mhz / 1000
            else
              printf "%.0fM", mhz
          }'
        )"
        ;;

      gpu-vram-usage)
        text="$(compact_bytes "$val")"
        ;;

      gpu-power)
        text="$(
          awk -v watts="$val" \
            'BEGIN { printf "%.0fW", watts }'
        )"
        ;;
    esac
  fi

  text="$(format_reading "$text")"

  # ----------------------------------------------------------
  # Sample history and sticky frequency boundaries.
  # ----------------------------------------------------------

  if [[ "$val" =~ ^-?[0-9]+([.][0-9]+)?$ ]]; then

    # Ignore invalid zero/negative clock readings.
    # Other metrics can legitimately have zero readings.
    if ! is_clock_metric || positive_number "$val"; then

      values+=("$val")

      if ((${#values[@]} > POINTS)); then
        values=("${values[@]:1}")
      fi

      # Clock boundaries persist even after old samples
      # leave the displayed history window.
      update_clock_limits "$val"
    fi
  fi

  # ----------------------------------------------------------
  # Render or hide sparkline.
  # ----------------------------------------------------------

  if [[ ! -e "$state" && ${#values[@]} -gt 0 ]]; then

    graph="$(make_graph)"

    # Pad graph while collecting the first samples.
    while ((${#graph} < POINTS)); do
      graph="▁$graph"
    done

    emit_reading "$line" "$graph $text"

  else
    emit_reading "$line" "$text"
  fi
}

# ============================================================
# Input sources
# ============================================================

if [[ "$metric" == cpu-temp ]]; then

  # Existing CPU temperature probe.
  script="${WAYBAR_SCRIPT_DIR:-$HOME/.config/waybar/scripts}/temp-cpu.sh"

  while true; do

    temp="$("$script" 2>/dev/null || printf 'N/A')"

    num="$(
      grep -oE '^[[:space:]]*[0-9]+' <<< "$temp" |
        tr -d ' ' || true
    )"

    line="$(
      jq -cn \
        --arg t "$temp" \
        --arg n "$num" \
        '{
          text: $t,
          tooltip: ("CPU temperature: " + $t),
          value: (
            if ($n | length) > 0
            then ($n | tonumber)
            else null
            end
          )
        }'
    )"

    render "$line"
    sleep "${WAYBAR_STATS_INTERVAL:-2}"

  done

else

  # tail -F survives atomic file replacement by stats-daemon.sh.
  tail -n 1 -F "$runtime/$metric.json" 2>/dev/null |
    while IFS= read -r line; do
      render "$line"
    done

fi
