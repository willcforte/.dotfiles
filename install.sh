#!/usr/bin/env bash
# Idempotent installer for a fresh Ubuntu 24.04 machine.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DOTFILES"

require_sudo() {
  if ! sudo -n true 2>/dev/null; then
    echo "==> sudo password required for install"
    sudo -v
  fi
}

#-----------------------------------------------------------
# 1. Base tools needed before we can add third-party apt repos.
#-----------------------------------------------------------
echo "==> Updating apt and installing bootstrap tools"
require_sudo
sudo apt-get update
sudo apt-get install -y \
  ca-certificates curl wget gnupg \
  software-properties-common

#-----------------------------------------------------------
# 2. Third-party apt repos (keys + sources).
#-----------------------------------------------------------
echo "==> Adding third-party apt repos"
sudo install -d -m 0755 /etc/apt/keyrings

# Docker
if [ ! -f /etc/apt/keyrings/docker.asc ]; then
  sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    -o /etc/apt/keyrings/docker.asc
  sudo chmod a+r /etc/apt/keyrings/docker.asc
fi
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

# GitHub CLI
if [ ! -f /etc/apt/keyrings/githubcli-archive-keyring.gpg ]; then
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
  sudo chmod a+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
fi
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] \
https://cli.github.com/packages stable main" \
  | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null

# Google Chrome
if [ ! -f /etc/apt/keyrings/google-chrome.gpg ]; then
  curl -fsSL https://dl.google.com/linux/linux_signing_key.pub \
    | sudo gpg --dearmor -o /etc/apt/keyrings/google-chrome.gpg
fi
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] \
https://dl.google.com/linux/chrome/deb/ stable main" \
  | sudo tee /etc/apt/sources.list.d/google-chrome.list >/dev/null

# Tailscale
codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"
if [ ! -f /usr/share/keyrings/tailscale-archive-keyring.gpg ]; then
  curl -fsSL "https://pkgs.tailscale.com/stable/ubuntu/${codename}.noarmor.gpg" \
    | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
fi
curl -fsSL "https://pkgs.tailscale.com/stable/ubuntu/${codename}.tailscale-keyring.list" \
  | sudo tee /etc/apt/sources.list.d/tailscale.list >/dev/null

sudo apt-get update

#-----------------------------------------------------------
# 3. apt packages from packages/apt.txt
#-----------------------------------------------------------
echo "==> Installing apt packages"
grep -vE '^\s*(#|$)' packages/apt.txt | xargs sudo apt-get install -y

#-----------------------------------------------------------
# 4. Snaps from packages/snap.txt (one per line, flags allowed)
#-----------------------------------------------------------
echo "==> Installing snaps"
while IFS= read -r line; do
  case "$line" in ''|\#*) continue ;; esac
  # shellcheck disable=SC2086
  sudo snap install $line
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
# 6. uv (Astral Python toolchain)
#-----------------------------------------------------------
if ! command -v uv >/dev/null 2>&1; then
  echo "==> Installing uv"
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi

#-----------------------------------------------------------
# 7. From-source installs (packages/from-source/*.sh)
#-----------------------------------------------------------
echo "==> Running from-source installs"
for script in "$DOTFILES"/packages/from-source/*.sh; do
  # shellcheck source=/dev/null
  source "$script"
done

#-----------------------------------------------------------
# 8. Claude Code (official native installer)
#-----------------------------------------------------------
if ! command -v claude >/dev/null 2>&1 && [ ! -x "$HOME/.local/bin/claude" ]; then
  echo "==> Installing Claude Code"
  curl -fsSL https://claude.ai/install.sh | bash
fi

#-----------------------------------------------------------
# 9. Ensure ~/.local/bin is on PATH for interactive bash shells.
#-----------------------------------------------------------
if ! grep -qxF 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc"; then
  echo "==> Adding ~/.local/bin to PATH in ~/.bashrc"
  printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$HOME/.bashrc"
fi

#-----------------------------------------------------------
# 10. Git identity
#-----------------------------------------------------------
echo "==> Setting git identity"
git config --global user.name "Will C. Forte"
git config --global user.email "willcforte@gmail.com"

#-----------------------------------------------------------
# 11. Stow dotfiles (symlink each package under stow/ into $HOME)
#-----------------------------------------------------------
echo "==> Stowing dotfiles"
mkdir -p "$HOME/.claude"
for pkg in "$DOTFILES"/stow/*/; do
  pkg_name="$(basename "$pkg")"
  stow --dir="$DOTFILES/stow" --target="$HOME" "$pkg_name"
done

#-----------------------------------------------------------
# 12. Install cron jobs.
#-----------------------------------------------------------
echo "==> Installing cron jobs"
if command -v crontab >/dev/null 2>&1; then
  # claude-daily-todo: generate today's prioritized list at 09:00 every day.
  CRON_TAG="# managed-by:claude-daily-todo"
  CRON_LINE="0 9 * * * $HOME/.local/bin/claude-daily-todo  $CRON_TAG"
  current_crontab="$(crontab -l 2>/dev/null || true)"
  if ! printf '%s\n' "$current_crontab" | grep -Fq "$CRON_TAG"; then
    { printf '%s\n' "$current_crontab"; printf '%s\n' "$CRON_LINE"; } \
      | sed '/^$/d' | crontab -
    echo "    installed claude-daily-todo @ 09:00 daily"
  else
    echo "    claude-daily-todo cron entry already present"
  fi
else
  echo "    crontab not found; skipping cron install"
fi

echo "==> Done. Open a new shell to pick up PATH changes."
