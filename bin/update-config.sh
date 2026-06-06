#!/usr/bin/env bash
# Apply this repo's configuration: home-manager (user env) then system-manager
# (system /etc, systemd). home-manager auto-selects the "will@<hostname>"
# generation when a matching host module exists, else "will". system-manager
# self-escalates via --sudo, so it will prompt for the sudo password.
set -euo pipefail
nix run home-manager/master -- switch -b backup --flake "$HOME/.dotfiles"
exec nix run 'github:numtide/system-manager' -- switch --flake "$HOME/.dotfiles" --sudo
