#!/usr/bin/env bash
# setup-arch.sh — user-friendly Arch install helper
# Date: 2026-02-09
set -euo pipefail
trap 'echo "Error on line $LINENO. Exiting." >&2' ERR

# --- Configurable ---
WORKDIR="${WORKDIR:-/tmp/.archstp}"
TARGET_USER="${SUDO_USER:-$USER}"
HOME_DIR="$(eval echo "~$TARGET_USER")"
RUN_AS_ROOT=false        # set true to require running script as root
PARU_GIT="https://aur.archlinux.org/paru.git"
HATTER_GIT="https://github.com/vinceliuice/Hatter-icon-theme.git"
SWAY_DOTS_REPO="https://github.com/piratheon/sway-noctalia-dots"   # trusted
NUSHELL_CONF="https://raw.githubusercontent.com/piratheon/nushell-config/refs/heads/main/config.nu"  # trusted
OMP_THEME="https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/refs/heads/main/themes/half-life.omp.json"

# --- Helper funcs ---
log(){ echo -e "\n==> $*"; }
confirm_or_quit(){
  read -r -p "$1 [y/N]: " ans
  case "$ans" in [Yy]*) return 0;; *) echo "Aborted."; exit 1;; esac
}

# --- Preconditions ---
if $RUN_AS_ROOT && [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root. Re-run with sudo." >&2
  exit 1
fi

mkdir -p "$WORKDIR"
cd "$WORKDIR"

log "Running as user: $TARGET_USER (home: $HOME_DIR)"
sudo -v || { echo "sudo required"; exit 1; }

# Keep a cached sudo session for duration
( while true; do sudo -v; sleep 60; done ) & disown || true

# --- 1. System update ---
log "1 — System update (pacman -Syu)"
sudo pacman -Syu --noconfirm

# --- 2. Essential build tools & git ---
log "2 — Install base-devel and git"
sudo pacman -S --needed --noconfirm base-devel git

# --- 3. Install paru (AUR helper) as non-root builder ---
if [ ! -d "$WORKDIR/paru" ]; then
  log "Cloning paru AUR repo"
  git clone "$PARU_GIT" "$WORKDIR/paru"
fi
cd "$WORKDIR/paru"
log "Building and installing paru"
# build as target user
sudo -u "$TARGET_USER" bash -c "cd \"$WORKDIR/paru\" && makepkg -si --noconfirm"
cd "$WORKDIR"

# --- 4. Configure mirrors & install paru-scanned packages ---
log "4 — Install paru utilities and refresh mirrors"
sudo pacman -S --needed --noconfirm reflector
# Install traurig (AUR) via paru; handle idempotent install
paru -S --noconfirm --needed traur || true
# Update mirrorlist (requires sudo)
sudo reflector --latest 5 --age 2 --fastest 5 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
log "Mirrorlist updated:"
sudo head -n 20 /etc/pacman.d/mirrorlist || true

# --- 5. Install packages (system + AUR) ---
log "5 — Installing packages (system + AUR)"
pkgs=(
  nautilus wezterm vimcat eza rg update-grub brave-bin qs oh-my-posh fish bat swayfx steam waydroid
  wine-mono wine-gecko wine npm cmake onlyoffice flatpak pamac obsidian-desktop nmap jre8-openjdk
  yt-dlp nvim localsend virtualbox krita gimp peazip fastfetch scrcpy telegram-desktop code # code maps to vscode in some AURs
  vlc tree bleachbit btop nu gpm
)
# Note: paru will install both repo and AUR packages as needed
paru -Syu --noconfirm --needed "${pkgs[@]}" || {
  echo "Some packages failed to install. Review output and rerun for missing ones." >&2
}

# --- 6. Shell & user config (run as target user) ---
log "6 — Prepare shell for $TARGET_USER"
# Ensure config directories
sudo -u "$TARGET_USER" mkdir -p "$HOME_DIR/.config/oh-my-posh/themes" "$HOME_DIR/.config/nushell"

# Install oh-my-posh theme
sudo -u "$TARGET_USER" bash -c "curl -fsSL '$OMP_THEME' -o '$HOME_DIR/.config/oh-my-posh/themes/half-life.omp.json'"

# Install nushell config (trusted repo)
sudo -u "$TARGET_USER" bash -c "curl -fsSL '$NUSHELL_CONF' -o '$HOME_DIR/.config/nushell/config.nu' || true"
sudo -u "$TARGET_USER" chmod +x "$HOME_DIR/.config/nushell/config.nu" || true

# Change shell to nu if installed
if command -v nu >/dev/null 2>&1; then
  log "Changing login shell to nushell for $TARGET_USER"
  sudo chsh -s "$(command -v nu)" "$TARGET_USER" || true
fi

# Enable gpm service (console mouse) if available
if systemctl list-unit-files | grep -q '^gpm'; then
  sudo systemctl enable --now gpm || true
fi

# --- 7. SwayFX / UI tweaks (trusted sway repo and icon theme) ---
log "7 — SwayFX & UI setup"
# Install related packages
paru -S --noconfirm --needed noctalia-shell ffmpeg audio-recorder grim wl-clipboard wf-recorder polkit-gnome dbus avizo gnome-keyring libinput-gestures tracker wlsunset autotiling || true

# Icon theme (silent install)
if [ ! -d "$WORKDIR/Hatter-icon-theme" ]; then
  git clone "$HATTER_GIT" "$WORKDIR/Hatter-icon-theme"
fi
# run installer non-interactively if present
if [ -x "$WORKDIR/Hatter-icon-theme/install.sh" ]; then
  bash "$WORKDIR/Hatter-icon-theme/install.sh" --silent || true
fi

# Clone your trusted sway dots into user's config
sudo -u "$TARGET_USER" bash -c "rm -rf '$HOME_DIR/.config/sway' && git clone '$SWAY_DOTS_REPO' '$HOME_DIR/.config/sway' || true"
# Move settings.json into noctalia dir if present
sudo -u "$TARGET_USER" bash -c "mkdir -p '$HOME_DIR/.config/sway/noctalia' || true"
if [ -f "$HOME_DIR/.config/sway/settings.json" ]; then
  sudo -u "$TARGET_USER" mv "$HOME_DIR/.config/sway/settings.json" "$HOME_DIR/.config/sway/noctalia/settings.json" || true
fi
sudo -u "$TARGET_USER" bash -c "chmod +x '$HOME_DIR/.config/sway/scripts/'* 2>/dev/null || true"

# --- 8. Display manager (ly) handling ---
log "8 — Install and configure ly (display manager)"
DM_SERVICE="/etc/systemd/system/display-manager.service"
if [ -L "$DM_SERVICE" ]; then
  current=$(readlink -f "$DM_SERVICE" || true)
  if [ -n "$current" ]; then
    name=$(basename "$current")
    log "Detected display manager target: $name — disabling it"
    sudo systemctl stop "$name" || true
    sudo systemctl disable "$name" || true
  fi
else
  log "No display manager symlink detected — safe to enable ly"
fi

paru -S --noconfirm --needed ly || true
# Prefer enabling ly.service (single instance) — if you specifically want tty2 enable ly@tty2
sudo systemctl enable --now ly.service || sudo systemctl enable --now ly@tty2.service || true

# --- 9. Final notes and cleanup ---
log "9 — Final tasks"
echo "Workspace used: $WORKDIR"
echo "Some actions (shell change, systemd enables) were performed for $TARGET_USER."
echo "Reboot recommended to ensure all services and kernel updates are active."

# offer cleanup prompt
if confirm_or_quit "Remove working directory $WORKDIR?"; then
  rm -rf "$WORKDIR"
  echo "Workdir removed."
fi

echo "Done."
