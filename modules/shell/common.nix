{ pkgs, ... }: {
  # Shell integrations shared across platforms (zsh on both Linux and Darwin).
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings.hostname = {
      ssh_only = false;
      aliases = {
        "persona-0020" = "p20";
        "will-pc14250" = "wpc";
        "will-mbp" = "mbp";
      };
    };

    # jj revision in the prompt, via the jj-starship binary. Only runs in
    # repos with a .jj directory.
    settings.format = "$all\${custom.jj}$character";
    settings.custom.jj = {
      command = "prompt";
      format = "on [$output](bold purple) ";
      ignore_timeout = true;
      shell = ["jj-starship" "--ignore-working-copy" "starship"];
      use_stdin = false;
      when = "test -d .jj";
    };
  };

  programs.zoxide.enable = true;
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };
}
