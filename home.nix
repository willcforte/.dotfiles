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
  # vscode is declared via programs.vscode below (extensions + settings).

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

  # VS Code, fully declarative. Extensions come from the nix-vscode-extensions
  # marketplace overlay (works because this is the official MS build on FHS
  # Ubuntu). userSettings makes settings.json a read-only store symlink — edit
  # settings here, not in the GUI; keep VS Code Settings Sync disabled.
  programs.vscode = {
    enable = true;
    # Immutable extensions dir: exactly the declared set, no GUI installs.
    # Flip to true if you want to install extensions ad-hoc in the GUI again.
    mutableExtensionsDir = false;
    profiles.default = {
      extensions = with pkgs.vscode-marketplace; [
        anthropic.claude-code
        charliermarsh.ruff
        davidanson.vscode-markdownlint
        jdinhlife.gruvbox
        leanprover.lean4
        ms-azuretools.vscode-containers
        ms-python.debugpy
        ms-python.python
        ms-python.vscode-pylance
        ms-python.vscode-python-envs
        ms-vscode-remote.remote-containers
        ms-vscode-remote.remote-ssh
        ms-vscode-remote.remote-ssh-edit
        ms-vscode-remote.remote-wsl
        ms-vscode-remote.vscode-remote-extensionpack
        ms-vscode.cmake-tools
        ms-vscode.cpp-devtools
        ms-vscode.cpptools
        ms-vscode.cpptools-extension-pack
        ms-vscode.cpptools-themes
        ms-vscode.remote-explorer
        ms-vscode.remote-server
        oijaz.unicode-latex
        rust-lang.rust-analyzer
        tailscale.vscode-tailscale
        tamasfe.even-better-toml
        tomoki1207.pdf
      ];
      userSettings = {
        "editor.fontSize" = 18;
        "editor.fontFamily" = "'Iosevka Nerd Font', monospace";
        "workbench.colorTheme" = "Gruvbox Dark Hard";
        "workbench.startupEditor" = "none";
        "editor.codeActionsOnSave" = [ "source.organizeImports" ];
        "editor.formatOnSave" = true;
        "rust-analyzer.imports.granularity.group" = "module";
        "claudeCode.useTerminal" = true;
        "workbench.secondarySideBar.defaultVisibility" = "hidden";
        "terminal.integrated.fontSize" = 18;
      };
    };
  };

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
