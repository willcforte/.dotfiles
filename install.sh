#!/usr/bin/env bash
# Single idempotent entry point for Ubuntu: installs any missing prerequisites
# (apt packages, rust, nix) and then applies the flake config (home-manager +
# system-manager). Safe to run anytime — it is both the installer and the
# updater. home.nix symlinks it to ~/.local/bin/update-config, so
# `update-config` and `./install.sh` do the same thing.
#
# Parity note vs the macOS install-darwin.sh: on Linux the system apply
# (system-manager --sudo) always needs sudo, and apt/apparmor need root too —
# so those two are guarded (dpkg / file compare) to skip entirely, and skip
# their sudo prompts, on routine config updates when nothing is missing.
set -euo pipefail

# Hardcoded (not derived from $BASH_SOURCE) so it works the same whether run
# from the repo or via the ~/.local/bin/update-config symlink.
DOTFILES="$HOME/.dotfiles"
cd "$DOTFILES"

#-----------------------------------------------------------
# 1. apt packages (guarded: skip the whole section — and its sudo — when every
#    package in packages/apt.txt is already installed).
#-----------------------------------------------------------
mapfile -t apt_pkgs < <(grep -vE '^[[:space:]]*(#|$)' packages/apt.txt)
apt_missing=0
for p in "${apt_pkgs[@]}"; do
  dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q 'install ok installed' || apt_missing=1
done
if [ "$apt_missing" -eq 1 ]; then
  echo "==> Installing apt packages (sudo required)"
  sudo apt-get update
  sudo apt-get install -y ca-certificates curl wget gnupg software-properties-common

  # Tailscale third-party repo (keys + source).
  sudo install -d -m 0755 /etc/apt/keyrings
  codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"
  curl -fsSL "https://pkgs.tailscale.com/stable/ubuntu/${codename}.noarmor.gpg" |
    sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
  curl -fsSL "https://pkgs.tailscale.com/stable/ubuntu/${codename}.tailscale-keyring.list" |
    sudo tee /etc/apt/sources.list.d/tailscale.list >/dev/null

  sudo apt-get update
  grep -vE '^[[:space:]]*(#|$)' packages/apt.txt | xargs sudo apt-get install -y
fi

#-----------------------------------------------------------
# 2. Rust toolchain (via rustup) — for Rust development only; Rust-built CLI
#    tools (bat, fd, ripgrep, ...) come from home-manager (see home.nix).
#-----------------------------------------------------------
if ! command -v rustup >/dev/null 2>&1 && [ ! -x "$HOME/.cargo/bin/rustup" ]; then
  echo "==> Installing Rust"
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
fi

#-----------------------------------------------------------
# 3. Nix (Determinate Systems installer — reliable on Linux; the macOS box
#    uses the plain installer instead, see install-darwin.sh) + flakes.
#-----------------------------------------------------------
if ! command -v nix >/dev/null 2>&1 && [ ! -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
  echo "==> Installing Nix"
  curl -fsSL https://install.determinate.systems/nix | sh -s -- install --no-confirm
fi
if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
  # nix-daemon.sh references unset vars; relax nounset while sourcing.
  set +u
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  set -u
fi
mkdir -p "$HOME/.config/nix"
if ! grep -qs 'experimental-features.*flakes' "$HOME/.config/nix/nix.conf" 2>/dev/null; then
  echo "==> Enabling nix flakes for user"
  echo "experimental-features = nix-command flakes" >>"$HOME/.config/nix/nix.conf"
fi

#-----------------------------------------------------------
# 4. Apply home-manager (user env; auto-selects will@<hostname>). Prefer the
#    installed CLI once present (faster, no flake re-fetch).
#-----------------------------------------------------------
echo "==> Applying home-manager configuration"
if command -v home-manager >/dev/null 2>&1; then
  home-manager switch -b backup --flake "$DOTFILES"
else
  nix run home-manager/master -- switch -b backup --flake "$DOTFILES"
fi
export PATH="$HOME/.nix-profile/bin:$PATH"

#-----------------------------------------------------------
# 4b. Register nix zsh in /etc/shells and set it as the login shell.
#     usermod avoids an interactive password prompt (unlike chsh).
#-----------------------------------------------------------
ZSH_PATH="$(command -v zsh)"
if ! grep -qxF "$ZSH_PATH" /etc/shells 2>/dev/null; then
  echo "==> Adding $ZSH_PATH to /etc/shells"
  echo "$ZSH_PATH" | sudo tee -a /etc/shells >/dev/null
fi
if [ "$(getent passwd "$USER" | cut -d: -f7)" != "$ZSH_PATH" ]; then
  echo "==> Setting login shell to $ZSH_PATH"
  sudo usermod -s "$ZSH_PATH" "$USER"
fi

#-----------------------------------------------------------
# 5. Apply system-manager (system /etc, systemd). Self-escalates via --sudo,
#    so it prompts for the sudo password.
#-----------------------------------------------------------
echo "==> Applying system-manager configuration"
# system-manager refuses to overwrite an /etc file it does not already own.
# The Nix installer's /etc/nix/nix.conf is such a file; move it aside on the
# first run so system-manager can take over. Idempotent: once system-manager
# owns it, the file carries our trusted-users line and this is skipped.
if [ -f /etc/nix/nix.conf ] && ! grep -q '^trusted-users' /etc/nix/nix.conf; then
  echo "==> Moving pre-existing /etc/nix/nix.conf aside for system-manager"
  sudo mv /etc/nix/nix.conf /etc/nix/nix.conf.pre-system-manager
fi
nix run 'github:numtide/system-manager' -- switch --flake "$DOTFILES" --sudo

#-----------------------------------------------------------
# 6. GitHub CLI auth (interactive — requires a browser; skipped once authed).
#-----------------------------------------------------------
if command -v gh >/dev/null 2>&1 && ! gh auth status >/dev/null 2>&1; then
  echo "==> Authenticating with GitHub"
  gh auth login
fi

#-----------------------------------------------------------
# 7. AppArmor profiles for nix GUI-app sandboxes (guarded: skip — and skip its
#    sudo — when every profile is already installed identically). Allows the
#    user namespaces that nix-installed browsers/Electron apps need on 24.04.
#-----------------------------------------------------------
apparmor_needed=0
for profile in "$DOTFILES"/apparmor/*; do
  name="$(basename "$profile")"
  cmp -s "$profile" "/etc/apparmor.d/$name" || apparmor_needed=1
done
if [ "$apparmor_needed" -eq 1 ]; then
  echo "==> Installing AppArmor profiles (sudo required)"
  for profile in "$DOTFILES"/apparmor/*; do
    name="$(basename "$profile")"
    sudo install -m 0644 "$profile" "/etc/apparmor.d/$name"
    sudo apparmor_parser -r "/etc/apparmor.d/$name"
  done
fi

echo "==> Done. Open a new shell to pick up PATH changes."
