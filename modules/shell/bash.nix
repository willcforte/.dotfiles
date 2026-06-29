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

      # Tailscale SSH re-auth: watch an interactive ssh session for the
      # "additional check" login URL; a clickable notification opens + focuses
      # it in the browser. Companion to the resume-probe user service.
      _tsssh_watch() {
        local log="$1" url seen=""
        while :; do
          url=$(grep -ohE 'https://login\.tailscale\.com/a/[A-Za-z0-9]+' "$log" \
                  2>/dev/null | head -1)
          if [ -n "$url" ] && [ "$url" != "$seen" ]; then
            seen="$url"
            if notify-send -u critical -A "open=Authenticate" \
                 "Tailscale SSH auth required" "Click to open the login page." \
                 | grep -q open; then
              xdg-open "$url" >/dev/null 2>&1
            fi
          fi
          sleep 1
        done
      }

      ssh() {
        if [ ! -t 1 ]; then command ssh "$@"; return; fi
        local log; log=$(mktemp)
        _tsssh_watch "$log" & local w=$!
        script -qefc "$(printf '%q ' command ssh "$@")" "$log"
        local rc=$?
        kill "$w" 2>/dev/null
        rm -f "$log"
        return $rc
      }
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
