#!/usr/bin/env bash
# Apply this repo's configuration on macOS: home-manager (user env) then
# nix-darwin (system config, Homebrew casks). The system step needs sudo for
# activation, so it will prompt for the password.
set -euo pipefail
nix run home-manager/master -- switch -b backup --flake "$HOME/.dotfiles#will@will-mbp"

# darwin-rebuild only exists after nix-darwin has been activated once; on the
# very first run fall back to `nix run nix-darwin` to bootstrap it.
if command -v darwin-rebuild >/dev/null 2>&1; then
  exec darwin-rebuild switch --flake "$HOME/.dotfiles#will-mbp"
else
  exec nix run nix-darwin -- switch --flake "$HOME/.dotfiles#will-mbp"
fi
