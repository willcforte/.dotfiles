#!/usr/bin/env bash
# Daily: bump ~/.dotfiles flake.lock, then apply.
#
# Kept as a stable on-disk script (not a nix-store writeShellScript) so the
# systemd unit's ExecStart never changes across nixpkgs bumps.
#
# The `home-manager switch` is launched as a DETACHED transient unit via
# systemd-run so this oneshot exits immediately. Otherwise the switch's own
# reloadSystemd step restarts this still-running service, which re-invokes the
# switch, looping forever. Detaching means nothing home-manager-managed is
# active during the switch, so there is nothing for reloadSystemd to restart.
set -euo pipefail
PROFILE="/nix/var/nix/profiles/default/bin"
NIXBIN="$HOME/.nix-profile/bin"
export PATH="$PROFILE:$NIXBIN:/usr/bin:/bin:$PATH"
cd "$HOME/.dotfiles" || exit 1

nix --extra-experimental-features 'nix-command flakes' flake update

exec systemd-run --user --collect \
  --working-directory="$HOME/.dotfiles" \
  --setenv=PATH="$PROFILE:$NIXBIN:/usr/bin:/bin" \
  "$NIXBIN/home-manager" switch -b backup --flake "$HOME/.dotfiles"
