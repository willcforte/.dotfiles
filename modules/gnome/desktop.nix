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

  };
}
