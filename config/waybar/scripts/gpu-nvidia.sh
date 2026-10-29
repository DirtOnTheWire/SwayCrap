#!/usr/bin/env bash
# NVIDIA backend placeholder.
# Detection is supported, but collection is intentionally N/A until tested.

reset_nvidia_metrics() {
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

sample_nvidia_gpu() {
  local card_dir="${1:?card directory required}"
  reset_nvidia_metrics
  # NVIDIA generally exposes the core temperature, not a portable hotspot.
  # Match the DRM device PCI address rather than assuming GPU index 0.
  command -v nvidia-smi >/dev/null 2>&1 || return 0
  local pci raw bus
  pci="$(basename "$(readlink -f "$card_dir/device" 2>/dev/null || echo unknown)")"
  [[ "$pci" =~ ^[[:xdigit:]]{4}:[[:xdigit:]]{2}:[[:xdigit:]]{2}\.[0-7]$ ]] || return 0
  bus="${pci^^}"
  raw="$(nvidia-smi --id="$bus" --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -n1 | tr -d '[:space:]' || true)"
  if [[ "$raw" =~ ^[0-9]+$ ]]; then
    GPU_TEMP_C="$raw"
    GPU_TEMP_EDGE_C="$raw"
    GPU_TEMP_SOURCE="Core"
  fi
}

nvidia_standalone() {
  local card_dir="${1:-}"
  [[ -n "$card_dir" && -d "$card_dir/device" ]] || { echo 'Usage: gpu-nvidia.sh /sys/class/drm/cardN' >&2; exit 2; }
  sample_nvidia_gpu "$card_dir"
  printf '%s\n' '{"vendor":"nvidia","usage_pct":null,"temp_c":null,"power_w":null,"core_clock_mhz":null,"vram_clock_mhz":null,"vram_used_bytes":null,"vram_total_bytes":null,"note":"NVIDIA backend not implemented/tested"}'
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  set -euo pipefail
  nvidia_standalone "$@"
fi
