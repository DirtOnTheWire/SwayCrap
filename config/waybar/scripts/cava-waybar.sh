#!/usr/bin/env bash

blocks=("▁" "▂" "▃" "▄" "▅" "▆" "▇" "█")

cava -p "$HOME/.config/waybar/cava-waybar.conf" |
while read -r -a values; do
    output=""

    for value in "${values[@]}"; do
        [[ "$value" =~ ^[0-7]$ ]] || {
            output=""
            break
        }

        output+="${blocks[$value]}"
    done

    [[ -n "$output" ]] && printf '%s\n' "$output"
done