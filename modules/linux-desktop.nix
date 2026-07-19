{ pkgs, ... }: {
  home.packages = with pkgs; [
    gearlever
    pinta
    solaar

    # GUI apps (formerly flatpak/snap/apt). GL via /run/opengl-driver
    # (nix-system-graphics) — no nixGL wrapping needed.
    obsidian
    slack
    vlc
    flameshot
    gimp
  ];

  # Zen reads user.js from the legacy ~/.zen profile (not the module's XDG
  # ~/.config/zen). Profile dir id is host-specific; inert on other hosts.
  home.file.".zen/8923kzk4.Default (release)/user.js".text = ''
    user_pref("cookiebanners.service.mode", 2);
  '';

  # so GNOME finds GUI apps & icons
  targets.genericLinux.enable = true;

  # nix-system-graphics (system-manager) owns /run/opengl-driver, so disable
  # home-manager's own non-NixOS GPU management — otherwise its activation
  # check compares that symlink against its own driver path, never matches,
  # and nags "GPU drivers require an update" on every switch.
  targets.genericLinux.gpu.enable = false;
}
