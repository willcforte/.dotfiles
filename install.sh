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
# 4. Snaps from packages/snap.txt
#-----------------------------------------------------------
echo "==> Installing snaps"
while IFS= read -r line; do
  case "$line" in ''|\#*) continue ;; esac
  # shellcheck disable=SC2086
  sudo snap install $line || sudo snap refresh $line
done < packages/snap.txt

#-----------------------------------------------------------
# 5. Flatpaks from packages/flatpak.txt (via flathub)
#-----------------------------------------------------------
echo "==> Installing flatpaks"
sudo flatpak remote-add --if-not-exists flathub \
  https://flathub.org/repo/flathub.flatpakrepo
while IFS= read -r line; do
  case "$line" in ''|\#*) continue ;; esac
  sudo flatpak install -y --noninteractive flathub "$line"
done < packages/flatpak.txt

#-----------------------------------------------------------
# 6. Rust toolchain (via rustup) — for Rust development only;
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
# 7. Nix (multi-user/daemon install via Determinate Systems
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
# 8. Stow dotfiles (symlink each package under stow/ into $HOME)
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
# 9. home-manager (packages + bash/starship/zoxide shell config —
#    see home.nix). -b backup moves aside pre-existing real files
#    that home-manager needs to own (e.g. Ubuntu's stock ~/.bashrc
#    and ~/.profile on first run → ~/.bashrc.backup).
#-----------------------------------------------------------
echo "==> Applying home-manager configuration"
nix run home-manager/release-25.05 -- switch -b backup \
  --flake "$DOTFILES/stow/nix/.config/home-manager"
export PATH="$HOME/.nix-profile/bin:$PATH"

#-----------------------------------------------------------
# 10. GitHub CLI auth (interactive — requires a browser).
#     gh comes from home-manager; credential helper is configured
#     in the stowed .gitconfig, so no `gh auth setup-git` needed.
#-----------------------------------------------------------
if ! gh auth status >/dev/null 2>&1; then
  echo "==> Authenticating with GitHub"
  gh auth login
fi

#-----------------------------------------------------------
# 11. AppArmor: allow user namespaces for nix zen-beta
#     (Ubuntu 24.04 blocks unprivileged userns; Firefox-based
#     browsers need it for their content-process sandbox)
#-----------------------------------------------------------
echo "==> Installing AppArmor profile for zen-beta"
sudo install -m 0644 "$DOTFILES/apparmor/zen-beta" /etc/apparmor.d/zen-beta
sudo apparmor_parser -r /etc/apparmor.d/zen-beta

#-----------------------------------------------------------
# 12. GNOME settings (dconf import — idempotent)
#-----------------------------------------------------------
echo "==> Importing GNOME settings"
if command -v dconf >/dev/null 2>&1; then
  dconf load /org/gnome/terminal/         < "$DOTFILES/gnome/terminal.dconf"
  dconf load /org/gnome/desktop/interface/ < "$DOTFILES/gnome/desktop.dconf"
  dconf load /org/gnome/shell/extensions/ < "$DOTFILES/gnome/extensions.dconf"
  echo "    imported terminal, desktop, and extension settings"
else
  echo "    dconf not found; skipping GNOME settings"
fi

echo "==> Done. Open a new shell to pick up PATH changes."
