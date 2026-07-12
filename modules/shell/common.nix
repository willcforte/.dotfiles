{ pkgs, ... }: {
  # Shell integrations shared across platforms (zsh on both Linux and Darwin).
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
    enableZshIntegration = true;
  };
}
