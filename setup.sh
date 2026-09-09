#!/usr/bin/env bash
# Configure Hyprland so Claude Desktop starts hidden on a special workspace,
# which is what makes the widget's "Show / hide window" action meaningful.
#
# Idempotent: every block is tagged with a marker and skipped if already there.
# Pass --dry-run to print what would change without writing anything.
set -euo pipefail

MARKER="claude-bridge"
WS="${CLAUDE_BRIDGE_WORKSPACE:-claude}"
KEY="${CLAUDE_BRIDGE_KEYBIND:-SUPER + ALT + C}"
DRY=0
[ "${1:-}" = "--dry-run" ] && DRY=1

HYPR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"

say() { printf '%s\n' "$*"; }
skip() { printf '  already configured: %s\n' "$*"; }

if [ ! -d "$HYPR" ]; then
  say "No Hyprland config at $HYPR — nothing to do."
  exit 1
fi

# Omarchy moved to Lua in Hyprland 0.55; older installs still use .conf.
if [ -f "$HYPR/hyprland.lua" ]; then
  LAYOUT=lua
elif [ -f "$HYPR/hyprland.conf" ]; then
  LAYOUT=conf
else
  say "Found neither hyprland.lua nor hyprland.conf in $HYPR."
  exit 1
fi
say "Detected $LAYOUT-style Hyprland config in $HYPR"

if [ "$LAYOUT" = conf ]; then
  cat <<EOF

This installer only writes the Lua layout automatically. For a .conf setup,
add these three lines yourself:

  exec-once = claude-desktop
  windowrulev2 = workspace special:$WS silent, class:^(com\\.anthropic\\.Claude)$
  bind = SUPER ALT, C, togglespecialworkspace, $WS

EOF
  exit 0
fi

append() { # file, marker-comment, body
  local file="$1" body="$2"
  if [ -f "$file" ] && grep -q "$MARKER" "$file"; then
    skip "$(basename "$file")"
    return
  fi
  if [ "$DRY" = 1 ]; then
    say "  would append to $(basename "$file"):"
    printf '%s\n' "$body" | sed 's/^/    /'
    return
  fi
  cp "$file" "$file.bak.$(date +%s)" 2>/dev/null || true
  printf '\n%s\n' "$body" >> "$file"
  say "  updated $(basename "$file")"
}

# Refuse to steal a keybind that is already doing something else.
if command -v omarchy >/dev/null 2>&1; then
  if omarchy menu keybindings --print 2>/dev/null \
     | grep -qiF "$(printf '%s' "$KEY" | tr -d ' ')" ; then
    say "NOTE: $KEY may already be bound. Check with:"
    say "  omarchy menu keybindings --print"
  fi
fi

append "$HYPR/autostart.lua" "-- $MARKER: keep the dispatch bridge up for the whole session.
o.launch_on_start(\"claude-desktop\")"

append "$HYPR/hyprland.lua" "-- $MARKER: park Claude Desktop on a special workspace so the app keeps
-- running (and the bridge stays up) while its window is out of the way.
o.window(\"com.anthropic.Claude\", {
  workspace = \"special:$WS silent\",
})"

append "$HYPR/bindings.lua" "-- $MARKER: show/hide Claude Desktop.
o.bind(\"$KEY\", \"Toggle Claude Desktop\", hl.dsp.workspace.toggle_special(\"$WS\"))"

if [ "$DRY" = 1 ]; then
  say "Dry run only — nothing written."
  exit 0
fi

if command -v hyprctl >/dev/null 2>&1; then
  hyprctl reload >/dev/null 2>&1 || true
  errors=$(hyprctl configerrors 2>/dev/null || true)
  if [ -n "$errors" ]; then
    say "Hyprland reported config errors:"
    say "$errors"
    exit 1
  fi
  say "Hyprland reloaded cleanly."
fi

say "Done. Claude Desktop will start hidden on special:$WS; toggle with $KEY."
