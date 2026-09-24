# Dotfiles environment

This repository is the primary source of truth for the current Linux desktop environment, especially the Hyprland-based setup.

## Goals

- keep all environment config under version control
- make configuration changes reproducible
- support both manual edits and automated install flows
- keep the repo structure understandable for humans and agent workflows

## Repository layout

```text
~/dotfiles/
├── README.md
├── AGENTS.md
├── INSTALL.md
├── install.sh
├── uninstall.sh
├── assets/
│   ├── icons/
│   ├── cursors/
│   └── fonts/
├── fish/
│   └── .config/
│       └── fish/
│           ├── config.fish
│           ├── completions/
│           ├── conf.d/
│           └── functions/
├── hypr/
│   └── .config/
│       └── hypr/
│           ├── hyprland.conf
│           ├── hyprland.lua
│           ├── bindings/
│           │   ├── apps.lua
│           │   ├── navigation.lua
│           │   └── utilities.lua
│           ├── config/
│           │   ├── constants.lua
│           │   ├── environment.lua
│           │   ├── look_and_feel.lua
│           │   └── monitors.lua
│           ├── input/
│           │   └── gestures.lua
│           ├── rules/
│           │   └── windows.lua
│           ├── services/
│           │   └── autostart.lua
│           └── wallpapers/
│               ├── aot.jpg
│               ├── blogo.jpg
│               ├── giyutomioka.jpg
│               ├── gl.jpg
│               └── hsin.jpg
├── kitty/
│   └── .config/
│       └── kitty/
│           └── kitty.conf
├── matugen/
│   └── .config/
│       └── matugen/
│           ├── config.toml
│           └── templates/
│               └── waybar-colors.css
├── quickshell/
│   └── .config/
│       └── quickshell/
│           └── rice/
│               └── shell.qml
│           └── clipboard/
│               └── shell.qml
├── scripts/
│   └── .local/
│       └── bin/
│           ├── apply-palette
│           ├── clipboard-items
│           ├── clipboard-history
│           ├── clipboard-restore
│           ├── clipboard-start
│           ├── screenshot
│           ├── waybar-start
│           ├── wallpaper-next
│           └── wallpaper-random
├── waybar/
│   └── .config/
│       └── waybar/
│           ├── config.jsonc
│           └── style.css
└── .git/
```

## Source-of-truth policy

This repository is treated as the canonical version for the active desktop environment. Any future environment changes should start here, not in ephemeral $HOME files.

## Install flow

```bash
cd ~/dotfiles
./install.sh --install
./install.sh --uninstall
./install.sh --restore
./install.sh --list-backups
```

The unified installer copies the repo-managed config into the correct XDG paths under $HOME for the current session and automatically creates a timestamped backup before mutating the live environment. If an install or uninstall step fails, the script restores the previous version automatically.

## Wallpaper palettes

The wallpaper scripts require `matugen`, `hyprpaper`, `hyprctl`, and `jq`. Each wallpaper change runs Matugen against the selected image, writes the generated palette to `~/.config/waybar/colors.css`, and signals Waybar to reload its colors.

The generated `colors.css` is runtime output and is intentionally not stored in the repository. The source template lives at `matugen/.config/matugen/templates/waybar-colors.css`.

## Notes

- The repo intentionally stores config under nested folders matching the real XDG layout.
- This makes it easy to mirror the environment while keeping a clean git history.
- Generated files, caches, and app runtime state are not tracked unless they are intentionally part of the managed setup.
- Backups are stored under ~/.dotfiles-backups by default and can be restored with --restore.
- Quickshell owns wallpaper selection and rotation; hyprpaper remains the renderer.
- Run wallpaper-next or wallpaper-random manually to change the current wallpaper.
- Matugen generates Waybar colors from every selected wallpaper and refreshes Waybar automatically.
- Cliphist stores text and image clipboard entries. `Super+V` opens the Quickshell Material-style picker and restores the selected entry.
- Image entries are labeled as binary data and show a thumbnail directly below the metadata.
- Print and Shift+Print save screenshots to Pictures and copy them into the image clipboard history.
