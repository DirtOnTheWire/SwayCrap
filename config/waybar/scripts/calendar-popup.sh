#!/usr/bin/env bash

APP_ID="waybar-calendar-popup"

# Toggle behavior: if it is already open, close it.
if pgrep -f "foot.*${APP_ID}" >/dev/null 2>&1; then
  pkill -f "foot.*${APP_ID}"
  exit 0
fi

exec foot \
  --app-id "$APP_ID" \
  --title "Calendar" \
  -W 90x30 \
  calcurse
