
#!/usr/bin/env bash
set -euo pipefail

WAYBAR_DIR="$HOME/.config/waybar"
DAEMON="$WAYBAR_DIR/scripts/stats-daemon.sh"

# Start stats daemon if not already running.
if ! pgrep -f "^(/usr/bin/)?bash $DAEMON([[:space:]]|$)" >/dev/null; then
    nohup bash "$DAEMON" >/dev/null 2>&1 </dev/null &
fi

# Restore saved pill visibility.
bash "$WAYBAR_DIR/scripts/stats-menu.sh" sync

# Restart Waybar.
pkill -x waybar 2>/dev/null || true

exec waybar \
    -c "$WAYBAR_DIR/config.jsonc" \
    -s "$WAYBAR_DIR/style.css"
