{ ... }: {
  # Machine-specific lines and secrets go in ~/.bashrc.local instead.
  programs.bash = {
    enable = true;
    historyControl = [ "ignoreboth" ];
    historySize = 1000;
    historyFileSize = 2000;
    shellAliases = {
      ccode = "claude --system-prompt \"\"";
      #ccbare = "claude --bare";
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

      # git helpers: gpush/gpull/gcom/gcpp (see ~/.claude/scripts/gq-shell.sh)
      [ -f "$HOME/.claude/scripts/gq-shell.sh" ] && . "$HOME/.claude/scripts/gq-shell.sh"

      # Machine-specific config and secrets (not in dotfiles repo)
      [ -f "$HOME/.bashrc.local" ] && . "$HOME/.bashrc.local"

      # Tailscale SSH re-auth: route ssh through the ts-ssh wrapper, which
      # surfaces the "additional check" login URL (clickable notification here,
      # auto-open from VSCode via remote.SSH.path). See bin/ts-ssh.sh.
      ssh() { "$HOME/.local/bin/ts-ssh" "$@"; }
    '';
  };

  # Shell integrations
  programs.starship = {
    enable = true;
    settings.hostname = {
      ssh_only = false;
      aliases = {
        "persona-0020" = "p20";
        "will-pc14250" = "wpc";
      };
    };
  };
  programs.zoxide.enable = true;
  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
  };
}
