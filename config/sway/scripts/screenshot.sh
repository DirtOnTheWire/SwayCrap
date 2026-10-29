#!/usr/bin/env bash
set -euo pipefail

mode="${1:-}"
tmp="$(mktemp --suffix=.png)"

cleanup() {
  rm -f "$tmp"
}
trap cleanup EXIT

edit_with_swappy() {
  local src="$1"
  swappy -f "$src"
}

case "$mode" in
  area)
    geom="$(slurp || true)"
    [[ -n "$geom" ]] || exit 0

    sleep 2
    grim -g "$geom" "$tmp"
    edit_with_swappy "$tmp"
    ;;

  window)
    geom="$(
      swaymsg -t get_tree | jq -r '
        recurse(.nodes[]?, .floating_nodes[]?)
        | select(.focused?)
        | .rect
        | "\(.x),\(.y) \(.width)x\(.height)"
      '
    )"

    [[ -n "$geom" && "$geom" != "null" ]] || exit 0

    sleep 2
    grim -g "$geom" "$tmp"
    edit_with_swappy "$tmp"
    ;;

  screen)
    output="$(
      swaymsg -t get_outputs |
        jq -r '.[] | select(.focused) | .name'
    )"

    [[ -n "$output" && "$output" != "null" ]] || exit 0

    sleep 2
    grim -o "$output" "$tmp"
    edit_with_swappy "$tmp"
    ;;

  *)
    echo "Usage: $0 {area|window|screen}" >&2
    exit 1
    ;;
esac