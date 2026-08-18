# better-omarchy

My [Omarchy](https://omarchy.org/) setup, cut into units you can turn on and off
one at a time.

Every customization is one folder under `units/`. A unit is a bar widget, a
keybinding, a Hyprland rule, or a system setting, and each one knows what it
touches, what it needs, and which keys it claims. Turning one off leaves nothing
behind.

```bash
git clone https://github.com/pehcastro/better-omarchy ~/localhost/better-omarchy
cd ~/localhost/better-omarchy && ./install.sh
```

The installer opens a picker. `--all` takes everything, `--none` just installs
the `bo` command.

## bo

```
bo list              every unit, and whether it is on
bo status            what is on, plus keybinding conflicts
bo add [unit...]     turn units on (no argument opens a picker)
bo remove [unit...]  turn units off (no argument opens a picker)
bo doctor            check every linked unit's dependencies exist
bo validate          run omarchy plugin validate on every plugin unit
bo sync              copy the live shell.json back into the repo
bo update            git pull, then reload
```

## Units

| Unit | What it does | Keys |
|---|---|---|
| `workspaces` | Workspace **names** in the bar instead of numbers, with a rename panel that opens under the workspace you are renaming. A "keep number" switch decides between `coding` and `coding (2)`. | `SUPER+F2` |
| `cpu` | CPU load in the bar. Click opens btop. Omarchy ships no CPU widget. | |
| `reopen` | Reopens the window you closed last. Exactly one: press it twice and the second press does nothing. | `SUPER+Z` |
| `windows-keys` | `ALT+F4` closes, `SUPER+E` opens files, `SUPER+B` opens the browser, `SUPER+R` opens the app menu. | `ALT+F4` `SUPER+E` `SUPER+B` `SUPER+R` |
| `my-apps` | Typora on `SUPER+SHIFT+W`, replacing Omawrite. | `SUPER+SHIFT+W` |
| `keyboard-intl` | US keyboard with AltGr accents. Plain typing is unchanged: `'` and `"` do not wait for a second key. | |
| `single-window-zen` | A workspace with one tiled window drops its gaps, border and rounding, so one app reads as full screen. Open a second window and all three come back. | |
| `no-idle-lock` | Never lock or start the screensaver on idle. Uses Omarchy's stay-awake flag, so `SUPER+CTRL+I` still toggles it back. | |

## How a unit works

```
units/reopen/
  unit.toml        name, summary, kind, dependencies, keys claimed
  hypr/*.lua       linked into ~/.config/hypr/modules.d/
  bin/*            linked into ~/.local/bin/
  plugin/          linked into ~/.config/omarchy/plugins/<id>/   (kind = plugin)
  apply.sh         run on add                                    (kind = setting)
  revert.sh        run on remove                                 (kind = setting)
```

`unit.toml` is a strict subset of TOML so a shell script can read it without a
parser:

```toml
name    = "reopen"
summary = "SUPER+Z reopens the window you closed last"
kind    = "hypr"
needs   = ["hyprctl", "socat", "jq"]
keys    = ["SUPER+Z"]
```

`kind` only decides the extra step. Any unit may carry `hypr/` and `bin/`,
whatever its kind, because a bar widget that also wants a keybinding is normal.

Your `~/.config/hypr/hyprland.lua` gets exactly one added line,
`require("hypr.modules")`. After that, adding a unit never edits a config file:
it drops a symlink into `~/.config/hypr/modules.d/` and the loader picks it up.

`bo status` lists every key each linked unit claims and flags two units fighting
over the same one.

## Why not `omarchy plugin add`

That installs one git repo per plugin. This is one repo for the whole setup, so
the installer uses the documented by-hand path instead: a folder in
`~/.config/omarchy/plugins/<id>/`, then `rescanPlugins` and `plugin enable`. The
plugins behave identically in the shell. `bo validate` still runs Omarchy's own
`omarchy plugin validate` on each one.

## What is not tracked

`monitors.lua` is machine-specific and gitignored. `shell.json` is copied rather
than symlinked, because Omarchy replaces that file instead of editing it: run
`bo sync` after changing the bar to pull your version back into the repo.
