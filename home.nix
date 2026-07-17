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
  home.sessionPath = [ "$HOME/.pixi/bin" "$HOME/.npm-global/bin" ];

  # npm's default global prefix is the read-only nodejs store path, so a bare
  # `npm install -g` (e.g. from Claude Code plugin hooks) fails with EACCES.
  # Point it at a writable directory in $HOME instead.
  home.sessionVariables.NPM_CONFIG_PREFIX = "$HOME/.npm-global";

  # Suppress the notify-send "N unread news items" popup on activation. No-op
  # on Darwin (notify-send doesn't exist there).
  news.display = "silent";

  imports = [
    ./modules/programs/git.nix
    ./modules/shell/common.nix
    ./modules/shell/zsh.nix
  ] ++ lib.optionals (!isDarwin) [
    ./modules/fonts.nix
    ./modules/gnome.nix
    ./modules/programs/zen.nix
    ./modules/programs/vscode.nix
    ./modules/services/tailscale-ssh-probe.nix
    # bash.nix keeps bash functional on Ubuntu (e.g. for scripts that source
    # ~/.bashrc). install.sh sets zsh as the actual login shell via usermod.
    ./modules/shell/bash.nix
    ./modules/services/nix-flake-autoupdate.nix
    ./modules/linux-desktop.nix
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
    just

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

    tailscale

    # CLI proxy that cuts LLM token use on common dev commands
    rtk

    # config in config/wezterm/.wezterm.lua
    wezterm

    nodejs
  ];

  # If claude-usage-bar is installed (not managed by Nix), register it as an
  # autostart entry so it launches on login. Conditional on the binary existing
  # so this is a no-op on macOS and machines where it hasn't been installed.
  home.activation.claudeUsageBarAutostart = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if command -v claude-usage-bar >/dev/null 2>&1; then
      mkdir -p "$HOME/.config/autostart"
      dst="$HOME/.config/autostart/claude-usage-bar.desktop"
      src="/usr/share/applications/claude-usage-bar.desktop"
      if [ -f "$src" ] && [ ! -e "$dst" ]; then
        cp "$src" "$dst"
      fi
    fi
  '';

  # Linear CLI (schpet/linear-cli) isn't in nixpkgs; install it globally via
  # npm (nodejs already declared above) on each activation so it stays current.
  # npm's default global prefix is the read-only nodejs store path, so point
  # it at a writable directory in $HOME instead. --allow-scripts is required
  # because the package's postinstall downloads the actual binary release.
  home.activation.linearCli = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run env PATH="${pkgs.nodejs}/bin:${pkgs.gnutar}/bin:${pkgs.xz}/bin:$PATH" ${pkgs.nodejs}/bin/npm install -g --prefix "$HOME/.npm-global" --allow-scripts=@schpet/linear-cli @schpet/linear-cli

    # Also symlink into ~/.local/bin, which is on PATH even in shells that
    # don't source .zshenv/.zshrc (e.g. sandboxed non-interactive tool shells).
    run mkdir -p "$HOME/.local/bin"
    run ln -sf "$HOME/.npm-global/bin/linear" "$HOME/.local/bin/linear"
  '';

  # Symlinks to dotfiles
  home.file = {
    ".wezterm.lua".source = liveLink "config/wezterm/.wezterm.lua";
    ".tmux.conf".source = liveLink "config/tmux/.tmux.conf";
    ".local/bin/gnome-settings-export" = {
      source = ./bin/gnome-settings-export;
      executable = true;
    };
    # Single idempotent install-or-update script per platform: installs missing
    # prereqs then applies the flake config. Same command (`update-config`) on
    # both; guarded so routine updates skip the heavy/sudo bits.
    ".local/bin/update-config" = {
      source = if isDarwin then ./install-darwin.sh else ./install.sh;
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
