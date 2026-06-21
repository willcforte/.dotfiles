{ config, pkgs, ... }:
let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
  liveLink = path: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${path}";
in {
  home.username = "will";
  home.homeDirectory = "/home/will";

  home.stateVersion = "25.05";

  # pixi installed via official installer (PIXI_NO_PATH_UPDATE=1); keep its
  # self-updating binary on PATH declaratively.
  home.sessionPath = [ "$HOME/.pixi/bin" ];

  # Suppress the notify-send "N unread news items" popup on activation.
  news.display = "silent";

  imports = [
    ./modules/gnome/terminal.nix
    ./modules/gnome/desktop.nix
    ./modules/gnome/extensions.nix
    ./modules/programs/zen.nix
    ./modules/programs/vscode.nix
    ./modules/programs/git.nix
    ./modules/shell/bash.nix
    ./modules/services/syncthing.nix
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

    # Structural code search/rewrite (AST patterns) + YAML processor (jq for YAML)
    ast-grep
    yq-go
    fzf

    # Lint/format toolbox + pre-commit framework (lint-before-commit gates)
    shellcheck
    shfmt
    actionlint
    pre-commit

    uv

    # CLI proxy that cuts LLM token use on common dev commands
    rtk

    # config in config/wezterm/.wezterm.lua
    wezterm

    nodejs

    # Terminal font
    (iosevka-bin.override { variant = "SGr-IosevkaTermSS18"; })

    # GUI apps (formerly flatpak/snap/apt). GL via /run/opengl-driver
    # (nix-system-graphics) — no nixGL wrapping needed.
    obsidian
    slack
    vlc
    flameshot
  ];

  # Symlinks to dotfiles
  home.file = {
    ".wezterm.lua".source = liveLink "config/wezterm/.wezterm.lua";
    ".tmux.conf".source = liveLink "config/tmux/.tmux.conf";
    ".local/bin/gnome-settings-export" = {
      source = ./bin/gnome-settings-export;
      executable = true;
    };
    ".local/bin/update-config" = {
      source = ./bin/update-config.sh;
      executable = true;
    };
    ".claude/LESSONS.md".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.claude-private/LESSONS.md";
  };

  # Make fontconfig see fonts from home.packages on non-NixOS.
  fonts.fontconfig.enable = true;

  # so GNOME finds GUI apps & icons
  targets.genericLinux.enable = true;

  programs.home-manager.enable = true;
}
