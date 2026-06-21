{ lib, ... }: {
  # Syncthing — instant peer-to-peer sync of ~/.claude-private (LESSONS.md,
  # symlinked into ~/.claude) across machines, locked to the
  # Tailscale tailnet (global discovery, relays, and NAT traversal off; peers added
  # by static tailnet IP). Carries file content only — .git is excluded via a
  # .stignore (see home.activation.claudePrivateStignore); git history syncs
  # separately through the GitHub remote. Keys persist in the state dir, so device
  # IDs stay stable across rebuilds.
  services.syncthing = {
    enable = true;
    overrideDevices = true;
    overrideFolders = true;
    settings = {
      options = {
        globalAnnounceEnabled = false;
        localAnnounceEnabled = false;
        relaysEnabled = false;
        natEnabled = false;
        urAccepted = -1;
        crashReportingEnabled = false;
      };
      devices = {
        "persona-0020" = {
          id = "XHDQTBK-C7X5RM2-IJK4LWP-A4QE2K4-BR44Q5C-C53XGC5-D5FCB65-KAEVQAM";
          addresses = [ "tcp://100.119.209.20:22000" ];
        };
        "will-pc14250" = {
          id = "247PMAV-6DKYW24-TASP2EX-LMGYIKE-MTHNRZ4-VJ2GOAB-VGDU24S-PAUWFQX";
          addresses = [ "tcp://100.97.45.110:22000" ];
        };
      };
      folders."claude-private" = {
        path = "/home/will/.claude-private";
        devices = [ "persona-0020" "will-pc14250" ];
        versioning = {
          type = "staggered";
          params = { cleanInterval = "3600"; maxAge = "2592000"; };
        };
      };
    };
  };

  # Keep Syncthing from syncing the .claude-private git internals — content only.
  home.activation.claudePrivateStignore = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    _d="$HOME/.claude-private"
    [ -d "$_d" ] && printf '.git\n' > "$_d/.stignore" || true
  '';
}
