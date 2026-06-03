# Host-specific config for will-pc14250 (personal PC).
{ pkgs, ... }: {
  home.packages = with pkgs; [
    kicad
  ];
}
