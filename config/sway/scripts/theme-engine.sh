#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# THE ONLY PLACE YOU EDIT THEMES
# Profiles: dark-red, light-red, dark-green, light-green, dark-blue, light-blue
###############################################################################

# Common settings
MAKE_BACKUPS=0
WRITE_TERMINAL_COLORS=0  # 1=write Foot and XFCE Terminal colors; 0=leave them alone
WRITE_EDITOR_COLORS=0    # 1=write Mousepad and Pluma colors; 0=leave them alone
FONT_NAME="Noto Sans 10"
CURSOR_THEME="Adwaita"
CURSOR_SIZE="24"


# Profile-specific mappings
# For each profile, set: GTK_THEME, ICON_THEME, and a small Sway palette
profile_vars() {
  local p="${1:?profile required}"

  # Terminal defaults.
  # Shifts are rotations from C_ACCENT in degrees.
  TERM_RED_SHIFT=-28
  TERM_GREEN_SHIFT=0
  TERM_YELLOW_SHIFT=48
  TERM_BLUE_SHIFT=0
  TERM_MAGENTA_SHIFT=-48
  TERM_CYAN_SHIFT=75

  TERM_RED_SAT=0.54
  TERM_GREEN_SAT=0.46
  TERM_YELLOW_SAT=0.58
  TERM_BLUE_SAT=0.30
  TERM_MAGENTA_SAT=0.36
  TERM_CYAN_SAT=0.70

  TERM_RED_LIGHT=0.38
  TERM_GREEN_LIGHT=0.58
  TERM_YELLOW_LIGHT=0.62
  TERM_BLUE_LIGHT=0.38
  TERM_MAGENTA_LIGHT=0.60
  TERM_CYAN_LIGHT=0.60

  TERM_BRIGHT_RED_SAT=0.64
  TERM_BRIGHT_GREEN_SAT=0.58
  TERM_BRIGHT_YELLOW_SAT=0.68
  TERM_BRIGHT_BLUE_SAT=0.52
  TERM_BRIGHT_MAGENTA_SAT=0.48
  TERM_BRIGHT_CYAN_SAT=0.85

  TERM_BRIGHT_RED_LIGHT=0.46
  TERM_BRIGHT_GREEN_LIGHT=0.68
  TERM_BRIGHT_YELLOW_LIGHT=0.72
  TERM_BRIGHT_BLUE_LIGHT=0.52
  TERM_BRIGHT_MAGENTA_LIGHT=0.70
  TERM_BRIGHT_CYAN_LIGHT=0.70

  case "$p" in

    # RED
    dark-red)
      GTK_THEME="Mint-Y-Dark-Red"
      ICON_THEME="Mint-Y-Red"
      C_BG="#111318"; C_FG="#e6e6e6"; C_DIM="#6b7280"; C_ACCENT="#ef4444"; C_URGENT="#fb7185"
      ;;
    light-red)
      GTK_THEME="Mint-Y-Red"
      ICON_THEME="Mint-Y-Red"
      C_BG="#f6f7fb"; C_FG="#111827"; C_DIM="#9ca3af"; C_ACCENT="#dc2626"; C_URGENT="#e11d48"

      # Custom cyan/pop color for light red
      TERM_CYAN_SHIFT=0
      TERM_CYAN_SAT=0.70
      TERM_CYAN_LIGHT=0.60
      TERM_BRIGHT_CYAN_SAT=0.85
      TERM_BRIGHT_CYAN_LIGHT=0.70
      ;;

    # GREEN
    dark-green)
      GTK_THEME="Mint-Y-Dark"
      ICON_THEME="Mint-Y"
      C_BG="#0f1411"; C_FG="#e6e6e6"; C_DIM="#6b7280"; C_ACCENT="#22c55e"; C_URGENT="#fb7185"
      ;;
    light-green)
      GTK_THEME="Mint-Y"
      ICON_THEME="Mint-Y"
      C_BG="#f6f7fb"; C_FG="#111827"; C_DIM="#9ca3af"; C_ACCENT="#16a34a"; C_URGENT="#e11d48"
      ;;

    # BLUE
    dark-blue)
      GTK_THEME="Mint-Y-Dark-Blue"
      ICON_THEME="Mint-Y-Blue"
      C_BG="#0f111a"; C_FG="#e6e6e6"; C_DIM="#6b7280"; C_ACCENT="#3b82f6"; C_URGENT="#fb7185"
      ;;
    light-blue)
      GTK_THEME="Mint-Y-Blue"
      ICON_THEME="Mint-Y-Blue"
      C_BG="#f6f7fb"; C_FG="#111827"; C_DIM="#9ca3af"; C_ACCENT="#2563eb"; C_URGENT="#e11d48"
      ;;

    # AQUA
    dark-aqua)
      GTK_THEME="Mint-Y-Dark-Aqua"
      ICON_THEME="Mint-Y-Aqua"
      C_BG="#101719"; C_FG="#e6eeee"; C_DIM="#71858a"; C_ACCENT="#20b8b8"; C_URGENT="#fb7185"
      ;;
    light-aqua)
      GTK_THEME="Mint-Y-Aqua"
      ICON_THEME="Mint-Y-Aqua"
      C_BG="#f4fafb"; C_FG="#17282b"; C_DIM="#82989b"; C_ACCENT="#159999"; C_URGENT="#e11d48"
      ;;

    # TEAL
    dark-teal)
      GTK_THEME="Mint-Y-Dark-Teal"
      ICON_THEME="Mint-Y-Teal"
      C_BG="#101715"; C_FG="#e6eeee"; C_DIM="#718680"; C_ACCENT="#16a085"; C_URGENT="#fb7185"
      ;;
    light-teal)
      GTK_THEME="Mint-Y-Teal"
      ICON_THEME="Mint-Y-Teal"
      C_BG="#f4f9f7"; C_FG="#182b27"; C_DIM="#869c94"; C_ACCENT="#138a72"; C_URGENT="#e11d48"
      ;;

    # PURPLE
    dark-purple)
      GTK_THEME="Mint-Y-Dark-Purple"
      ICON_THEME="Mint-Y-Purple"
      C_BG="#15121a"; C_FG="#eae6ee"; C_DIM="#81758d"; C_ACCENT="#a855f7"; C_URGENT="#fb7185"
      ;;
    light-purple)
      GTK_THEME="Mint-Y-Purple"
      ICON_THEME="Mint-Y-Purple"
      C_BG="#f9f6fc"; C_FG="#241b30"; C_DIM="#a096ac"; C_ACCENT="#9333ea"; C_URGENT="#e11d48"
      ;;

    # PINK
    dark-pink)
      GTK_THEME="Mint-Y-Dark-Pink"
      ICON_THEME="Mint-Y-Pink"
      C_BG="#191218"; C_FG="#eee6ec"; C_DIM="#917886"; C_ACCENT="#ec4899"; C_URGENT="#fb7185"
      ;;
    light-pink)
      GTK_THEME="Mint-Y-Pink"
      ICON_THEME="Mint-Y-Pink"
      C_BG="#fcf6fa"; C_FG="#301b29"; C_DIM="#aa96a3"; C_ACCENT="#db2777"; C_URGENT="#e11d48"
      ;;

    # ORANGE
    dark-orange)
      GTK_THEME="Mint-Y-Dark-Orange"
      ICON_THEME="Mint-Y-Orange"
      C_BG="#191510"; C_FG="#eee9e2"; C_DIM="#91816e"; C_ACCENT="#f97316"; C_URGENT="#fb7185"
      ;;
    light-orange)
      GTK_THEME="Mint-Y-Orange"
      ICON_THEME="Mint-Y-Orange"
      C_BG="#fcf9f4"; C_FG="#2b2118"; C_DIM="#a99b89"; C_ACCENT="#ea580c"; C_URGENT="#e11d48"
      ;;

    # YELLOW
    dark-yellow)
      GTK_THEME="Mint-Y-Dark-Yellow"
      ICON_THEME="Mint-Y-Yellow"
      C_BG="#181710"; C_FG="#eeeddf"; C_DIM="#8f8b73"; C_ACCENT="#eab308"; C_URGENT="#fb7185"
      ;;
    light-yellow)
      GTK_THEME="Mint-Y-Yellow"
      ICON_THEME="Mint-Y-Yellow"
      C_BG="#fbfaf2"; C_FG="#292719"; C_DIM="#a5a18b"; C_ACCENT="#b8860b"; C_URGENT="#e11d48"
      ;;

    # BROWN
    dark-brown)
      GTK_THEME="Mint-Y-Dark-Brown"
      ICON_THEME="Mint-Y-Brown"
      C_BG="#171410"; C_FG="#eae6e0"; C_DIM="#88796c"; C_ACCENT="#a97852"; C_URGENT="#fb7185"
      ;;
    light-brown)
      GTK_THEME="Mint-Y-Brown"
      ICON_THEME="Mint-Y-Brown"
      C_BG="#faf7f3"; C_FG="#2c241e"; C_DIM="#a3978d"; C_ACCENT="#926544"; C_URGENT="#e11d48"
      ;;

    # GREY
    dark-grey)
      GTK_THEME="Mint-Y-Dark-Grey"
      ICON_THEME="Mint-Y-Grey"
      C_BG="#151619"; C_FG="#e6e7e9"; C_DIM="#797f88"; C_ACCENT="#8b949e"; C_URGENT="#fb7185"
      ;;
    light-grey)
      GTK_THEME="Mint-Y-Grey"
      ICON_THEME="Mint-Y-Grey"
      C_BG="#f6f7f8"; C_FG="#20242a"; C_DIM="#969ba3"; C_ACCENT="#687582"; C_URGENT="#e11d48"
      ;;

    # SAND
    dark-sand)
      GTK_THEME="Mint-Y-Dark-Sand"
      ICON_THEME="Mint-Y-Sand"
      C_BG="#171611"; C_FG="#edeae2"; C_DIM="#8c8778"; C_ACCENT="#c5a46d"; C_URGENT="#fb7185"
      ;;
    light-sand)
      GTK_THEME="Mint-Y-Sand"
      ICON_THEME="Mint-Y-Sand"
      C_BG="#faf8f3"; C_FG="#29251e"; C_DIM="#a49d8d"; C_ACCENT="#a88651"; C_URGENT="#e11d48"
      ;;

    *)
      echo "Unknown profile: $p" >&2
      exit 1
      ;;
  esac
}

###############################################################################
# Paths / state
###############################################################################

GTK3_FILE="$HOME/.config/gtk-3.0/settings.ini"
GTK4_FILE="$HOME/.config/gtk-4.0/settings.ini"
GTK2_FILE="$HOME/.gtkrc-2.0"

SWAY_THEME_DIR="$HOME/.config/sway/themes"
SWAY_THEME_FILE="$SWAY_THEME_DIR/current.conf"

POLYBAR_DIR="$HOME/.config/polybar"
POLYBAR_COLORS="$POLYBAR_DIR/colors.ini"

STATE_DIR="$HOME/.config/sway/theme-engine"
STATE_FILE="$STATE_DIR/current_profile"

FOOT_DIR="$HOME/.config/foot"
FOOT_FILE="$FOOT_DIR/foot.ini"

XFCE_TERM_SCHEME_DIR="$HOME/.local/share/xfce4/terminal/colorschemes"
XFCE_TERM_SCHEME_FILE="$XFCE_TERM_SCHEME_DIR/theme-engine.theme"

###############################################################################
# Helpers
###############################################################################

nohash() { printf "%s\n" "${1#\#}"; }

ensure_dir() { mkdir -p -- "$1"; }

backup_if_exists() {
  local f="$1"

  (( MAKE_BACKUPS == 1 )) || return 0
  [[ -f "$f" ]] || return 0
  [[ -f "$f.bak" ]] && return 0

  cp -a -- "$f" "$f.bak" || true
}

write_file() {
  local path="$1"
  local content="$2"
  ensure_dir "$(dirname "$path")"
  backup_if_exists "$path"
  printf '%s\n' "$content" > "$path"
}

have_cmd() { command -v "$1" >/dev/null 2>&1; }

current_profile() {
  [[ -f "$STATE_FILE" ]] && cat "$STATE_FILE" || echo "dark-blue"
}

set_current_profile() {
  ensure_dir "$STATE_DIR"
  echo "$1" >"$STATE_FILE"
}

hex_to_rgb() {
  local h="${1#\#}"
  printf "%d %d %d\n" "0x${h:0:2}" "0x${h:2:2}" "0x${h:4:2}"
}

rgb_to_hex() {
  printf "#%02x%02x%02x\n" "$1" "$2" "$3"
}

clamp() {
  local v="$1"
  ((v<0)) && v=0
  ((v>255)) && v=255
  echo "$v"
}

mix_hex() {
  # mix_hex A B t(0-100) => 0=A, 100=B
  local a="$1" b="$2" t="$3"
  read -r ar ag ab < <(hex_to_rgb "$a")
  read -r br bg bb < <(hex_to_rgb "$b")
  local r g bl
  r=$(( (ar*(100-t) + br*t) / 100 ))
  g=$(( (ag*(100-t) + bg*t) / 100 ))
  bl=$(( (ab*(100-t) + bb*t) / 100 ))
  rgb_to_hex "$(clamp "$r")" "$(clamp "$g")" "$(clamp "$bl")"
}

hsl_color() {
  # Usage: hsl_color "#ef4444" 0 0.55 0.62
  # args: base_hex, hue_rotation_degrees, saturation, lightness

  python3 - "$1" "$2" "$3" "$4" <<'PY'
import sys, colorsys

hex_color = sys.argv[1].lstrip("#")
rotate = float(sys.argv[2])
sat = float(sys.argv[3])
light = float(sys.argv[4])

r = int(hex_color[0:2], 16) / 255.0
g = int(hex_color[2:4], 16) / 255.0
b = int(hex_color[4:6], 16) / 255.0

h, l, s = colorsys.rgb_to_hls(r, g, b)

h = (h + rotate / 360.0) % 1.0

r, g, b = colorsys.hls_to_rgb(h, light, sat)

print(f"{round(r * 255):02x}{round(g * 255):02x}{round(b * 255):02x}")
PY
}

###############################################################################
# Applyers
###############################################################################

apply_gtk() {
  write_file "$GTK3_FILE" \
"[Settings]
gtk-theme-name=${GTK_THEME}
gtk-icon-theme-name=${ICON_THEME}
gtk-cursor-theme-name=${CURSOR_THEME}
gtk-cursor-theme-size=${CURSOR_SIZE}
gtk-font-name=${FONT_NAME}
"

  write_file "$GTK4_FILE" \
"[Settings]
gtk-theme-name=${GTK_THEME}
gtk-icon-theme-name=${ICON_THEME}
gtk-cursor-theme-name=${CURSOR_THEME}
gtk-cursor-theme-size=${CURSOR_SIZE}
gtk-font-name=${FONT_NAME}
"

  write_file "$GTK2_FILE" \
"gtk-theme-name=\"${GTK_THEME}\"
gtk-icon-theme-name=\"${ICON_THEME}\"
gtk-font-name=\"${FONT_NAME}\"
gtk-cursor-theme-name=\"${CURSOR_THEME}\"
gtk-cursor-theme-size=${CURSOR_SIZE}
"
}

derive_sway_palette() {
  SWAY_BACKGROUND="$C_BG"
  SWAY_TEXT="$C_FG"

  local N1 N2 N3 N4 N5 N6 N7
  N1="$(mix_hex "$C_BG" "$C_FG" 6)"
  N2="$(mix_hex "$C_BG" "$C_FG" 10)"
  N3="$(mix_hex "$C_BG" "$C_FG" 16)"
  N4="$(mix_hex "$C_BG" "$C_FG" 24)"
  N5="$(mix_hex "$C_BG" "$C_FG" 34)"
  N6="$(mix_hex "$C_BG" "$C_FG" 48)"
  N7="$(mix_hex "$C_BG" "$C_FG" 62)"

  SWAY_SEPARATOR="$(mix_hex "$C_DIM" "$C_FG" 25)"

  local ACC="$C_ACCENT"
  local URG="$C_URGENT"

  SWAY_1="$C_FG"
  SWAY_2="$N5"
  SWAY_3="$N2"
  SWAY_4="$ACC"
  SWAY_5="$N7"
  SWAY_6="$N6"
  SWAY_7="$URG"
  SWAY_8="$N4"
  SWAY_9="$N3"
  SWAY_10="$N5"
  SWAY_11="$C_FG"
  SWAY_12="$(mix_hex "$ACC" "$C_BG" 12)"
  SWAY_13="$(mix_hex "$URG" "$C_BG" 0)"
  SWAY_14="$(mix_hex "$ACC" "$C_FG" 10)"
  SWAY_15="#000000"
  SWAY_16="#ffffff"
  SWAY_17="$(mix_hex "$C_BG" "#000000" 12)"

  BAR_BG="$(mix_hex "$C_BG" "$C_FG" 8)"
  BAR_SEP="$(mix_hex "$C_BG" "$C_FG" 45)"
  BAR_BORDER="$(mix_hex "$C_BG" "$C_FG" 45)"

  BAR_FOCUS_BG="$(mix_hex "$C_BG" "$C_ACCENT" 14)"
  BAR_ACTIVE_BG="$(mix_hex "$C_BG" "$C_FG" 10)"
  BAR_INACTIVE_BG="$(mix_hex "$C_BG" "$C_FG" 6)"

  BAR_TEXT="$C_FG"
  BAR_URGENT_BG="$(mix_hex "$C_BG" "$C_URGENT" 10)"
}

derive_newt_palette() {
  export NEWT_COLORS="
  root=white,black
  window=black,white
  border=green,white
  title=cyan,white
  textbox=black,white
  button=black,white
  actbutton=white,green
  listbox=black,white
  actlistbox=white,cyan
  shadow=black,black
  "
}

derive_polybar_palette() {
  PB_BG="$C_BG"
  PB_FG="$C_FG"
  PB_ACCENT="$C_ACCENT"
  PB_ACCENT_SOFT="$(mix_hex "$C_ACCENT" "$C_BG" 35)"
  PB_URGENT="$C_URGENT"
  PB_BG_ALT="$(mix_hex "$C_BG" "$C_FG" 8)"
  PB_DIM="$(mix_hex "$C_DIM" "$C_FG" 10)"
  PB_BORDER="$(mix_hex "$C_BG" "$C_FG" 22)"
}

is_light_hex() {
  local h="${1#\#}"
  local r=$((16#${h:0:2}))
  local g=$((16#${h:2:2}))
  local b=$((16#${h:4:2}))
  local y=$(( (299*r + 587*g + 114*b) / 1000 ))

  (( y > 150 ))
}

derive_terminal_black() {
  if is_light_hex "$C_BG"; then
    local bright_tinted bright_lifted

    TERM_BLACK="$(nohash "$(mix_hex "$C_FG" "$C_BG" 8)")"

    bright_tinted="$(mix_hex "$C_BG" "$C_ACCENT" 18)"
    bright_lifted="$(mix_hex "$bright_tinted" "$C_FG" 8)"
    TERM_BRIGHT_BLACK="$(nohash "$bright_lifted")"
  else
    local bright_tinted bright_lifted

    TERM_BLACK="$(nohash "$(mix_hex "$C_BG" "$C_FG" 8)")"

    bright_tinted="$(mix_hex "$C_BG" "$C_ACCENT" 28)"
    bright_lifted="$(mix_hex "$bright_tinted" "$C_FG" 10)"
    TERM_BRIGHT_BLACK="$(nohash "$bright_lifted")"
  fi
}

derive_terminal_palette() {
  TERM_BG="$(nohash "$C_BG")"
  TERM_FG="$(nohash "$(mix_hex "$C_FG" "$C_ACCENT" 8)")"
  TERM_DIM="$(nohash "$C_DIM")"
  TERM_ACCENT="$(nohash "$C_ACCENT")"
  TERM_ACCENT_SOFT="$(mix_hex "$TERM_ACCENT" "$TERM_BG" 35)"
  TERM_URGENT="$(nohash "$C_URGENT")"

  derive_terminal_black

  TERM_WHITE="$(hsl_color "$C_ACCENT" 0 0.12 0.78)"
  TERM_BRIGHT_WHITE="$(hsl_color "$C_ACCENT" 0 0.16 0.88)"

  TERM_RED="$(hsl_color "$C_ACCENT" "$TERM_RED_SHIFT" "$TERM_RED_SAT" "$TERM_RED_LIGHT")"
  TERM_GREEN="$(hsl_color "$C_ACCENT" "$TERM_GREEN_SHIFT" "$TERM_GREEN_SAT" "$TERM_GREEN_LIGHT")"
  TERM_YELLOW="$(hsl_color "$C_ACCENT" "$TERM_YELLOW_SHIFT" "$TERM_YELLOW_SAT" "$TERM_YELLOW_LIGHT")"
  TERM_BLUE="$(hsl_color "$C_ACCENT" "$TERM_BLUE_SHIFT" "$TERM_BLUE_SAT" "$TERM_BLUE_LIGHT")"
  TERM_MAGENTA="$(hsl_color "$C_ACCENT" "$TERM_MAGENTA_SHIFT" "$TERM_MAGENTA_SAT" "$TERM_MAGENTA_LIGHT")"
  TERM_CYAN="$(hsl_color "$C_ACCENT" "$TERM_CYAN_SHIFT" "$TERM_CYAN_SAT" "$TERM_CYAN_LIGHT")"

  TERM_BRIGHT_RED="$(hsl_color "$C_ACCENT" "$TERM_RED_SHIFT" "$TERM_BRIGHT_RED_SAT" "$TERM_BRIGHT_RED_LIGHT")"
  TERM_BRIGHT_GREEN="$(hsl_color "$C_ACCENT" "$TERM_GREEN_SHIFT" "$TERM_BRIGHT_GREEN_SAT" "$TERM_BRIGHT_GREEN_LIGHT")"
  TERM_BRIGHT_YELLOW="$(hsl_color "$C_ACCENT" "$TERM_YELLOW_SHIFT" "$TERM_BRIGHT_YELLOW_SAT" "$TERM_BRIGHT_YELLOW_LIGHT")"
  TERM_BRIGHT_BLUE="$(hsl_color "$C_ACCENT" "$TERM_BLUE_SHIFT" "$TERM_BRIGHT_BLUE_SAT" "$TERM_BRIGHT_BLUE_LIGHT")"
  TERM_BRIGHT_MAGENTA="$(hsl_color "$C_ACCENT" "$TERM_MAGENTA_SHIFT" "$TERM_BRIGHT_MAGENTA_SAT" "$TERM_BRIGHT_MAGENTA_LIGHT")"
  TERM_BRIGHT_CYAN="$(hsl_color "$C_ACCENT" "$TERM_CYAN_SHIFT" "$TERM_BRIGHT_CYAN_SAT" "$TERM_BRIGHT_CYAN_LIGHT")"
}

apply_foot() {
  ensure_dir "$FOOT_DIR"
  backup_if_exists "$FOOT_FILE"

  cat >"$FOOT_FILE" <<EOF
# Autogenerated by theme-engine.sh

[main]
font=monospace:size=10
initial-color-theme=1

[colors]
background=${TERM_BG}
foreground=${TERM_FG}
alpha=1.0

# normal
regular0=${TERM_BLACK}
regular1=${TERM_RED}
regular2=${TERM_GREEN}
regular3=${TERM_YELLOW}
regular4=${TERM_BLUE}
regular5=${TERM_MAGENTA}
regular6=${TERM_CYAN}
regular7=${TERM_WHITE}

# bright
bright0=${TERM_BRIGHT_BLACK}
bright1=${TERM_BRIGHT_RED}
bright2=${TERM_BRIGHT_GREEN}
bright3=${TERM_BRIGHT_YELLOW}
bright4=${TERM_BRIGHT_BLUE}
bright5=${TERM_BRIGHT_MAGENTA}
bright6=${TERM_BRIGHT_CYAN}
bright7=${TERM_BRIGHT_WHITE}

selection-foreground=${TERM_BG}
selection-background=${TERM_ACCENT}
urls=${TERM_ACCENT}
cursor=${TERM_BG} ${TERM_ACCENT}
EOF
}

apply_xfce_terminal() {
  ensure_dir "$XFCE_TERM_SCHEME_DIR"
  backup_if_exists "$XFCE_TERM_SCHEME_FILE"

  cat >"$XFCE_TERM_SCHEME_FILE" <<EOF
[Scheme]
Name=Theme Engine
ColorForeground=#${TERM_WHITE}
ColorBackground=#${TERM_BG}
ColorCursor=#${TERM_ACCENT}
ColorPalette=#${TERM_BLACK};#${TERM_RED};#${TERM_GREEN};#${TERM_YELLOW};#${TERM_BLUE};#${TERM_MAGENTA};#${TERM_CYAN};#${TERM_WHITE};#${TERM_BRIGHT_BLACK};#${TERM_BRIGHT_RED};#${TERM_BRIGHT_GREEN};#${TERM_BRIGHT_YELLOW};#${TERM_BRIGHT_BLUE};#${TERM_BRIGHT_MAGENTA};#${TERM_BRIGHT_CYAN};#${TERM_BRIGHT_WHITE}
EOF
}

apply_mousepad_style() {
  local MOUSEPAD_STYLE_DIR MOUSEPAD_STYLE_FILE
  local EDITOR_CYAN EDITOR_CYAN_BRIGHT

  EDITOR_CYAN="#$(hsl_color "$C_ACCENT" "$TERM_CYAN_SHIFT" "$TERM_CYAN_SAT" "$TERM_CYAN_LIGHT")"
  EDITOR_CYAN_BRIGHT="#$(hsl_color "$C_ACCENT" "$TERM_CYAN_SHIFT" "$TERM_BRIGHT_CYAN_SAT" "$TERM_BRIGHT_CYAN_LIGHT")"

  MOUSEPAD_STYLE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/gtksourceview-4/styles"
  MOUSEPAD_STYLE_FILE="$MOUSEPAD_STYLE_DIR/theme-engine.xml"

  ensure_dir "$MOUSEPAD_STYLE_DIR"

  cat > "$MOUSEPAD_STYLE_FILE" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<style-scheme id="theme-engine" name="Theme Engine" version="1.0" xmlns="http://gtksourceview.org/language-specs">
  <author>theme-engine.sh</author>
  <description>Generated Mousepad theme</description>

  <style name="text" foreground="${C_FG}" background="${C_BG}"/>
  <style name="selection" foreground="${C_BG}" background="${C_ACCENT}"/>
  <style name="current-line" background="$(mix_hex "$C_BG" "$C_FG" 8)"/>
  <style name="line-numbers" foreground="${C_DIM}" background="${C_BG}"/>
  <style name="current-line-number" foreground="${C_FG}" background="$(mix_hex "$C_BG" "$C_FG" 8)"/>
  <style name="right-margin" foreground="${C_DIM}" background="${C_BG}"/>
  <style name="bracket-match" foreground="${C_BG}" background="${C_ACCENT}"/>
  <style name="bracket-mismatch" foreground="${C_BG}" background="${C_URGENT}"/>

  <style name="def:comment" foreground="$(mix_hex "$C_DIM" "$C_ACCENT" 18)" italic="true"/>
  <style name="def:string" foreground="$(mix_hex "$C_ACCENT" "$C_FG" 35)"/>
  <style name="def:keyword" foreground="${C_ACCENT}" bold="true"/>
  <style name="def:number" foreground="#$(hsl_color "$C_ACCENT" 48 0.55 0.62)"/>
  <style name="def:function" foreground="#$(hsl_color "$C_ACCENT" -48 0.45 0.62)"/>
  <style name="def:type" foreground="#$(hsl_color "$C_ACCENT" -48 0.45 0.62)"/>
  <style name="def:preprocessor" foreground="${C_ACCENT}"/>
  <style name="def:error" foreground="${C_URGENT}" underline="true"/>

  <!-- variable-ish scopes -->
  <style name="def:identifier" foreground="${EDITOR_CYAN}"/>
  <style name="def:variable" foreground="${EDITOR_CYAN}"/>
  <style name="def:special-variable" foreground="${EDITOR_CYAN_BRIGHT}" bold="true"/>
  <style name="def:property" foreground="${EDITOR_CYAN}"/>

  <!-- shell / bash -->
  <style name="sh:variable" foreground="${EDITOR_CYAN_BRIGHT}"/>
  <style name="sh:variable-definition" foreground="${EDITOR_CYAN_BRIGHT}" bold="true"/>

  <!-- python-ish -->
  <style name="python:builtin-object" foreground="${EDITOR_CYAN_BRIGHT}"/>
  <style name="python:self" foreground="${EDITOR_CYAN_BRIGHT}" bold="true"/>

  <!-- javascript / typescript-ish -->
  <style name="js:object" foreground="${EDITOR_CYAN}"/>
  <style name="js:property" foreground="${EDITOR_CYAN}"/>
  <style name="typescript:variable" foreground="${EDITOR_CYAN}"/>
  <style name="typescript:property" foreground="${EDITOR_CYAN}"/>

  <!-- css-ish -->
  <style name="css:custom-property" foreground="${EDITOR_CYAN_BRIGHT}"/>
  <style name="css:property-name" foreground="${EDITOR_CYAN}"/>
</style-scheme>
EOF

  echo "Mousepad style written to: $MOUSEPAD_STYLE_FILE"

  if have_cmd xfconf-query; then
    xfconf-query -c mousepad \
      -p /preferences/view/color-scheme \
      -s theme-engine \
      --create \
      -t string 2>/dev/null || true
  fi
}

apply_pluma_style() {
  local PLUMA_STYLE_DIR_3 PLUMA_STYLE_DIR_4
  local PLUMA_STYLE_FILE_3 PLUMA_STYLE_FILE_4
  local EDITOR_CYAN EDITOR_CYAN_BRIGHT

  EDITOR_CYAN="#$(hsl_color "$C_ACCENT" "$TERM_CYAN_SHIFT" "$TERM_CYAN_SAT" "$TERM_CYAN_LIGHT")"
  EDITOR_CYAN_BRIGHT="#$(hsl_color "$C_ACCENT" "$TERM_CYAN_SHIFT" "$TERM_BRIGHT_CYAN_SAT" "$TERM_BRIGHT_CYAN_LIGHT")"

  PLUMA_STYLE_DIR_3="${XDG_DATA_HOME:-$HOME/.local/share}/gtksourceview-3.0/styles"
  PLUMA_STYLE_DIR_4="${XDG_DATA_HOME:-$HOME/.local/share}/gtksourceview-4/styles"

  PLUMA_STYLE_FILE_3="$PLUMA_STYLE_DIR_3/theme-engine.xml"
  PLUMA_STYLE_FILE_4="$PLUMA_STYLE_DIR_4/theme-engine.xml"

  ensure_dir "$PLUMA_STYLE_DIR_3"
  ensure_dir "$PLUMA_STYLE_DIR_4"

  cat > "$PLUMA_STYLE_FILE_4" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<style-scheme id="theme-engine" name="Theme Engine" version="1.0" xmlns="http://gtksourceview.org/language-specs">
  <author>theme-engine.sh</author>
  <description>Generated Pluma theme</description>

  <style name="text" foreground="${C_FG}" background="${C_BG}"/>
  <style name="selection" foreground="${C_BG}" background="${C_ACCENT}"/>
  <style name="current-line" background="$(mix_hex "$C_BG" "$C_FG" 8)"/>
  <style name="line-numbers" foreground="${C_DIM}" background="${C_BG}"/>
  <style name="current-line-number" foreground="${C_FG}" background="$(mix_hex "$C_BG" "$C_FG" 8)"/>
  <style name="right-margin" foreground="${C_DIM}" background="${C_BG}"/>
  <style name="bracket-match" foreground="${C_BG}" background="${C_ACCENT}"/>
  <style name="bracket-mismatch" foreground="${C_BG}" background="${C_URGENT}"/>

  <style name="def:comment" foreground="$(mix_hex "$C_DIM" "$C_ACCENT" 18)" italic="true"/>
  <style name="def:string" foreground="$(mix_hex "$C_ACCENT" "$C_FG" 35)"/>
  <style name="def:keyword" foreground="${C_ACCENT}" bold="true"/>
  <style name="def:number" foreground="#$(hsl_color "$C_ACCENT" 48 0.55 0.62)"/>
  <style name="def:function" foreground="#$(hsl_color "$C_ACCENT" -48 0.45 0.62)"/>

  <style name="def:identifier" foreground="${EDITOR_CYAN}"/>
  <style name="def:variable" foreground="${EDITOR_CYAN}"/>
  <style name="def:special-variable" foreground="${EDITOR_CYAN_BRIGHT}" bold="true"/>
  <style name="def:property" foreground="${EDITOR_CYAN}"/>
  <style name="def:type" foreground="#$(hsl_color "$C_ACCENT" -48 0.45 0.62)"/>
  <style name="def:preprocessor" foreground="${C_ACCENT}"/>
  <style name="def:error" foreground="${C_URGENT}" underline="true"/>

  <!-- variable-ish scopes -->
  <style name="def:identifier" foreground="${EDITOR_CYAN}"/>
  <style name="def:variable" foreground="${EDITOR_CYAN}"/>
  <style name="def:special-variable" foreground="${EDITOR_CYAN_BRIGHT}" bold="true"/>
  <style name="def:property" foreground="${EDITOR_CYAN}"/>

  <!-- shell / bash -->
  <style name="sh:variable" foreground="${EDITOR_CYAN_BRIGHT}"/>
  <style name="sh:variable-definition" foreground="${EDITOR_CYAN_BRIGHT}" bold="true"/>

  <!-- python-ish -->
  <style name="python:builtin-object" foreground="${EDITOR_CYAN_BRIGHT}"/>
  <style name="python:self" foreground="${EDITOR_CYAN_BRIGHT}" bold="true"/>

  <!-- javascript / typescript-ish -->
  <style name="js:object" foreground="${EDITOR_CYAN}"/>
  <style name="js:property" foreground="${EDITOR_CYAN}"/>
  <style name="typescript:variable" foreground="${EDITOR_CYAN}"/>
  <style name="typescript:property" foreground="${EDITOR_CYAN}"/>

  <!-- css-ish -->
  <style name="css:custom-property" foreground="${EDITOR_CYAN_BRIGHT}"/>
  <style name="css:property-name" foreground="${EDITOR_CYAN}"/>
</style-scheme>
EOF

  cp "$PLUMA_STYLE_FILE_4" "$PLUMA_STYLE_FILE_3"

  echo "Pluma style written to:"
  echo "  $PLUMA_STYLE_FILE_3"
  echo "  $PLUMA_STYLE_FILE_4"

  if have_cmd gsettings; then
    gsettings set org.mate.pluma.preferences.editor scheme 'theme-engine' 2>/dev/null || true
    gsettings set org.mate.pluma color-scheme 'theme-engine' 2>/dev/null || true
  fi
}

apply_sway() {
  ensure_dir "$SWAY_THEME_DIR"
  backup_if_exists "$SWAY_THEME_FILE"

  cat >"$SWAY_THEME_FILE" <<EOF
# Autogenerated by theme-engine.sh — edit theme-engine.sh profiles, not this file.

set \$sway_background ${SWAY_BACKGROUND}
set \$sway_text       ${SWAY_TEXT}
set \$sway_separator  ${SWAY_SEPARATOR}

set \$sway_color1  ${SWAY_1}
set \$sway_color2  ${SWAY_2}
set \$sway_color3  ${SWAY_3}
set \$sway_color4  ${SWAY_4}
set \$sway_color5  ${SWAY_5}
set \$sway_color6  ${SWAY_6}
set \$sway_color7  ${SWAY_7}
set \$sway_color8  ${SWAY_8}
set \$sway_color9  ${SWAY_9}
set \$sway_color10 ${SWAY_10}
set \$sway_color11 ${SWAY_11}
set \$sway_color12 ${SWAY_12}
set \$sway_color13 ${SWAY_13}
set \$sway_color14 ${SWAY_14}
set \$sway_color15 ${SWAY_15}
set \$sway_color16 ${SWAY_16}
set \$sway_color17 ${SWAY_17}

# class                 border       backgr.           text      indicator     child_border
client.focused          \$sway_color4    \$sway_background    \$sway_text  \$sway_color4     \$sway_color4
client.focused_inactive \$sway_color9    \$sway_background    \$sway_text  \$sway_separator  \$sway_color10
client.unfocused        \$sway_color9    \$sway_background    \$sway_text  \$sway_separator  \$sway_color10
client.urgent           \$sway_color7    \$sway_background    \$sway_text  \$sway_color7     \$sway_color7

client.background       \$sway_background

# ---- Sway window/bar palette (separate from window palette)
set \$bar_bg          ${BAR_BG}
set \$bar_text        ${BAR_TEXT}
set \$bar_sep         ${BAR_SEP}
set \$bar_border      ${BAR_BORDER}
set \$bar_focus_bg    ${BAR_FOCUS_BG}
set \$bar_active_bg   ${BAR_ACTIVE_BG}
set \$bar_inactive_bg ${BAR_INACTIVE_BG}
set \$bar_urgent_bg   ${BAR_URGENT_BG}

EOF
}

apply_polybar() {
  ensure_dir "$POLYBAR_DIR"
  backup_if_exists "$POLYBAR_COLORS"

  cat >"$POLYBAR_COLORS" <<EOF
[colors]
bg = $PB_BG
bg-alt = $PB_BG_ALT
fg = $PB_FG
dim = $PB_DIM
border = $PB_BORDER
accent = $PB_ACCENT
urgent = $PB_URGENT
EOF
}

apply_waybar() {
  local WAYBAR_DIR="$HOME/.config/waybar"
  mkdir -p "$WAYBAR_DIR"

  cat > "$WAYBAR_DIR/colors.css" <<EOF
@define-color cyan #${TERM_CYAN};
@define-color bg ${PB_BG};
@define-color bg_alt ${PB_BG_ALT};
@define-color fg ${PB_FG};
@define-color dim ${PB_DIM};
@define-color border ${PB_BORDER};
@define-color accent ${PB_ACCENT};
@define-color urgent ${PB_URGENT};
EOF
}

apply_swaync() {
  local SWAYNC_DIR="$HOME/.config/swaync"
  mkdir -p "$SWAYNC_DIR"

  local NOTI_HOVER
  local NOTI_FOCUS
  local NOTI_DARKER

  NOTI_HOVER="$(mix_hex "$PB_BG_ALT" "$PB_ACCENT" 10)"
  NOTI_FOCUS="$(mix_hex "$PB_BG_ALT" "$PB_ACCENT" 6)"
  NOTI_DARKER="$(mix_hex "$PB_BG" "#000000" 15)"

  cat > "$SWAYNC_DIR/colors.css" <<EOF
@define-color cc-bg alpha(${PB_BG}, 0.88);

@define-color noti-border-color ${PB_ACCENT};
@define-color noti-bg ${PB_BG_ALT};
@define-color noti-bg-darker ${NOTI_DARKER};
@define-color noti-bg-hover ${NOTI_HOVER};
@define-color noti-bg-focus transparent;

@define-color noti-close-bg alpha(${PB_FG}, 0.10);
@define-color noti-close-bg-hover alpha(${PB_ACCENT}, 0.25);

@define-color text-color ${PB_FG};
@define-color text-color-disabled ${PB_DIM};

@define-color bg-selected ${PB_ACCENT};
EOF
}

apply_xfce_xsettings() {
  if have_cmd xfconf-query; then
    xfconf-query -c xsettings -p /Net/ThemeName -s "$GTK_THEME" 2>/dev/null || true
    xfconf-query -c xsettings -p /Net/IconThemeName -s "$ICON_THEME" 2>/dev/null || true
    xfconf-query -c xsettings -p /Gtk/CursorThemeName -s "$CURSOR_THEME" 2>/dev/null || true
    xfconf-query -c xsettings -p /Gtk/CursorThemeSize -s "$CURSOR_SIZE" 2>/dev/null || true
    xfconf-query -c xsettings -p /Gtk/FontName -s "$FONT_NAME" 2>/dev/null || true
    if [[ "$GTK_THEME" == *Dark* ]]; then
      gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
    else
      gsettings set org.gnome.desktop.interface color-scheme 'default'
    fi
  fi
}

apply_gnome_settings() {
  if have_cmd gsettings; then
    if [[ "$GTK_THEME" == *Dark* ]]; then
      gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
    else
      gsettings set org.gnome.desktop.interface color-scheme 'prefer-light' 2>/dev/null || true
    fi

    gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface icon-theme "$ICON_THEME" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface cursor-theme "$CURSOR_THEME" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface cursor-size "$CURSOR_SIZE" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface font-name "$FONT_NAME" 2>/dev/null || true
  fi
}

apply_profile() {
  local p="${1:?profile required}"
  profile_vars "$p"
  derive_sway_palette
  derive_polybar_palette
  derive_terminal_palette

  #apply_gtk
  #apply_gnome_settings
  apply_xfce_xsettings
  apply_sway
  apply_swaync
  # apply_polybar
  apply_waybar

  if (( WRITE_EDITOR_COLORS )); then
    apply_mousepad_style
    apply_pluma_style
  fi

  if (( WRITE_TERMINAL_COLORS )); then
    apply_foot
    apply_xfce_terminal
  fi

  set_current_profile "$p"

  if have_cmd swaymsg; then
    swaymsg reload >/dev/null 2>&1 || true
  fi

  echo "Applied: $p"
  echo "  GTK theme : $GTK_THEME"
  echo "  Icons     : $ICON_THEME"
  echo "  Terminal shifts: red=$TERM_RED_SHIFT green=$TERM_GREEN_SHIFT yellow=$TERM_YELLOW_SHIFT blue=$TERM_BLUE_SHIFT magenta=$TERM_MAGENTA_SHIFT cyan=$TERM_CYAN_SHIFT"
  echo "  XFCE Terminal scheme: $XFCE_TERM_SCHEME_FILE"
}

###############################################################################
# Menu / picker
###############################################################################

pick_profile() {
  local items=(
    dark-red light-red
    dark-green light-green
    dark-blue light-blue
    dark-aqua light-aqua
    dark-teal light-teal
    dark-purple light-purple
    dark-pink light-pink
    dark-orange light-orange
    dark-yellow light-yellow
    dark-brown light-brown
    dark-grey light-grey
    dark-sand light-sand
  )
  local cur; cur="$(current_profile)"

  profile_vars "$cur"
  derive_terminal_palette
  derive_newt_palette

  if have_cmd fzf; then
    printf "%s\n" "${items[@]}" | fzf \
      --prompt='Select theme:: ' \
      --info=inline-right \
      --border=sharp \
      --height=100% \
      --scrollbar=▐█ \
      --cycle \
      --no-multi \
      --header="current: $cur"
    return 0
  fi

  if have_cmd whiptail; then
    whiptail --title "Theme Picker" --menu "Current: $cur" 18 60 10 \
      "${items[0]}" "" "${items[1]}" "" "${items[2]}" "" "${items[3]}" "" "${items[4]}" "" "${items[5]}" "" \
      3>&1 1>&2 2>&3
    return 0
  fi

  if have_cmd dialog; then
    local out
    out="$(mktemp)"
    dialog --clear --title "Theme Picker" --menu "Current: $cur" 18 60 10 \
      "${items[0]}" "" "${items[1]}" "" "${items[2]}" "" "${items[3]}" "" "${items[4]}" "" "${items[5]}" "" \
      2>"$out" || true
    cat "$out"
    rm -f "$out"
    return 0
  fi

  echo "Current: $cur"
  select p in "${items[@]}"; do
    [[ -n "${p:-}" ]] && echo "$p" && return 0
  done
}

toggle_profile() {
  local cur next
  cur="$(current_profile)"

  case "$cur" in
    dark-*)  next="light-${cur#dark-}" ;;
    light-*) next="dark-${cur#light-}" ;;
    *)       next="dark-blue" ;;
  esac

  apply_profile "$next"
}

###############################################################################
# Entry
###############################################################################

cmd="${1:-menu}"

case "$cmd" in
  menu)
    p="$(pick_profile || true)"
    [[ -n "${p:-}" ]] && apply_profile "$p"
    ;;
  toggle)
    toggle_profile
    ;;
  apply)
    apply_profile "${2:?Usage: $0 apply <profile>}"
    ;;
  current)
    current_profile
    ;;
  popup)
    exec foot --app-id theme-engine-fzf -W 90x22 "$0" menu
    ;;
  *)
    echo "Usage:"
    echo "  $0 menu       # pick theme"
    echo "  $0 toggle     # flip light<->dark for current color"
    echo "  $0 apply NAME # apply a specific profile"
    echo "  $0 current"
    exit 1
    ;;
esac