{ config, pkgs, lib, ... }:
let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
  liveLink = path: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${path}";
  # Base VSCode settings stored in the Nix store; home.activation.vscodeSettings
  # writes a writable copy to ~/.config/Code/User/settings.json and merges any
  # extra keys VSCode wrote (e.g. extension popups). Nix wins on key conflicts.
  vscodeBaseSettings = pkgs.writeText "vscode-nix-settings.json" (builtins.toJSON {
    "editor.fontSize" = 24;
    "editor.fontFamily" = "'Iosevka Nerd Font', monospace";
    "workbench.colorTheme" = "Gruvbox Dark Hard";
    "workbench.startupEditor" = "none";
    "editor.codeActionsOnSave" = [ "source.organizeImports" ];
    "editor.formatOnSave" = true;
    "rust-analyzer.imports.granularity.group" = "module";
    "claudeCode.useTerminal" = true;
    "chat.disableAIFeatures" = true;
    "workbench.secondarySideBar.defaultVisibility" = "hidden";
    "terminal.integrated.fontSize" = 22;
    "security.workspace.trust.enabled" = false;
    "accessibility.signals.terminalBell" = { "sound" = "on"; };
    "makefile.configureOnOpen" = true;
    "terminal.integrated.enableBell" = true;
    "terminal.integrated.enableVisualBell" = true;
  });
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
    ".local/bin/gnome-settings-export" = {
      source = ./bin/gnome-settings-export;
      executable = true;
    };
    ".local/bin/update-config" = {
      source = ./bin/update-config.sh;
      executable = true;
    };
  };

  # Write a writable settings.json (not a store symlink) so VSCode can persist
  # extension popup responses. On each switch: merge surviving VSCode-written keys
  # with the Nix base (Nix wins on conflict). Also writes .nix-settings-base.json
  # as a snapshot for dotfiles-sync to diff against when adopting new keys.
  home.activation.vscodeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    _cfg="$HOME/.config/Code/User"
    _settings="$_cfg/settings.json"
    _base="${vscodeBaseSettings}"
    mkdir -p "$_cfg"
    cp --no-preserve=mode --remove-destination "$_base" "$_cfg/.nix-settings-base.json"
    if [ -f "$_settings" ] && [ ! -L "$_settings" ]; then
      ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$_settings" "$_base" > "$_settings.tmp"
      mv "$_settings.tmp" "$_settings"
    else
      rm -f "$_settings"
      cp --no-preserve=mode "$_base" "$_settings"
    fi
  '';

  # Make fontconfig see fonts from home.packages on non-NixOS.
  fonts.fontconfig.enable = true;

  # so GNOME finds GUI apps & icons
  targets.genericLinux.enable = true;

  # VS Code. Extensions come from the nix-vscode-extensions marketplace overlay
  # (works because this is the official MS build on FHS Ubuntu). Settings are
  # managed by home.activation.vscodeSettings (writable file, not a store
  # symlink) — edit vscodeBaseSettings in the let block above. Keep VS Code
  # Settings Sync disabled.
  programs.vscode = {
    enable = true;
    # Mutable extensions dir: the declared set below is installed, but VS Code
    # may also install extensions ad-hoc from the GUI/marketplace. GUI-installed
    # ones are reconciled into the list below by `/dotfiles-sync`, which prompts
    # to adopt them so they become declarative.
    mutableExtensionsDir = true;
    profiles.default = {
      extensions = with pkgs.vscode-marketplace; [
        anthropic.claude-code
        charliermarsh.ruff
        davidanson.vscode-markdownlint
        github.vscode-github-actions
        github.vscode-pull-request-github
        jdinhlife.gruvbox
        leanprover.lean4
        ms-azuretools.vscode-containers
        ms-python.debugpy
        ms-python.mypy-type-checker
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
        renan-r-santos.pixi-code
        rust-lang.rust-analyzer
        singularityinc.claude-notifier
        tailscale.vscode-tailscale
        tamasfe.even-better-toml
        tomoki1207.pdf
      ];
    };
  };

  programs.git = {
    enable = true;
    settings = {
      user.name = "Will C. Forte";
      user.email = "willcforte@gmail.com";
      init.defaultBranch = "main";
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

  # Syncthing — instant peer-to-peer sync of ~/.claude/memory across machines,
  # locked to the Tailscale tailnet (global discovery, relays, and NAT traversal
  # off; peers added by static tailnet IP). Devices/folders are filled in once each
  # machine's device ID is known (two-phase bring-up). Keys persist in the state
  # dir, so device IDs stay stable across rebuilds.
  services.syncthing = {
    enable = true;
    overrideDevices = true;
    overrideFolders = true;
    settings = {
      options = {
        globalAnnounceEnabled = false;
        localAnnounceEnabled = false;
        relaysEnabled = false;
        natEnabled = false;
        urAccepted = -1;
        crashReportingEnabled = false;
      };
      devices = {
        "persona-0020" = {
          id = "XHDQTBK-C7X5RM2-IJK4LWP-A4QE2K4-BR44Q5C-C53XGC5-D5FCB65-KAEVQAM";
          addresses = [ "tcp://100.119.209.20:22000" ];
        };
        "will-pc14250" = {
          id = "247PMAV-6DKYW24-TASP2EX-LMGYIKE-MTHNRZ4-VJ2GOAB-VGDU24S-PAUWFQX";
          addresses = [ "tcp://100.97.45.110:22000" ];
        };
      };
      folders."claude-memory" = {
        path = "/home/will/.claude/memory";
        devices = [ "persona-0020" "will-pc14250" ];
        versioning = {
          type = "staggered";
          params = { cleanInterval = "3600"; maxAge = "2592000"; };
        };
      };
    };
  };

  programs.home-manager.enable = true;
}
