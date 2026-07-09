{ config, pkgs, lib, isDarwin, ... }:
let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
  liveLink = path: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${path}";
  mutableConfig = "${config.home.homeDirectory}/.claude-private";
  mkMutableSymlink = path: config.lib.file.mkOutOfStoreSymlink "${mutableConfig}/${path}";
in {
  home.username = "will";
  home.homeDirectory = if isDarwin then "/Users/will" else "/home/will";

  home.stateVersion = "25.05";

  # pixi installed via official installer (PIXI_NO_PATH_UPDATE=1); keep its
  # self-updating binary on PATH declaratively.
  home.sessionPath = [ "$HOME/.pixi/bin" ];

  # Suppress the notify-send "N unread news items" popup on activation. No-op
  # on Darwin (notify-send doesn't exist there).
  news.display = "silent";

  imports = [
    ./modules/programs/git.nix
    ./modules/shell/common.nix
  ] ++ lib.optionals (!isDarwin) [
    ./modules/fonts.nix
    ./modules/gnome.nix
    ./modules/programs/zen.nix
    ./modules/programs/vscode.nix
    ./modules/services/tailscale-ssh-probe.nix
    ./modules/shell/bash.nix
    ./modules/linux-desktop.nix
  ] ++ lib.optionals isDarwin [
    ./modules/shell/zsh.nix
  ];

  home.packages = with pkgs; [
    gh
    neovim
    tmux
    btop
    tree
    lazygit
    lazydocker
    jujutsu
    lazyjj

    # version control
    gh
    lazygit
    lazydocker
    jujutsu
    lazyjj
    gh-dash

    # CLI tools
    lsd
    nmap
    vim
    tldr
    fzf
    bat
    dust
    fd
    ripgrep
    ripgrep-all
    procs

    # Structural code search/rewrite (AST patterns) + YAML processor (jq for YAML)
    ast-grep
    yq-go

    # tomlq (jq for TOML), from python `yq`. Expose only tomlq so its `yq`
    # binary doesn't collide with yq-go above.
    (runCommand "tomlq" { } ''
      mkdir -p $out/bin
      ln -s ${yq}/bin/tomlq $out/bin/tomlq
    '')

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
      source = if pkgs.stdenv.isDarwin then ./bin/update-config-darwin.sh else ./bin/update-config.sh;
      executable = true;
    };
    ".local/bin/ts-ssh" = {
      source = ./bin/ts-ssh.sh;
      executable = true;
    };
    ".claude/LESSONS.md".source = mkMutableSymlink "LESSONS.md";
  };

  programs.home-manager.enable = true;
}
