# Writing an OmaCast extension

An extension is one JSON file in `~/.config/omarchy/omacast/extensions/`. It
names a keyword and something that answers for it. There is no QML, nothing
compiled, and no restart beyond the next time the launcher opens.

```json
{
  "id": "spotify",
  "title": "Spotify",
  "keyword": "music",
  "aliases": ["song", "track"],
  "search": "omacast-spotify search {query}",
  "when": "playerctl --list-all | grep -q spotify",
  "minChars": 2,
  "debounceMs": 250,
  "glyph": "",
  "tier": "substring",
  "view": "player"
}
```

`search` runs with `{query}` replaced by the shell-quoted search text and any
`{filter}` replaced by another filter's value, so `music:blue year:1959` reaches
the script as two arguments. It prints JSON: an array of rows, or one row per
line.

## Fields

| field | default | what it does |
| --- | --- | --- |
| `id` | required | unique; also the default keyword |
| `search` | required unless `socket` | the command that answers |
| `keyword` | `id` | what you type before the colon |
| `aliases` | `[]` | other keywords that reach it |
| `when` | `""` | shell test; a nonzero exit hides the keyword |
| `minChars` | `1` | do not run until the query is this long |
| `debounceMs` | `200` | wait this long after the last keystroke |
| `timeoutMs` | `4000` | kill a script that has not answered |
| `maxRows` | `8` | rows read from the answer |
| `tier` | `substring` | how strong a match this counts as |
| `view` | `list` | layout the rows want |
| `always` | `false` | answer unscoped queries too |
| `cacheMs` | `0` | keep an answer this long |
| `refreshMs` | `0` | re-ask this often while the rows are on screen |
| `socket` | `""` | a unix socket to ask instead of running a command |

## cacheMs

`0` means nothing is cached, and that is the default on purpose. Set it and the
answer is held in memory, keyed by the exact command that would have run, so a
different query or a different filter can never be served someone else's answer.
A hit skips the debounce as well as the process: reopening the launcher on a
query you just ran redraws with no shell-out at all.

Do not set it on anything that reflects live state the user is about to change.
What is playing, which containers are up, what is on the clipboard, what your
volume is: all of those are wrong the moment the user acts on them, and the
launcher has no way to tell them apart from a dictionary lookup. That judgement
is yours, not the launcher's, which is why the default is off.

Good candidates are answers that are expensive and stable: a units table, a
timezone list, an emoji index, a repository listing behind a network call.

The cache is per session and bounded: sixteen answers per extension, evicted
least-recently-used, and dropped entirely if a session somehow touches more than
forty-eight extensions. It survives the launcher closing, and nothing else.

## refreshMs

`0` means off. Set it and the command is re-run on that interval and its rows
are replaced in place: no spinner, no flicker, and the selection stays on the
row it was on. `spotify:` and its progress bar are the case this exists for.

It only runs while all of these hold, and every one is checked again on each
tick:

- the launcher is open
- the query has not changed
- this extension's rows are actually on screen

A refresh that comes back empty is ignored rather than blanking the card, on the
grounds that an empty answer at that moment is nearly always a timeout.

Keep the interval honest. One second is reasonable for a progress bar. Anything
under that is a process per extension several times a second, for rows the user
is looking at rather than reading.

## socket: answering without a process

`search` starts a program per keystroke. A program that is already running does
not want to be started again, and for something that holds an index or a
connection open, starting it per keystroke is the whole cost.

Set `socket` to a unix socket path and the launcher connects to it and talks
newline-delimited JSON. One line out per query:

```json
{"epoch": 41, "query": "kind of blue", "filters": {"year": "1959"}}
```

One or more lines back:

```json
{"epoch": 41, "query": "kind of blue", "rows": [ ... ]}
```

Echo the `epoch` you were given. That is the whole protocol and the only thing
that makes a pushed answer safe: the launcher bumps an epoch on every keystroke
and drops any answer that no longer matches, so a program that answers late
cannot repopulate the list two keystrokes after the user moved on. An answer
with a missing, wrong, or stale epoch is discarded silently.

You may push more than once for the same epoch. Each push replaces the rows,
which is how a program streams a first cheap answer and refines it, without the
launcher polling for it.

Practical notes:

- The connection is opened when someone types the keyword, not on startup, and
  it is retried at most every three seconds. An extension nobody types costs
  nothing.
- The connection outlives the launcher closing, so the next open pays nothing to
  reconnect.
- If the socket is not there, the launcher falls back to `search` when the
  extension has one. Declaring both is the way to make a daemon-backed extension
  degrade to a slow answer instead of no answer.
- `timeoutMs` still applies. A question nobody answers clears the spinner and
  shows nothing.
- `cacheMs` and `refreshMs` work the same over a socket as over a command.

A minimal daemon, in any language, is: bind a `SOCK_STREAM` unix socket, accept,
read lines, write lines back.

## Rows

A row is `{ id, title, subtitle, exec }` plus whatever a view reads. `id` only
has to be unique within one answer, and it is what keeps the selection in place
across a refresh, so make it stable: derive it from the thing, not from the
thing's current state.

Fields the launcher names:

`id` `title` `subtitle` `detail` `accessory` `icon` `glyph` `art` `preview`
`group` `view` `mono` `exec` `score` `actions`, plus the per-view ones:
`progress` `lengthSeconds` `status` `player` `seek` `controls` `shuffle` `loop`
`canNext` `canPrev` for `player`, `year` `month` `today` `weekStart` `marks` for
`calendar`, and `value` `min` `max` `step` `setExec` for `slider`.

A view that draws a header as well as rows reads that header off the first row.
`gitbranches` and `gitstashes` both do it: every row carries its own branch or
stash, and row zero also carries a `repo` object with the name, the path and,
for branches, the uncommitted counts the header warns about. Putting it on every
row would be the same object a dozen times; putting it in a second kind of row
would mean a header that can be selected and pressed.

Anything else you put on a row is carried through untouched, so a view can read
a field this file has never heard of. The exceptions are the names the launcher
owns for itself and will not let a script set: `key`, `providerId`, `tier`,
`local`, `score`, `run`, `pending`.

`score` orders your rows against each other. It never crosses tiers, so a big
number cannot lift an extension above a calculator answer.

### Rows that keep the launcher open

Three fields decide what the two keys that always mean something do.

| field | what Enter and Escape do with it |
| --- | --- |
| `keepOpen` | Enter runs `exec` and the launcher stays open. Without it Enter closes, which is right for anything that starts a program elsewhere and wrong for anything that only changes what this card will show next. |
| `clearTo` | after that, the box is set to this text. `"do: "` makes Enter behave the way it does in a chat: the sentence is sent, the box empties, and what was sent is still on the card. |
| `escExec` | Escape runs this before it does anything else. A row with something running says so here, so stopping reaches the process instead of waiting for the row to notice nobody is looking. |

### slider rows

```json
{"title": "Output Volume", "view": "slider", "value": 90, "min": 0,
 "max": 100, "step": 5, "accessory": "90%",
 "setExec": "omacast-volume set output {value}"}
```

`title` is the label, `accessory` is the formatted current value, and `setExec`
keeps its literal `{value}` until the drag ends. `min` and `max` default to 0
and 100, `step` to 1.


## Cases: keeping it working

### What `bo test` already gives you

Run it on your unit and, without you having written anything:

```bash
bo test weather
```

- the extension JSON is read the way the launcher reads it: an `id` and a
  `search` are there, `view` and `tier` are names the launcher knows, and the
  numbers are numbers
- the command in `search` is on `PATH`, and when it is a script your own unit
  ships but has not linked, it says so rather than saying "not found"
- the command runs, with `{query}` filled in and every other placeholder empty,
  and again with nothing typed when `minChars` is 0
- what it printed parses, and every row survives the launcher's own reading:
  a `title` on each, `exec` a string, `score` a number, `progress` between 0
  and 1, every action named
- an extension whose `when` is false here is skipped, not failed

That is the whole of it. It proves your extension answers. It cannot prove the
answer is right.

### Why a case exists

Moving the clock out of a `tz:` row title into its own field kept every row
valid, and left the hero drawing cities with no times against them. `bo test`
stayed green through all of it. Nothing caught it until a screen recording did,
two hours later.

So an extension may ship `<name>.cases.json` beside its own JSON: queries, and
what the answer to each has to look like.

```
config/omarchy/omacast/extensions/weather.json
config/omarchy/omacast/extensions/weather.cases.json
```

`bo test` finds it on its own and runs it after the extension itself, calling
the command named in `search` with one argument, the case's `query`:

```
ok      weather                1 row, 4 bare
ok      weather cases          6 held
```

`bo test <unit>` runs only that unit, which is the one to run while you are
working. The script has to be on `PATH` for the cases to run at all, so link
the unit first with `bo add <unit>`.

### When a case earns its place

Write one for the thing that would break quietly:

- an input your script had to work to understand. `unit:5 km in miles` only
  works because the script takes `in` away from qalc, which reads it as inches
  and answers in cubic metres. Nothing about that survives a rewrite by
  accident.
- a field a view depends on. A hero drawing a clock, a timegrid drawing people:
  drop the field and every row is still valid JSON and the screen is still
  wrong.
- an answer that must stay silent. `unit:firefox` prints nothing, because
  `qalc -t firefox` answers "0 B" with exit code 0 and a launcher full of
  confident nonsense is worse than an empty one.
- the shape of a number. Turning off qalc's autoconversion is the difference
  between `11.0231 lb` and `11 lb + 0.369810 oz`, and only one of those is a
  number somebody can use.

Do not write one for what the implementation happens to do today. A case
asserting the fourth row is metres is a case you will delete the first time you
reorder a list, and deleting cases is a habit worth not starting. Do not write
one against anything you cannot run here either: a network answer that changes,
`gh` behind a login, hardware this machine does not have. `when` keeps those
extensions out of `bo test` entirely, and a case is not the place to argue with
that.

### Writing one

A case is a query and a set of assertions about one row of the answer.

```json
[
  { "why": "a city gives a hero, and the hero carries a clock",
    "query": "tokyo",
    "minRows": 2,
    "row": 0,
    "view": "hero",
    "fields": ["clock", "title"],
    "matches": { "clock": "^[0-9]{2}:[0-9]{2}$" } }
]
```

| | |
|---|---|
| `why` | what this is protecting. Printed when it fails |
| `query` | the one argument the command is called with |
| `minRows`, `maxRows` | how many rows the answer must have |
| `row` | which row the rest of the case is about, default 0 |
| `view` | that row's `view` |
| `fields` | must be present and non-empty |
| `absent` | must be missing or empty |
| `matches` | a regex per field, Python's `re.search`, so unanchored unless you anchor it |

Two things to know about the shape:

- an assertion on a row is only checked when there is a row. Set `minRows`
  whenever you assert on one, or an extension that has gone completely silent
  passes every case you wrote.
- `matches` takes a negative lookahead, which is how you say a field must not
  be something: `{ "zoneid": "^(?!UTC$)" }`.

### `why`, which is the field that matters

`why` is not a comment. It is the whole message somebody gets when the case
fails:

```
fail    unit cases             1 of 8 broke
        row 0 title is '11 lb + 0.369810 oz', wanted /^[0-9.]+ lb$/
        (one number, not a mixed-unit sum: without conv none this reads 11 lb + 0.369810 oz)
```

The first line says which key was wrong. Only the second says what was being
protected, and that is the one that tells the reader whether to fix the script
or to fix the case. Written as `"why": "title matches"` it says nothing anybody
did not already have on the line above.

Write it as the promise, in the words a user would use: the thing the extension
is for, not the field it happens to be stored in.

### A worked example

`unit.cases.json`, in this unit. `unit:` converts through qalc, and almost every
case is about an input qalc gets wrong on the way in:

```json
[
  { "why": "in is the preposition, not inches: qalc on its own reads it as a unit and answers in cubic metres",
    "query": "5 km in miles",
    "minRows": 1,
    "row": 0,
    "view": "hero",
    "fields": ["title", "subtitle"],
    "matches": { "title": "^3\\.1[0-9]* mi$" } },

  { "why": "a bare f is Fahrenheit, not farads",
    "query": "180f in c",
    "minRows": 1,
    "row": 0,
    "view": "hero",
    "matches": { "title": "^82\\.2[0-9]* °C$" } },

  { "why": "the hero carries the rate, which is what stops the next four queries",
    "query": "20 miles in km",
    "minRows": 1,
    "row": 0,
    "fields": ["detail"],
    "matches": { "detail": "^1 mile = 1\\.6" } },

  { "why": "a temperature carries no rate: a scale with an offset does not have one",
    "query": "180f in c",
    "minRows": 1,
    "row": 0,
    "absent": ["detail"] },

  { "why": "a word that is not a unit answers nothing rather than qalc's guess at it: qalc -t firefox is 0 B",
    "query": "firefox",
    "maxRows": 0 }
]
```

Note what is not asserted. Not the exact digits, `^3\.1[0-9]* mi$` rather than
`3.10686 mi`, because a qalc release changing its precision is not a bug in
this extension. Not the rows under the hero, beyond the first one being
kilometres, because their order is a judgement that may change. Each case names
one promise and holds it loosely enough to survive being right.

The last two are the pair worth copying. `absent` is how you assert that
something stayed off, and it is the only kind of case that catches a field
creeping back in. A `maxRows: 0` case is how you assert silence, and silence is
the answer no other check can see.

### Breaking it on purpose

A case you have not watched fail is not a test. Change the thing it protects,
run `bo test <unit>`, read the line, put it back:

```
fail    unit cases             1 of 8 broke
        row 0 title is '0.1 k°C', wanted /^373\.15 K$/
        (a bare k is kelvin only when the other side is already a temperature)
```

If it passed while broken, the case is asserting something else than you think,
usually because the answer came back empty and there was no `minRows` to catch
it.

### What `bo new extension` writes

The scaffold ships a `<name>.cases.json` with three cases that already pass
against the stub it writes: a bare keyword answers with its hint row, a typed
word comes back as the title of exactly one row, and that row has an `exec` so
Enter does something. They are there to be edited, not admired. As you replace
the body of the script, replace them with what your extension promises instead.
