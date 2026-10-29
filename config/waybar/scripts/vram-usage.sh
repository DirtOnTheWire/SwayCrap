#!/usr/bin/env bash
set -euo pipefail

NODATA_OUTPUT="${NODATA_OUTPUT:-N/A}"
VRAM_FORMAT="${VRAM_FORMAT:-used/total}"  # used | used/total | pct
VRAM_UNIT="${VRAM_UNIT:-auto}"            # auto | mib | gib

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

fmt_bytes() {
  local bytes="$1"
  local unit="$VRAM_UNIT"
  if [[ "$unit" == "auto" ]]; then
    # auto: use GiB if >= 1GiB, else MiB
    if (( bytes >= 1073741824 )); then unit="gib"; else unit="mib"; fi
  fi
  if [[ "$unit" == "gib" ]]; then
    awk -v b="$bytes" 'BEGIN{printf "%.1fGiB", b/1073741824}'
  else
    awk -v b="$bytes" 'BEGIN{printf "%.0fMiB", b/1048576}'
  fi
}

# ---------- AMD (amdgpu) ----------
amd_vram() {
  local card_dir="$1"

  # Prefer mem_info_vram_used/total (newer kernels)
  local used_f="$card_dir/device/mem_info_vram_used"
  local tot_f="$card_dir/device/mem_info_vram_total"

  if [[ -r "$used_f" && -r "$tot_f" ]]; then
    local used total
    used="$(cat "$used_f" 2>/dev/null | tr -dc '0-9' || true)"
    total="$(cat "$tot_f" 2>/dev/null | tr -dc '0-9' || true)"
    [[ -n "$used" && -n "$total" ]] || return 1
    echo "$used $total"
    return 0
  fi

  # Fallback: try mem_info_vram_total + use "vram used" from gpu memory info if present
  return 1
}

# ---------- NVIDIA via nvidia-smi ----------
nvidia_vram() {
  local card_dir="$1"
  command -v nvidia-smi >/dev/null 2>&1 || return 1

  local pci
  pci="$(awk -F= '/PCI_SLOT_NAME=/{print $2; exit}' "$card_dir/device/uevent" 2>/dev/null || true)"
  pci="$(normalize_pci "$pci")"
  [[ -n "$pci" ]] || return 1

  local line
  while IFS= read -r line; do
    # csv: "00000000:03:00.0, 512, 24564" (MiB)
    local bus used total
    bus="$(echo "$line"  | awk -F',' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$1); print $1}')"
    used="$(echo "$line" | awk -F',' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$2); print $2}')"
    total="$(echo "$line"| awk -F',' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$3); print $3}')"
    bus="$(normalize_pci "$bus")"
    if [[ "$bus" == "$pci" && "$used" =~ ^[0-9]+$ && "$total" =~ ^[0-9]+$ ]]; then
      # Convert MiB -> bytes for common formatting
      echo "$(( used * 1048576 )) $(( total * 1048576 ))"
      return 0
    fi
  done < <(
    if command -v timeout >/dev/null 2>&1; then
      timeout 0.6 nvidia-smi --query-gpu=pci.bus_id,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null || true
    else
      nvidia-smi --query-gpu=pci.bus_id,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null || true
    fi
  )
  return 1
}

# ---------- Intel (i915) via intel_gpu_top JSON (best-effort “GPU memory”) ----------
intel_mem() {
  local card_dir="$1"
  command -v intel_gpu_top >/dev/null 2>&1 || return 1
  command -v jq >/dev/null 2>&1 || return 1

  # Run once, timeboxed. Avoid hanging.
  local out=""
  if command -v timeout >/dev/null 2>&1; then
    out="$(timeout 1.6 intel_gpu_top -J -s 400 -o - 2>/dev/null || true)"
  else
    out="$(intel_gpu_top -J -s 400 -o - 2>/dev/null || true)"
  fi
  local json
  json="$(printf "%s\n" "$out" | awk 'NF{last=$0} END{print last}')"
  [[ -n "$json" ]] || return 1

  # intel_gpu_top JSON schema varies. Try common locations:
  # If we can find "memory" fields, interpret as bytes.
  local used total
  used="$(jq -r '(.memory.used // .memory_used // empty)' <<<"$json" 2>/dev/null || true)"
  total="$(jq -r '(.memory.total // .memory_total // empty)' <<<"$json" 2>/dev/null || true)"

  [[ "$used" =~ ^[0-9]+$ && "$total" =~ ^[0-9]+$ ]] || return 1
  echo "$used $total"
}

main() {
  local card_dir driver
  card_dir="$(pick_card_dir)"
  driver="$(driver_for_card "$card_dir")"

  local used_b="" total_b=""

  # AMD
  if [[ "$driver" == "amdgpu" ]]; then
    read -r used_b total_b < <(amd_vram "$card_dir" || true)
  fi

  # NVIDIA (nvidia or nouveau often indicates an NVIDIA device)
  if [[ -z "$used_b" && ( "$driver" == "nvidia" || "$driver" == "nouveau" ) ]]; then
    read -r used_b total_b < <(nvidia_vram "$card_dir" || true)
  fi

  # Intel best-effort
  if [[ -z "$used_b" && "$driver" == "i915" ]]; then
    read -r used_b total_b < <(intel_mem "$card_dir" || true)
  fi

  [[ -n "${used_b:-}" && -n "${total_b:-}" ]] || { echo "$NODATA_OUTPUT"; exit 0; }

  case "$VRAM_FORMAT" in
    used)
      fmt_bytes "$used_b"
      ;;
    pct)
      awk -v u="$used_b" -v t="$total_b" 'BEGIN{ if(t>0) printf "%d%%", (u*100/t)+0.5; else print "N/A" }'
      ;;
    *)
      printf "%s/%s" "$(fmt_bytes "$used_b")" "$(fmt_bytes "$total_b")"
      ;;
  esac
}

main "$@"
