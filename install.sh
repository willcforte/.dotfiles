#!/usr/bin/env bash
# Single idempotent entry point for Ubuntu and macOS: installs any missing
# prerequisites and then applies the flake config (home-manager everywhere,
# plus system-manager on Linux / nix-darwin on macOS). Safe to run anytime —
# it is both the installer and the updater. home.nix symlinks it to
# ~/.local/bin/update-config, so `update-config` and `./install.sh` do the
# same thing on either platform.
#
# Steps that genuinely differ per OS are branched inline (if/elif on $OS) so
# shared steps stay written once — fixes to shared logic apply to both
# platforms automatically instead of needing to be ported between two files.
set -euo pipefail

case "$(uname)" in
Linux) OS=linux ;;
Darwin) OS=darwin ;;
*)
  echo "install.sh only supports Linux (Ubuntu) and macOS." >&2
  exit 1
  ;;
esac

# Hardcoded (not derived from $BASH_SOURCE) so it works the same whether run
# from the repo or via the ~/.local/bin/update-config symlink.
DOTFILES="$HOME/.dotfiles"
cd "$DOTFILES"

if [ ! -d "$HOME/.dotfiles-private" ]; then
  echo "WARNING: ~/.dotfiles-private not cloned — some private assets this config depends on will be missing; clone it with: git clone git@github.com:willcforte/.dotfiles-private ~/.dotfiles-private" >&2
fi

#-----------------------------------------------------------
# 1. apt packages (Linux, sudo required) / Homebrew (macOS). Apt section is
#    guarded: skip the whole section — and its sudo — when every package in
#    packages/apt.txt is already installed.
#-----------------------------------------------------------
if [ "$OS" = linux ]; then
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
elif [ "$OS" = darwin ]; then
  # nix-darwin's `homebrew` module (darwin/system.nix) manages casks
  # declaratively but will not install Homebrew itself — it just skips with a
  # warning if `brew` isn't already on PATH.
  if ! command -v brew >/dev/null 2>&1; then
    echo "==> Installing Homebrew"
    unset NONINTERACTIVE
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  [ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"
fi

#-----------------------------------------------------------
# 2. Nix. Linux uses the Determinate Systems installer (reliable there); macOS
#    uses the plain upstream installer instead — the Determinate installer
#    currently crashes on Apple Silicon while reading TLS trust certs from
#    Keychain during encrypted-volume creation, a known open bug:
#    https://github.com/DeterminateSystems/nix-installer/issues/1514
#-----------------------------------------------------------
if ! command -v nix >/dev/null 2>&1 && [ ! -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
  echo "==> Installing Nix"
  if [ "$OS" = linux ]; then
    curl -fsSL https://install.determinate.systems/nix | sh -s -- install --no-confirm
  else
    sh <(curl -L https://nixos.org/nix/install) --daemon
  fi
fi
if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
  # nix-daemon.sh references unset vars; relax nounset while sourcing.
  set +u
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  set -u
fi

#-----------------------------------------------------------
# 3. Enable nix flakes for the user (shared: neither installer sets this in
#    /etc/nix/nix.conf, and it's needed for the flake-based switches below).
#-----------------------------------------------------------
mkdir -p "$HOME/.config/nix"
if ! grep -qs 'experimental-features.*flakes' "$HOME/.config/nix/nix.conf" 2>/dev/null; then
  echo "==> Enabling nix flakes for user"
  echo "experimental-features = nix-command flakes" >>"$HOME/.config/nix/nix.conf"
fi

#-----------------------------------------------------------
# 4. Rust toolchain (via rustup, shared) — for Rust development only;
#    Rust-built CLI tools (bat, fd, ripgrep, ...) come from home-manager (see
#    home.nix).
#-----------------------------------------------------------
if ! command -v rustup >/dev/null 2>&1 && [ ! -x "$HOME/.cargo/bin/rustup" ]; then
  echo "==> Installing Rust"
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
fi

#-----------------------------------------------------------
# 5. pixi (macOS only; self-updating binary. home.nix puts ~/.pixi/bin on
#    PATH declaratively via home.sessionPath).
#-----------------------------------------------------------
if [ "$OS" = darwin ]; then
  if ! command -v pixi >/dev/null 2>&1 && [ ! -x "$HOME/.pixi/bin/pixi" ]; then
    echo "==> Installing pixi"
    curl -fsSL https://pixi.sh/install.sh | PIXI_NO_PATH_UPDATE=1 sh
  fi
fi

#-----------------------------------------------------------
# 6. Apply home-manager (user env; shared). Prefer the installed CLI once
#    present (faster, no flake re-fetch). Linux boxes' hostnames match their
#    flake output names, so a bare --flake auto-selects will@<hostname>; the
#    Mac's hostname doesn't, so its output is targeted explicitly.
#-----------------------------------------------------------
if [ "$OS" = linux ]; then
  HM_TARGET="$DOTFILES"
else
  HM_TARGET="$DOTFILES#will@will-mbp"
fi
echo "==> Applying home-manager configuration"
if command -v home-manager >/dev/null 2>&1; then
  home-manager switch -b backup --flake "$HM_TARGET"
else
  nix run home-manager/master -- switch -b backup --flake "$HM_TARGET"
fi
export PATH="$HOME/.nix-profile/bin:$PATH"
if [ "$OS" = linux ]; then
  nix-collect-garbage --delete-older-than 14d
fi

#-----------------------------------------------------------
# 7. Register nix zsh in /etc/shells and set it as the login shell
#    (Linux only — macOS ships zsh as the default login shell already).
#    usermod avoids an interactive password prompt (unlike chsh).
#-----------------------------------------------------------
if [ "$OS" = linux ]; then
  ZSH_PATH="$(command -v zsh)"
  if ! grep -qxF "$ZSH_PATH" /etc/shells 2>/dev/null; then
    echo "==> Adding $ZSH_PATH to /etc/shells"
    echo "$ZSH_PATH" | sudo tee -a /etc/shells >/dev/null
  fi
  if [ "$(getent passwd "$USER" | cut -d: -f7)" != "$ZSH_PATH" ]; then
    echo "==> Setting login shell to $ZSH_PATH"
    sudo usermod -s "$ZSH_PATH" "$USER"
  fi
fi

#-----------------------------------------------------------
# 8. Apply system-level config: system-manager (Linux: /etc, systemd) or
#    nix-darwin (macOS: Homebrew casks, /etc/zshrc). Both self-escalate and
#    prompt for the sudo password.
#-----------------------------------------------------------
if [ "$OS" = linux ]; then
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
else
  # First activation only: nix-darwin refuses to overwrite pre-existing *real*
  # /etc files it manages. The plain Nix installer writes /etc/zshrc,
  # /etc/bashrc, etc. with content nix-darwin doesn't recognize, which aborts
  # activation with "Unexpected files in /etc". Move any such files aside to
  # *.before-nix-darwin (only if not already a symlink and not already backed
  # up); nix-darwin then recreates them. Skipped once darwin-rebuild exists
  # (i.e. after first switch).
  if ! command -v darwin-rebuild >/dev/null 2>&1; then
    for f in /etc/zshrc /etc/bashrc /etc/zprofile /etc/zshenv; do
      if [ -f "$f" ] && [ ! -L "$f" ] && [ ! -e "$f.before-nix-darwin" ]; then
        echo "==> Moving aside pre-existing $f (nix-darwin will recreate it)"
        sudo mv "$f" "$f.before-nix-darwin"
      fi
    done
  fi

  echo "==> Applying nix-darwin configuration"
  if command -v darwin-rebuild >/dev/null 2>&1; then
    darwin-rebuild switch --flake "$DOTFILES#will-mbp"
  else
    nix run nix-darwin -- switch --flake "$DOTFILES#will-mbp"
  fi
  export PATH="/run/current-system/sw/bin:$PATH"
fi

#-----------------------------------------------------------
# 9. GitHub CLI auth (shared; interactive — requires a browser; skipped once
#    authed).
#-----------------------------------------------------------
if command -v gh >/dev/null 2>&1 && ! gh auth status >/dev/null 2>&1; then
  echo "==> Authenticating with GitHub"
  gh auth login
fi

#-----------------------------------------------------------
# 10. AppArmor profiles for nix GUI-app sandboxes (Linux only; guarded: skip
#     — and skip its sudo — when every profile is already installed
#     identically). Allows the user namespaces that nix-installed
#     browsers/Electron apps need on 24.04.
#-----------------------------------------------------------
if [ "$OS" = linux ]; then
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
fi

echo "==> Done. Open a new shell (or run 'exec zsh') to pick up PATH changes."
