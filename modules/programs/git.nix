{ ... }: {
  programs.git = {
    enable = true;
    settings = {
      user.name = "Will C. Forte";
      user.email = "willcforte@gmail.com";
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
      # Clear any inherited helper (empty string), then delegate to gh.
      credential."https://github.com".helper = [ "" "!gh auth git-credential" ];
      credential."https://gist.github.com".helper = [ "" "!gh auth git-credential" ];
    };
  };
}
