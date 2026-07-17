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

  programs.jujutsu = {
    enable = true;
    settings = {
      user.name = "Will C. Forte";
      user.email = "willcforte@gmail.com";
      aliases.bl = [ "bookmark" "list" "--all-remotes" ];
      aliases.resync = [
        "rebase"
        "-s"
        "roots(trunk()..@)"
        "-d"
        "trunk()"
        "--ignore-immutable"
      ];
      revsets.log = "@ | bookmarks() | remote_bookmarks() | trunk()";
    };
  };
}
