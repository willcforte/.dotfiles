#!/usr/bin/env bash
# Apply this repo's configuration on macOS: home-manager (user env) then
# nix-darwin (system config, Homebrew casks). darwin-rebuild needs sudo for
# activation, so it will prompt for the password.
set -euo pipefail
nix run home-manager/master -- switch -b backup --flake "$HOME/.dotfiles#will@will-mbp"
exec darwin-rebuild switch --flake "$HOME/.dotfiles#will-mbp"
