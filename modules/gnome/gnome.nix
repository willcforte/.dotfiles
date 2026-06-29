# Generated via dconf2nix: https://github.com/gvolpe/dconf2nix
{ lib, ... }:

with lib.hm.gvariant;

{
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      clock-format = "12h";
      clock-show-date = true;
      clock-show-weekday = true;
      color-scheme = "light";
      enable-hot-corners = false;
      gtk-theme = "Yaru-dark";
      icon-theme = "Yaru";
    };

    "org/gnome/shell/extensions/dash-to-dock" = {
      dash-max-icon-size = 46;
      dock-fixed = true;
      dock-position = "BOTTOM";
      multi-monitor = false;
    };

    "org/gnome/shell/extensions/date-menu-formatter" = {
      font-size = 12;
      font-weight = "bold";
      pattern = "EEE MMM d       t      D";
      text-align = "center";
      update-level = 1;
    };

    "org/gnome/shell/extensions/ding" = {
      check-x11wayland = true;
    };

    "org/gnome/shell/extensions/tiling-assistant" = {
      active-window-hint-color = "rgb(211,70,21)";
      last-version-installed = 46;
      tiling-popup-all-workspace = true;
    };

    "org/gnome/terminal/legacy/profiles:" = {
      default = "b1dcc9dd-5262-4d8d-a863-c897e6d979b9";
      list = [ "b1dcc9dd-5262-4d8d-a863-c897e6d979b9" ];
    };

    "org/gnome/terminal/legacy/profiles:/:b1dcc9dd-5262-4d8d-a863-c897e6d979b9" = {
      default-size-columns = 80;
      use-system-font = true;
      visible-name = "Will";
    };
  };
}
