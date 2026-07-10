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
    # zsh is configured on both platforms; bash only on Linux (login shell).
    enableZshIntegration = true;
    enableBashIntegration = pkgs.stdenv.isLinux;
  };
}
