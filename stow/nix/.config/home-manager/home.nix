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

  programs.bash.shellAliases.ccode = "claude";

  programs.home-manager.enable = true;
}
