{ pkgs, lib, ... }:
let
  # Base VSCode settings stored in the Nix store; home.activation.vscodeSettings
  # writes a writable copy to ~/.config/Code/User/settings.json and merges any
  # extra keys VSCode wrote (e.g. extension popups). Nix wins on key conflicts.
  #
  # Settings Sync (sync.enable=true) periodically overwrites settings.json with
  # the cloud copy shortly after activation, clobbering any nix-managed key not
  # present there. Listing every nix-managed key in settingsSync.ignoredSettings
  # makes Settings Sync treat them as local-only, so it leaves them alone.
  vscodeManagedSettings = {
    "editor.fontSize" = 24;
    "editor.fontFamily" = "'Iosevka Nerd Font', monospace";
    "workbench.colorTheme" = "Gruvbox Light Hard";
    "workbench.startupEditor" = "none";
    "editor.codeActionsOnSave" = [ "source.organizeImports" ];
    "editor.formatOnSave" = true;
    "rust-analyzer.imports.granularity.group" = "module";
    "claudeCode.useTerminal" = true;
    "chat.disableAIFeatures" = true;
    "workbench.secondarySideBar.defaultVisibility" = "hidden";
    "terminal.integrated.fontSize" = 22;
    "security.workspace.trust.enabled" = false;
    "accessibility.signals.terminalBell" = { "sound" = "on"; };
    "makefile.configureOnOpen" = true;
    "terminal.integrated.enableBell" = true;
    "terminal.integrated.enableVisualBell" = true;
    "remote.SSH.path" = "/home/will/.local/bin/ts-ssh";
    "remote.SSH.connectTimeout" = 60;
    "files.associations" = {
      "justfile" = "makefile";
    };
  };
  vscodeBaseSettings = pkgs.writeText "vscode-nix-settings.json" (builtins.toJSON
    (vscodeManagedSettings // {
      "settingsSync.ignoredSettings" = builtins.attrNames vscodeManagedSettings;
    }));
in {
  # VS Code. Extensions come from the nix-vscode-extensions marketplace overlay
  # (works because this is the official MS build on FHS Ubuntu). Settings are
  # managed by home.activation.vscodeSettings (writable file, not a store
  # symlink) — edit vscodeBaseSettings in the let block above. Keep VS Code
  # Settings Sync disabled.
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

  # Write a writable settings.json (not a store symlink) so VSCode can persist
  # extension popup responses. On each switch: merge surviving VSCode-written keys
  # with the Nix base (Nix wins on conflict). Also writes .nix-settings-base.json
  # as a snapshot for dotfiles-sync to diff against when adopting new keys.
  home.activation.vscodeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    _cfg="$HOME/.config/Code/User"
    _settings="$_cfg/settings.json"
    _base="${vscodeBaseSettings}"
    mkdir -p "$_cfg"
    cp --no-preserve=mode --remove-destination "$_base" "$_cfg/.nix-settings-base.json"
    if [ -f "$_settings" ] && [ ! -L "$_settings" ]; then
      # VSCode writes JSONC (trailing commas, // comments); strip those before
      # merging so jq can parse it. python3 is always present on Ubuntu.
      _clean=$(python3 -c "
import json, re, sys
t = open(sys.argv[1]).read()
t = re.sub(r'//[^\n]*', "", t)
t = re.sub(r'/\*.*?\*/', "", t, flags=re.DOTALL)
t = re.sub(r',(\s*[}\]])', r'\1', t)
print(json.dumps(json.loads(t)))
" "$_settings" 2>/dev/null)
      if [ -n "$_clean" ]; then
        echo "$_clean" | ${pkgs.jq}/bin/jq -s '.[0] * .[1]' - "$_base" > "$_settings.tmp"
        mv "$_settings.tmp" "$_settings"
      else
        cp --no-preserve=mode "$_base" "$_settings"
      fi
    else
      rm -f "$_settings"
      cp --no-preserve=mode "$_base" "$_settings"
    fi
  '';

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
