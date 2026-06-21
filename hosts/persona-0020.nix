# Host-specific config for persona-0020 (work desktop).
{ lib, ... }: {
  # Syncthing disabled on this host (base home.nix enables it).
  services.syncthing.enable = lib.mkForce false;
}
