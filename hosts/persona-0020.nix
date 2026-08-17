# Host-specific config for persona-0020 (work desktop).
{ ... }: {
  # Syncthing enabled (base home.nix); syncs ~/.claude-private with will-pc14250.

  # LocalSend (home.nix, Linux-only) needs its discovery/transfer port open.
  # ufw is unmanaged by Nix here (no firewall module in this repo), so this
  # is a manual one-time step on a fresh install:
  #   sudo ufw allow 53317/tcp
  #   sudo ufw allow 53317/udp
}
