# AGENTS.md

This repository is the canonical source of truth for the local Arch + Hyprland development environment.

## Source-of-truth rules

- Treat this repository as the authoritative copy of all managed dotfiles.
- Prefer editing files in this repo instead of editing live files under $HOME.
- Use the install script to apply repo changes into the active desktop environment.
- Keep the directory layout stable so agents and humans can reason about the environment consistently.

## Repository structure

The repo mirrors the desktop environment using XDG-compatible directories:

- hypr/.config/hypr/ for Hyprland config and wallpapers
- waybar/.config/waybar/ for bar config and styling
- fish/.config/fish/ for shell config and functions
- kitty/.config/kitty/ for terminal config
- quickshell/.config/quickshell/ for widget shell config, wallpaper orchestration, and Material-style launcher UI
- quickshell/.config/quickshell/clipboard/ for the Material-style clipboard overlay
- matugen/.config/matugen/ for wallpaper-derived color generation templates
- quickshell/r41n/scripts/.local/bin/ for helper scripts, including idempotent desktop startup and clipboard helpers
- assets/ for reusable artwork, icons, cursors, and fonts

## Workflow

1. Make edits in the repository.
2. Validate the configuration locally if possible.
3. Run ./install.sh --install to sync the repo into the user environment.
4. Use ./install.sh --restore to recover from a failed deployment or bad state.
5. Commit only repo-managed config and supporting docs.

## Do not commit

- transient cache files
- generated runtime state
- editor/OS metadata
- backups created by install/uninstall scripts

## Installation

```bash
./install.sh
```

## Removal

```bash
./uninstall.sh
```
