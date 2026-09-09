#!/bin/sh
# Toggle a Hyprland special workspace, across both dispatch syntaxes.
#
# Omarchy's Lua-configured Hyprland rejects the classic
# "dispatch togglespecialworkspace <name>" form as a Lua syntax error, while a
# stock .conf Hyprland has no hl.dsp table. Neither is detectable up front, so
# try the classic form and fall back on a non-zero exit (hyprctl returns 7 for
# a rejected dispatch and 0 for "ok"). A rejected dispatch does nothing, so the
# fallback cannot double-toggle.

ws=${1:-claude}
# Keep the name safe to embed in the Lua string literal below.
ws=$(printf '%s' "$ws" | tr -cd 'A-Za-z0-9_-')
[ -n "$ws" ] || ws=claude

if hyprctl dispatch togglespecialworkspace "$ws" >/dev/null 2>&1; then
  exit 0
fi

if hyprctl dispatch "hl.dsp.workspace.toggle_special(\"$ws\")" >/dev/null 2>&1; then
  exit 0
fi

echo "could not toggle special workspace: $ws" >&2
exit 1
