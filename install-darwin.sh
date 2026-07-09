#!/usr/bin/env bash
# macOS bootstrap: Nix, Homebrew, nix-darwin, home-manager, rustup, pixi.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DOTFILES"

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
#    /etc/nix/nix.conf, and it's needed before the first flake-based
#    nix-darwin/home-manager switch below).
#-----------------------------------------------------------
echo "==> Enabling nix flakes for user"
mkdir -p "$HOME/.config/nix"
if ! grep -qs 'experimental-features.*flakes' "$HOME/.config/nix/nix.conf" 2>/dev/null; then
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
eval "$(/opt/homebrew/bin/brew shellenv)"

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
# 6. Bootstrap nix-darwin (system config: Homebrew casks, /etc/zshrc
#    integration) then home-manager (user env: packages, dotfiles).
#-----------------------------------------------------------
echo "==> Applying nix-darwin configuration"
nix run nix-darwin -- switch --flake "$DOTFILES#will-mbp"
export PATH="/run/current-system/sw/bin:$PATH"

echo "==> Applying home-manager configuration"
nix run home-manager/master -- switch -b backup --flake "$DOTFILES#will@will-mbp"
export PATH="$HOME/.nix-profile/bin:$PATH"

#-----------------------------------------------------------
# 7. GitHub CLI auth (interactive — requires a browser).
#-----------------------------------------------------------
if ! gh auth status >/dev/null 2>&1; then
  echo "==> Authenticating with GitHub"
  gh auth login
fi

echo "==> Done. Open a new shell to pick up PATH changes."
