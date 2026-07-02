{ pkgs, ... }:
let
  probe = pkgs.writeShellScript "tailscale-ssh-resume-probe" ''
    export PATH=/usr/bin:/bin:${pkgs.glib}/bin:$PATH

    probe() {
      out=$(timeout 20 ssh -o BatchMode=yes -o ConnectTimeout=8 \
              -o StrictHostKeyChecking=accept-new p20 true 2>&1)
      url=$(printf '%s\n' "$out" \
        | grep -oE 'https://login\.tailscale\.com/a/[A-Za-z0-9]+' | head -1)
      if [ -n "$url" ]; then
        notify-send -u critical "Tailscale SSH auth needed" "Opening login in Zen…"
        xdg-open "$url" >/dev/null 2>&1
      fi
    }

    gdbus monitor --system --dest org.freedesktop.login1 \
        --object-path /org/freedesktop/login1 2>/dev/null \
      | while IFS= read -r line; do
          case "$line" in
            *PrepareForSleep*false*) probe ;;
          esac
        done
  '';
in {
  systemd.user.services.tailscale-ssh-resume-probe = {
    Unit = {
      Description = "Auto-open Tailscale SSH re-auth in browser on resume from sleep";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${probe}";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
