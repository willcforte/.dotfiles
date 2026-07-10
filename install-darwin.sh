#!/usr/bin/env bash
# Single idempotent entry point for macOS: installs any missing prerequisites
# (Nix, Homebrew, rustup, pixi) and then applies the flake config
# (home-manager + nix-darwin). Safe to run anytime — it is both the installer
# and the updater. home.nix symlinks it to ~/.local/bin/update-config, so
# `update-config` and `./install-darwin.sh` do the same thing.
set -euo pipefail

# Hardcoded (not derived from $BASH_SOURCE) so it works the same whether run
# from the repo or via the ~/.local/bin/update-config symlink.
DOTFILES="$HOME/.dotfiles"

#-----------------------------------------------------------
# 1. Nix (multi-user/daemon install via the plain upstream installer). The
#    Determinate Systems installer (used on Linux, see install.sh) currently
#    crashes on Apple Silicon Macs while reading TLS trust certs from
#    Keychain during encrypted-volume creation — a known open bug:
#    https://github.com/DeterminateSystems/nix-installer/issues/1514
#-----------------------------------------------------------
if ! command -v nix >/dev/null 2>&1 && [ ! -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
  echo "==> Installing Nix"
  sh <(curl -L https://nixos.org/nix/install) --daemon
fi
if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
  # nix-daemon.sh references unset vars; relax nounset while sourcing.
  set +u
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  set -u
fi

#-----------------------------------------------------------
# 2. Enable nix flakes for the user (the plain installer doesn't set this in
#    /etc/nix/nix.conf, and it's needed for the flake-based switches below).
#-----------------------------------------------------------
mkdir -p "$HOME/.config/nix"
if ! grep -qs 'experimental-features.*flakes' "$HOME/.config/nix/nix.conf" 2>/dev/null; then
  echo "==> Enabling nix flakes for user"
  echo "experimental-features = nix-command flakes" >>"$HOME/.config/nix/nix.conf"
fi

#-----------------------------------------------------------
# 3. Homebrew. nix-darwin's `homebrew` module (darwin/system.nix) manages
#    casks declaratively but will not install Homebrew itself — it just
#    skips with a warning if `brew` isn't already on PATH.
#-----------------------------------------------------------
if ! command -v brew >/dev/null 2>&1; then
  echo "==> Installing Homebrew"
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
[ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"

#-----------------------------------------------------------
# 4. Rust toolchain (via rustup) — for Rust development only; Rust-built CLI
#    tools (bat, fd, ripgrep, ...) come from home-manager (see home.nix).
#-----------------------------------------------------------
if ! command -v rustup >/dev/null 2>&1 && [ ! -x "$HOME/.cargo/bin/rustup" ]; then
  echo "==> Installing Rust"
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
fi

#-----------------------------------------------------------
# 5. pixi (self-updating binary; home.nix puts ~/.pixi/bin on PATH
#    declaratively via home.sessionPath).
#-----------------------------------------------------------
if ! command -v pixi >/dev/null 2>&1 && [ ! -x "$HOME/.pixi/bin/pixi" ]; then
  echo "==> Installing pixi"
  curl -fsSL https://pixi.sh/install.sh | PIXI_NO_PATH_UPDATE=1 sh
fi

#-----------------------------------------------------------
# 6. Apply home-manager (user env: packages, dotfiles). Prefer the installed
#    `home-manager` CLI once present (faster, no flake re-fetch); fall back to
#    `nix run` on the very first run.
#-----------------------------------------------------------
echo "==> Applying home-manager configuration"
if command -v home-manager >/dev/null 2>&1; then
  home-manager switch -b backup --flake "$DOTFILES#will@will-mbp"
else
  nix run home-manager/master -- switch -b backup --flake "$DOTFILES#will@will-mbp"
fi
export PATH="$HOME/.nix-profile/bin:$PATH"

#-----------------------------------------------------------
# 7. Apply nix-darwin (system config: Homebrew casks, /etc/zshrc). darwin-rebuild
#    only exists after the first activation, so fall back to `nix run nix-darwin`
#    to bootstrap it. The activation step self-escalates and prompts for sudo.
#-----------------------------------------------------------
# First activation only: nix-darwin refuses to overwrite pre-existing *real*
# /etc files it manages. The plain Nix installer writes /etc/zshrc, /etc/bashrc,
# etc. with content nix-darwin doesn't recognize, which aborts activation with
# "Unexpected files in /etc". Move any such files aside to *.before-nix-darwin
# (only if not already a symlink and not already backed up); nix-darwin then
# recreates them. Skipped once darwin-rebuild exists (i.e. after first switch).
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

#-----------------------------------------------------------
# 8. GitHub CLI auth (interactive — requires a browser; skipped once authed).
#-----------------------------------------------------------
if command -v gh >/dev/null 2>&1 && ! gh auth status >/dev/null 2>&1; then
  echo "==> Authenticating with GitHub"
  gh auth login
fi

echo "==> Done. Open a new shell (or run 'exec zsh') to pick up PATH changes."
