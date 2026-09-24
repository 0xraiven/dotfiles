#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="${HOME}"
SCRIPT_TARGET="$HOME_DIR/.config/quickshell/scripts"
BACKUP_ROOT="${DOTFILES_BACKUP_ROOT:-$HOME_DIR/.dotfiles-backups}"
OPERATION="install"
DRY_RUN=false
CUSTOM_BACKUP_ID=""
USE_BACKUP=true
SKIP_PACKAGES=false

# Terminal colors if stdout is an interactive terminal
if [ -t 1 ]; then
  C_RESET="\033[0m"
  C_BOLD="\033[1m"
  C_GREEN="\033[32m"
  C_YELLOW="\033[33m"
  C_BLUE="\033[34m"
  C_RED="\033[31m"
else
  C_RESET=""
  C_BOLD=""
  C_GREEN=""
  C_YELLOW=""
  C_BLUE=""
  C_RED=""
fi

log() {
  echo -e "$*"
}

info() {
  echo -e "${C_BLUE}==>${C_RESET} ${C_BOLD}$*${C_RESET}"
}

success() {
  echo -e "${C_GREEN}==>${C_RESET} ${C_BOLD}$*${C_RESET}"
}

warn() {
  echo -e "${C_YELLOW}==> Warning:${C_RESET} $*" >&2
}

fail() {
  echo -e "${C_RED}==> Error:${C_RESET} $*" >&2
  exit 1
}

# Directories and files managed by this repository
MANAGED_TARGETS=(
  "$HOME_DIR/.config/hypr"
  "$HOME_DIR/.config/waybar"
  "$HOME_DIR/.config/fish"
  "$HOME_DIR/.config/kitty"
  "$HOME_DIR/.config/quickshell"
  "$HOME_DIR/.config/matugen"
  "$SCRIPT_TARGET"
  "$HOME_DIR/.local/share/dotfiles-assets"
)

# Obsolete / deprecated paths to remove during installation
LEGACY_PATHS=(
  "$HOME_DIR/.config/quickshell/power"
  "$HOME_DIR/.config/quickshell/r41n"
  "$HOME_DIR/.config/quickshell/clipboard"
  "$HOME_DIR/.config/quickshell/wallpaper"
  "$HOME_DIR/.local/bin/apply-palette"
  "$HOME_DIR/.local/bin/clipboard-history"
  "$HOME_DIR/.local/bin/clipboard-items"
  "$HOME_DIR/.local/bin/clipboard-restore"
  "$HOME_DIR/.local/bin/clipboard-start"
  "$HOME_DIR/.local/bin/launcher-items"
  "$HOME_DIR/.local/bin/screenshot"
  "$HOME_DIR/.local/bin/spotlight-items"
  "$HOME_DIR/.local/bin/wallpaper-items"
  "$HOME_DIR/.local/bin/wallpaper-next"
  "$HOME_DIR/.local/bin/wallpaper-picker"
  "$HOME_DIR/.local/bin/wallpaper-random"
  "$HOME_DIR/.local/bin/waybar-start"
)

usage() {
  cat <<EOF
Usage: $(basename "$0") [flags]

Flags:
  -i, --install            Install dotfiles and packages into $HOME (default)
  -u, --uninstall          Remove installed dotfiles from $HOME
  -r, --restore [ID]      Restore the latest backup or a specific backup ID
  -l, --list-backups       List all available backups
  -n, --dry-run            Show what would happen without modifying files
  -b, --backup-root DIR    Override the backup directory
  --no-backup              Skip automatic backups before install/uninstall
  --skip-packages          Skip detecting and installing required system packages
  -h, --help               Show this help

Examples:
  $(basename "$0") --install
  $(basename "$0") --install --dry-run
  $(basename "$0") --install --skip-packages
  $(basename "$0") --uninstall
  $(basename "$0") --restore
  $(basename "$0") --restore 20260924-190530
  $(basename "$0") --list-backups
EOF
}

ensure_dir() {
  local dir="$1"
  if [ "$DRY_RUN" = true ]; then
    log "[dry-run] mkdir -p $dir"
    return 0
  fi
  mkdir -p "$dir"
}

copy_tree() {
  local src="$1"
  local dst="$2"
  if [ ! -d "$src" ]; then
    return 0
  fi
  if [ "$DRY_RUN" = true ]; then
    log "[dry-run] cp -a $src/. $dst/"
    return 0
  fi
  ensure_dir "$dst"
  cp -a "$src/." "$dst/"
}

remove_if_exists() {
  local target="$1"
  if [ ! -e "$target" ] && [ ! -L "$target" ]; then
    return 0
  fi
  if [ "$DRY_RUN" = true ]; then
    log "[dry-run] rm -rf $target"
    return 0
  fi
  rm -rf "$target"
}

detect_and_install_packages() {
  info "Checking required system packages..."

  # Binary to Arch package mapping
  local -A command_map=(
    ["Hyprland"]="hyprland"
    ["hyprpaper"]="hyprpaper"
    ["waybar"]="waybar"
    ["kitty"]="kitty"
    ["fish"]="fish"
    ["quickshell"]="quickshell"
    ["matugen"]="matugen"
    ["cliphist"]="cliphist"
    ["wl-copy"]="wl-clipboard"
    ["grim"]="grim"
    ["slurp"]="slurp"
    ["qalc"]="libqalculate"
    ["powerprofilesctl"]="power-profiles-daemon"
    ["jq"]="jq"
    ["python3"]="python"
    ["wpctl"]="wireplumber"
    ["brightnessctl"]="brightnessctl"
    ["pavucontrol"]="pavucontrol"
    ["gtk-launch"]="gtk3"
    ["xdg-open"]="xdg-utils"
    ["xdg-user-dir"]="xdg-user-dirs"
    ["flock"]="util-linux"
    ["file"]="file"
  )

  local required_fonts=(
    "ttf-jetbrains-mono-nerd"
    "otf-font-awesome"
  )

  local missing_pkgs=()

  # Check command binaries
  for cmd in "${!command_map[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing_pkgs+=("${command_map[$cmd]}")
    fi
  done

  # Check fonts (via pacman or fc-list)
  for font_pkg in "${required_fonts[@]}"; do
    if command -v pacman >/dev/null 2>&1; then
      if ! pacman -Q "$font_pkg" >/dev/null 2>&1; then
        missing_pkgs+=("$font_pkg")
      fi
    fi
  done

  # Remove duplicates if any
  if [ "${#missing_pkgs[@]}" -gt 0 ]; then
    mapfile -t missing_pkgs < <(printf '%s\n' "${missing_pkgs[@]}" | sort -u)
  fi

  if [ "${#missing_pkgs[@]}" -eq 0 ]; then
    success "All required packages are installed."
    return 0
  fi

  warn "The following required packages are missing: ${missing_pkgs[*]}"

  if [ "$DRY_RUN" = true ]; then
    log "[dry-run] would install packages: ${missing_pkgs[*]}"
    return 0
  fi

  # Detect available package manager
  local installer=""
  if command -v yay >/dev/null 2>&1; then
    installer="yay"
  elif command -v paru >/dev/null 2>&1; then
    installer="paru"
  elif command -v pacman >/dev/null 2>&1; then
    installer="pacman"
  fi

  if [ -z "$installer" ]; then
    warn "No supported package manager found (pacman, yay, paru). Please install manually: ${missing_pkgs[*]}"
    return 0
  fi

  info "Installing missing packages via $installer..."
  case "$installer" in
    yay)
      yay -S --needed --noconfirm "${missing_pkgs[@]}"
      ;;
    paru)
      paru -S --needed --noconfirm "${missing_pkgs[@]}"
      ;;
    pacman)
      if [ "$(id -u)" -eq 0 ]; then
        pacman -S --needed --noconfirm "${missing_pkgs[@]}"
      elif command -v sudo >/dev/null 2>&1; then
        sudo pacman -S --needed --noconfirm "${missing_pkgs[@]}"
      else
        fail "Root privileges or sudo required to install packages with pacman."
      fi
      ;;
  esac

  success "Package installation completed."
}

latest_backup_id() {
  if [ ! -d "$BACKUP_ROOT" ]; then
    return 1
  fi

  local latest
  latest="$(find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort | tail -n 1)"
  if [ -n "$latest" ]; then
    echo "$latest"
    return 0
  fi

  return 1
}

list_backups() {
  if [ ! -d "$BACKUP_ROOT" ]; then
    log "No backups found in $BACKUP_ROOT"
    return 0
  fi

  info "Available backups in $BACKUP_ROOT:"
  find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -printf '  %f\n' | sort
}

create_backup() {
  local backup_id="$1"
  local backup_dir="$BACKUP_ROOT/$backup_id"
  local target rel

  ensure_dir "$backup_dir"

  for target in "${MANAGED_TARGETS[@]}"; do
    if [ -e "$target" ] || [ -L "$target" ]; then
      rel="${target#$HOME_DIR/}"
      ensure_dir "$backup_dir/$(dirname "$rel")"
      if [ "$DRY_RUN" = true ]; then
        log "[dry-run] cp -a $target $backup_dir/$rel"
      else
        cp -a "$target" "$backup_dir/$rel"
      fi
    fi
  done

  echo "$backup_id"
}

restore_backup() {
  local backup_id="$1"
  local backup_dir="$BACKUP_ROOT/$backup_id"
  local item rel target

  if [ ! -d "$backup_dir" ]; then
    fail "Backup '$backup_id' does not exist at $backup_dir"
  fi

  info "Restoring backup '$backup_id'..."

  while IFS= read -r item; do
    rel="${item#$backup_dir/}"
    target="$HOME_DIR/$rel"

    if [ "$DRY_RUN" = true ]; then
      log "[dry-run] restore $backup_dir/$rel -> $target"
      continue
    fi

    if [ -e "$target" ] || [ -L "$target" ]; then
      rm -rf "$target"
    fi

    ensure_dir "$(dirname "$target")"
    cp -a "$backup_dir/$rel" "$target"
  done < <(find "$backup_dir" -mindepth 1 -printf '%P\n' | sort)

  success "Backup '$backup_id' restored successfully."
}

install_repo() {
  info "Starting dotfiles installation from $REPO_DIR into $HOME_DIR"

  # 1. Detect and install required packages
  if [ "$SKIP_PACKAGES" = false ]; then
    detect_and_install_packages
  fi

  # 2. Create backup of existing config
  local backup_id=""
  if [ "$USE_BACKUP" = true ]; then
    backup_id="$(date +%Y%m%d-%H%M%S)"
    if [ "$DRY_RUN" = true ]; then
      log "[dry-run] would create backup at $BACKUP_ROOT/$backup_id"
    else
      create_backup "$backup_id" >/dev/null
      success "Backup created at $BACKUP_ROOT/$backup_id"
    fi
  fi

  # 3. Apply dotfiles into $HOME
  if ! (
    set -e

    # Copy managed config directories
    copy_tree "$REPO_DIR/hypr/.config/hypr" "$HOME_DIR/.config/hypr"
    copy_tree "$REPO_DIR/waybar/.config/waybar" "$HOME_DIR/.config/waybar"
    copy_tree "$REPO_DIR/fish/.config/fish" "$HOME_DIR/.config/fish"

    if [ -d "$REPO_DIR/kitty/.config/kitty" ]; then
      copy_tree "$REPO_DIR/kitty/.config/kitty" "$HOME_DIR/.config/kitty"
    fi

    if [ -d "$REPO_DIR/quickshell/.config/quickshell" ]; then
      copy_tree "$REPO_DIR/quickshell/.config/quickshell" "$HOME_DIR/.config/quickshell"
    fi

    if [ -d "$REPO_DIR/matugen/.config/matugen" ]; then
      copy_tree "$REPO_DIR/matugen/.config/matugen" "$HOME_DIR/.config/matugen"
    fi

    if [ -d "$REPO_DIR/assets" ]; then
      ensure_dir "$HOME_DIR/.local/share"
      remove_if_exists "$HOME_DIR/.local/share/dotfiles-assets"
      if [ "$DRY_RUN" = true ]; then
        log "[dry-run] cp -a $REPO_DIR/assets $HOME_DIR/.local/share/dotfiles-assets"
      else
        cp -a "$REPO_DIR/assets" "$HOME_DIR/.local/share/dotfiles-assets"
      fi
    fi

    # Set executable permissions on scripts
    if [ "$DRY_RUN" = true ]; then
      log "[dry-run] chmod +x $SCRIPT_TARGET/*/*"
    else
      chmod +x "$SCRIPT_TARGET"/*/* 2>/dev/null || true
    fi

    # Clean legacy/obsolete paths
    for legacy_path in "${LEGACY_PATHS[@]}"; do
      remove_if_exists "$legacy_path"
    done

    # Ensure wallpaper directory exists and apply initial palette
    local wp_dir="${WALLPAPER_DIR:-$HOME_DIR/Pictures/Wallpapers}"
    ensure_dir "$wp_dir"

    local current_wp=""
    local state_file="${XDG_STATE_HOME:-$HOME_DIR/.local/state}/dotfiles/wallpaper-index"
    if [ -f "$state_file" ] && [ -d "$wp_dir" ]; then
      local idx=0
      read -r idx < "$state_file" || idx=0
      mapfile -t wps < <(find "$wp_dir" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | sort)
      if [ "${#wps[@]}" -gt 0 ]; then
        current_wp="${wps[$(( idx % ${#wps[@]} ))]}"
      fi
    fi
    if [ -z "$current_wp" ] && [ -d "$wp_dir" ]; then
      current_wp="$(find "$wp_dir" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | sort | head -n 1)"
    fi

    if [ -n "$current_wp" ] && [ -f "$current_wp" ]; then
      if [ "$DRY_RUN" = true ]; then
        log "[dry-run] would apply palette for $current_wp"
      elif [ -x "$SCRIPT_TARGET/wallpaper/apply-palette" ]; then
        "$SCRIPT_TARGET/wallpaper/apply-palette" "$current_wp" >/dev/null 2>&1 || true
      fi
    fi
  ); then
    if [ -n "$backup_id" ] && [ "$DRY_RUN" = false ]; then
      warn "Installation failed; restoring previous state from backup $backup_id"
      restore_backup "$backup_id"
    fi
    fail "Installation failed."
  fi

  success "Dotfiles installed successfully from $REPO_DIR into $HOME_DIR"
}

uninstall_repo() {
  info "Starting dotfiles removal from $HOME_DIR"

  local backup_id=""
  if [ "$USE_BACKUP" = true ]; then
    backup_id="$(date +%Y%m%d-%H%M%S)"
    if [ "$DRY_RUN" = true ]; then
      log "[dry-run] would create backup at $BACKUP_ROOT/$backup_id"
    else
      create_backup "$backup_id" >/dev/null
      success "Backup created at $BACKUP_ROOT/$backup_id"
    fi
  fi

  if ! (
    set -e
    for target in "${MANAGED_TARGETS[@]}"; do
      remove_if_exists "$target"
    done
  ); then
    if [ -n "$backup_id" ] && [ "$DRY_RUN" = false ]; then
      warn "Uninstall failed; restoring previous state from backup $backup_id"
      restore_backup "$backup_id"
    fi
    fail "Uninstall failed."
  fi

  success "Dotfiles removed successfully from $HOME_DIR"
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -i|--install)
        OPERATION="install"
        ;;
      -u|--uninstall)
        OPERATION="uninstall"
        ;;
      -r|--restore)
        OPERATION="restore"
        if [ "$#" -gt 1 ] && [[ "$2" != -* ]]; then
          CUSTOM_BACKUP_ID="$2"
          shift
        fi
        ;;
      -l|--list-backups)
        OPERATION="list-backups"
        ;;
      -n|--dry-run)
        DRY_RUN=true
        ;;
      -b|--backup-root)
        if [ "$#" -lt 2 ]; then
          fail "Missing value for $1"
        fi
        BACKUP_ROOT="$2"
        shift
        ;;
      --no-backup)
        USE_BACKUP=false
        ;;
      --skip-packages)
        SKIP_PACKAGES=true
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        fail "Unknown option: $1"
        ;;
    esac
    shift
  done
}

main() {
  parse_args "$@"

  case "$OPERATION" in
    install)
      install_repo
      ;;
    uninstall)
      uninstall_repo
      ;;
    restore)
      if [ -n "$CUSTOM_BACKUP_ID" ]; then
        restore_backup "$CUSTOM_BACKUP_ID"
      else
        local latest
        latest="$(latest_backup_id || true)"
        if [ -z "$latest" ]; then
          fail "No backups available in $BACKUP_ROOT"
        fi
        restore_backup "$latest"
      fi
      ;;
    list-backups)
      list_backups
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
