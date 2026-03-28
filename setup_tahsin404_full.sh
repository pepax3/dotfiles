#!/usr/bin/env bash
set -Eeuo pipefail

TARGET_USER="p"
TARGET_HOME="/home/${TARGET_USER}"
REPO_DIR="${TARGET_HOME}/Suckless"
DOTFILES_DIR="${TARGET_HOME}/dotfiles"
YAY_BUILD_DIR="${TARGET_HOME}/.cache/bootstrap/yay"
WALLPAPER="${REPO_DIR}/Wallpaper/gargantua-black-3840x2160-9621.jpg"

log()  { printf '\n[+] %s\n' "$*"; }
warn() { printf '\n[!] %s\n' "$*" >&2; }
die()  { printf '\n[-] %s\n' "$*" >&2; exit 1; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing command: $1"
}

require_target_user() {
  [ "$(id -un)" = "$TARGET_USER" ] || die "Run this script as user '$TARGET_USER', not $(id -un)."
  [ "$HOME" = "$TARGET_HOME" ] || warn "Current HOME is '$HOME', but this script targets '$TARGET_HOME'."
  [ -d "$TARGET_HOME" ] || die "Target home does not exist: $TARGET_HOME"
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
    return 0
  fi

  cp -a "${items[@]}" "$dst"/
}

copy_dir_clean() {
  local src="$1"
  local dst="$2"

  [ -d "$src" ] || {
    warn "Missing source directory: $src"
    return 0
  }

  if [ -e "$dst" ] || [ -L "$dst" ]; then
    backup_path "$dst"
  fi

  mkdir -p "$dst"
  cp -a "$src"/. "$dst"/
}

install_pacman_packages() {
  local pkgs=("$@")
  [ "${#pkgs[@]}" -gt 0 ] || return 0

  log "Installing official Arch packages"
  sudo pacman -Syu --needed --noconfirm "${pkgs[@]}"
}

clone_or_update() {
  local url="$1"
  local dir="$2"

  if [ -d "$dir/.git" ]; then
    if git -C "$dir" diff --quiet && git -C "$dir" diff --cached --quiet; then
      log "Updating $(basename "$dir")"
      git -C "$dir" pull --ff-only || warn "Could not fast-forward update $dir, keeping existing checkout"
    else
      warn "$dir has local changes, skipping git pull"
    fi
  elif [ -e "$dir" ]; then
    die "$dir exists but is not a git repo. Move or delete it first."
  else
    log "Cloning $(basename "$dir")"
    git clone --depth 1 "$url" "$dir"
  fi
}

install_yay() {
  if command -v yay >/dev/null 2>&1; then
    log "yay already installed"
    return 0
  fi

  log "Installing yay"
  mkdir -p "$(dirname "$YAY_BUILD_DIR")"
  clone_or_update "https://aur.archlinux.org/yay.git" "$YAY_BUILD_DIR"
  (
    cd "$YAY_BUILD_DIR"
    makepkg -si --noconfirm --needed
  )
}

install_yay_packages() {
  local pkgs=("$@")
  [ "${#pkgs[@]}" -gt 0 ] || return 0

  log "Installing AUR packages with yay"
  yay -S --needed --noconfirm --answerclean None --answerdiff None --removemake "${pkgs[@]}"
}

patch_repo_paths() {
  log "Patching hardcoded home paths to $TARGET_HOME"

  while IFS= read -r -d '' file; do
    sed -i "s|/home/xelius|$TARGET_HOME|g" "$file"
  done < <(grep -RIlZ '/home/xelius' "$REPO_DIR" "$DOTFILES_DIR" 2>/dev/null || true)
}

install_dotfiles() {
  log "Installing dotfiles from nested repo layout"

  mkdir -p "$TARGET_HOME/.config" "$TARGET_HOME/.cache/wal" "$TARGET_HOME/.local/share"

  declare -A dir_map=(
    ["$DOTFILES_DIR/hypr/.config/hypr"]="$TARGET_HOME/.config/hypr"
    ["$DOTFILES_DIR/kitty/.config/kitty"]="$TARGET_HOME/.config/kitty"
    ["$DOTFILES_DIR/nvim/.config/nvim"]="$TARGET_HOME/.config/nvim"
    ["$DOTFILES_DIR/picom/.config/picom"]="$TARGET_HOME/.config/picom"
    ["$DOTFILES_DIR/polybar/.config/polybar"]="$TARGET_HOME/.config/polybar"
    ["$DOTFILES_DIR/ranger/.config/ranger"]="$TARGET_HOME/.config/ranger"
    ["$DOTFILES_DIR/wal/.config/wal"]="$TARGET_HOME/.config/wal"
    ["$DOTFILES_DIR/waybar/.config/waybar"]="$TARGET_HOME/.config/waybar"
    ["$DOTFILES_DIR/wofi/.config/wofi"]="$TARGET_HOME/.config/wofi"
  )

  local src dst
  for src in "${!dir_map[@]}"; do
    dst="${dir_map[$src]}"
    [ -d "$src" ] && copy_dir_clean "$src" "$dst"
  done

  if [ -d "$DOTFILES_DIR/qt/.config" ]; then
    log "Copying qt config contents"
    copy_contents "$DOTFILES_DIR/qt/.config" "$TARGET_HOME/.config"
  fi

  if [ -f "$DOTFILES_DIR/bashrc" ]; then
    backup_path "$TARGET_HOME/.bashrc"
    cp -a "$DOTFILES_DIR/bashrc" "$TARGET_HOME/.bashrc"
  fi
}

install_suckless_support_files() {
  log "Installing support files from Suckless repo"

  mkdir -p "$TARGET_HOME/.config/polybar" "$TARGET_HOME/.config/picom" "$TARGET_HOME/.cache/wal"

  [ -f "$REPO_DIR/bar.sh" ] && install -m 755 "$REPO_DIR/bar.sh" "$TARGET_HOME/.config/polybar/bar.sh"
  [ -f "$REPO_DIR/config.ini" ] && install -m 644 "$REPO_DIR/config.ini" "$TARGET_HOME/.config/polybar/config.ini"

  if [ ! -f "$TARGET_HOME/.config/picom/picom.conf" ] && [ -f "$REPO_DIR/picom.conf" ]; then
    install -m 644 "$REPO_DIR/picom.conf" "$TARGET_HOME/.config/picom/picom.conf"
  fi

  [ -f "$REPO_DIR/starship.toml" ] && install -m 644 "$REPO_DIR/starship.toml" "$TARGET_HOME/.config/starship.toml"

  [ -f "$REPO_DIR/colors-wal-dwm.h" ] && install -m 644 "$REPO_DIR/colors-wal-dwm.h" "$TARGET_HOME/.cache/wal/colors-wal-dwm.h"
  [ -f "$REPO_DIR/colors-wal-dmenu.h" ] && install -m 644 "$REPO_DIR/colors-wal-dmenu.h" "$TARGET_HOME/.cache/wal/colors-wal-dmenu.h"
  [ -f "$REPO_DIR/colors-wal-st.h" ] && install -m 644 "$REPO_DIR/colors-wal-st.h" "$TARGET_HOME/.cache/wal/colors-wal-st.h"
}

write_hyprpaper_conf() {
  local hyprpaper_conf="$TARGET_HOME/.config/hypr/hyprpaper.conf"
  mkdir -p "$TARGET_HOME/.config/hypr"

  cat > "$hyprpaper_conf" <<EOF_HYPRPAPER
preload = $WALLPAPER
wallpaper = ,$WALLPAPER
splash = false
ipc = on
EOF_HYPRPAPER

  log "Wrote $hyprpaper_conf"
}

patch_hyprland_conf() {
  local hyprconf="$TARGET_HOME/.config/hypr/hyprland.conf"
  [ -f "$hyprconf" ] || return 0

  log "Patching Hyprland config"

  sed -i 's|exec-once = quickshell|exec-once = waybar|g' "$hyprconf"

  if ! grep -Fq 'exec-once = waybar' "$hyprconf"; then
    printf '\nexec-once = waybar\n' >> "$hyprconf"
  fi
}

run_pywal() {
  if [ -f "$WALLPAPER" ]; then
    log "Generating pywal colors from wallpaper"
    wal -i "$WALLPAPER"
  else
    warn "Wallpaper not found: $WALLPAPER"
  fi
}

refresh_font_cache() {
  log "Refreshing font cache"
  fc-cache -fv >/dev/null
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
  local xinit="$TARGET_HOME/.xinitrc"
  backup_path "$xinit"

  cat > "$xinit" <<EOF_XINIT
#!/bin/sh

[ -f "\$HOME/.Xresources" ] && xrdb -merge "\$HOME/.Xresources"
[ -f "\$HOME/.cache/wal/sequences" ] && cat "\$HOME/.cache/wal/sequences"
[ -f "\$HOME/.cache/wal/colors.Xresources" ] && xrdb -merge "\$HOME/.cache/wal/colors.Xresources"

[ -f "$WALLPAPER" ] && feh --bg-fill "$WALLPAPER" &

if command -v picom >/dev/null 2>&1; then
  if [ -f "\$HOME/.config/picom/picom.conf" ]; then
    picom --config "\$HOME/.config/picom/picom.conf" &
  else
    picom &
  fi
fi

if command -v polybar >/dev/null 2>&1; then
  if [ -x "\$HOME/.config/polybar/bar.sh" ]; then
    "\$HOME/.config/polybar/bar.sh" &
  fi
fi

exec dwm
EOF_XINIT

  chmod +x "$xinit"
  log "Wrote $xinit"
}

enable_services() {
  log "Enabling useful system services"
  sudo systemctl enable --now NetworkManager.service || warn "Could not enable NetworkManager"
  sudo systemctl enable --now bluetooth.service || warn "Could not enable bluetooth"
}

main() {
  require_target_user

  need_cmd bash
  need_cmd git
  need_cmd make
  need_cmd pacman
  need_cmd sudo
  need_cmd grep
  need_cmd sed
  need_cmd install
  need_cmd fc-cache

  local official_packages=(
    base-devel git go curl wget unzip pkgconf cmake meson ninja
    xorg-server xorg-xinit xorg-xrdb feh
    libx11 libxinerama libxft imlib2 freetype2 harfbuzz fontconfig
    jsoncpp yajl python python-pywal starship ranger neovim kitty dolphin
    hyprland hyprpaper quickshell waybar wofi wl-clipboard grim slurp
    qt6ct xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-hyprland
    polkit-kde-agent udiskie udisks2 brightnessctl playerctl
    pavucontrol blueman bluez bluez-utils networkmanager
    pipewire wireplumber cava flameshot mpd
    ttf-hack-nerd ttf-firacode-nerd ttf-lekton-nerd ttf-monofur-nerd
  )

  local aur_packages=(
    polybar-dwm-git
    picom-ftlabs-git
    wlogout
    bashtop-git
  )

  install_pacman_packages "${official_packages[@]}"
  install_yay
  install_yay_packages "${aur_packages[@]}"

  clone_or_update "https://github.com/Tahsin404/Suckless.git" "$REPO_DIR"
  clone_or_update "https://github.com/Tahsin404/dotfiles.git" "$DOTFILES_DIR"

  patch_repo_paths
  install_dotfiles
  install_suckless_support_files
  write_hyprpaper_conf
  patch_hyprland_conf
  run_pywal
  refresh_font_cache

  build_and_install "$REPO_DIR/slstatus"
  build_and_install "$REPO_DIR/dwm"
  build_and_install "$REPO_DIR/st"
  build_and_install "$REPO_DIR/dmenu"

  write_xinitrc
  enable_services

  log "Finished successfully"
  printf '\nDWM start:\n  startx\n\n'
  printf 'Hyprland start from TTY:\n  Hyprland\n\n'
  printf 'Optional auto-start on tty1 in ~/.bash_profile:\n'
  printf '  [[ -z $DISPLAY && $(tty) = /dev/tty1 ]] && exec startx\n\n'
}

main "$@"
