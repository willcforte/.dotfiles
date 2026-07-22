{ pkgs, lib, ... }:
{
  # VS Code. Extensions come from the nix-vscode-extensions marketplace overlay
  # (works because this is the official MS build on FHS Ubuntu). Settings are
  # NOT Nix-managed: Will uses VS Code Settings Sync (cloud) for settings.json,
  # so Nix only owns extensions here.
  programs.vscode = {
    enable = true;
    # Mutable extensions dir: the declared set below is installed, but VS Code
    # may also install extensions ad-hoc from the GUI/marketplace. GUI-installed
    # ones are reconciled into the list below by `/dotfiles-sync`, which prompts
    # to adopt them so they become declarative.
    mutableExtensionsDir = true;
    profiles.default = {
      extensions = with pkgs.vscode-marketplace; [
        anthropic.claude-code
        charliermarsh.ruff
        davidanson.vscode-markdownlint
        github.vscode-github-actions
        github.vscode-pull-request-github
        jdinhlife.gruvbox
        leanprover.lean4
        ms-azuretools.vscode-containers
        ms-python.debugpy
        ms-python.mypy-type-checker
        ms-python.python
        ms-python.vscode-pylance
        ms-python.vscode-python-envs
        ms-vscode-remote.remote-containers
        ms-vscode-remote.remote-ssh
        ms-vscode-remote.remote-ssh-edit
        ms-vscode-remote.remote-wsl
        ms-vscode-remote.vscode-remote-extensionpack
        ms-vscode.cmake-tools
        ms-vscode.cpp-devtools
        ms-vscode.cpptools
        ms-vscode.cpptools-extension-pack
        ms-vscode.cpptools-themes
        ms-vscode.remote-explorer
        ms-vscode.remote-server
        oijaz.unicode-latex
        renan-r-santos.pixi-code
        rust-lang.rust-analyzer
        tailscale.vscode-tailscale
        tamasfe.even-better-toml
        tomoki1207.pdf
	changwang.copy-file-path-with-range
      ];
    };
  };

  # On a fresh machine ~/.vscode/extensions doesn't exist yet, so
  # home-manager's own extension-symlinking activation script fails its first
  # `ln -s` with "No such file or directory" (whichever extension it hits
  # first, e.g. rust-lang.rust-analyzer). Pre-create the dir so that's silent.
  # A machine previously on immutableExtensionsDir may still have
  # ~/.vscode/extensions as a symlink into the Nix store; mkdir -p errors on
  # that stray non-directory entry, so clear it first.
  home.activation.vscodeExtensionsDir =
    lib.hm.dag.entryBefore [ "installPackages" ] ''
      if [ -L "$HOME/.vscode/extensions" ]; then
        rm -f "$HOME/.vscode/extensions"
      fi
      mkdir -p "$HOME/.vscode/extensions"
    '';

  # The mutableExtensionsDir path only regenerates extensions.json via an
  # onChange hook when the immutable extension set *changes*. A reinstall that
  # produces an identical set leaves a stale/clobbered extensions.json, so VS
  # Code loads only whatever few entries survived. Remove the manifest on every
  # activation; VS Code rebuilds it from the full extensions dir (Nix symlinks +
  # ad-hoc GUI installs) on next launch.
  home.activation.vscodeExtensionsManifest =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      rm -f "$HOME/.vscode/extensions/extensions.json" \
            "$HOME/.vscode/extensions/.init-default-profile-extensions"
    '';

  # Trusted domains (link-open confirmation for e.g. terminal links) aren't a
  # settings.json key — VS Code stores them in the application-state SQLite DB
  # under key http.linkProtectionTrustedDomains. Upsert "*" so all domains are
  # trusted and the confirmation prompt never appears.
  home.activation.vscodeTrustedDomains = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    _db="$HOME/.config/Code/User/globalStorage/state.vscdb"
    if [ -f "$_db" ]; then
      ${pkgs.sqlite}/bin/sqlite3 "$_db" \
        "INSERT INTO ItemTable (key, value) VALUES ('http.linkProtectionTrustedDomains', '[\"*\"]')
         ON CONFLICT(key) DO UPDATE SET value=excluded.value;"
    fi
  '';
}
