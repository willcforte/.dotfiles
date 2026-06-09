{ config, pkgs, lib, ... }:
let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
  liveLink = path: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${path}";
in {
  home.username = "will";
  home.homeDirectory = "/home/will";

  home.stateVersion = "25.05";

  imports = [
    ./modules/gnome/terminal.nix
    ./modules/gnome/desktop.nix
    ./modules/gnome/extensions.nix
  ];

  home.packages = with pkgs; [
    gh
    neovim
    tmux
    btop
    tree
    lazygit
    lazydocker
    gearlever
    pinta
    solaar

    # CLI tools (migrated from apt)
    lsd
    nmap
    vim
    tldr

    # Rust-built CLI tools
    bat
    dust
    fd
    ripgrep
    ripgrep-all
    procs

    uv

    # config in config/wezterm/.wezterm.lua
    wezterm

    nodejs

    # Terminal font
    (iosevka-bin.override { variant = "SGr-IosevkaTermSS18"; })

    # GUI apps (formerly flatpak/snap/apt). GL via /run/opengl-driver
    # (nix-system-graphics) — no nixGL wrapping needed.
    obsidian
    slack
    vscode
    vlc
    flameshot
  ];

  # Symlinks to dotfiles
  home.file = {
    ".wezterm.lua".source = liveLink "config/wezterm/.wezterm.lua";
    ".tmux.conf".source = liveLink "config/tmux/.tmux.conf";
    # Only settings.json is dotfiles-managed; the rest of ~/.claude is
    # runtime state and secrets (gitignored). liveLink keeps it writable.
    ".claude/settings.json".source = liveLink "config/claude/settings.json";
    ".local/bin/gnome-settings-export" = {
      source = ./bin/gnome-settings-export;
      executable = true;
    };
    ".local/bin/update-config" = {
      source = ./bin/update-config.sh;
      executable = true;
    };
  };

  # Make fontconfig see fonts from home.packages on non-NixOS.
  fonts.fontconfig.enable = true;

  # so GNOME finds GUI apps & icons
  targets.genericLinux.enable = true;

  programs.git = {
    enable = true;
    settings = {
      user.name = "Will C. Forte";
      user.email = "willcforte@gmail.com";
      push.autoSetupRemote = true;
      # Clear any inherited helper (empty string), then delegate to gh.
      credential."https://github.com".helper = [ "" "!gh auth git-credential" ];
      credential."https://gist.github.com".helper = [ "" "!gh auth git-credential" ];
    };
  };

  # Machine-specific lines and secrets go in ~/.bashrc.local instead.
  programs.bash = {
    enable = true;
    historyControl = [ "ignoreboth" ];
    historySize = 1000;
    historyFileSize = 2000;
    shellAliases = {
      ccode = "claude";
      ls = "ls --color=auto";
      grep = "grep --color=auto";
      ll = "ls -alF";
      la = "ls -A";
      l = "ls -CF";
    };
    initExtra = ''
      # bash-completion (Ubuntu system package)
      if ! shopt -oq posix; then
        if [ -f /usr/share/bash-completion/bash_completion ]; then
          . /usr/share/bash-completion/bash_completion
        elif [ -f /etc/bash_completion ]; then
          . /etc/bash_completion
        fi
      fi

      export PATH="$HOME/.local/bin:$PATH"

      # Rust toolchain (rustup is installed by install.sh)
      [ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

      # Nix daemon env for non-login shells
      [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ] \
        && . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

      # Machine-specific config and secrets (not in dotfiles repo)
      [ -f "$HOME/.bashrc.local" ] && . "$HOME/.bashrc.local"
    '';
  };

  # Shell integrations
  programs.starship.enable = true;
  programs.zoxide.enable = true;

  programs.home-manager.enable = true;
}
