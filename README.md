# better-omarchy

A marketplace system for Omarchy, backed by a registry, plus the units that
ship with it.

A **marketplace** is a git repo holding customizations and a `registry.json`
listing them. `bo` reads any marketplace, installs what you pick, and removes it
cleanly. This repo is one marketplace; point `bo` at anyone else's and their
work appears in your list beside this one.

```bash
curl -fsSL https://raw.githubusercontent.com/pehcastro/better-omarchy/master/setup.sh | bash
```

That clones this repo, links `bo` into `~/.local/bin`, and leaves the clone as
your first marketplace. Piped into `bash` like that it cannot open the picker,
so it tells you to run `bo add` when you are ready. Nothing turns on without you
choosing it.

## One plugin, one repo

Omarchy's plugin system is good at what it is for: QML loaded into the running
shell. It validates a manifest before installing, hot-reloads plugin code when
you save a file, lets you clone a built-in to hack on it, and falls back to the
stock bar when yours fails to load. Its installer is deliberately inert, and the
manual says so: it "never runs anything from the plugin, never executes an
install hook, and never asks for sudo." `bo` builds on that system rather than
replacing it, down to running `omarchy plugin validate` on every plugin unit
here.

What has no room in it is more than one plugin per repo. The manual is direct
about the unit of distribution: "A third-party plugin is just a git repo with a
`manifest.json` at its root." `omarchy plugin add <git-url>` clones a repo,
validates the repo root, reads `manifest.json` there for an id, and moves the
checkout to `~/.config/omarchy/plugins/<id>/`. The validator wants that manifest
in the folder it is handed, so a repo carrying two plugins in two subfolders
never gets past it:

```
$ omarchy plugin validate ./repo-with-two-plugins
omarchy-plugin-validate: missing manifest.json in ./repo-with-two-plugins
```

The shell reads the installed directory the same way. Its scan of the
third-party plugin directory is one manifest per top-level folder:

```bash
for sub in "$dir"/*/; do
  [[ -f "$sub/manifest.json" ]] || continue
```

First-party plugins are allowed several manifests in one source directory, by a
`*.manifest.json` sibling convention the same scan supports a few lines up.
Omarchy's own repo uses it: eight bar widgets share
`shell/plugins/bar/widgets/`. Third-party plugins do not get that.

The community directory records the consequence. Of its listings, a handful are
marked as living in a multi-plugin repo, and those carry an empty install
command and the note that "automatic installation is unavailable because this
plugin is stored inside a multi-plugin repository without a transactional
Omarchy update path."

There is one way through, and it is worth naming because it is real and it does
not help. A `manifest.json` at the root of a monorepo, with its entry point
pointing down into a subfolder, validates and installs: the whole checkout lands
in `~/.config/omarchy/plugins/<id>/` and the shell loads the one file the
manifest named. What it buys is exactly one plugin. `manifest.json` carries a
single `id`, so the second plugin in the repo has no way to be named, no switch
of its own, and no settings of its own. Anything that is not QML, such as a
Hyprland module, has no route at all.

So three small customizations are three repos, three `omarchy plugin add`
commands, and no way to hand somebody your set. That is the pain this repo
started from.

To be fair about the half that is already solved: `omarchy plugin update` with
no argument walks every git-managed plugin you have, fetches its origin, prints
the diff and asks before fast-forwarding. Keeping up with plugins you have is
handled.

## A marketplace is a file you host

Finding plugins is handled too, by [omarchyplugins.com](https://omarchyplugins.com),
a community directory the official manual points authors and users at. It works,
it is well stocked, and it is worth browsing before you write anything. It is
also a directory in the usual sense: you open an issue with your repo, automated
validation runs, and a maintainer approves the listing. One list, one set of
maintainers, one place to be accepted into.

This is the other model. Any git repo with a `registry.json` at its root is a
marketplace. That is the whole mechanism. Publishing is `git push`, and the only
person who decides what is in your marketplace is you.

```bash
bo market add https://github.com/someone/their-omarchy-units
bo list                       # theirs appear beside these
bo add their-thing
```

Units are named `marketplace/unit`, and you can drop the marketplace half when
only one marketplace offers that name.

The shape is borrowed from [shadcn/ui's GitHub registries](https://ui.shadcn.com/docs/registry/github),
where, in their words, you "add a `registry.json` file to the root of the repo,
describe the files you want to share, and users can install them with the shadcn
CLI", and "you do not need to set up a registry server or publish generated JSON
files." One qualifier, because it cuts both ways: shadcn also runs a central
index of registries, and getting the short `@namespace` handle there means a
pull request their team reviews. `bo` has no equivalent, which is the point and
also the cost. Nobody vets a marketplace before you add it. What the model buys:

- **Many sources.** Add as many marketplaces as you like. The only ordering
  rule in `bo` is that the checkout it runs from is listed first, so it can
  find itself and refuse to remove itself. Nothing else about it is special.
- **One file to fetch.** A client can read `registry.json` off
  raw.githubusercontent and see the whole catalogue before cloning anything.
- **Updatable as a set.** `bo update` fetches every marketplace and prints one
  line per unit whose registry entry moved, with a column marking the ones you
  actually have on.
- **Machine readable**, so a tool can drive it.

### Local and remote

A marketplace is one of two kinds, and `bo market list` prints which in its
second column.

A **remote** marketplace is one `bo market add <git-url>` cloned into
`~/.local/share/better-omarchy/marketplaces/`. `bo market update` fetches it,
and `bo market list` says how many commits behind the last fetch left it.

A **local** marketplace is a tree on this machine that `bo` only points at.
Nothing is copied and there is nothing to fetch, so an edit to the tree changes
what the marketplace offers at once. That is the kind you want while you write
a unit.

```bash
bo market link ~/code/my-units      # point at a tree, do not copy it
bo market unlink my-units           # stop pointing at it
```

`bo market link` needs a `registry.json` at the path, and takes the name from
that file unless you pass one. `bo market unlink` deletes nothing and refuses
while a unit from that marketplace is on. `bo market remove` is the other one:
it deletes a cloned tree, and it refuses for a tree `bo` never copied.

### Browse it from the launcher

With `omacast` on, type `bo:` into the launcher to walk the same marketplaces
in a window. It has three levels: the marketplaces and what you have, one
marketplace as tiles, and one unit's own page with the switch on it. `Enter`
goes in, `Escape` comes back, and typing narrows the level you are on.

Turning a plugin unit on or off closes the launcher, applies the change, and
reopens it on the page you were on. The shell watches
`~/.config/omarchy/plugins`, and a change there unloads every panel, overlay and
menu plugin. The launcher is an overlay, so the window cannot survive its own
toggle. A `hypr` or a `setting` unit touches no plugin directory, so its switch
moves with the window still up.

## What a unit can hold

A plugin manifest describes QML. The validator requires `schemaVersion`, `id`,
`name`, `version`, `kinds` and `entryPoints`. Around those sit `description`,
`author`, `license`, `keepLoaded`, an `omarchy` block the clone command uses,
and a `barWidget` block that declares a widget's default section and its
settings schema. That is the shape of it, and it is the right shape for what it
does: the plugin system is about code inside the shell process.

A customization is often not only that. It wants a Hyprland keybinding, a
script on your `PATH`, a file under `~/.config`, a package you need installed,
or another plugin turned on first. None of those have a manifest field, so
today they arrive as a plugin plus a README telling you what to paste where.
The community directory has a status for it: a sizeable slice of its listings
are tagged "Manual setup".

A **unit** is a folder that can carry all of them, and `bo` records what it
linked so it can take it back out.

| A unit folder | Where `bo` puts it |
|---|---|
| `plugin/` | `~/.config/omarchy/plugins/<id>`, then `omarchy plugin enable` |
| `hypr/*.lua` | `~/.config/hypr/modules.d/`, then `hyprctl reload` |
| `bin/*` | `~/.local/bin/` |
| `config/**` | `~/.config/`, path for path |
| `apply.sh`, `revert.sh` | run on add and on remove |

And four `unit.toml` fields with no manifest equivalent:

- `requires` turns another unit on first, and `bo add` refuses if no
  marketplace you have offers it.
- `conflicts` refuses to turn a unit on while the one it fights is on.
- `needs` lists commands, and `bo doctor` says which are not on your `PATH`.
- `keys` lists the shortcuts a unit claims, and `bo status` reports two linked
  units claiming the same one. It compares those declared strings, not your
  live Hyprland bindings, so it catches unit against unit and not unit against
  something you bound yourself.

Removal follows from that and not from being tidier. `omarchy plugin remove`
disables the plugin and deletes or backs up its folder, which cleans up
everything it knows about. What it cannot know about is the line you pasted
into `bindings.lua` by hand, because no manifest field ever mentioned it. A
unit has somewhere to put that line, so `bo remove` can take it back out.

## Existing plugins still work

`bo market add` also takes a plain Omarchy plugin repo, the kind
`omarchy plugin add` installs: a `manifest.json` at the root and no
`registry.json`. `wrap_plugin_repo` turns it into a marketplace holding one
unit. It reads the id, name, version, author and description out of the
manifest, writes a `unit.toml` and a generated `registry.json` under `.bo/`,
and points that unit's `plugin/` at the repo root with a relative symlink. One
checkout, not a copy, and the author's tree is left exactly as published.

```bash
bo market add https://github.com/ericvrp/omarchy-bar-autohide
bo add bar-autohide
```

Nothing is asked of the author, and nothing more is claimed for it either: a
wrapped plugin has no `needs`, no `keys`, no `conflicts` and no content hash,
so `bo doctor`, `bo status` and the per-unit changelog have nothing to say
about it.

## Safety

It buys no safety, and on one axis it is worse than what it builds on. Both
tools land unsandboxed code in a long-lived shell process, and both warn you
when you add a source. But `omarchy plugin add` never executes anything from
the plugin at install time. `bo add` does: it links a unit's `bin/` scripts
into your `PATH`, and a `setting` unit runs its `apply.sh` there and then. That
is what buys the extra reach described above, and it is a real trade, not a
free one.

Two smaller differences worth knowing. `omarchy plugin update` shows a full diff
and asks per plugin before it fast-forwards; `bo update` prints a per-unit
summary and asks per marketplace, and names the `git diff` that shows you the
rest. And nobody reviews a marketplace before you add it. A readable registry is
what lets you look first.

## The units in this marketplace

Five. `bo list` shows what is on, and every unit has a README beside it.

**[omacast](units/omacast/README.md)** is the launcher, and most of what this
repo is. Forty-one keywords in one box: apps, arithmetic, files, images,
windows, processes, git, GitHub, containers, music, radio, clipboard, notes,
reminders, themes, keybindings, timezones, a calendar, a system dashboard and
the web. `bo:` is one of them, so this marketplace is a screen in the launcher
as well as a command. Everything it answers ships inside it, including which
key opens it: `units/omacast/hypr/keys.lua` has three presets and one line to
switch.

**[better-workspaces](units/better-workspaces/README.md)** puts workspace names
in the bar instead of numbers. `Super+F2` renames the one you are on, `Super+=`
goes to the first free one, and a workspace nobody is using leaves the bar.

**[undo-close](units/undo-close/README.md)** reopens the window you closed last,
on `Super+Z`. Exactly one: press twice and the second press does nothing.

**[zen-mode](units/zen-mode/README.md)** lets a lone tiled window fill its
workspace, with no gaps, border or rounding. Open a second and all three return.

**[nkz-keys](units/nkz-keys/README.md)** is one person's setup: `Alt+F4`,
`Super+E`, `Super+B`, `Super+R`, `Super+grave`, and a `monitors.lua` that is
gitignored because that file is wrong on any other machine. Copy it, do not
add it.

## bo

```
bo list                 every unit available, and whether it is on
bo list --json          the same, for a program
bo search <term>        find a unit by name, summary, category or tag
bo info <unit>          everything known about one unit
bo status               what is on, plus keybinding conflicts
bo diff <unit>          what it changed, against the snapshot from install
bo snapshots            every snapshot here, including orphaned ones
bo restore <unit>       replay a snapshot, even if the unit is gone

bo add [unit...]        turn units on (no argument opens a picker)
bo remove [unit...]     turn units off (no argument opens a picker)
bo remove --purge ...   also delete a widget's bar position and settings

bo new unit <name>      start a unit here, filled in and ready to add
bo new extension <name> start a unit whose job is one launcher keyword

bo update               fetch every marketplace, show what changed, apply
bo outdated             linked units whose marketplace moved on
bo relink               apply those changes

bo market ...           add, link, remove and inspect marketplaces
bo doctor               check every linked unit's dependencies exist
bo uninstall            turn everything off and take bo off this machine
bo test [target...]     run launcher extensions and check what they print
bo test --fast          only the checks that run nothing
bo validate             run omarchy plugin validate on every plugin unit
bo registry [name]      rebuild a marketplace's registry.json (authors)
bo sync                 copy the live shell.json into this checkout
bo version              what this is and where it lives
```

Run `bo` with no arguments for the interactive version of all of this.

`bo test` takes a unit, a keyword, or `marketplace/unit`, and with no target it
checks everything. It runs four kinds of check, and `--only` picks them:
`manifest` reads `unit.toml` and each extension's own JSON, `answer` runs each
extension and reads the rows it prints, `actions` proves every action names a
program that exists, and `cases` runs the assertions in
`<extension>.cases.json`. `--fast` is `--only manifest`.

`bo uninstall` is the way out. It turns every unit off one at a time, so each
one puts back whatever it displaced, then deletes `bo`'s state directory, its
clones and its `~/.local/bin/bo` link. It names anything it moved aside and
could not put back. It never deletes a tree you linked, and it never deletes
this checkout.

Nothing that runs code or pulls a change in happens without being asked first.
`--yes` answers yes to every question, for scripts.

## Further

- [docs/UNITS.md](docs/UNITS.md) is for writing one: the `unit.toml` fields,
  what each kind links where, and how to add a keyword to the launcher.
- [docs/MARKETPLACE.md](docs/MARKETPLACE.md) is for hosting a collection of
  your own: the registry, the hooks, and the release flow.
- [units/omacast/README.md](units/omacast/README.md) is the launcher itself:
  what you can type, every key, and the settings file.
