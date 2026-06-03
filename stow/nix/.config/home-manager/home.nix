{ pkgs, ... }: {
  home.username = "will";
  home.homeDirectory = "/home/will";

  home.stateVersion = "25.05";

  # Packages only — their configs are stowed (stow/git/.gitconfig,
  # stow/tmux/.tmux.conf) and take precedence over anything
  # home-manager would generate. Keep config out of here.
  home.packages = with pkgs; [
    git
    gh
    neovim
    tmux
    btop
    tree
    lazygit
    lazydocker
  ];

  # Non-NixOS (Ubuntu) integration: adds ~/.nix-profile/share to
  # XDG_DATA_DIRS (via environment.d) so GNOME finds desktop entries
  # and icons of nix-installed GUI apps (e.g. zen-beta).
  targets.genericLinux.enable = true;

  programs.bash.shellAliases.ccode = "claude";

  programs.home-manager.enable = true;
}
