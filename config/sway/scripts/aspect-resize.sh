
#!/usr/bin/env bash

# SwayCrap Aspect Ratio Resize
#
# 16:9  - Widescreen application content
# 4:3   - Classic application content
# equal - Equalize horizontal tiled containers
#
# Floating: resize both dimensions and center.
# Tiled: adjust width using application content height.
#
# Compatible with Sway and SwayFX.

set -euo pipefail

MODE="${1:-}"

case "$MODE" in
    16:9)
        NUM=16
        DEN=9
        ;;
    4:3)
        NUM=4
        DEN=3
        ;;
    equal)
        ;;
    *)
        echo "Usage: $0 {16:9|4:3|equal}" >&2
        exit 1
        ;;
esac

# ------------------------------------------------------------
# Find focused window
# ------------------------------------------------------------

TREE=$(swaymsg -t get_tree -r)

# IMPORTANT:
# Search both tiled nodes and floating nodes.

# Find focused tiled OR floating window.
WINDOW=$(jq -c '
    first(
        recurse((.nodes[]?, .floating_nodes[]?))
        | select(
            .focused == true and
            (.type == "con" or .type == "floating_con")
        )
    ) // empty
' <<< "$TREE")


if [[ -z "$WINDOW" ]]; then
    echo "No focused window found" >&2
    exit 1
fi

ID=$(jq -r '.id' <<< "$WINDOW")
FLOATING=$(jq -r '.floating // "auto_off"' <<< "$WINDOW")

# Find the immediate tiled parent.
PARENT=$(jq -c --argjson id "$ID" '
    first(
        recurse((.nodes[]?, .floating_nodes[]?))
        | select(
            [.nodes[]?.id] | index($id)
        )
    ) // empty
' <<< "$TREE")

# ------------------------------------------------------------
# Equal spacing (tiled only)
# ------------------------------------------------------------

if [[ "$MODE" == "equal" ]]; then

    if [[ "$FLOATING" == "user_on" ||
          "$FLOATING" == "auto_on" ]]; then
        echo "Equal spacing requires a tiled window" >&2
        exit 1
    fi

    LAYOUT=$(jq -r '.layout // ""' <<< "$PARENT")

    if [[ "$LAYOUT" != "splith" ]]; then
        echo "Requires a horizontal split" >&2
        exit 1
    fi

    COUNT=$(jq '.nodes | length' <<< "$PARENT")

    if (( COUNT < 2 )); then
        exit 0
    fi

    TOTAL=$(jq '[.nodes[].rect.width] | add' <<< "$PARENT")
    TARGET=$(( TOTAL / COUNT ))

    while read -r SIBLING; do
        swaymsg -q \
            "[con_id=$SIBLING] resize set width $TARGET px"
    done < <(jq -r '.nodes[].id' <<< "$PARENT")

    exit 0
fi

# ------------------------------------------------------------
# Read application geometry
# ------------------------------------------------------------

CURRENT_WIDTH=$(jq -r '.rect.width' <<< "$WINDOW")
CURRENT_HEIGHT=$(jq -r '.rect.height' <<< "$WINDOW")

CONTENT_WIDTH=$(jq -r '.window_rect.width' <<< "$WINDOW")
CONTENT_HEIGHT=$(jq -r '.window_rect.height' <<< "$WINDOW")

# Borders and titlebar overhead.
EXTRA_WIDTH=$(( CURRENT_WIDTH - CONTENT_WIDTH ))
EXTRA_HEIGHT=$(( CURRENT_HEIGHT - CONTENT_HEIGHT ))

# ------------------------------------------------------------
# Floating windows
# ------------------------------------------------------------

if [[ "$FLOATING" == "user_on" ||
      "$FLOATING" == "auto_on" ]]; then

    # Get current workspace dimensions.
    WORKSPACE=$(swaymsg -t get_workspaces -r |
        jq -c 'first(.[] | select(.focused == true))')

    OW=$(jq -r '.rect.width' <<< "$WORKSPACE")
    OH=$(jq -r '.rect.height' <<< "$WORKSPACE")

    # Leave room around the floating window.
    MAX_WIDTH=$(( OW - EXTRA_WIDTH ))
    MAX_HEIGHT=$(( OH - EXTRA_HEIGHT ))

    # Fill the available workspace height.
    HEIGHT=$(( OH - EXTRA_HEIGHT ))
    WIDTH=$(( HEIGHT * NUM / DEN ))

    # Restrict width to available space.
    if (( WIDTH > MAX_WIDTH )); then
        WIDTH=$MAX_WIDTH
        HEIGHT=$(( WIDTH * DEN / NUM ))
    fi

    # Restrict height if necessary.
    if (( HEIGHT > MAX_HEIGHT )); then
        HEIGHT=$MAX_HEIGHT
        WIDTH=$(( HEIGHT * NUM / DEN ))
    fi

    if (( WIDTH < 1 || HEIGHT < 1 )); then
        echo "Workspace too small" >&2
        exit 1
    fi

    # Convert content dimensions back to window dimensions.
    WIDTH=$(( WIDTH + EXTRA_WIDTH ))
    HEIGHT=$(( HEIGHT + EXTRA_HEIGHT ))

    # Resize floating window.
    swaymsg -q \
        "[con_id=$ID] resize set width $WIDTH px height $HEIGHT px"

    # Center floating window.
    swaymsg -q \
        "[con_id=$ID] move position center"

    exit 0
fi

# ------------------------------------------------------------
# Tiled windows
# ------------------------------------------------------------

LAYOUT=$(jq -r '.layout // ""' <<< "$PARENT")

if [[ "$LAYOUT" != "splith" ]]; then
    echo "Aspect preset requires horizontal split" >&2
    exit 1
fi

# Calculate width using actual application height.
HEIGHT=$CONTENT_HEIGHT
TARGET_CONTENT_WIDTH=$(( HEIGHT * NUM / DEN ))

# Add border overhead.
WIDTH=$(( TARGET_CONTENT_WIDTH + EXTRA_WIDTH ))

# Leave space for neighboring tiled windows.
PARENT_WIDTH=$(jq -r '.rect.width' <<< "$PARENT")
MAX_WIDTH=$(( PARENT_WIDTH * 85 / 100 ))

if (( WIDTH > MAX_WIDTH )); then
    WIDTH=$MAX_WIDTH
fi

if (( WIDTH < 1 )); then
    echo "Invalid target width" >&2
    exit 1
fi

# Resize tiled column.
swaymsg -q \
    "[con_id=$ID] resize set width $WIDTH px"
