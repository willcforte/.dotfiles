{ config, pkgs, ... }:
let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
  liveLink = path: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${path}";
  mutableConfig = "${config.home.homeDirectory}/.claude-private";
  mkMutableSymlink = path: config.lib.file.mkOutOfStoreSymlink "${mutableConfig}/${path}";
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
    ./modules/fonts.nix
    ./modules/gnome.nix
    ./modules/programs/zen.nix
    ./modules/programs/vscode.nix
    ./modules/programs/git.nix
    ./modules/shell/bash.nix
  ];

  home.packages = with pkgs; [
    # useful command explanations
    tldr # e.g. tldr fzf

    # CLI tools
    gh
    neovim
    lazygit
    lazydocker
    tmux
    btop
    tree
    gearlever
    solaar
    lsd
    bat
    dust
    fd
    ripgrep
    ripgrep-all
    procs
    ast-grep
    yq-go
    shellcheck
    shfmt
    actionlint
    pre-commit
    nmap
    uv
    rtk
    wezterm
    nodejs
    fzf

    # GUI apps
    obsidian
    slack
    vlc
    gimp
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
    ".claude/LESSONS.md".source = mkMutableSymlink "LESSONS.md";

    # Zen reads user.js from the legacy ~/.zen profile (not the module's XDG
    # ~/.config/zen). Profile dir id is host-specific; inert on other hosts.
    ".zen/8923kzk4.Default (release)/user.js".text = ''
      user_pref("cookiebanners.service.mode", 2);
    '';
  };

  # so GNOME finds GUI apps & icons
  targets.genericLinux.enable = true;

  programs.home-manager.enable = true;
}
