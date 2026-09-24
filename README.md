# Dotfiles
My personal dotfiles configuration,this is still under development so breaking changes can be expected,
also you are open to contribute or give me any suggestions on how can i further improve this.

---

## Highlights

- **Dynamic Material You Theming**: Colors generated on the fly with Matugen from the current wallpaper (`~/Pictures/Wallpapers`) and automatically synchronized across Hyprland borders, Waybar, and Quickshell widgets.
- **Unified Spotlight Launcher**: Smooth macOS-style floating launcher powered by Quickshell:
  - App and desktop file search with fast fuzzy matching
  - Dual-pane Clipboard History inspector with image and text previews (`:` or `Super + V`)
  - Dual-pane Wallpaper Picker with high-resolution image preview and instant theming (`@`)
  - Environment controls and system actions (`>`)
  - Live mathematical calculation with Qalc
  - Direct shell command execution
- **Automated Installer & Package Management**:
  - Automatically detects and installs required packages via `yay`, `paru`, or `pacman`
  - Automated timestamped backups before applying changes
  - One-command rollback (`./install.sh --restore`) and `--dry-run` inspection

---

## Installation

### 1. Clone the repository

```bash
git clone https://github.com/0xraiven/dotfiles.git ~/git/dotfiles
cd ~/git/dotfiles
```

### 2. Install dotfiles and packages

Run the installer:

```bash
./install.sh --install
```

The installer will:
1. Detect any missing system dependencies and install them using `yay`, `paru`, or `pacman`.
2. Create a timestamped backup of existing configs under `~/.dotfiles-backups/`.
3. Deploy configurations into `~/.config/` (`hypr`, `waybar`, `fish`, `kitty`, `quickshell`, `matugen`) and `~/.local/share/dotfiles-assets`.
4. Ensure `~/Pictures/Wallpapers` exists and apply the Matugen palette matching the active wallpaper.

### Installer Flags

| Flag | Description |
| :--- | :--- |
| `-i`, `--install` | Install dotfiles and packages into `$HOME` (default) |
| `-u`, `--uninstall` | Remove installed repo configurations from `$HOME` |
| `-r`, `--restore [ID]` | Restore the latest backup or specify a backup timestamp |
| `-l`, `--list-backups` | List all available timestamped backups |
| `-n`, `--dry-run` | Preview actions without modifying any files |
| `-b`, `--backup-root DIR` | Override backup destination directory |
| `--no-backup` | Skip automatic backup creation |
| `--skip-packages` | Skip detecting and installing system packages |
| `-h`, `--help` | Show command usage and options |

---

## Keybinds

### Applications & Launcher

| Keybinding | Action |
| :--- | :--- |
| <kbd>Super</kbd> (tap) | Open **Spotlight Launcher** |
| <kbd>Super</kbd> + <kbd>V</kbd> | Open Spotlight in **Clipboard History** mode |
| <kbd>Super</kbd> + <kbd>T</kbd> | Open Terminal (`kitty`) |
| <kbd>Super</kbd> + <kbd>W</kbd> | Open Web Browser (`zen-browser`) |
| <kbd>Super</kbd> + <kbd>E</kbd> | Open File Manager (`nautilus`) |
| <kbd>Super</kbd> + <kbd>C</kbd> | Open Code Editor (`code`) |
| <kbd>Super</kbd> + <kbd>A</kbd> | Open Antigravity IDE |
| <kbd>Super</kbd> + <kbd>Q</kbd> | Close active window |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>Q</kbd> | Exit Hyprland session |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>R</kbd> | Reload Hyprland configuration |
| <kbd>Super</kbd> + <kbd>F</kbd> | Toggle Fullscreen |
| <kbd>Super</kbd> + <kbd>Space</kbd> | Toggle Floating mode |
| <kbd>Super</kbd> + <kbd>Tab</kbd> | Cycle next window |

### Window Navigation & Management

| Keybinding | Action |
| :--- | :--- |
| <kbd>Super</kbd> + <kbd>←</kbd> / <kbd>→</kbd> / <kbd>↑</kbd> / <kbd>↓</kbd> | Focus window in direction |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>←</kbd> / <kbd>→</kbd> / <kbd>↑</kbd> / <kbd>↓</kbd> | Move focused window in direction |
| <kbd>Super</kbd> + <kbd>Ctrl</kbd> + <kbd>←</kbd> / <kbd>→</kbd> / <kbd>↑</kbd> / <kbd>↓</kbd> | Resize focused window |
| <kbd>Super</kbd> + <kbd>LMB (drag)</kbd> | Move floating window |
| <kbd>Super</kbd> + <kbd>RMB (drag)</kbd> | Resize window |
| <kbd>Super</kbd> + <kbd>1</kbd> – <kbd>9</kbd> | Switch to workspace 1 – 9 |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>1</kbd> – <kbd>9</kbd> | Move window to workspace 1 – 9 |
| <kbd>Super</kbd> + <kbd>O</kbd> | Switch to workspace 10 |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>0</kbd> | Move window to workspace 10 |
| <kbd>Super</kbd> + <kbd>[</kbd> / <kbd>Super</kbd> + <kbd>]</kbd> | Switch to previous / next workspace |
| <kbd>Super</kbd> + <kbd>S</kbd> | Toggle Special workspace (Scratchpad) |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>S</kbd> | Move window to Special workspace (Scratchpad) |

### System & Hardware Utilities

| Keybinding | Action |
| :--- | :--- |
| <kbd>Print</kbd> | Screenshot selected region (copies to clipboard and saves to `~/Pictures/Screenshots`) |
| <kbd>Shift</kbd> + <kbd>Print</kbd> | Fullscreen screenshot (copies to clipboard and saves to `~/Pictures/Screenshots`) |
| <kbd>Super</kbd> + <kbd>L</kbd> | Lock session (`loginctl lock-session`) |
| <kbd>XF86AudioRaiseVolume</kbd> | Volume Up (+5%) |
| <kbd>XF86AudioLowerVolume</kbd> | Volume Down (-5%) |
| <kbd>XF86AudioMute</kbd> | Toggle Audio Mute |
| <kbd>XF86MonBrightnessUp</kbd> | Screen Brightness Up (+5%) |
| <kbd>XF86MonBrightnessDown</kbd> | Screen Brightness Down (-5%) |

---

## Spotlight Launcher Modes

When opening Spotlight (<kbd>Super</kbd>), prefix your query or use the dedicated shortcuts:

| Prefix / Mode | Action |
| :--- | :--- |
| *(None)* | Search desktop applications, files, or execute shell commands |
| `:` *(or Super+V)* | **Clipboard History**: Dual-pane list and preview inspector. Press <kbd>Return</kbd> to restore. |
| `@` | **Wallpaper Picker**: Dual-pane wallpaper browser with live image preview. Press <kbd>Return</kbd> to apply wallpaper and regenerate theme. |
| `>` | **System Controls**: Quick actions (Next/Random Wallpaper, Screenshots, Waybar restart, Power profiles, Suspend, Reboot, Shutdown). |
| `[math]` | **Calculator**: Type expressions (e.g. `128 * 4 + 16`) for instant Qalc calculation. |

---

## Wallpapers

Wallpapers are stored in `~/Pictures/Wallpapers`. Drop any `.jpg`, `.png`, or `.webp` images into that folder, and they will immediately appear in the Spotlight Wallpaper Picker (`@`), cycle via Next/Random commands, and update your desktop theme colors.
