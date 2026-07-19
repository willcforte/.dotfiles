{ config, ... }:
let
  # Absolute path to an on-disk script (see note in the .sh): keeps ExecStart a
  # constant string so nixpkgs bumps never mark this unit "changed" and trigger
  # a reloadSystemd restart loop.
  script = "${config.home.homeDirectory}/.dotfiles/modules/services/nix-flake-autoupdate.sh";
in {
  systemd.user.services.nix-flake-autoupdate = {
    Unit.Description = "Daily flake.lock bump + home-manager switch for ~/.dotfiles";
    Service = {
      Type = "oneshot";
      ExecStart = script;
    };
  };

  systemd.user.timers.nix-flake-autoupdate = {
    Unit.Description = "Daily timer: bump ~/.dotfiles flake.lock and switch";
    Timer = {
      OnCalendar = "daily";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
