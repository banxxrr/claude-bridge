# Setup spec

This file is written for an AI coding agent (or a careful human) to reconcile
against a machine's actual config. It states the **desired end state and the
constraints**, not a fixed list of commands — Hyprland config layouts differ
between versions and users, so a transcript of commands would be wrong more
often than right.

If `setup.sh` works on the machine, prefer it. This document is for when it
does not, or when the user wants the changes reviewed and adapted.

## Desired end state

1. **Claude Desktop starts with the graphical session.** It hosts the dispatch
   bridge; if it is not running, this machine cannot be reached from claude.ai
   or the phone app.

2. **Its window lives on a Hyprland special workspace, and starts hidden.** The
   default workspace name is `claude`. It must not steal a normal workspace at
   login.

3. **A keybinding toggles that special workspace.** Default `SUPER + ALT + C`.

4. **The widget's `specialWorkspace` setting matches the workspace name** used
   in rules 2 and 3. It is read from this widget's entry in
   `~/.config/omarchy/shell.json` and defaults to `claude`.

The window's Wayland `app_id` is `com.anthropic.Claude` — confirmed from the
`StartupWMClass` in `com.anthropic.Claude.desktop` and from `hyprctl clients`.

## Constraints

- **Never quit and relaunch Claude Desktop to move its window.** Restarting it
  drops the dispatch bridge for roughly 20 seconds. Toggling a special
  workspace is what keeps the app alive; that is the whole design.
- **Do not overwrite an existing keybinding.** Check first:
  `omarchy menu keybindings --print`. On a stock Omarchy, `SUPER + C` is
  Universal copy and `SUPER + SHIFT + C` is Calendar, which is why the default
  here is `SUPER + ALT + C`. If that is taken too, pick another and tell the
  user what you chose.
- **Back up each file before editing it**, and make every block idempotent —
  tag it with a `claude-bridge` comment and skip if that marker is present.
- **Validate before declaring success:** `hyprctl reload` then
  `hyprctl configerrors`. Empty output means clean.

## Config layout

Omarchy on Hyprland 0.55+ uses Lua. Personal overrides live in
`~/.config/hypr/`, loaded after Omarchy's defaults:

| File | Add |
|------|-----|
| `autostart.lua` | `o.launch_on_start("claude-desktop")` |
| `hyprland.lua` | `o.window("com.anthropic.Claude", { workspace = "special:claude silent" })` |
| `bindings.lua` | `o.bind("SUPER + ALT + C", "Toggle Claude Desktop", hl.dsp.workspace.toggle_special("claude"))` |

Older `.conf` installs use `exec-once`, `windowrulev2` and `bind` instead;
`setup.sh --dry-run` prints those lines for that layout.

Omarchy ships a Claude Code skill covering this config surface. An agent doing
this setup should follow it rather than relying on remembered Hyprland syntax,
which changes between versions.

## Verifying

```sh
# window parked and hidden after a relaunch
hyprctl clients -j | jq '.[] | select(.class=="com.anthropic.Claude") | .workspace.name'
# → "special:claude"

hyprctl monitors -j | jq '[.[].specialWorkspace.name]'
# → all empty when hidden; one shows "special:claude" when toggled on
```
