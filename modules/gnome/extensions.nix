# Generated via dconf2nix: https://github.com/gvolpe/dconf2nix
{ lib, ... }:

with lib.hm.gvariant;

{
  dconf.settings = {
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

  };
}
