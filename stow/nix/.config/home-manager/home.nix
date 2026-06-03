{ pkgs, ... }: {
  home.username = "will";
  home.homeDirectory = "/home/will";

  home.stateVersion = "25.05";

  home.packages = with pkgs; [
    git
    gh
    neovim
    tmux
    btop
  ];

  programs.tmux = {
    enable = true;
    clock24 = false;
    extraConfig = ''
      set -g mouse on
    '';
  };

  programs.git = {
    enable = true;
    userName = "Will C. Forte";
    userEmail = "willcforte@gmail.com";
  };

  programs.gh = {
    enable = true;
    gitCredentialHelper = {
      enable = true;
    };
    settings = {
      git_protocol = "https";
      prompt = "enabled";
    };
  };

  programs.bash.shellAliases.ccode = "claude";

  programs.home-manager.enable = true;
}
