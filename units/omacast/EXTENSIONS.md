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

Anything else you put on a row is carried through untouched, so a view can read
a field this file has never heard of. The exceptions are the names the launcher
owns for itself and will not let a script set: `key`, `providerId`, `tier`,
`local`, `score`, `run`, `pending`.

`score` orders your rows against each other. It never crosses tiers, so a big
number cannot lift an extension above a calculator answer.

### slider rows

```json
{"title": "Output Volume", "view": "slider", "value": 90, "min": 0,
 "max": 100, "step": 5, "accessory": "90%",
 "setExec": "omacast-volume set output {value}"}
```

`title` is the label, `accessory` is the formatted current value, and `setExec`
keeps its literal `{value}` until the drag ends. `min` and `max` default to 0
and 100, `step` to 1.


## Cases

`bo test` proves an extension runs and returns valid JSON. That is not enough.
Moving the clock out of a `tz:` row title into its own field kept every row
valid and left the hero drawing cities with no times against them, and nothing
caught it until a screen recording did, two hours later.

An extension may ship `<name>.cases.json` beside its own JSON: queries, and what
the answer has to look like.

```json
[
  { "why": "a city gives a hero with a clock",
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
| `query` | what to ask |
| `minRows`, `maxRows` | how many rows the answer must have |
| `row` | which row the rest of the case is about, default 0 |
| `view` | that row's view |
| `fields` | must be present and non-empty |
| `absent` | must not be |
| `matches` | a regex per field |
| `why` | printed when it fails |

`why` matters more than it looks. A failing assertion should say what it was
protecting, not only which key was wrong.
