{ pkgs, ... }: {
  # Shell integrations shared by bash (Linux) and zsh (Darwin).
  programs.starship = {
    enable = true;
    settings.hostname = {
      ssh_only = false;
      aliases = {
        "persona-0020" = "p20";
        "will-pc14250" = "wpc";
        "will-mbp" = "mbp";
      };
    };
  };
  programs.zoxide.enable = true;
  programs.fzf = {
    enable = true;
    enableBashIntegration = pkgs.stdenv.isLinux;
    enableZshIntegration = pkgs.stdenv.isDarwin;
  };
}
