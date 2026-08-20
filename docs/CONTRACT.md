# The revert contract

A unit that goes on a machine has to be able to come off it. This is the
agreement that makes that true, and it is small enough that somebody else's
unit can keep it without any code landing in `bo`.

## The shape

Everything a unit changes falls into one of four classes. The class decides what
removal does, and it is the only decision a unit author has to get right.

| class | what it means | what `bo remove` does |
|---|---|---|
| `added` | nothing was there before | takes it away, says nothing |
| `displaced` | something was there and this took its place | puts the old thing back, without asking |
| `rebound` | a value somebody acts on by habit, changed | asks, because the old value is an opinion from install day and the new one is muscle memory |
| `keeps` | data the unit made that belongs to the user | leaves it, and says where it is |

`rebound` is the class the other three exist to isolate. Restoring a keybinding
from four months ago is not a favour; whoever has been using it since has the
unit's binding in their fingers, not the one it replaced.

## Two halves

**What `bo` can see, it records without being told.** Every path a unit links
into place is read before the link is made: its bytes, or the fact that nothing
was there. Presence decides the class, which is a reading and not a guess: if
something was there, this is a displacement; if not, it is an addition. A unit
that only links files declares nothing and is still fully reversible.

**What only the author knows is declared.** One line in `unit.toml`:

```toml
touches = [
  "displaced:barwidget:omarchy.workspaces",
  "rebound:key:SUPER+B",
  "keeps:file:~/.local/state/omarchy/closed-windows",
]
```

Each entry is `class:kind:key`. The class is never inferred here, because the
case that needs declaring is exactly the case `bo` cannot see: a keybinding that
exists before and after with a different meaning looks identical from outside.

### kinds

| kind | key is | read as |
|---|---|---|
| `file` | a path | its bytes and mode, or a symlink target, or absent |
| `barwidget` | a widget id | its entry in `shell.json`, with section and index |
| `shelljson` | a dotted path | that value in `shell.json` |
| `command` | a name | the first match on `PATH` |
| `key` | `SUPER+B` | what Hyprland says the binding does, asked live |

## When it happens

`bo add` reads every item before it changes anything, and again once it is on.
Two values per item, `before` and `after`, written to
`~/.local/state/better-omarchy/snapshots/<marketplace>/<unit>/manifest.json`
with a sha256 of each. Values too big to sit inline go in `values/` beside it.

State, not the repo: a checkout is shared between machines and may be a git
tree, and a snapshot is one machine on one day.

`bo remove` replays it. For each item, in order:

1. the unit never changed it, so there is nothing to do
2. what is there now is not what the unit left, so somebody changed it since and
   it is theirs: kept, and named on the way out
3. otherwise the class decides

A hash that does not match is refused rather than replayed.

## The escape hatch

A unit whose changes are none of those kinds ships `snapshot.sh` and
`restore.sh`, each executable, each handed a directory of its own:

```
snapshot.sh <dir>    write whatever you need into <dir>
restore.sh  <dir>    put it back from <dir>
```

Both must be idempotent and must exit non-zero on failure. Same contract,
arbitrary content.

## What a unit that promises nothing gets

Said out loud. `bo add` prints what a unit will put back before it goes on, and
`bo info` says the same. A unit with no `touches` and no scripts is described as
putting back every file it links and nothing else, which is the truth.

## Reading it back

```
bo diff <unit>       what it changed: before, installed, and now
bo doctor            what has drifted since a unit went on
bo snapshots         every snapshot here, including orphaned ones
bo restore <unit>    replay one, even if the unit is gone from its marketplace
```

`bo restore` works without the unit because the snapshot is self-contained. A
marketplace that disappears must not strand a machine.

## The awkward questions

**Installed twice.** The first snapshot wins and is kept until it is restored. A
second one taken while the first is unrestored would record what the unit itself
put there as the thing to go back to, which loses the original for good.

**Two units touching the same thing.** Install order decides what the second one
records. Removing them out of order is safe rather than correct: the earlier
unit's restore makes the later unit's `after` stale, so the later removal sees a
value it does not recognise and keeps it. `bo doctor` reports the overlap.

**A unit that vanished from its marketplace.** The snapshot stays.
`bo restore <ref>` replays it without needing the unit.

**Leaving entirely.** `bo uninstall` turns every unit off through the same path a
single `bo remove` takes, so every slot is handed back before the state that
records it is deleted, then removes `bo`'s state directory, its clones and its
own bin link. A marketplace you pointed at with `bo market link` is a tree of
your own and is never deleted.
