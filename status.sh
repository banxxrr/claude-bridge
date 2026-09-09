#!/bin/sh
# Report Claude Desktop's state without assuming how it was installed.
#
# Detection is by Electron's SingletonLock, which every Claude Desktop build
# writes into its user-data directory as a "<hostname>-<pid>" symlink and
# removes on a clean exit. That is install-method independent, unlike matching
# a binary name. A crash can leave the lock behind, so the pid is always
# checked against /proc before it is believed.
#
# Prints: dir=<path> running=<0|1> pid=<n> suppressed=<0|1>
#
# "suppressed" reports the shared quit-hold: the user quit deliberately and
# auto-restart must stay off. It clears itself once the app is seen running
# under a different pid, i.e. something genuinely started it again.

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
      *claude-desktop*) ;;
      *) continue ;;
    esac
    # Electron helpers share the binary and the name. Accept only a process
    # whose parent is not itself claude-desktop, i.e. the main process. Without
    # this, helpers still dying after a quit reported the app as running under
    # a new pid, which upstream read as "someone restarted it".
    ppid=$(awk '{print $4}' "/proc/$candidate/stat" 2>/dev/null)
    parent=$(cat "/proc/$ppid/comm" 2>/dev/null)
    [ "$parent" = "claude-desktop" ] && continue
    running=1
    pid=$candidate
    break
  done
fi

hold="${XDG_RUNTIME_DIR:-/tmp}/claude-bridge/quit-hold"
suppressed=0
if [ -f "$hold" ]; then
  held=$(cat "$hold" 2>/dev/null)
  case "$held" in
    ''|*[!0-9]*) held=0 ;;
  esac
  if [ "$running" -eq 1 ] && [ "$pid" -ne "$held" ]; then
    rm -f "$hold"
  else
    suppressed=1
  fi
fi

echo "dir=$dir"
echo "running=$running"
echo "pid=$pid"
echo "suppressed=$suppressed"
