# SwayCrap
Sway dot files that just works

# Xubuntu + Sway Desktop

A customized Sway desktop built on Xubuntu, combining tiling window management with familiar XFCE applications and graphical configuration tools.

The goal is a tiling traditional desktop environment that just works. The regular XFCE session remains available as an alternative.

<!-- Add screenshots here, e.g. ![Desktop](screenshots/desktop.png) -->

## Features

- Sway Wayland compositor with XWayland compatibility
- Waybar, Sway Notification Center, and HistUI notification history
- XFCE appearance, display, and power management tools
- Thunar file manager and graphical desktop utilities
- Wofi, dmenu, and custom keyboard-driven application menus
- Built-in shortcut help (`Super+F1`)
- Theme picker (`Super+T`) with optional terminal/editor coloring
- Full XFCE session still available at login

## 1. System requirements

These instructions target **Xubuntu 26.04** with an existing graphical login manager and XFCE desktop. Packages and configuration details may differ on other releases.

## 2. Install Sway and desktop dependencies

Enable Ubuntu Universe and refresh package metadata:

```bash
sudo add-apt-repository -y universe
sudo apt update
```

Install the desktop and supporting tools:

```bash
sudo apt install -y \
  sway swaybg swayidle swaylock xwayland \
  waybar sway-notification-center swayosd \
  foot grim slurp swappy wl-clipboard \
  wofi dmenu fzf jq cava \
  playerctl brightnessctl copyq \
  network-manager-gnome blueman mate-polkit \
  xfce4-settings xfconf xfce4-power-manager \
  xfce4-terminal mousepad pluma thunar engrampa \
  pavucontrol galculator synaptic \
  qt5-gtk-platformtheme qt6-gtk-platformtheme \
  xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-wlr \
  pipewire wireplumber pipewire-pulse libnotify-bin \
  lm-sensors pciutils python3 \
  git make build-essential sassc python3-libsass optipng inkscape \
  fonts-noto fonts-noto-color-emoji fonts-font-awesome \
  mint-y-icons golang libgtk-4-dev libglib2.0-dev \
  pkg-config pysassc
```

**Notes:**

- Volume keybindings use `wpctl` (PipeWire/WirePlumber), independently of SwayOSD.
- SwayOSD displays on-screen indicators.
- The existing Waybar icons work with `fonts-font-awesome`; Nerd Fonts are not required.
- XDG portals help with desktop integration, including file selection and screen sharing. Adjust these packages to your needs.
- Some packages may already be installed by Xubuntu. Check availability with `apt show PACKAGE` when using another release.

## 3. Install the dotfiles

The repository is arranged to match your home directory: `.config/` contains the desktop configuration, and `Pictures/Wallpapers/` contains the included lightcycle wallpapers.

### Download the repository

```bash
git clone https://github.com/YOUR_USERNAME/YOUR_REPOSITORY.git
cd YOUR_REPOSITORY
```

Replace the example URL and directory with your actual repository name.

### Copy the configuration and wallpapers

**Back up any existing settings before copying.** Matching files in your home directory may be overwritten.

```bash
mkdir -p "$HOME/.config" "$HOME/Pictures"
cp -a .config/. "$HOME/.config/"
cp -a Pictures/. "$HOME/Pictures/"
```

This merges the supplied files into `~/.config/` and `~/Pictures/`, without copying the README or screenshots into your home directory. Existing unrelated files are left in place.

### First launch

The Sway configuration includes generated theme color files. If these are not shipped with the repository, run the theme engine once to create them **before starting Sway**. Install the dependencies and themes described below as needed.

Log out and choose **Sway** at the login screen. The regular XFCE session remains available.

## 4. Build Mint-Y GTK themes

```bash
mkdir -p "$HOME/Downloads/mint-build"
cd "$HOME/Downloads/mint-build"
git clone https://github.com/linuxmint/mint-themes.git
cd mint-themes
make
```

Install the themes for the current user:

```bash
mkdir -p "$HOME/.themes"
cp -a usr/share/themes/Mint-Y* "$HOME/.themes/"
```

Verify and preview:

```bash
find "$HOME/.themes" -mindepth 1 -maxdepth 1 \
  -type d -name 'Mint-Y*' -printf '%f\n' | sort
xfce4-appearance-settings
```

## 5. Install HistUI

[HistUI](https://github.com/jmylchreest/histui) provides the notification-history interface and monitoring daemon.

```bash
cd "$HOME/Downloads"
git clone https://github.com/jmylchreest/histui.git
cd histui

CGO_ENABLED=0 go build -ldflags "-s -w" -o histui ./cmd/histui
CGO_ENABLED=1 go build -ldflags "-s -w" -o histuid ./cmd/histuid

sudo install -m 755 histui histuid /usr/local/bin/

histui --version
histuid --version
```

The Sway configuration launches `histuid --monitor`. The `histui` launcher should use the executable on `PATH` rather than a hard-coded home-directory path.

## 6. Configure Qt appearance (optional)

Add the following to `~/.profile` if you want Qt applications to follow the XFCE-selected GTK theme:

```bash
# Qt follows XFCE's selected GTK theme
export QT_QPA_PLATFORMTHEME=gtk3
unset QT_QPA_PLATFORMTHEME_QT6
unset QT_STYLE_OVERRIDE
```

Log out and back in to apply the session environment changes. Individual Qt applications may use their own appearance settings.

## 7. Theme engine

The theme picker is **Super+T** and its script is:

`~/.config/sway/scripts/theme-engine.sh`

### Generated files

| File | Purpose |
|---|---|
| `~/.config/sway/themes/current.conf` | Sway colors |
| `~/.config/waybar/colors.css` | Waybar colors |
| `~/.config/swaync/colors.css` | Notification center colors |
| `~/.config/sway/theme-engine/current_profile` | Last selected theme |

The engine also changes supported XFCE appearance settings through `xfconf-query`. Other functions in the script may be disabled; check the script for the version you publish.

### Optional terminal and editor colors

Terminal and text-editor coloring should be **off by default**. Set these values in `theme-engine.sh` to enable them:

```bash
# 0 = leave application color settings alone; 1 = generate color profiles
WRITE_TERMINAL_COLORS=0
WRITE_EDITOR_COLORS=0
```

When enabled, the engine can write:

| Application | File |
|---|---|
| Foot | `~/.config/foot/foot.ini` |
| XFCE Terminal | `~/.local/share/xfce4/terminal/colorschemes/theme-engine.theme` |
| Mousepad | `~/.local/share/gtksourceview-4/styles/theme-engine.xml` |
| Pluma | `~/.local/share/gtksourceview-3.0/styles/theme-engine.xml` |

Enabling either feature can replace customized colors. Back up relevant application settings first.

### Terminal color examples

![Six terminal color themes shown side by side in htop](screenshots/terminal-themes.png)

*Six optional terminal color profiles created by the theme engine, shown with htop. Terminal and editor color generation are disabled by default; enable `WRITE_TERMINAL_COLORS=1` in `theme-engine.sh` to use terminal color syncing.*

### Optional Bash prompt colors

Choose **one** prompt and add it to `~/.bashrc`:

```bash
# Blue username/hostname and white working directory
PS1='\[\e[94m\]\u@\h:\[\e[0m\]\[\e[37m\]\w\[\e[0m\]\$ '
```

Or:

```bash
# Cyan username/hostname and white working directory
PS1='\[\e[96m\]\u@\h:\[\e[0m\]\[\e[37m\]\w\[\e[0m\]\$ '
```

Reload with `source ~/.bashrc`. These prompt colors work independently of the theme engine.

## 8. Keyboard shortcuts

**Super** means the Windows/Super key. **Super+F1** opens the built-in help window at any time, so you do not need to memorize these bindings.

### General

| Shortcut | Action |
|---|---|
| `Super+Q` | Application and system menu |
| `Super+D` | dmenu launcher |
| `Super+Z` | Wofi launcher |
| `Super+Enter` | Foot terminal |
| `Super+Shift+Q` | Close focused window |
| `Super+Shift+R` | Reload Sway configuration |
| `Super+Shift+E` | Exit Sway with confirmation |
| `Super+F1` | Show built-in shortcut help |

### Windows and focus

| Shortcut | Action |
|---|---|
| `Super+Arrows` or `Super+J/K/L/;` | Focus another window |
| `Super+Shift+Arrows` or `Super+Shift+J/K/L/;` | Move focused window |
| `Super+F` | Toggle fullscreen |
| `Super+Shift+Space` | Toggle floating |
| `Super+Space` | Switch focus between tiling/floating windows |
| `Super+R` | Resize mode (arrows or J/K/L/; to resize; Enter/Escape to exit) |
| `Super+A` | Focus parent container |
| `Super+I` | Hide window title bars |
| `Super+O` | Show window title bars |
| `Super+G` | Toggle gaps |

### Layouts

| Shortcut | Action |
|---|---|
| `Super+H` | Horizontal split |
| `Super+V` | Vertical split |
| `Super+S` | Stacking layout |
| `Super+W` | Tabbed layout |
| `Super+E` | Toggle split layout |

### Workspaces and displays

| Shortcut | Action |
|---|---|
| `Super+1`–`Super+9` | Switch to workspaces 1–9 |
| `Super+0` | Switch to workspace 10 |
| `Super+Shift+1`–`Super+Shift+9` | Move focused window to workspace 1–9 |
| `Super+Shift+0` | Move focused window to workspace 10 |
| `Super+Ctrl+Arrows` | Move current workspace to another display |

### Desktop tools

| Shortcut | Action |
|---|---|
| `Super+T` | Theme picker |
| `Super+N` | Notification center |
| `Super+M` | Toggle Waybar visibility |
| `Super+Print` | Screenshot menu |

**Screenshot menu:** `1` selects an area; `2` captures the active window; `3` captures the full screen. Press **Enter** or **Escape** to exit the menu.

### Audio and display

| Shortcut | Action |
|---|---|
| `Super+=` | Volume up |
| `Super+-` | Volume down |
| `Super+Backspace` | Mute/unmute |
| `Super+Mouse wheel` | Adjust volume |
| Hardware volume keys | Volume up/down and mute |
| Hardware brightness keys | Screen brightness |
| Media keys | Play/pause, next, previous |

Volume adjustments use `wpctl` directly, so they continue to work if SwayOSD is unavailable.

### Super+Q menu

Press **Super+Q**, select a numbered category, then a numbered item.

| Main menu | Contents |
|---|---|
| **1 — General apps** | `1` Firefox · `2` Thunar · `3` Calculator · `4` XFCE Task Manager |
| **2 — Games/recording** | `1` OBS Studio · `2` Steam |
| **3 — Macros** | Reserved for personal macros |
| **4 — System** | `1` Synaptic · `2` XFCE Settings · `3` Display Settings |
| **9 — Power** | `5` Shutdown · `6` Restart · `7` Logout · `8` Suspend · `9` Lock |

OBS Studio and Steam need to be installed separately if you want those menu entries to launch. The macro menu is reserved for personal shortcuts in the public configuration.

The full in-desktop help is maintained in `~/.config/sway/help.txt`.

## 9. Optional components and customization

The configuration includes disabled alternatives for PulseAudio volume keys, application launchers, PolicyKit agents, and other tools. Enable only one conflicting set of bindings or services at a time.

If your SwayOSD version supports disabling Caps Lock indicators, its backend configuration may use:

```toml
[input]
ignore_caps_lock_key = true
```

Check the installed SwayOSD version and its backend configuration location before applying this setting.

## 10. Notes for new installations

This is a personal desktop configuration, not a complete distribution or fully automated installer. A fresh installation may require adjusting wallpaper paths, hardware-specific Waybar widgets, screen configuration, optional utilities, and application launchers.

Keep private clipboard history and machine-specific state out of the repository. Your normal XFCE session remains available from the login screen.


## Credits

- [Sway](https://swaywm.org/)
- [Waybar](https://github.com/Alexays/Waybar)
- [Sway Notification Center](https://github.com/ErikReider/SwayNotificationCenter)
- [SwayOSD](https://github.com/ErikReider/SwayOSD)
- [HistUI](https://github.com/jmylchreest/histui)
- [Linux Mint themes](https://github.com/linuxmint/mint-themes)
- Xubuntu and the XFCE project
