#!/usr/bin/env bash
# ssh wrapper: surface the Tailscale SSH "additional check" login URL.
# Interactive (terminal): clickable notification. Non-interactive (VSCode
# Remote-SSH, scripts): auto-open the URL in the browser. Calls the real
# /usr/bin/ssh, so it is safe to alias `ssh` to this and to set it as
# VSCode's remote.SSH.path.
export PATH=/usr/bin:/bin:$PATH
: "${XDG_RUNTIME_DIR:=/run/user/$(id -u)}"; export XDG_RUNTIME_DIR
: "${DBUS_SESSION_BUS_ADDRESS:=unix:path=$XDG_RUNTIME_DIR/bus}"
export DBUS_SESSION_BUS_ADDRESS
RE='https://login\.tailscale\.com/a/[A-Za-z0-9]+'

if [ -t 1 ]; then
  log=$(mktemp)
  ( seen=""
    while :; do
      url=$(grep -ohE "$RE" "$log" 2>/dev/null | head -1)
      if [ -n "$url" ] && [ "$url" != "$seen" ]; then
        seen="$url"
        notify-send -u critical -A "open=Authenticate" \
          "Tailscale SSH auth required" "Click to open the login page." \
          | grep -q open && xdg-open "$url" >/dev/null 2>&1
      fi
      sleep 1
    done ) & w=$!
  script -qefc "$(printf '%q ' /usr/bin/ssh "$@")" "$log"
  rc=$?; kill "$w" 2>/dev/null; rm -f "$log"; exit "$rc"
fi

exec /usr/bin/ssh "$@" 2> >(tee /dev/stderr \
  | grep --line-buffered -oE "$RE" | head -1 \
  | xargs -r -I{} sh -c 'notify-send -u critical "Tailscale SSH auth needed" \
      "Opening login in Zen…"; xdg-open "{}" >/dev/null 2>&1')
