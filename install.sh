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
# 6. GitHub CLI auth (interactive — requires a browser)
#-----------------------------------------------------------
if ! gh auth status >/dev/null 2>&1; then
  echo "==> Authenticating with GitHub"
  gh auth login
fi

#-----------------------------------------------------------
# 7. uv (Astral Python toolchain)
#-----------------------------------------------------------
if ! command -v uv >/dev/null 2>&1; then
  echo "==> Installing uv"
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi

#-----------------------------------------------------------
# 7b. Starship prompt
#-----------------------------------------------------------
if ! command -v starship >/dev/null 2>&1; then
  echo "==> Installing Starship"
  curl -sS https://starship.rs/install.sh | sh -s -- --yes
fi

#-----------------------------------------------------------
# 7d. Rust (via rustup)
#-----------------------------------------------------------
if ! command -v rustup >/dev/null 2>&1; then
  echo "==> Installing Rust"
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
fi
export PATH="$HOME/.cargo/bin:$PATH"

#-----------------------------------------------------------
# 7e. Cargo-installed CLI tools
#-----------------------------------------------------------
echo "==> Installing cargo tools"
cargo_install() {
  local crate="$1" bin="$2"
  if ! command -v "$bin" >/dev/null 2>&1; then
    echo "    cargo install $crate"
    cargo install "$crate"
  else
    echo "    already installed: $bin"
  fi
}
cargo_install bat           bat
cargo_install du-dust       dust
cargo_install fd-find       fd
cargo_install ripgrep_all   rga
cargo_install procs         procs
cargo_install zoxide        zoxide

#-----------------------------------------------------------
# 8. From-source installs (packages/from-source/*.sh)
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
# 9b. zoxide init in ~/.bashrc
#-----------------------------------------------------------
if ! grep -qF 'zoxide init bash' "$HOME/.bashrc"; then
  echo "==> Adding zoxide init to ~/.bashrc"
  printf '\neval "$(zoxide init bash)"\n' >> "$HOME/.bashrc"
fi

#-----------------------------------------------------------
# 9c. Starship init in ~/.bashrc
#-----------------------------------------------------------
if ! grep -qF 'starship init bash' "$HOME/.bashrc"; then
  echo "==> Adding starship init to ~/.bashrc"
  printf '\neval "$(starship init bash)"\n' >> "$HOME/.bashrc"
fi

#-----------------------------------------------------------
# 10. Stow dotfiles (symlink each package under stow/ into $HOME)
#-----------------------------------------------------------
echo "==> Stowing dotfiles"
mkdir -p "$HOME/.claude"
for pkg in "$DOTFILES"/stow/*/; do
  pkg_name="$(basename "$pkg")"
  stow --dir="$DOTFILES/stow" --target="$HOME" "$pkg_name"
done

#-----------------------------------------------------------
# 10b. GNOME settings (dconf import — idempotent)
#-----------------------------------------------------------
echo "==> Importing GNOME settings"
if command -v dconf >/dev/null 2>&1; then
  dconf load /org/gnome/terminal/        < "$DOTFILES/gnome/terminal.dconf"
  dconf load /org/gnome/desktop/interface/ < "$DOTFILES/gnome/desktop.dconf"
  dconf load /org/gnome/shell/extensions/ < "$DOTFILES/gnome/extensions.dconf"
  echo "    imported terminal, desktop, and extension settings"
else
  echo "    dconf not found; skipping GNOME settings"
fi

#-----------------------------------------------------------
# 10c. Zen Browser — link dotfiles into Flatpak profile
#-----------------------------------------------------------
echo "==> Linking Zen Browser dotfiles"
ZEN_BASE="$HOME/.var/app/app.zen_browser.zen/.zen"
if [ -f "$ZEN_BASE/installs.ini" ]; then
  ZEN_PROFILE=$(grep 'Default=' "$ZEN_BASE/installs.ini" | head -1 | cut -d= -f2)
  ZEN_PROFILE_DIR="$ZEN_BASE/$ZEN_PROFILE"
  if [ -d "$ZEN_PROFILE_DIR" ]; then
    ln -sf "$HOME/.config/zen-dotfiles/user.js" "$ZEN_PROFILE_DIR/user.js"
    mkdir -p "$ZEN_PROFILE_DIR/chrome"
    ln -sf "$HOME/.config/zen-dotfiles/chrome/userChrome.css" \
           "$ZEN_PROFILE_DIR/chrome/userChrome.css"
    echo "    linked to profile: $ZEN_PROFILE"
  else
    echo "    Zen profile dir not found ($ZEN_PROFILE); skipping"
  fi
else
  echo "    Zen Browser not installed; skipping"
fi

#-----------------------------------------------------------
# 11. Cron jobs (additive — tagged entries, safe to re-run)
#-----------------------------------------------------------
echo "==> Installing cron jobs"
if command -v crontab >/dev/null 2>&1; then
  current_crontab="$(crontab -l 2>/dev/null || true)"

  add_cron() {
    local tag="$1" line="$2"
    if ! printf '%s\n' "$current_crontab" | grep -Fq "$tag"; then
      current_crontab="$(printf '%s\n%s\n' "$current_crontab" "$line" | sed '/^$/d')"
      echo "    installed: $tag"
    else
      echo "    already present: $tag"
    fi
  }

  add_cron "managed-by:claude-daily-todo" \
    "0 9 * * * $HOME/.local/bin/claude-daily-todo  # managed-by:claude-daily-todo"

  add_cron "managed-by:dotfiles-maintenance" \
    "0 14 * * 0 cd $DOTFILES && $HOME/.local/bin/claude --dangerously-skip-permissions -p 'Review packages/apt.txt, snap.txt, and flatpak.txt for renamed or deprecated packages. Check install.sh for issues. Edit and commit any clear improvements with: git add -A && git commit -m chore: automated dotfiles maintenance. Do nothing if there is nothing to fix.' >> $HOME/.claude/cron.log 2>&1  # managed-by:dotfiles-maintenance"

  printf '%s\n' "$current_crontab" | crontab -
else
  echo "    crontab not found; skipping"
fi

echo "==> Done. Open a new shell to pick up PATH changes."
