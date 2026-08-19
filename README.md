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

That installs `bo`, adds this repo as your first marketplace, and lets you pick.
Nothing turns on without you choosing it.

## What this adds to Omarchy

Omarchy has a plugin system, and it is good at what it is for: QML loaded into
the running shell. It validates a manifest, hot-reloads on save, lets you clone
a built-in to hack on it, and falls back to the stock bar when yours breaks.
`bo` uses all of that rather than working around it, down to calling
`omarchy plugin validate` itself and mutating config over the shell's own IPC.

What it does not do is anything that is not QML. There is no manifest field for
a keybinding, a script on your `PATH`, a file in `~/.config`, a package you
need, a plugin you depend on, or one you conflict with. So a real customization
arrives as a plugin plus a README telling you what to paste where, and taking it
back out is a manual job.

A **unit** is a folder that can hold all of those at once, and knows what it
touched:

| | Omarchy plugin | bo unit |
|---|---|---|
| QML in the shell | yes | yes, unchanged |
| Hyprland keybinding or rule | no | yes |
| Script on your PATH | no | yes |
| Files in `~/.config` | no | yes |
| Needs another unit | no | `requires` |
| Fights another unit | no | `conflicts`, and a key-conflict check |
| Commands it needs | no | `needs`, checked by `bo doctor` |
| Removing it | leaves state behind | removes what it linked |

And the second half: Omarchy has no distribution at all. There is no index, no
search, no notion of a source. You install from a git URL somebody typed, one
repo at a time, and there is no way to publish a collection or to be told a
plugin you have moved on.

## Decentralized on purpose

A **marketplace** is any git repo with a `registry.json` at its root. That is the
whole mechanism. Publishing is `git push`. There is nobody to register with,
nobody to approve you, and no server that can go away and take the index with
it.

It is the shape [shadcn/ui](https://ui.shadcn.com) uses, and the one coding
agents adopted for their own extensions: a repo, a manifest at a known path, a
client that reads it, nobody in the middle. It buys four things here:

- **Many sources, no centre.** Add as many marketplaces as you like. Yours ranks
  no lower than this one, and this one is not privileged in the code.
- **Read before you run.** A unit is scripts and QML in a repo you cloned.
  `bo update` shows a per-unit changelog before applying anything.
- **Updatable as a set.** A collection updates together and tells you which of
  its parts you actually have on.
- **A tool can drive it.** `registry.json` is machine readable, which is the same
  reason agent marketplaces adopted the shape.

`bo` also installs a plain Omarchy plugin repo, wrapping it as a marketplace of
one, so nothing you already have is stranded.

It buys no safety. A marketplace is code that runs unsandboxed, exactly as
`omarchy plugin add` is. `bo` says so when you add one, and a readable registry
is what lets you check first.

## The units in this marketplace

Five. `bo list` shows what is on, and every unit has a README beside it.

**[omacast](units/omacast/README.md)** is the launcher, and most of what this
repo is. Apps, arithmetic, files, images, windows, music, radio, clipboard,
notes, reminders, themes, a calendar, a system dashboard and the web, in one
box. Everything it answers ships inside it, including which key opens it:
`units/omacast/hypr/keys.lua` has three presets and one line to switch.

**[better-workspaces](units/better-workspaces/README.md)** puts workspace names in
the bar instead of numbers, with `Super+F2` to rename the one you are on.

**[undo-close](units/undo-close/README.md)** reopens the window you closed last,
on `Super+Z`. Exactly one: press twice and the second press does nothing.

**[zen-mode](units/zen-mode/README.md)** lets a lone tiled window fill its
workspace, with no gaps, border or rounding. Open a second and all three return.

**[nkz-keys](units/nkz-keys/README.md)** is one person's setup: `Alt+F4`,
`Super+E`, `Super+B`, `Super+R`, and a `monitors.lua` that is gitignored because
that file is wrong on any other machine. Copy it, do not add it.

## bo

```
bo list                 every unit available, and whether it is on
bo search <term>        find a unit by name, summary, category or tag
bo info <unit>          everything known about one unit
bo status               what is on, plus keybinding conflicts

bo add [unit...]        turn units on (no argument opens a picker)
bo remove [unit...]     turn units off (no argument opens a picker)

bo new unit <name>      start a unit here, filled in and ready to add
bo new extension <name> start a unit whose job is one launcher keyword

bo update               fetch every marketplace, show what changed, apply
bo outdated             linked units whose marketplace moved on
bo relink               apply those changes

bo market ...           add, remove and inspect marketplaces
bo doctor               check every linked unit's dependencies exist
bo test [unit]          run each launcher extension, check what it prints,
                        and run the cases it ships
bo validate             run omarchy plugin validate on every plugin unit
bo registry             rebuild registry.json (for marketplace authors)
bo sync                 copy the live shell.json into this checkout
bo version              what this is and where it lives
```

## Using another marketplace

```bash
bo market add https://github.com/someone/their-omarchy-units
bo list                       # theirs appear beside these
bo add their-thing
```

Units are named `marketplace/unit`, and you can drop the marketplace half when
only one offers that name.

`bo` also reads a plain Omarchy plugin repo, the kind `omarchy plugin add`
takes, so an existing plugin installs and removes through `bo` without its
author changing anything.

**A marketplace is code that runs on your machine.** Units link scripts into
your `PATH` and QML into your shell process, unsandboxed. Read what you turn on.

## Further

- [docs/UNITS.md](docs/UNITS.md) is for writing one: the `unit.toml` fields,
  what each kind links where, and how to add a keyword to the launcher.
- [docs/MARKETPLACE.md](docs/MARKETPLACE.md) is for hosting a collection of
  your own: the registry, the hooks, and the release flow.
- [units/omacast/README.md](units/omacast/README.md) is the launcher itself:
  what you can type, every key, and the settings file.
