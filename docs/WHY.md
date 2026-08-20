# Why another plugin installer

Omarchy already has a plugin system, and this builds on it rather than replacing
it. This file is the long answer to why it exists at all. The short answer is in
the [README](../README.md).

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
