#!/usr/bin/env bash
set -euo pipefail

NODATA_OUTPUT="${NODATA_OUTPUT:-N/A}"
POWER_PAD_WIDTH="${POWER_PAD_WIDTH:-3}"
POWER_PAD_CHAR="${POWER_PAD_CHAR:-0}"   # 0 or space
POWER_UNIT="${POWER_UNIT:-W}"

normalize_pci() {
  local s="${1:-}"
  if [[ "$s" =~ ^[0-9a-fA-F]{8}: ]]; then echo "${s:4}"; else echo "$s"; fi
}

pick_card_dir() {
  local card="${GPU_CARD:-}"
  local pci="${GPU_PCI:-}"
  local match="${GPU_MATCH:-}"

  if [[ -n "$card" ]]; then
    local d="/sys/class/drm/card${card}"
    [[ -d "$d" ]] && { echo "$d"; return 0; }
  fi

  if [[ -n "$pci" ]]; then
    local want; want="$(normalize_pci "$pci")"
    for d in /sys/class/drm/card*; do
      [[ -r "$d/device/uevent" ]] || continue
      local got
      got="$(awk -F= '/PCI_SLOT_NAME=/{print $2; exit}' "$d/device/uevent" 2>/dev/null || true)"
      got="$(normalize_pci "$got")"
      [[ -n "$got" && "$got" == "$want" ]] && { echo "$d"; return 0; }
    done
  fi

  if [[ -n "$match" ]]; then
    for d in /sys/class/drm/card*; do
      [[ -d "$d" ]] || continue
      local label vendor driver pci_name
      label="$(basename "$d")"
      vendor="$(cat "$d/device/vendor" 2>/dev/null || true)"
      pci_name="$(awk -F= '/PCI_SLOT_NAME=/{print $2; exit}' "$d/device/uevent" 2>/dev/null || true)"
      driver=""
      if [[ -L "$d/device/driver" ]]; then
        driver="$(basename "$(readlink -f "$d/device/driver" 2>/dev/null || true)")"
      fi
      if echo "$label $vendor $driver $pci_name" | grep -Eqi -- "$match"; then
        echo "$d"; return 0
      fi
    done
  fi

  echo "/sys/class/drm/card0"
}

driver_for_card() {
  local card_dir="$1"
  if [[ -L "$card_dir/device/driver" ]]; then
    basename "$(readlink -f "$card_dir/device/driver" 2>/dev/null || true)"
  else
    echo ""
  fi
}

read_num() {
  local f="$1"
  [[ -r "$f" ]] || return 1
  tr -dc '0-9.' < "$f" 2>/dev/null
}

format_watts() {
  local watts="$1"
  local fmt
  if [[ "$POWER_PAD_CHAR" == "0" ]]; then
    printf -v fmt '%%0%dd%%s\n' "$POWER_PAD_WIDTH"
  else
    printf -v fmt '%%%dd%%s\n' "$POWER_PAD_WIDTH"
  fi
  printf "$fmt" "$watts" "$POWER_UNIT"
}

hwmon_power_watts() {
  local card_dir="$1"
  local f raw watts

  shopt -s nullglob
  local candidates=(
    "$card_dir/device/hwmon"/hwmon*/power1_average
    "$card_dir/device/hwmon"/hwmon*/power1_input
    "$card_dir/device/hwmon"/hwmon*/power2_average
    "$card_dir/device/hwmon"/hwmon*/power2_input
    "$card_dir/hwmon"/hwmon*/power1_average
    "$card_dir/hwmon"/hwmon*/power1_input
  )
  shopt -u nullglob

  for f in "${candidates[@]}"; do
    [[ -r "$f" ]] || continue
    raw="$(read_num "$f" || true)"
    [[ -n "$raw" ]] || continue

    if [[ "$raw" =~ ^[0-9]+$ ]]; then
      # hwmon power files are usually microwatts; round to whole watts
      if (( raw >= 1000000 )); then
        watts=$(( (raw + 500000) / 1000000 ))
      elif (( raw >= 1000 )); then
        watts=$(( (raw + 500) / 1000 ))
      else
        watts=$raw
      fi
      echo "$watts"
      return 0
    fi
  done

  return 1
}

nvidia_power_watts() {
  local card_dir="$1"
  command -v nvidia-smi >/dev/null 2>&1 || return 1

  local pci
  pci="$(awk -F= '/PCI_SLOT_NAME=/{print $2; exit}' "$card_dir/device/uevent" 2>/dev/null || true)"
  pci="$(normalize_pci "$pci")"
  [[ -n "$pci" ]] || return 1

  local line
  while IFS= read -r line; do
    local bus p
    bus="$(echo "$line" | awk -F',' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$1); print $1}')"
    p="$(echo "$line"   | awk -F',' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$2); print $2}')"
    bus="$(normalize_pci "$bus")"
    if [[ "$bus" == "$pci" && "$p" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
      awk -v x="$p" 'BEGIN { printf "%d\n", int(x + 0.5) }'
      return 0
    fi
  done < <(
    if command -v timeout >/dev/null 2>&1; then
      timeout 0.6 nvidia-smi --query-gpu=pci.bus_id,power.draw --format=csv,noheader,nounits 2>/dev/null || true
    else
      nvidia-smi --query-gpu=pci.bus_id,power.draw --format=csv,noheader,nounits 2>/dev/null || true
    fi
  )

  return 1
}

main() {
  local card_dir driver watts=""
  card_dir="$(pick_card_dir)"
  driver="$(driver_for_card "$card_dir")"

  case "$driver" in
    amdgpu|i915|xe)
      watts="$(hwmon_power_watts "$card_dir" || true)"
      ;;
    nvidia|nouveau)
      watts="$(nvidia_power_watts "$card_dir" || true)"
      [[ -n "$watts" ]] || watts="$(hwmon_power_watts "$card_dir" || true)"
      ;;
    *)
      watts="$(hwmon_power_watts "$card_dir" || true)"
      ;;
  esac

  [[ -n "$watts" && "$watts" =~ ^[0-9]+$ ]] || { echo "$NODATA_OUTPUT"; exit 0; }
  format_watts "$watts"
}

main "$@"