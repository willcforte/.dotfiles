# Dotfiles

Personal dotfiles for Ubuntu 24.04 LTS, managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Layout

```
install.sh        # one-shot provisioning: apt/snap/flatpak repos + packages
packages/         # package manifests (apt.txt, snap.txt, flatpak.txt)
gnome/            # dconf dumps for GNOME desktop/terminal/extensions
stow/             # stow packages — symlinked into $HOME
├── claude/       # Claude Code settings.json
├── git/          # .gitconfig
├── gnome/        # gnome-settings-export helper
├── tmux/         # .tmux.conf
└── wezterm/      # .wezterm.lua
```

## Install

```bash
git clone https://github.com/willcforte/.dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh          # installs packages + third-party repos (asks for sudo)
```

## Stow

Each directory under `stow/` is a package. To symlink one into `$HOME`:

```bash
cd ~/.dotfiles/stow
stow -t ~ <package>   # e.g. stow -t ~ claude
```

`-D` unstows; `-R` restows after changes.
