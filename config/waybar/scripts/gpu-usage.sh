#!/usr/bin/env bash
set -euo pipefail

NODATA_OUTPUT="${NODATA_OUTPUT:-N/A}"

normalize_pci() {
  local s="${1:-}"
  if [[ "$s" =~ ^[0-9a-fA-F]{8}: ]]; then
    echo "${s:4}"
  else
    echo "$s"
  fi
}

read_int_file() {
  local f="$1"
  [[ -r "$f" ]] || return 1
  if command -v timeout >/dev/null 2>&1; then
    timeout 0.2 cat "$f" 2>/dev/null | tr -dc '0-9'
  else
    cat "$f" 2>/dev/null | tr -dc '0-9'
  fi
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
    local want
    want="$(normalize_pci "$pci")"
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

nvidia_util_from_card() {
  local card_dir="$1"
  command -v nvidia-smi >/dev/null 2>&1 || return 1

  local pci
  pci="$(awk -F= '/PCI_SLOT_NAME=/{print $2; exit}' "$card_dir/device/uevent" 2>/dev/null || true)"
  pci="$(normalize_pci "$pci")"
  [[ -n "$pci" ]] || return 1

  local line
  while IFS= read -r line; do
    local bus util
    bus="$(echo "$line" | awk -F',' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$1); print $1}')"
    util="$(echo "$line" | awk -F',' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$2); print $2}')"
    bus="$(normalize_pci "$bus")"
    if [[ "$bus" == "$pci" && "$util" =~ ^[0-9]+$ ]]; then
      echo "$util"
      return 0
    fi
  done < <(nvidia-smi --query-gpu=pci.bus_id,utilization.gpu --format=csv,noheader,nounits 2>/dev/null || true)

  return 1
}

intel_gpu_top_fallback() {
  local card_dir="$1"

  # Determine driver for this card
  local driver=""
  if [[ -L "$card_dir/device/driver" ]]; then
    driver="$(basename "$(readlink -f "$card_dir/device/driver" 2>/dev/null || true)")"
  fi

  # Auto-enable on i915, or allow manual override
  if [[ "${USE_INTEL_GPU_TOP:-0}" != "1" && "$driver" != "i915" ]]; then
    return 1
  fi

  command -v intel_gpu_top >/dev/null 2>&1 || return 1
  command -v jq >/dev/null 2>&1 || return 1

  # Run ONCE. If timeout exists, always use it. No "|| intel_gpu_top" fallback.
  local out=""
  if command -v timeout >/dev/null 2>&1; then
    out="$(timeout 1.6 intel_gpu_top -J -s 400 -o - 2>/dev/null || true)"
  else
    # Worst-case fallback: short sample, but this can block if intel_gpu_top blocks.
    out="$(intel_gpu_top -J -s 400 -o - 2>/dev/null || true)"
  fi

  # intel_gpu_top can emit multiple JSON objects; take the last non-empty line
  local json
  json="$(printf "%s\n" "$out" | awk 'NF{last=$0} END{print last}')"
  [[ -n "$json" ]] || return 1

  jq -r '
    if .engines then
      ([.engines | to_entries[] | .value.busy] | max) // empty
    else empty end
  ' <<<"$json" 2>/dev/null | awk '
    /^[0-9]+(\.[0-9]+)?$/ {printf "%d\n", ($1+0.5); exit}
  '
}


main() {
  local card_dir
  card_dir="$(pick_card_dir)"

  # sysfs candidates (AMDGPU + some Intel variants)
  local sys_candidates=(
    "$card_dir/device/gpu_busy_percent"
    "$card_dir/device/gt_busy_percent"
    "$card_dir/device/gt0_busy_percent"
    "$card_dir/device/gt1_busy_percent"
  )

  local v
  for f in "${sys_candidates[@]}"; do
    v="$(read_int_file "$f" || true)"
    if [[ -n "$v" && "$v" =~ ^[0-9]+$ ]]; then
      printf "%3d%%\n" "$v"
      return 0
    fi
  done

  # NVIDIA via nvidia-smi
  v="$(nvidia_util_from_card "$card_dir" || true)"
  if [[ -n "$v" && "$v" =~ ^[0-9]+$ ]]; then
    printf "%3d%%\n" "$v"
    return 0
  fi

  # Intel i915 via intel_gpu_top
  v="$(intel_gpu_top_fallback "$card_dir" || true)"
  if [[ -n "$v" && "$v" =~ ^[0-9]+$ ]]; then
    printf "%3d%%\n" "$v"
    return 0
  fi

  echo "$NODATA_OUTPUT"
}

main "$@"

