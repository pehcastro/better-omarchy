# Running a marketplace

A marketplace is a git repo with a `marketplace.json` at its root, units in
`units/`, and a generated `registry.json` committed beside them. That is the
whole distribution mechanism. There is no server, no account and no index to
publish to: a user runs `bo market add <git-url>` and your units appear in their
`bo list` next to everyone else's.

This repo is one, and nothing in `bo` is specific to it.

## What this adds, and what it builds on

See the README for the short version. The part that matters when you are hosting
one: Omarchy's plugin system covers QML in the shell and nothing else, and it has
no distribution at all. There is no index, no search, no source but a git URL a
person types. `omarchy-plugin-catalog`, despite the name, is a local `find` over
two directories.

So a registry is not a second opinion about plugins. It is the layer Omarchy does
not have: a way to publish a collection, keep it updated as a set, and let a
client discover what is in it before installing.

`bo` builds on Omarchy rather than replacing it, and a marketplace author gets
that for free:

- Plugin units are checked with `omarchy plugin validate`, the same gate
  `omarchy plugin add` uses. There is no second validator to drift from it.
- Config changes go through the shell's own IPC, because the shell holds
  `shell.json` in memory and rewrites the whole file on every mutation of its
  own. Editing that file behind its back gets your change overwritten.
- The reserved `omarchy.*` namespace is left alone. An id there is dropped by
  the shell with only a console warning, so it fails invisibly.

One tradeoff to know about: `bo` links a unit's plugin folder rather than copying
it. The shell discovers a symlinked plugin and loads it, but its file watcher
does not follow symlinks, so editing a linked plugin needs
`omarchy restart shell` rather than reloading on save. That is the price of one
checkout instead of a copy to keep in step.

## Existing Omarchy plugins

`bo market add` also takes a plain Omarchy plugin repo, the kind
`omarchy plugin add` installs: a `manifest.json` at the root and no registry.

```bash
bo market add https://github.com/ericvrp/omarchy-bar-autohide
bo add bar-autohide
```

It becomes a marketplace holding one unit. Nothing is asked of the author, and
their tree is left exactly as published: the generated `unit.toml` and
`registry.json` live under `.bo/`, and the unit's `plugin/` is a relative
symlink back to the repo root, so there is one checkout to update rather than a
copy to keep in step.

What you gain over `omarchy plugin add` is removal: `bo remove` takes out the
symlinks it made and leaves the bar layout entry alone, where `plugin disable`
deletes that entry along with the widget's position and settings.

What you do not gain is any of the rest. A plugin repo has no `needs`, no
`keys`, no `conflicts` and no version history bo can read, so `bo doctor`,
`bo status` and the per-unit changelog have nothing to say about it.

## marketplace.json

```json
{
  "name": "acme",
  "title": "Acme units",
  "description": "What this collection is for",
  "homepage": "https://github.com/acme/omarchy-units",
  "maintainer": "acme"
}
```

`name` is what users type: `bo add acme/thing`. Pick it once and leave it
alone, because it is half of every unit reference anyone writes down. The other
four fields are copied into the registry and shown by `bo market info`.

Two marketplaces cannot share a name on one machine, and `bo market add` refuses
the second. A user can override the name at add time, so a collision is
awkward rather than fatal.

## registry.json

Generated. Never edit it by hand.

```bash
bo registry          # this checkout
bo registry acme     # a named marketplace
```

`bo registry` runs `tools/build-registry` from the marketplace root, so a
marketplace of your own needs that script. Copy this one.

It exists so `bo` can answer "what changed" without walking the tree, and so a
client can fetch one file from raw.githubusercontent and see the whole catalogue
before cloning anything.

At the top:

| Field | Where it comes from |
|---|---|
| `schema` | always `1` |
| `name`, `title`, `description`, `homepage`, `maintainer` | `marketplace.json` |
| `generated_at_commit` | `git rev-parse HEAD` when the registry was built |
| `units` | one entry per `units/*/unit.toml`, keyed by unit name |

And per unit:

| Field | Where it comes from |
|---|---|
| `name`, `summary`, `version`, `kind` | `unit.toml`. All four are required, and the build fails naming the missing one. |
| `category` | `unit.toml`, or `Other` |
| `tags`, `needs`, `keys` | `unit.toml`, or an empty list |
| `author` | `unit.toml`, or empty |
| `pluginId` | the `id` in `unit.toml`, or empty |
| `path` | the unit folder relative to the repo root |
| `files` | how many tracked files the unit has |
| `hash` | sha256 of the content of every tracked file in the unit |
| `commit` | the last commit that touched the unit folder |
| `updated` | that commit's date, ISO 8601 |
| `author_last` | that commit's author |

The build refuses a unit whose `unit.toml` says a `name` other than its folder,
because `bo add <name>` would then look in the wrong place.

## Why hash is content and not git

`commit` and `updated` come from git, and they move for reasons that have
nothing to do with a unit: a rebase, a squash, a rename elsewhere in the tree.
If `bo update` compared those, every client would be told to relink everything
after any history rewrite.

`hash` is the sha256 of each tracked file's path and bytes, in sorted order, so
a rebuild after an unrelated commit produces the same value. That is what lets
`bo update` tell a real change from a reshuffle, and what `bo outdated` compares
against the hash recorded in `~/.local/state/better-omarchy/installed.json` when
the unit was linked.

Two details in the builder that are there for a reason:

- A unit added but not yet staged has no tracked files, so the builder falls
  back to the working tree. A new unit can be described by `bo` before its first
  commit.
- `git ls-files` reports what the index holds, which lags the working tree right
  after a rename. A listed file that is not on disk is skipped rather than
  killing the build; the next rebuild, once staged, sees the truth.

## The hooks

```bash
git config core.hooksPath .githooks
```

`pre-commit` rebuilds `registry.json` and stages it whenever the commit touches
`units/`. A commit that changes a unit and leaves the registry stale publishes a
change no client can see, which is the failure this prevents. It is the same
`tools/build-registry` that `bo registry` runs, so a build failure stops the
commit.

`commit-msg` enforces Conventional Commits, because `git-cliff` reads the
history to build the changelog and an unconventional subject is silently
dropped from it. It also rejects two things:

- An em dash, U+2014. It compares raw bytes and never decodes the message file,
  so the test holds on every platform and in every codepage. A changelog is text
  a later reader copies, so nothing here writes one.
- A `Co-authored-by:` trailer. This repository credits no co-author, no tool and
  no bot.

## Releasing

A unit carries its own version and is bumped on its own schedule. The repo tag
is about `bo` and the marketplace itself.

```bash
$EDITOR units/thing/unit.toml       # version = "0.2.0"
bo registry                         # or let the pre-commit hook do it
git add -A
git commit -m "feat(thing): what changed"
git cliff --tag v0.3.0 --output CHANGELOG.md
git add CHANGELOG.md
git commit -m "docs(changelog): v0.3.0"
git tag v0.3.0
git push --follow-tags
```

Versions follow SemVer, and for the repo tag that means a breaking change to the
unit format or the `bo` interface is a major, a new unit or command is a minor,
and a fix is a patch. `cliff.toml` matches tags against `v[0-9]*`, groups
commits by type, and skips `chore` and `style` entirely.

Bumping the unit version is the step that is easy to forget and the one that
matters most to a client. Without it `bo update` still notices, because the
content hash moved, but it says so as `(content changed, version did not)`,
which tells your users you forgot.

## What a client sees

`bo update` fetches every marketplace, prints what changed, then applies it.

```
better-omarchy
  changed  on better-workspaces      0.1.0 -> 0.2.0
  new         clipboard            0.1.0  Clipboard history in the bar
  changed     cpu-meter            0.1.0 (content changed, version did not)
  updated d5d89fe4451b -> 8c0f1a92be40
```

Each line is one unit whose registry entry differs between the commit the client
has and the one they are about to get. `new` and `removed` are units that
appeared or went. `changed` means the hash moved, and the detail says whether
the version moved with it. The `on` column marks the units that client actually
has linked, so the report is about their machine and not just about your repo.

Then it fast-forwards and relinks. A unit that gained a `hypr/` file, a `bin/`
script or a `config/` file needs new symlinks; everything already linked needs
nothing, because a symlink into the checkout is already the new content.

Two ways your users see nothing:

- **You did not rebuild the registry.** The diff reads `registry.json` at both
  commits, so a unit change with a stale registry prints `no unit changed; the
  update touches only docs or tooling`, and nothing relinks.
- **They have local commits.** `bo` only ever fast-forwards, and warns rather
  than merging. Someone who edited a unit in place has to rebase or stash first.

## Before you publish

Add your own repo as a local marketplace and try the round trip: `bo add
your/unit`, then `bo remove your/unit`, then check `~/.config/hypr/modules.d`,
`~/.local/bin`, `~/.config/omarchy/plugins` and `~/.config` for anything of
yours still sitting there. A unit that leaves something behind on remove is the
bug users report and you never see.

```bash
bo test            every extension answers, and every unit.toml is sound
bo validate        omarchy plugin validate over every plugin unit
bo doctor          every linked unit's dependencies are on PATH
```

Then push. A user who already has your marketplace gets it on their next `bo
update`.
