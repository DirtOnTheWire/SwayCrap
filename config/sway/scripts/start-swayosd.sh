#!/usr/bin/env bash

# ============================================================
# SwayOSD launcher / watchdog
# ============================================================

ENABLE_LOGS=0
RESTART_DELAY=3
CHECK_INTERVAL=3
MAX_FAILURES=3

RUNTIME="${XDG_RUNTIME_DIR:-/tmp}"
LOCK="$RUNTIME/swayosd-start.lock"
LOG="$RUNTIME/swayosd.log"

exec 9>"$LOCK"
flock -n 9 || exit 0

if (( ENABLE_LOGS )); then
    exec >>"$LOG" 2>&1
else
    exec >/dev/null 2>&1
fi

# ------------------------------------------------------------
# Wait for Sway to be ready
# ------------------------------------------------------------

until swaymsg -t get_version >/dev/null 2>&1; do
    sleep 1
done

# ------------------------------------------------------------
# Check SwayOSD D-Bus registration
# Both names should belong to a healthy running server.
# ------------------------------------------------------------

swayosd_healthy() {
    local names

    names=$(timeout 2s busctl --user --acquired list --no-pager) || return 1

    grep -q '^org\.erikreider\.swayosd ' <<< "$names" &&
    grep -q '^org\.erikreider\.swayosd-server ' <<< "$names"
}

# ------------------------------------------------------------
# Start, monitor, and restart SwayOSD
# ------------------------------------------------------------

while true; do
    # Don't duplicate an already healthy server.
    if swayosd_healthy; then
        sleep "$CHECK_INTERVAL"
        continue
    fi

    # Don't interfere with a server started elsewhere.
    if pgrep -x swayosd-server >/dev/null; then
        echo "SwayOSD: existing server unhealthy; waiting"
        sleep "$CHECK_INTERVAL"
        continue
    fi

    swayosd-server &
    pid=$!
    failures=0

    # Give the server time to register on D-Bus.
    sleep 3

    while kill -0 "$pid" 2>/dev/null; do
        if swayosd_healthy; then
            failures=0
        else
            ((failures += 1))

            if (( failures >= MAX_FAILURES )); then
                echo "SwayOSD: D-Bus registration failed; restarting"

                kill "$pid" 2>/dev/null || true
                sleep 1

                if kill -0 "$pid" 2>/dev/null; then
                    kill -KILL "$pid" 2>/dev/null || true
                fi

                break
            fi
        fi

        sleep "$CHECK_INTERVAL"
    done

    wait "$pid" 2>/dev/null || true
    sleep "$RESTART_DELAY"
done