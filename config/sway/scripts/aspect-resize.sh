
#!/usr/bin/env bash

# SwayCrap Aspect Ratio Resize
#
# 16:9  - Resize focused window to widescreen
# 4:3   - Resize focused window to classic ratio
# equal - Equalize horizontal sibling containers
#
# Floating windows: resize width + height, center.
# Tiled windows: resize column width only.

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

# Read the Sway layout tree.
TREE=$(swaymsg -t get_tree)

# Find the currently focused window.
WINDOW=$(jq -c '
    [
        recurse(.nodes[]?, .floating_nodes[]?)
        | select(.focused == true and .type == "con")
    ] | first // empty
' <<< "$TREE")

if [[ -z "$WINDOW" ]]; then
    echo "No focused window found" >&2
    exit 1
fi

ID=$(jq -r '.id' <<< "$WINDOW")
FLOATING=$(jq -r '.floating' <<< "$WINDOW")

# Find the immediate parent container.
PARENT=$(jq -c --argjson id "$ID" '
    [
        recurse(.nodes[]?, .floating_nodes[]?)
        | select(
            .nodes? and
            ([.nodes[].id] | index($id))
        )
    ] | last // empty
' <<< "$TREE")

# ------------------------------------------------------------
# Equal spacing
# ------------------------------------------------------------

if [[ "$MODE" == "equal" ]]; then
    # Floating windows cannot share tiled columns.
    if [[ "$FLOATING" != "user_off" &&
          "$FLOATING" != "auto_off" ]]; then
        echo "Equal spacing requires a tiled window" >&2
        exit 1
    fi

    # Only equalize siblings in a horizontal split.
    LAYOUT=$(jq -r '.layout // ""' <<< "$PARENT")

    if [[ "$LAYOUT" != "splith" ]]; then
        echo "Focused window is not in a horizontal split" >&2
        exit 1
    fi

    COUNT=$(jq '.nodes | length' <<< "$PARENT")

    if (( COUNT < 2 )); then
        exit 0
    fi

    # Average the existing column widths.
    TOTAL=$(jq '
        [.nodes[].rect.width] | add
    ' <<< "$PARENT")

    TARGET=$(( TOTAL / COUNT ))

    # Adjust each sibling without changing focus.
    while read -r SIBLING; do
        swaymsg -q \
            "[con_id=$SIBLING] resize set width $TARGET px"
    done < <(jq -r '.nodes[].id' <<< "$PARENT")

    exit 0
fi

# ------------------------------------------------------------
# Floating window
# ------------------------------------------------------------

if [[ "$FLOATING" == "user_on" ||
      "$FLOATING" == "auto_on" ]]; then

    # Get the dimensions of the focused workspace.
    WORKSPACE=$(swaymsg -t get_workspaces |
        jq -c '.[] | select(.focused == true)')

    OW=$(jq -r '.rect.width' <<< "$WORKSPACE")
    OH=$(jq -r '.rect.height' <<< "$WORKSPACE")

    # Start at 80% of the available screen height.
    HEIGHT=$(( OH * 80 / 100 ))
    WIDTH=$(( HEIGHT * NUM / DEN ))

    # Avoid excessive width on narrower screens.
    MAX_WIDTH=$(( OW * 85 / 100 ))

    if (( WIDTH > MAX_WIDTH )); then
        WIDTH=$MAX_WIDTH
        HEIGHT=$(( WIDTH * DEN / NUM ))
    fi

    # Resize and center the floating window.
    swaymsg -q \
        "[con_id=$ID] resize set width $WIDTH px height $HEIGHT px"

    swaymsg -q \
        "[con_id=$ID] move position center"

    exit 0
fi

# ------------------------------------------------------------
# Tiled window
# ------------------------------------------------------------

# Aspect presets work on horizontal tiled columns.
LAYOUT=$(jq -r '.layout // ""' <<< "$PARENT")

if [[ "$LAYOUT" != "splith" ]]; then
    echo "Aspect preset requires a horizontal split" >&2
    exit 1
fi


# Use actual application content height
HEIGHT=$(jq -r '.window_rect.height' <<< "$WINDOW")

# Calculate desired application content width
CONTENT_WIDTH=$(( HEIGHT * NUM / DEN ))

# Account for borders and decorations
CURRENT_WIDTH=$(jq -r '.rect.width' <<< "$WINDOW")
CURRENT_CONTENT_WIDTH=$(jq -r '.window_rect.width' <<< "$WINDOW")

WIDTH=$(( CONTENT_WIDTH + CURRENT_WIDTH - CURRENT_CONTENT_WIDTH ))

# Reserve room for neighboring columns
PARENT_WIDTH=$(jq -r '.rect.width' <<< "$PARENT")
MAX_WIDTH=$(( PARENT_WIDTH * 85 / 100 ))

if (( WIDTH > MAX_WIDTH )); then
    WIDTH=$MAX_WIDTH
fi

# Resize the focused tiled column
swaymsg -q \
    "[con_id=$ID] resize set width $WIDTH px"


