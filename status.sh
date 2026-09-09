#!/bin/sh
# Report Claude Desktop's state without assuming how it was installed.
#
# Detection is by Electron's SingletonLock, which every Claude Desktop build
# writes into its user-data directory as a "<hostname>-<pid>" symlink and
# removes on a clean exit. That is install-method independent, unlike matching
# a binary name. A crash can leave the lock behind, so the pid is always
# checked against /proc before it is believed.
#
# Prints: dir=<path> running=<0|1> pid=<n>

dir=""
for d in "${XDG_CONFIG_HOME:-$HOME/.config}/Claude" \
         "$HOME/.config/Claude" \
         "$HOME"/.var/app/*/config/Claude; do
  if [ -d "$d" ]; then dir="$d"; break; fi
done

running=0
pid=0

if [ -n "$dir" ] && [ -L "$dir/SingletonLock" ]; then
  target=$(readlink "$dir/SingletonLock" 2>/dev/null)
  candidate=${target##*-}
  case "$candidate" in
    ''|*[!0-9]*) candidate=0 ;;
  esac
  if [ "$candidate" -gt 0 ] && [ -d "/proc/$candidate" ]; then
    running=1
    pid=$candidate
  fi
fi

# Fallback for a stale lock after a crash. Only "claude-desktop" is matched:
# the bare name "claude" is the Claude Code CLI, and matching it reported the
# desktop app as running whenever a terminal session was open. The executable
# is confirmed through /proc so a same-named unrelated process cannot pass.
if [ "$running" -eq 0 ]; then
  for candidate in $(pgrep -x claude-desktop 2>/dev/null); do
    exe=$(readlink "/proc/$candidate/exe" 2>/dev/null)
    case "$exe" in
      *claude-desktop*)
        running=1
        pid=$candidate
        break
        ;;
    esac
  done
fi

echo "dir=$dir"
echo "running=$running"
echo "pid=$pid"
