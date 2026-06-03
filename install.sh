#!/usr/bin/env bash
# Ubuntu 24.04.4 LTS
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DOTFILES"

#-----------------------------------------------------------
# 1. Bootstrap tools needed before adding third-party apt repos.
#-----------------------------------------------------------
echo "==> sudo password required for install"
sudo -v

echo "==> Updating apt and installing bootstrap tools"
sudo apt-get update
sudo apt-get install -y ca-certificates curl wget gnupg software-properties-common

#-----------------------------------------------------------
# 2. Third-party apt repos (keys + sources).
#-----------------------------------------------------------
echo "==> Adding third-party apt repos"
sudo install -d -m 0755 /etc/apt/keyrings

# Tailscale
codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"
curl -fsSL "https://pkgs.tailscale.com/stable/ubuntu/${codename}.noarmor.gpg" \
  | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
curl -fsSL "https://pkgs.tailscale.com/stable/ubuntu/${codename}.tailscale-keyring.list" \
  | sudo tee /etc/apt/sources.list.d/tailscale.list >/dev/null

sudo apt-get update

#-----------------------------------------------------------
# 3. apt packages from packages/apt.txt
#-----------------------------------------------------------
echo "==> Installing apt packages"
grep -vE '^\s*(#|$)' packages/apt.txt | xargs sudo apt-get install -y

#-----------------------------------------------------------
# 4. Rust toolchain (via rustup) — for Rust development only;
#    Rust-built CLI tools (bat, fd, ripgrep, ...) come from
#    home-manager (see home.nix).
#-----------------------------------------------------------
# Guard: the rustup.rs installer aborts if rustup is already present
# (e.g. installed via apt).
if ! command -v rustup >/dev/null 2>&1 && [ ! -x "$HOME/.cargo/bin/rustup" ]; then
  echo "==> Installing Rust"
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
fi

#-----------------------------------------------------------
# 5. Nix (multi-user/daemon install via Determinate Systems
#     installer — idempotent-ish via guard, enables flakes)
#-----------------------------------------------------------
if ! command -v nix >/dev/null 2>&1 \
   && [ ! -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
  echo "==> Installing Nix"
  curl -fsSL https://install.determinate.systems/nix | sh -s -- install --no-confirm
fi
# Make nix available in this shell.
if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
  # nix-daemon.sh references unset vars; relax nounset while sourcing.
  set +u
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  set -u
fi

#-----------------------------------------------------------
# 6. Stow dotfiles (symlink each package under stow/ into $HOME)
#-----------------------------------------------------------
echo "==> Stowing dotfiles"
mkdir -p "$HOME/.claude" "$HOME/.local/bin"
for pkg in "$DOTFILES"/stow/*/; do
  pkg_name="$(basename "$pkg")"
  while IFS= read -r src; do
    rel="${src#${pkg}}"
    tgt="$HOME/$rel"
    # Skip if the target resolves to a path inside the stow package (directory
    # folding — stow already manages this via a parent directory symlink).
    real_tgt="$(realpath "$tgt" 2>/dev/null || true)"
    if [[ "$real_tgt" == "$DOTFILES"/stow/* ]]; then
      continue
    fi
    if [ -L "$tgt" ]; then
      rm "$tgt"
    elif [ -f "$tgt" ]; then
      if diff -q "$src" "$tgt" >/dev/null 2>&1; then
        echo "    replacing identical real file with symlink: $tgt"
        rm "$tgt"
      else
        echo "    WARNING: $tgt differs from dotfiles source — leaving it"
      fi
    fi
  done < <(find "$pkg" -type f)
  stow --dir="$DOTFILES/stow" --target="$HOME" "$pkg_name"
done

#-----------------------------------------------------------
# 7. home-manager (packages + bash/starship/zoxide shell config —
#    see home.nix). -b backup moves aside pre-existing real files
#    that home-manager needs to own (e.g. Ubuntu's stock ~/.bashrc
#    and ~/.profile on first run → ~/.bashrc.backup).
#-----------------------------------------------------------
echo "==> Applying home-manager configuration"
nix run home-manager/release-25.05 -- switch -b backup \
  --flake "$DOTFILES/stow/nix/.config/home-manager"
export PATH="$HOME/.nix-profile/bin:$PATH"

#-----------------------------------------------------------
# 8. GitHub CLI auth (interactive — requires a browser).
#     gh comes from home-manager; credential helper is configured
#     in the stowed .gitconfig, so no `gh auth setup-git` needed.
#-----------------------------------------------------------
if ! gh auth status >/dev/null 2>&1; then
  echo "==> Authenticating with GitHub"
  gh auth login
fi

#-----------------------------------------------------------
# 9. AppArmor: allow user namespaces for nix-installed browsers
#     and Electron apps (Ubuntu 24.04 blocks unprivileged userns,
#     which their content-process sandboxes need)
#-----------------------------------------------------------
echo "==> Installing AppArmor profiles"
for profile in "$DOTFILES"/apparmor/*; do
  name="$(basename "$profile")"
  sudo install -m 0644 "$profile" "/etc/apparmor.d/$name"
  sudo apparmor_parser -r "/etc/apparmor.d/$name"
done

echo "==> Done. Open a new shell to pick up PATH changes."
