{ pkgs, lib, ... }:
let
  # Base VSCode settings stored in the Nix store; home.activation.vscodeSettings
  # writes a writable copy to ~/.config/Code/User/settings.json and merges any
  # extra keys VSCode wrote (e.g. extension popups). Nix wins on key conflicts.
  vscodeBaseSettings = pkgs.writeText "vscode-nix-settings.json" (builtins.toJSON {
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
  });
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
      ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$_settings" "$_base" > "$_settings.tmp"
      mv "$_settings.tmp" "$_settings"
    else
      rm -f "$_settings"
      cp --no-preserve=mode "$_base" "$_settings"
    fi
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
