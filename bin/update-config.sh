#!/usr/bin/env bash
# Apply the home-manager configuration from this repo. Auto-selects the
# "will@<hostname>" generation when a matching host module exists, else "will".
set -euo pipefail
exec nix run home-manager/release-25.05 -- switch -b backup --flake "$HOME/.dotfiles"
