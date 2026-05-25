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

# GitHub CLI
if [ ! -f /etc/apt/keyrings/githubcli-archive-keyring.gpg ]; then
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
  sudo chmod a+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
fi
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] \
https://cli.github.com/packages stable main" \
  | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null

# Tailscale
codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"
if [ ! -f /usr/share/keyrings/tailscale-archive-keyring.gpg ]; then
  curl -fsSL "https://pkgs.tailscale.com/stable/ubuntu/${codename}.noarmor.gpg" \
    | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
fi
curl -fsSL "https://pkgs.tailscale.com/stable/ubuntu/${codename}.tailscale-keyring.list" \
  | sudo tee /etc/apt/sources.list.d/tailscale.list >/dev/null

# VS Code
if [ ! -f /etc/apt/keyrings/packages.microsoft.gpg ]; then
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
    | gpg --dearmor \
    | sudo tee /etc/apt/keyrings/packages.microsoft.gpg >/dev/null
  sudo chmod a+r /etc/apt/keyrings/packages.microsoft.gpg
fi
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/packages.microsoft.gpg] \
https://packages.microsoft.com/repos/code stable main" \
  | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null

sudo apt-get update

#-----------------------------------------------------------
# 3. apt packages from packages/apt.txt
#-----------------------------------------------------------
echo "==> Installing apt packages"
grep -vE '^\s*(#|$)' packages/apt.txt | xargs sudo apt-get install -y

#-----------------------------------------------------------
# 4. Flatpaks from packages/flatpak.txt (via flathub)
#-----------------------------------------------------------
echo "==> Installing flatpaks"
sudo flatpak remote-add --if-not-exists flathub \
  https://flathub.org/repo/flathub.flatpakrepo
while IFS= read -r line; do
  case "$line" in ''|\#*) continue ;; esac
  sudo flatpak install -y --noninteractive flathub "$line"
done < packages/flatpak.txt

#-----------------------------------------------------------
# 5. GitHub CLI auth (interactive — requires a browser)
#-----------------------------------------------------------
if ! gh auth status >/dev/null 2>&1; then
  echo "==> Authenticating with GitHub"
  gh auth login
fi
gh auth setup-git

#-----------------------------------------------------------
# 6. uv (Astral Python toolchain)
#-----------------------------------------------------------
if ! command -v uv >/dev/null 2>&1; then
  echo "==> Installing uv"
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi
export PATH="$HOME/.local/bin:$PATH"

#-----------------------------------------------------------
# 6b. Starship prompt
#-----------------------------------------------------------
if ! command -v starship >/dev/null 2>&1; then
  echo "==> Installing Starship"
  curl -sS https://starship.rs/install.sh | sh -s -- --yes
fi

#-----------------------------------------------------------
# 6c. Rust (via rustup)
#-----------------------------------------------------------
if ! command -v rustup >/dev/null 2>&1; then
  echo "==> Installing Rust"
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
fi
export PATH="$HOME/.cargo/bin:$PATH"

#-----------------------------------------------------------
# 6d. Cargo-installed CLI tools
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
# 6e. Iosevka Nerd Font
#-----------------------------------------------------------
if ! fc-list | grep -qi "iosevka nerd"; then
  echo "==> Installing Iosevka Nerd Font"
  FONT_DIR="$HOME/.local/share/fonts"
  mkdir -p "$FONT_DIR"
  IOSEVKA_URL="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Iosevka.tar.xz"
  curl -fsSL "$IOSEVKA_URL" | tar -xJ -C "$FONT_DIR"
  fc-cache -f "$FONT_DIR"
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
# 8. Claude Code (Node.js LTS is a prerequisite)
#-----------------------------------------------------------
if ! command -v node >/dev/null 2>&1; then
  echo "==> Installing Node.js LTS (required for Claude Code)"
  curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
  sudo apt-get install -y nodejs
fi
if ! command -v claude >/dev/null 2>&1; then
  echo "==> Installing Claude Code"
  npm install -g @anthropic-ai/claude-code
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
mkdir -p "$HOME/.claude" "$HOME/.local/bin"
for pkg in "$DOTFILES"/stow/*/; do
  pkg_name="$(basename "$pkg")"
  # Pre-remove any existing symlink (absolute or relative) or identical real file
  # at each target path. Stow refuses to touch absolute symlinks and cannot replace
  # real files, so we clear the way and let stow create fresh relative symlinks.
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

  printf '%s\n' "$current_crontab" | crontab -
else
  echo "    crontab not found; skipping"
fi

echo "==> Done. Open a new shell to pick up PATH changes."
