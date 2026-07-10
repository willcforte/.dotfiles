{ config, pkgs, ... }:
let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
  updater = pkgs.writeShellScript "nix-flake-autoupdate" ''
    export PATH=/nix/var/nix/profiles/default/bin:${config.home.homeDirectory}/.nix-profile/bin:${pkgs.git}/bin:/usr/bin:/bin:$PATH
    cd ${dotfiles} || exit 1
    exec nix --extra-experimental-features 'nix-command flakes' flake update
  '';
in {
  systemd.user.services.nix-flake-autoupdate = {
    Unit.Description = "Daily nix flake.lock update for ~/.dotfiles (no switch, no reboot)";
    Service = {
      Type = "oneshot";
      ExecStart = "${updater}";
    };
  };

  systemd.user.timers.nix-flake-autoupdate = {
    Unit.Description = "Daily timer: bump ~/.dotfiles flake.lock";
    Timer = {
      OnCalendar = "daily";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
