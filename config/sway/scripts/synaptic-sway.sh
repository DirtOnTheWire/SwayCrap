#!/usr/bin/env bash
set -euo pipefail

theme="$(
  awk -F= '/^gtk-theme-name=/ {print $2; exit}' \
    "$HOME/.config/gtk-3.0/settings.ini" 2>/dev/null || true
)"

icon_theme="$(
  awk -F= '/^gtk-icon-theme-name=/ {print $2; exit}' \
    "$HOME/.config/gtk-3.0/settings.ini" 2>/dev/null || true
)"

theme="${theme:-Mint-Y-Dark-Blue}"
icon_theme="${icon_theme:-Mint-Y-Blue}"

xhost +SI:localuser:root >/dev/null 2>&1 || true

pkexec env \
  DISPLAY="${DISPLAY:-:0}" \
  XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}" \
  GDK_BACKEND=x11 \
  GTK_THEME="$theme" \
  GTK_ICON_THEME="$icon_theme" \
  synaptic

xhost -SI:localuser:root >/dev/null 2>&1 || truex
