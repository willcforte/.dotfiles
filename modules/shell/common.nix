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

    # 1. Add your custom JJ module into your prompt layout string
    settings.format = "$all\${custom.jj}$character";

    # 2. Define the custom JJ module block
    settings.custom.jj = {
      command = "prompt";
      format = "on [$output](bold purple) ";
      ignore_timeout = true;
      # Calls the 'jj-starship' binary in the shell 
      shell = ["jj-starship" "--ignore-working-copy" "starship"];
      use_stdin = false;
      # Only triggers the command if a .jj directory exists
      when = "test -d .jj";
    };
  };

  programs.zoxide.enable = true;
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };
}
