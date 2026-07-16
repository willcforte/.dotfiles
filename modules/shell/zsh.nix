# Cross-platform zsh config, shared by Linux and Darwin. zsh is the login shell
# on both platforms; install.sh registers the nix zsh in /etc/shells and sets
# it via usermod on Ubuntu. Machine-specific lines and secrets go in
# ~/.zshrc.local instead.
{ isDarwin, ... }: {
  programs.zsh = {
    enable = true;
    shellAliases = {
      ccode = "claude --system-prompt \"\"";
      #ccbare = "claude --bare";
      # BSD ls (macOS) uses -G for colour; GNU ls (Linux) uses --color=auto.
      ls = if isDarwin then "ls -G" else "ls --color=auto";
      grep = "grep --color=auto";
      ll = "ls -alF";
      la = "ls -A";
      l = "ls -CF";
    };
    oh-my-zsh = {
      enable = true;
      # "macos" plugin is Darwin-only. fzf keybindings come from
      # programs.fzf.enableZshIntegration (common.nix), not an omz plugin,
      # to avoid double-binding.
      plugins = [ "git" ] ++ (if isDarwin then [ "macos" ] else [ ]);
      theme = ""; # starship (modules/shell/common.nix) owns the prompt
    };
    initContent = ''
      export PATH="$HOME/.local/bin:$PATH"

      # Rust toolchain (rustup is installed by the platform bootstrap script)
      [ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

      # Nix daemon env for non-login shells (same path on Linux and macOS)
      [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ] \
        && . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

      # git helpers: gpush/gpull/gcom/gcpp (see ~/.claude/scripts/gq-shell.sh)
      [ -f "$HOME/.claude/scripts/gq-shell.sh" ] && . "$HOME/.claude/scripts/gq-shell.sh"

      # Machine-specific config and secrets (not in dotfiles repo)
      [ -f "$HOME/.zshrc.local" ] && . "$HOME/.zshrc.local"

      # pixi autocompletion (guarded: pixi is installed out-of-band, may be absent)
      command -v pixi >/dev/null && eval "$(pixi completion --shell zsh)"
    ''
    + (if isDarwin then ''

      # Homebrew (Apple Silicon)
      [ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv)"
    '' else ''

      # Tailscale SSH re-auth: route ssh through the ts-ssh wrapper, which
      # surfaces the "additional check" login URL (Linux desktop only).
      ssh() { "$HOME/.local/bin/ts-ssh" "$@"; }
    '');
  };
}
