{ ... }: {
  nixpkgs.hostPlatform = "aarch64-darwin";

  # Nix itself is installed and managed by the plain Nix installer (see
  # install-darwin.sh), not nix-darwin, to avoid two tools fighting over
  # /etc/nix/nix.conf and the daemon.
  nix.enable = false;

  system.primaryUser = "will";
  system.stateVersion = 7;

  # nix-darwin's own /etc/zshrc integration (separate from home-manager's
  # programs.zsh, which owns ~/.zshrc — see modules/shell/zsh.nix).
  programs.zsh.enable = true;

  # Homebrew casks for GUI apps that don't have (or aren't worth using as)
  # Nix packages on Darwin, mirroring the Linux GUI app list in
  # modules/linux-desktop.nix where a mac equivalent exists. No
  # `cleanup = "zap"` on this first pass — that uninstalls anything not
  # declared here, which is too aggressive for a fresh box Will may also
  # install casks on by hand.
  system.activationScripts.postActivation.text = ''
    pmset -a displaysleep 0
  '';

  homebrew = {
    enable = true;
    onActivation.autoUpdate = true;
    casks = [
      "slack"
      "obsidian"
      "vlc"
      "gimp"
    ];
  };
}
