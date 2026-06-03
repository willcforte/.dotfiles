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

# GitHub CLI
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
sudo chmod a+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] \
https://cli.github.com/packages stable main" \
  | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null

# Tailscale
codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"
curl -fsSL "https://pkgs.tailscale.com/stable/ubuntu/${codename}.noarmor.gpg" \
  | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
curl -fsSL "https://pkgs.tailscale.com/stable/ubuntu/${codename}.tailscale-keyring.list" \
  | sudo tee /etc/apt/sources.list.d/tailscale.list >/dev/null

# VS Code
curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
  | gpg --dearmor \
  | sudo tee /etc/apt/keyrings/packages.microsoft.gpg >/dev/null
sudo chmod a+r /etc/apt/keyrings/packages.microsoft.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/packages.microsoft.gpg] \
https://packages.microsoft.com/repos/code stable main" \
  | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null

# Node.js LTS (for Claude Code)
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -

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
# 6. GitHub CLI auth (interactive — requires a browser)
#-----------------------------------------------------------
if ! gh auth status >/dev/null 2>&1; then
  echo "==> Authenticating with GitHub"
  gh auth login
fi
gh auth setup-git

#-----------------------------------------------------------
# 7. uv (Astral Python toolchain)
#-----------------------------------------------------------
echo "==> Installing uv"
curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="$HOME/.local/bin:$PATH"

#-----------------------------------------------------------
# 8. Starship prompt
#-----------------------------------------------------------
echo "==> Installing Starship"
curl -sS https://starship.rs/install.sh | sh -s -- --yes

#-----------------------------------------------------------
# 9. Rust (via rustup) and cargo CLI tools
#-----------------------------------------------------------
echo "==> Installing Rust"
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
export PATH="$HOME/.cargo/bin:$PATH"

echo "==> Installing cargo tools"
cargo install bat du-dust fd-find ripgrep_all procs zoxide

#-----------------------------------------------------------
# 10. IosevkaTerm SS18 font (official Iosevka build, latest release)
#-----------------------------------------------------------
echo "==> Installing IosevkaTerm SS18"
FONT_DIR="$HOME/.local/share/fonts"
mkdir -p "$FONT_DIR"
# Asset names embed the version (e.g. PkgTTF-IosevkaTermSS18-34.6.1.zip), so
# resolve the latest hinted TTF package URL via the releases API.
font_url="$(curl -fsSL https://api.github.com/repos/be5invis/Iosevka/releases/latest \
  | grep -oE 'https://[^"]*PkgTTF-IosevkaTermSS18-[0-9.]+\.zip' \
  | head -1)"
tmp_zip="$(mktemp --suffix=.zip)"
curl -fsSL "$font_url" -o "$tmp_zip"
unzip -o -q "$tmp_zip" -d "$FONT_DIR"
rm -f "$tmp_zip"
fc-cache -f "$FONT_DIR"

#-----------------------------------------------------------
# 11. Claude Code
#-----------------------------------------------------------
echo "==> Installing Claude Code"
npm install -g @anthropic-ai/claude-code

#-----------------------------------------------------------
# 12. ~/.bashrc additions (guards necessary — appends are not idempotent)
#-----------------------------------------------------------
if ! grep -qxF 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc"; then
  printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$HOME/.bashrc"
fi
if ! grep -qF 'zoxide init bash' "$HOME/.bashrc"; then
  printf '\neval "$(zoxide init bash)"\n' >> "$HOME/.bashrc"
fi
if ! grep -qF 'starship init bash' "$HOME/.bashrc"; then
  printf '\neval "$(starship init bash)"\n' >> "$HOME/.bashrc"
fi

#-----------------------------------------------------------
# 13. Stow dotfiles (symlink each package under stow/ into $HOME)
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
# 14. GNOME settings (dconf import — idempotent)
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
