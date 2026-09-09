#!/bin/sh
# Quit Claude Desktop and hold auto-restart off until something starts it again.
#
# The hold is a file rather than in-memory state because a bar surface exists
# per monitor, so several widget instances supervise the same app. Without
# shared state the instance you clicked stays quiet while its peers relaunch
# what you just quit.

pid=$1
case "$pid" in
  ''|*[!0-9]*) echo "usage: quit.sh <pid>" >&2; exit 1 ;;
esac

dir="${XDG_RUNTIME_DIR:-/tmp}/claude-bridge"
mkdir -p "$dir" 2>/dev/null || true
printf '%s' "$pid" > "$dir/quit-hold"

kill "$pid" 2>/dev/null
