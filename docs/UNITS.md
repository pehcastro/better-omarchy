# Writing a unit

A unit is one folder with a `unit.toml` in it. `bo add` reads that file, links
whatever the folder holds into the right places, and `bo remove` takes the
links back out. Nothing else edits a config file.

## What deserves to be a unit

A unit stands on its own. A file inside one does not.

That is the whole test. `zen-mode` is a unit because turning it off gives you
your gaps back and nothing else changes. The launcher's `file:` keyword is not a
unit, because the script that answers it needs the QML that draws the rows, the
ranking that orders them, and the query parser that spots the keyword. `bo
remove files` would have meant uninstalling half a launcher and leaving the
other half running, so every launcher keyword ships inside `omacast` instead.

The same test cuts the other way. Some customizations are one command and do not
need a folder at all:

```bash
omarchy toggle idle stay-awake     # never lock or dim on idle
omarchy toggle nightlight
omarchy theme set catppuccin       # or type theme: in the launcher
```

A unit that only runs one of those buys you the ability to turn it off, which is
what `kind = "setting"` is for. A unit that wraps something already reversible
in one word buys you nothing.

## Starting one

```bash
bo new unit my-thing                   hypr/*.lua
bo new unit my-widget --kind plugin    plugin/manifest.json and Widget.qml
bo new unit my-setting --kind setting  apply.sh and revert.sh
bo new extension weather               one launcher keyword
```

That writes the folder below, filled in, and refuses to touch one that already
exists. Everything it writes is valid as it stands: `bo add` links it without an
edit, and a scaffolded extension answers its keyword the moment the launcher
reloads. It ends by printing the commands to run next.

```
units/undo-close/
  unit.toml        what this is, what it needs, which keys it claims
  README.md        how to use it, and what was hard about building it
  hypr/*.lua       linked into ~/.config/hypr/modules.d/
  bin/*            linked into ~/.local/bin/
  plugin/          linked into ~/.config/omarchy/plugins/<id>/   (kind = plugin)
  config/*         mirrored into ~/.config, path for path
  apply.sh         run on add                                    (kind = setting)
  revert.sh        run on remove                                 (kind = setting)
```

## unit.toml

```toml
name     = "undo-close"
summary  = "Reopen the window you closed last"
version  = "0.1.0"
category = "Productivity"
tags     = ["hyprland", "windows"]
author   = "pehcastro"
kind     = "hypr"
needs    = ["hyprctl", "socat", "jq"]
keys     = ["SUPER+Z"]
```

It is a strict subset of TOML, `key = "value"` and `key = ["a", "b"]`, one per
line, no tables and no multi-line values, so `bo` reads it with `sed` and no
dependency.

| Key | Type | Required | What it is for |
|---|---|---|---|
| `name` | string | yes | Has to match the folder name. `bo registry` refuses otherwise, because a mismatch means `bo add <name>` looks in the wrong place. |
| `summary` | string | yes | One line. It is the whole of what `bo list` and `bo search` show, so it has to say what the thing does rather than what it is called. |
| `version` | string | yes | SemVer. You bump it; nothing bumps it for you. `bo update` reports a version change and a content change differently. |
| `kind` | string | yes | `hypr`, `plugin` or `setting`. Only decides the extra step. |
| `category` | string | no | Free text. Shown as a column in `bo list` and searched. Defaults to `Other` in the registry. |
| `tags` | list | no | Searched by `bo search`, and nothing else reads them. |
| `author` | string | no | Shown by `bo info`. |
| `id` | string | no | The plugin id. Required when `kind = "plugin"`, and has to match `id` in `plugin/manifest.json`, because that is the name the folder is linked under and the name `omarchy plugin enable` is given. |
| `needs` | list | no | Commands that have to be on `PATH`. `bo doctor` checks these for every linked unit and names the unit that is missing one. |
| `keys` | list | no | Every keybinding the unit claims, written the way you would say it. `bo status` uses them to catch two linked units fighting over one binding. Nothing binds them; this is a declaration, and the Lua is still what binds. |
| `requires` | list | no | Bare unit names of units this one does not work without. |
| `conflicts` | list | no | Bare unit names of units this one cannot be on at the same time as. |

`requires` and `conflicts` name bare unit names, not `marketplace/unit` refs,
because a unit author cannot know which marketplace a user got the other one
from. Both are resolved against whatever is available on the machine.

- `requires`: `bo add` turns the other unit on first, saying so as it goes. If
  no marketplace here has a unit by that name, the add fails rather than half
  installing.
- `conflicts`: `bo add` refuses while the other one is on, and names the `bo
  remove` that clears the way.

## What each kind adds

`kind` only decides the extra step. Any unit may carry `hypr/`, `bin/` and
`config/` whatever its kind, because a bar widget that also wants a keybinding
is normal.

**`hypr`** adds nothing. The `.lua` in `hypr/` is linked and that is the unit.

**`plugin`** links the whole `plugin/` folder to
`~/.config/omarchy/plugins/<id>/`, rescans, and runs `omarchy plugin enable
<id>` only when the bar layout has never seen that id. A widget that is already
placed keeps its position and its settings, which is the reason for the check:
`plugin enable` appends the widget to its default section, so calling it on a
placed widget would move it and drop what you had set.

Removing a plugin unit deliberately does not run `plugin disable`. For a bar
widget that command deletes the layout entry, taking its position and every
setting with it. Removing the symlink is enough, the stale entry renders nothing
while the plugin is gone, and it is what makes a later `bo add` put the widget
back where it was.

**`setting`** runs `apply.sh` on add and `revert.sh` on remove. Both take
`set -euo pipefail`, unlike the extension scripts, because `bo` reads their exit
status: a setting that half applied has to say so rather than pass. `bo` records
that a setting ran, not what it did, so `apply.sh` has to be safe to run twice.
A unit with no `revert.sh` warns on remove and leaves the setting as it is.

## config/

A unit's `config/` mirrors into `~/.config`, path for path. This is how one unit
extends another program without `bo` knowing anything about that program: a
launcher extension is nothing but
`config/omarchy/omacast/extensions/thing.json`.

Files are linked one at a time here, unlike a plugin folder, because two units
will want to drop files into the same directory. On remove, each link goes and
then every directory that only existed for this unit is removed, up to
`~/.config`.

## Where things go

| Path | What |
|---|---|
| `~/.local/share/better-omarchy/marketplaces/<name>/` | each marketplace checkout |
| `~/.local/state/better-omarchy/linked` | which units are on |
| `~/.local/state/better-omarchy/installed.json` | the version and hash each was at |
| `~/.config/hypr/modules.d/` | symlinks to unit Lua files |
| `~/.config/omarchy/plugins/<id>/` | symlinks to unit plugin folders |
| `~/.local/bin/` | symlinks to unit scripts |
| `~/.config/...` | whatever the unit's `config/` mirrors |

Your `~/.config/hypr/hyprland.lua` gets exactly one added line,
`require("hypr.modules")`. After that, adding a unit never edits a config file.

Linked Lua names carry the marketplace and the unit, `<market>-<unit>-<file>`,
so two units can both ship a `bindings.lua` without colliding and `ls modules.d`
says who owns what.

`monitors.lua` is machine-specific and is not tracked. `shell.json` is copied
rather than symlinked, because Omarchy replaces that file instead of editing it:
run `bo sync` after changing the bar to pull your version into the checkout.

## Three things that will bite you

- **Symlinks inside a plugin folder fail Omarchy's validator.** A symlinked
  plugin *directory* is fine, because the scanner uses `find -L`. That is why
  `bo` links the whole `plugin/` folder and never file by file. `bo validate`
  runs the real validator over every plugin unit.
- **Hyprland's `require_all` will not see your Lua.** It runs `find -type f`,
  which does not match a symlink. `bo` writes its own loader using `find -L` and
  `dofile`, so this is handled: put `.lua` in `hypr/` and write it as you would
  any Omarchy Lua config.
- **Regenerate `registry.json` when you change a unit**, with `bo registry`. A
  stale registry means `bo update` reports no change and nobody gets your work.
  See [MARKETPLACE.md](MARKETPLACE.md).

To take a key Omarchy already uses, call `hl.unbind` first or both bindings
fire:

```lua
hl.unbind("SUPER + F")
o.bind("SUPER + F", "File manager", { omarchy = "nautilus" })
```

# Writing a launcher extension

An extension adds one keyword to `omacast`. It is a JSON file naming that
keyword and a command, plus the command. The command prints JSON and can be a
shell script, a Python file, or anything else that writes to stdout.

```bash
bo new extension weather
```

That writes a unit that already answers: add it, open the launcher, type
`weather:hello`, and the row comes back with hello in it. Then replace the body
of the script and keep the shape. The unit it writes carries
`requires = ["omacast"]`, so adding it turns the launcher on first. It also
writes a `weather.cases.json` whose cases pass against that stub, so the unit
starts with a test you edit rather than one you have to remember to start.

Run `bo test weather` after every change. Nothing else checks what a script
prints: malformed JSON fails silently in the launcher and shows as an empty
result.

## The extension JSON

Lives at `config/omarchy/omacast/extensions/<name>.json` inside your unit, which
mirrors to `~/.config/omarchy/omacast/extensions/<name>.json` on add.

```json
{
  "id": "weather",
  "keyword": "wx",
  "title": "Weather",
  "search": "my-weather-lookup {query}",
  "when": "command -v my-weather-lookup",
  "view": "hero"
}
```

| Field | Default | What it does |
|---|---|---|
| `id` | required | Identifies the extension. An extension with no `id` is ignored entirely, with no error. |
| `search` | required | The command template. No `search`, and the extension is ignored the same way. |
| `keyword` | the `id` | What the user types before the colon, lowercased. |
| `aliases` | `[]` | Other keywords that reach the same extension, lowercased. `spotify` also answers to `music`, `song`, `track` and `play`. |
| `title` | the `id` | The group heading over its rows. |
| `subtitle` | `title` | The second line on any row that does not set its own. |
| `glyph` | `""` | The icon on any row that does not set its own. A nerd font glyph. |
| `when` | `""` | A shell test, run once when the extension loads and never per keystroke. Non-zero exit and the extension is silent for the whole session. An extension for software you do not have costs nothing. |
| `minChars` | `1` | How much has to be typed after the keyword before the command runs at all. `0` means a bare `win:` runs it, which is what an extension that lists things needs. |
| `debounceMs` | `200` | How long typing has to stop before the command starts. A newer keystroke kills a running command and starts again. |
| `timeoutMs` | `4000` | When a command that has not returned is killed. A network lookup wants more than the default; `radio` and `spotify` use 8000. |
| `maxRows` | `8` | How many rows are read from the answer. The rest are dropped, so a script may print everything it has. |
| `tier` | `substring` | Which band the rows sort into. See below. |
| `view` | `list` | The layout. See below. |
| `always` | `false` | Whether the extension answers an unscoped query, one with no keyword. |

`always` is off because a launcher that shells out to six services on every
keystroke is a launcher nobody keeps. `date:` is the one built-in that opts in,
and its gate is deliberately narrow for exactly that reason: `date -d` reads
"may" as a month and "1" as a day of this month, which would put a date on top
of every search for a file called `1`.

## The command template

`{query}` becomes the text after the keyword, shell quoted. Any other
`{filter}` becomes the value of another filter in the same query, also shell
quoted, so `file:report format:pdf in:~/work` can reach
`omacast-search-files {query} {format} {in}` as three arguments.

A placeholder with nothing to fill it becomes an empty string rather than being
left as a literal brace, so a script never receives `{format}` and treats it as
a search term. Every script has to cope with empty arguments.

The command runs under `bash -lc`.

## What the command prints

Either a JSON array of rows, or one JSON object per line. Line mode matters for
a script that streams and costs nothing for one that does not. One malformed
line is skipped rather than losing the rest of a long answer, which is exactly
why a silent mistake stays silent: use `bo test`.

A row with an empty or missing `title` is dropped.

| Field | Type | What it does |
|---|---|---|
| `title` | string | The first line. Required in practice: a row without one never appears. |
| `id` | string | Distinguishes this row from the others. Falls back to the title, then the row's position. |
| `subtitle` | string | The second line. Defaults to the extension's `subtitle`. |
| `detail` | string | A third piece of text, drawn by the views that have room for it. |
| `accessory` | string | Short text on the right of the row: a size, a duration, a count. |
| `exec` | string | The shell command `Enter` runs. Absent or empty and the row does nothing. |
| `score` | number | Orders this row against the others from the same extension, clamped to 0 to 99999. Without one, rows keep the order they were printed in. It never crosses tiers, so an extension cannot outrank a calculator answer by returning a big number. |
| `group` | string | The heading over this row, when it should differ from the extension's `title`. |
| `icon` | string | An icon path or name. |
| `glyph` | string | A nerd font glyph, when there is no icon. |
| `art` | string | Cover art, for `cards` and `player`. |
| `preview` | string | The body text `split` shows beside the list. |
| `mono` | bool | Draw the text in a fixed pitch. A calendar's columns only line up that way. |
| `progress` | number | 0 to 1. In `dashboard` it makes the row a meter; in `hero` it draws a bar. |
| `view` | string | Overrides the extension's `view`. Only the first row's is read, so a script puts the row that decides the layout first. That is how `music:` shows one hero for what is playing and cards for the rest. |
| `actions` | array | Everything else this row can do. See below. |

A `calendar` row carries `year`, `month`, `today`, `weekStart` and `marks`, an
array of day numbers. The script sends the numbers and the view draws the grid.

A `player` row carries `status`, `player`, `lengthSeconds`, `progress`, `seek`,
`controls`, `shuffle`, `loop`, `canNext` and `canPrev`. `controls` is an object
of shell commands keyed `shuffle`, `prev`, `playPause`, `next` and `loop`.
`seek` is a command template holding `{seconds}`, which the scrubber fills in
when it is clicked.

Nothing outside these fields is read, so a script can carry its own fields
through for its own use.

## Actions

An action is `{ title, shortcut, exec }`. `Enter` runs the row's primary action,
`Shift+Enter` the second, and `Ctrl+K` shows the rest.

Give an action a `query` as well and running it lands you on that query instead
of closing the launcher. That is what makes pressing play on a search result
show the player rather than throwing you into Spotify's own window: the thing
you started is the thing you want to look at next.

## Tiers

The tier is the kind of match and it always wins. A row's `score` only breaks
ties inside its own tier, so a bias can reorder equals and can never lift a weak
match above a strong one.

| tier | Use it when |
|---|---|
| `calc` | the row is the answer to what was typed, and nothing else can be more relevant |
| `forced` | a sigil or a keyword named this provider and nothing else |
| `prefix` | the thing's name starts with what was typed |
| `substring` | the thing's name contains it |
| `weak` | the match is an acronym, a tag, or something else indirect |
| `file` | the rows are paths, which are long and match by accident |
| `web` | the row is a fallback that is always available and always last |

Most extensions want `prefix` or `substring`. `file` exists because a path
matches too easily to sit level with a named thing.

## Views

| view | Use it for |
|---|---|
| `list` | a choice between named things |
| `hero` | one answer that is the point: a sum, a date, a confirmation |
| `cards` | things you recognise by their picture |
| `grid` | things you pick by looking |
| `split` | things whose content matters more than their name |
| `dashboard` | readings, some of which are proportions |
| `calendar` | a month |
| `player` | what is playing |

## Testing it

```bash
bo test              every unit
bo test weather      one
```

For each extension JSON in the unit it checks the JSON itself, checks that the
command named in `search` is on `PATH`, runs it, and reads what came back the
way the launcher would: every row parsed, every `title` there, `exec` a string,
`score` a number, `progress` a fraction, every action carrying a title. It also
checks every `unit.toml`, and that a plugin unit's `manifest.json` carries the
same `id`.

```
ok      theme                  0 rows, 22 bare
skipped spotify-library        when condition false: test -s ...
fail    weather                row 2 has no title, so the launcher drops it
```

An extension whose `when` fails on this machine is skipped rather than failed,
because an extension for software you do not have is meant not to run here.

`{query}` is replaced by a harmless term and every other placeholder by an empty
argument, which is what the launcher passes for a filter nobody typed. An
extension whose `minChars` is 0 is asked twice, once with the term and once with
nothing, because that kind answers a bare `sys:` with everything it has and a
typed `sys:test` with nothing. The two counts are the `rows` and the `bare` in
the report.

The command runs for real. An extension that writes something when it runs will
write it.

### Cases

All of that proves an extension answers. None of it proves the answer is right:
a field a view depends on can disappear and every row stays valid JSON. So an
extension may ship `<name>.cases.json` beside its own JSON, a list of queries
and what the answer to each has to look like, and `bo test` runs them after the
extension itself.

```
ok      unit                   0 rows
ok      unit cases             8 held
```

`bo new extension` writes one that already passes. What the cases can assert,
when one is worth writing, and how to make a failure say what it was
protecting: `units/omacast/EXTENSIONS.md`.

Editing the QML wants a full `omarchy restart shell` to be certain. After each
reload, check `journalctl --user -n 50 | grep -iE "TypeError|error"`: a
TypeError inside a delegate binding renders a blank row rather than failing
loudly, so nothing tells you otherwise.
