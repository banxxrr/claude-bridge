#!/bin/sh
# Start Claude Desktop without assuming how it was installed.
#
# Ordered by specificity: a native binary first (wrapped in uwsm-app when the
# session provides it, so the app lands in the right systemd scope), then the
# desktop entry, then Flatpak. Detaches so the caller returns immediately —
# the launcher stays alive for the app's lifetime, and blocking on it would
# pin the calling Process forever.

# Starting clears the quit-hold: an explicit launch is consent to supervise.
dir="${XDG_RUNTIME_DIR:-/tmp}/claude-bridge"
mkdir -p "$dir" 2>/dev/null || true
rm -f "$dir/quit-hold"

# One launch at a time across every monitor's widget instance. Claude Desktop
# takes ~20s to come up; without this, three instances each spawn into that
# window on the same poll tick.
stamp="$dir/launch-stamp"
if [ -f "$stamp" ]; then
  now=$(date +%s)
  then=$(stat -c %Y "$stamp" 2>/dev/null || echo 0)
  if [ $((now - then)) -lt 45 ]; then
    exit 0
  fi
fi
: > "$stamp"

if command -v claude-desktop >/dev/null 2>&1; then
  if command -v uwsm-app >/dev/null 2>&1; then
    setsid uwsm-app -- claude-desktop >/dev/null 2>&1 &
  else
    setsid claude-desktop >/dev/null 2>&1 &
  fi
  exit 0
fi

if command -v gtk-launch >/dev/null 2>&1; then
  for entry in com.anthropic.Claude claude-desktop Claude; do
    if [ -f "/usr/share/applications/$entry.desktop" ] \
       || [ -f "$HOME/.local/share/applications/$entry.desktop" ]; then
      setsid gtk-launch "$entry" >/dev/null 2>&1 &
      exit 0
    fi
  done
fi

if command -v flatpak >/dev/null 2>&1; then
  if flatpak info com.anthropic.Claude >/dev/null 2>&1; then
    setsid flatpak run com.anthropic.Claude >/dev/null 2>&1 &
    exit 0
  fi
fi

echo "no Claude Desktop installation found" >&2
exit 1
