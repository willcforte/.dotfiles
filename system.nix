# System-level config managed by numtide/system-manager.
# Activated separately from home-manager via `update-config`
# (nix run github:numtide/system-manager -- switch --flake . --sudo).
{ ... }: {
  config = {
    nixpkgs.hostPlatform = "x86_64-linux";

    # Show asterisks while typing the sudo password.
    # NOTE: sudo ignores any sudoers.d filename containing a ".", so the
    # drop-in must be dot-free. 0440 root:root is required by sudo.
    environment.etc."sudoers.d/pwfeedback" = {
      text = "Defaults pwfeedback\n";
      mode = "0440";
    };
  };
}
