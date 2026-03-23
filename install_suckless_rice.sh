#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR="$HOME/Suckless"
DOTFILES_DIR="$HOME/dotfiles"
WALLPAPER="$REPO_DIR/Wallpaper/gargantua-black-3840x2160-9621.jpg"

log()  { printf '\n[+] %s\n' "$*"; }
warn() { printf '\n[!] %s\n' "$*" >&2; }
die()  { printf '\n[-] %s\n' "$*" >&2; exit 1; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing command: $1"
}

clone_or_update() {
  local url="$1"
  local dir="$2"

  if [ -d "$dir/.git" ]; then
    log "Updating $(basename "$dir")"
    git -C "$dir" pull --ff-only
  elif [ -e "$dir" ]; then
    die "$dir exists but is not a git repo. Move or delete it first."
  else
    log "Cloning $(basename "$dir")"
    git clone "$url" "$dir"
  fi
}

backup_path() {
  local target="$1"
  if [ -e "$target" ] || [ -L "$target" ]; then
    local backup="${target}.bak.$(date +%s)"
    warn "Backing up $target -> $backup"
    mv "$target" "$backup"
  fi
}

copy_contents() {
  local src="$1"
  local dst="$2"

  mkdir -p "$dst"
  shopt -s dotglob nullglob
  local items=("$src"/*)
  shopt -u dotglob

  if [ "${#items[@]}" -eq 0 ]; then
    warn "Nothing found in $src"
    return
  fi

  cp -a "${items[@]}" "$dst"/
}

build_and_install() {
  local dir="$1"
  [ -d "$dir" ] || die "Missing directory: $dir"

  log "Building $(basename "$dir")"
  make -C "$dir"

  log "Installing $(basename "$dir")"
  sudo make -C "$dir" clean install
}

write_xinitrc() {
  local xinit="$HOME/.xinitrc"
  backup_path "$xinit"

  cat > "$xinit" <<EOF
#!/bin/sh

[ -f "\$HOME/.Xresources" ] && xrdb -merge "\$HOME/.Xresources"

# pywal colors
[ -f "\$HOME/.cache/wal/sequences" ] && cat "\$HOME/.cache/wal/sequences"
[ -f "\$HOME/.cache/wal/colors.Xresources" ] && xrdb -merge "\$HOME/.cache/wal/colors.Xresources"

# wallpaper
[ -f "$WALLPAPER" ] && feh --bg-fill "$WALLPAPER" &

# compositor
if command -v picom >/dev/null 2>&1; then
  if [ -f "\$HOME/.config/picom/picom.conf" ]; then
    picom --config "\$HOME/.config/picom/picom.conf" &
  else
    picom &
  fi
fi

# polybar
if command -v polybar >/dev/null 2>&1; then
  if [ -x "\$HOME/.config/polybar/launch.sh" ]; then
    "\$HOME/.config/polybar/launch.sh" &
  else
    polybar &
  fi
fi

exec dwm
EOF

  chmod +x "$xinit"
  log "Wrote $xinit"
}

main() {
  for cmd in git make sudo wal feh xrdb fc-cache; do
    need_cmd "$cmd"
  done

  log "Checking optional runtime tools"
  for cmd in picom polybar starship ranger; do
    if command -v "$cmd" >/dev/null 2>&1; then
      printf '[ok] %s found\n' "$cmd"
    else
      printf '[warn] %s not found\n' "$cmd"
    fi
  done

  clone_or_update "https://github.com/Tahsin404/Suckless.git" "$REPO_DIR"
  clone_or_update "https://github.com/Tahsin404/dotfiles.git" "$DOTFILES_DIR"

  mkdir -p "$HOME/.config" "$HOME/.cache/wal"

  if [ -d "$DOTFILES_DIR/.config" ]; then
    log "Backing up conflicting config dirs"
    for dir in polybar picom ranger; do
      if [ -e "$HOME/.config/$dir" ] && [ -e "$DOTFILES_DIR/.config/$dir" ]; then
        backup_path "$HOME/.config/$dir"
      fi
    done

    log "Copying dotfiles config"
    copy_contents "$DOTFILES_DIR/.config" "$HOME/.config"
  else
    warn "No .config directory found in $DOTFILES_DIR"
  fi

  if [ -d "$DOTFILES_DIR/.cache/wal" ]; then
    log "Refreshing wal cache files from dotfiles"
    rm -rf "$HOME/.cache/wal"
    mkdir -p "$HOME/.cache/wal"
    copy_contents "$DOTFILES_DIR/.cache/wal" "$HOME/.cache/wal"
  else
    warn "No .cache/wal found in $DOTFILES_DIR"
  fi

  if [ -f "$WALLPAPER" ]; then
    log "Generating pywal colors from wallpaper"
    wal -i "$WALLPAPER"
  else
    warn "Wallpaper not found: $WALLPAPER"
  fi

  log "Refreshing font cache"
  fc-cache -fv >/dev/null

  build_and_install "$REPO_DIR/dwm"
  build_and_install "$REPO_DIR/st"
  build_and_install "$REPO_DIR/dmenu"

  write_xinitrc

  log "Finished successfully"
  printf '\nRun this to start:\n'
  printf '  startx\n\n'
  printf 'Optional tty1 auto-start in ~/.bash_profile:\n'
  printf '  [[ -z $DISPLAY && $(tty) = /dev/tty1 ]] && exec startx\n\n'
}

main "$@"
