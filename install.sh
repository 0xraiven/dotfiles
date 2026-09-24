#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="${HOME}"
BACKUP_ROOT="${DOTFILES_BACKUP_ROOT:-$HOME_DIR/.dotfiles-backups}"
OPERATION="install"
DRY_RUN=false
CUSTOM_BACKUP_ID=""
USE_BACKUP=true

MANAGED_TARGETS=(
  "$HOME_DIR/.config/hypr"
  "$HOME_DIR/.config/waybar"
  "$HOME_DIR/.config/fish"
  "$HOME_DIR/.config/kitty"
  "$HOME_DIR/.config/quickshell"
  "$HOME_DIR/.local/bin"
  "$HOME_DIR/.local/share/dotfiles-assets"
)

usage() {
  cat <<EOF
Usage: $(basename "$0") [flags]

Flags:
  -i, --install            Install the repo-managed configs into $HOME
  -u, --uninstall          Remove installed dotfiles from $HOME
  -r, --restore [ID]      Restore the latest backup or a specific backup ID
  -l, --list-backups       List all available backups
  -n, --dry-run            Show what would happen without changing files
  -b, --backup-root DIR    Override the backup directory
  --no-backup              Skip automatic backups before install/uninstall
  -h, --help               Show this help

Examples:
  $(basename "$0") --install
  $(basename "$0") --uninstall
  $(basename "$0") --restore
  $(basename "$0") --restore 20260924-190530
  $(basename "$0") --list-backups
EOF
}

log() {
  echo "$*"
}

fail() {
  echo "Error: $*" >&2
  exit 1
}

ensure_dir() {
  local dir="$1"
  if [ "$DRY_RUN" = true ]; then
    echo "[dry-run] mkdir -p $dir"
    return 0
  fi
  mkdir -p "$dir"
}

copy_tree() {
  local src="$1"
  local dst="$2"
  if [ "$DRY_RUN" = true ]; then
    echo "[dry-run] cp -a $src/. $dst/"
    return 0
  fi

  if [ ! -d "$src" ]; then
    return 0
  fi

  ensure_dir "$dst"
  cp -a "$src/." "$dst/"
}

remove_if_exists() {
  local target="$1"
  if [ "$DRY_RUN" = true ]; then
    if [ -e "$target" ] || [ -L "$target" ]; then
      echo "[dry-run] rm -rf $target"
    fi
    return 0
  fi

  if [ -e "$target" ] || [ -L "$target" ]; then
    rm -rf "$target"
  fi
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
    echo "No backups found in $BACKUP_ROOT"
    return 0
  fi

  find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort
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
        echo "[dry-run] cp -a $target $backup_dir/$rel"
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

  if [ "$DRY_RUN" = true ]; then
    log "[dry-run] Restoring backup $backup_id"
    while IFS= read -r item; do
      rel="${item#$backup_dir/}"
      target="$HOME_DIR/$rel"
      echo "[dry-run] restore $backup_dir/$rel -> $target"
    done < <(find "$backup_dir" -mindepth 1 -printf '%P\n' | sort)
    return 0
  fi

  while IFS= read -r item; do
    rel="${item#$backup_dir/}"
    target="$HOME_DIR/$rel"

    if [ -e "$target" ] || [ -L "$target" ]; then
      rm -rf "$target"
    fi

    ensure_dir "$(dirname "$target")"
    cp -a "$backup_dir/$rel" "$target"
  done < <(find "$backup_dir" -mindepth 1 -printf '%P\n' | sort)
}

install_repo() {
  local backup_id=""

  if [ "$USE_BACKUP" = true ]; then
    backup_id="$(date +%Y%m%d-%H%M%S)"
    if [ "$DRY_RUN" = true ]; then
      log "[dry-run] would create backup $BACKUP_ROOT/$backup_id"
      create_backup "$backup_id"
    else
      create_backup "$backup_id"
      log "Backup created at $BACKUP_ROOT/$backup_id"
    fi
  fi

  if [ "$DRY_RUN" = true ]; then
    log "[dry-run] install from $REPO_DIR into $HOME_DIR"
    echo "[dry-run] would install hypr config"
    copy_tree "$REPO_DIR/hypr/.config/hypr" "$HOME_DIR/.config/hypr"
    copy_tree "$REPO_DIR/waybar/.config/waybar" "$HOME_DIR/.config/waybar"
    copy_tree "$REPO_DIR/fish/.config/fish" "$HOME_DIR/.config/fish"
    if [ -d "$REPO_DIR/kitty/.config/kitty" ]; then copy_tree "$REPO_DIR/kitty/.config/kitty" "$HOME_DIR/.config/kitty"; fi
    if [ -d "$REPO_DIR/quickshell/.config/quickshell" ]; then copy_tree "$REPO_DIR/quickshell/.config/quickshell" "$HOME_DIR/.config/quickshell"; fi
    if [ -d "$REPO_DIR/scripts/.local/bin" ]; then
      ensure_dir "$HOME_DIR/.local/bin"
      echo "[dry-run] cp -a $REPO_DIR/scripts/.local/bin/. $HOME_DIR/.local/bin/"
    fi
    if [ -d "$REPO_DIR/assets" ]; then
      ensure_dir "$HOME_DIR/.local/share"
      echo "[dry-run] cp -a $REPO_DIR/assets $HOME_DIR/.local/share/dotfiles-assets"
    fi
    return 0
  fi

  if ! (
    set -e
    copy_tree "$REPO_DIR/hypr/.config/hypr" "$HOME_DIR/.config/hypr"
    copy_tree "$REPO_DIR/waybar/.config/waybar" "$HOME_DIR/.config/waybar"
    copy_tree "$REPO_DIR/fish/.config/fish" "$HOME_DIR/.config/fish"

    if [ -d "$REPO_DIR/kitty/.config/kitty" ]; then
      copy_tree "$REPO_DIR/kitty/.config/kitty" "$HOME_DIR/.config/kitty"
    fi

    if [ -d "$REPO_DIR/quickshell/.config/quickshell" ]; then
      copy_tree "$REPO_DIR/quickshell/.config/quickshell" "$HOME_DIR/.config/quickshell"
    fi

    if [ -d "$REPO_DIR/scripts/.local/bin" ]; then
      ensure_dir "$HOME_DIR/.local/bin"
      cp -a "$REPO_DIR/scripts/.local/bin/." "$HOME_DIR/.local/bin/"
    fi

    if [ -d "$REPO_DIR/assets" ]; then
      ensure_dir "$HOME_DIR/.local/share"
      rm -rf "$HOME_DIR/.local/share/dotfiles-assets"
      cp -a "$REPO_DIR/assets" "$HOME_DIR/.local/share/dotfiles-assets"
    fi
  ); then
    if [ -n "$backup_id" ]; then
      echo "Install failed; restoring previous state from backup $backup_id" >&2
      restore_backup "$backup_id"
    fi
    return 1
  fi

  log "Dotfiles installed successfully from $REPO_DIR into $HOME_DIR"
}

uninstall_repo() {
  local backup_id=""

  if [ "$USE_BACKUP" = true ]; then
    backup_id="$(date +%Y%m%d-%H%M%S)"
    if [ "$DRY_RUN" = true ]; then
      log "[dry-run] would create backup $BACKUP_ROOT/$backup_id"
      create_backup "$backup_id"
    else
      create_backup "$backup_id"
      log "Backup created at $BACKUP_ROOT/$backup_id"
    fi
  fi

  if [ "$DRY_RUN" = true ]; then
    log "[dry-run] uninstall from $HOME_DIR"
    for target in "${MANAGED_TARGETS[@]}"; do
      remove_if_exists "$target"
    done
    return 0
  fi

  if ! (
    set -e
    for target in "${MANAGED_TARGETS[@]}"; do
      remove_if_exists "$target"
    done
  ); then
    if [ -n "$backup_id" ]; then
      echo "Uninstall failed; restoring previous state from backup $backup_id" >&2
      restore_backup "$backup_id"
    fi
    return 1
  fi

  log "Dotfiles removed successfully from $HOME_DIR"
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
      log "Backup restored from $BACKUP_ROOT"
      ;;
    "list-backups")
      list_backups
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
