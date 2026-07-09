{ ... }: {
  # Machine-specific lines and secrets go in ~/.zshrc.local instead.
  programs.zsh = {
    enable = true;
    shellAliases = {
      ccode = "claude --system-prompt \"\"";
      #ccbare = "claude --bare";
      ls = "ls -G";
      grep = "grep --color=auto";
      ll = "ls -alF";
      la = "ls -A";
      l = "ls -CF";
    };
    oh-my-zsh = {
      enable = true;
      plugins = [ "git" "macos" "fzf" ];
      theme = ""; # starship (modules/shell/common.nix) owns the prompt
    };
    initContent = ''
      export PATH="$HOME/.local/bin:$PATH"

      # Rust toolchain (rustup is installed by install-darwin.sh)
      [ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

      # Nix daemon env for non-login shells
      [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ] \
        && . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

      # Machine-specific config and secrets (not in dotfiles repo)
      [ -f "$HOME/.zshrc.local" ] && . "$HOME/.zshrc.local"

      # pixi autocompletion
      eval "$(pixi completion --shell zsh)"
    '';
  };
}
