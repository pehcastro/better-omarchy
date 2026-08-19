# omacast

A launcher. One box that answers with apps, arithmetic, files, git, music, your
notes and the web, and draws each of those the way it deserves rather than as
one long list.

`Super+K` opens it. To change that, edit the one line at the top of
`hypr/keys.lua`:

```lua
local preset = "balanced"
```

- `additive`: `Super+Shift+K`, and every Omarchy default survives.
- `balanced`: `Super+K`, with the keybindings cheatsheet moved to `Super+H`.
- `full`: the same, and nothing else opens a launcher any more.

Nothing reads this from a settings file, because a Hyprland keybinding has to be
Lua and reaching into JSON from there would be worse than a variable. The
Omarchy menu keeps its bar icon and `Super+Shift+F12` in all three, so `full` is
recoverable without editing config.

**Type `?` to see every keyword your machine actually has.** That list is built
from what is loaded, so it is always true, and this file explains what is in it.

---

## Just start typing

With no keyword at all, four things answer:

| Type | Get |
|---|---|
| `firefox`, `thun` | applications, ranked by match and by what you actually launch |
| `theme`, `lock`, `screenshot` | Omarchy's own commands (24 of them, listed under `>` below) |
| `wiki`, `dl` | your own quicklinks, matched by title or tag |
| `2+2*10`, `40 miles in km` | the answer, large |
| `27 november 2027`, `next friday` | the day of the week, the week number, how far away |
| anything with no match | search the web |

The calculator answers unscoped only when the text passes a gate: it must
contain a digit **and** either an operator (`+ - * / ^ % ( )`) or one of `to`,
`in`, `as`. "5" alone is not a question and "a + b" is not arithmetic.

`date:` is the only other extension that answers unscoped, and its own matching
is deliberately narrow, because `date -d` reads "may" as a month and "1" as a
day of this month.

With the box **empty** you may also get:

- a URL sitting on your clipboard, offered to open. Only an explicit scheme
  counts; `github.com/x` on its own does not, because this row appears uninvited.
- your last 20 queries, if you turn them on with `"recents": true`. Off by
  default: half of them are partial words from a search you abandoned.

---

## The four shorthands

| Sigil | Same as | For |
|---|---|---|
| `=` | `calc:` | arithmetic and conversion |
| `>` | `run:` | Omarchy commands |
| `?` | `web:` | search the web |
| `/` | `command:` | the launcher's own actions |

Only a leading sigil counts, and everything after it is the whole query, so
`=2+2` works and `total =2+2` is plain text.

`?` on its own is the exception: with nothing after it there is nothing to
search for, so it lists every keyword instead. `:`, `h:` and `help:` do the
same. `Enter` on one of those rows types `keyword:` into the box, ready for the
rest of the line, and runs nothing.

`/` reaches files when what follows looks like a path: a slash, a dot or a
tilde. `/~/Documents`, `//home/nkz` and `/report.pdf` all become file searches.
`/etc` does not, because it has none of the three; that one needs `file:etc`.

---

## Keys

| Key | What |
|---|---|
| `Enter` | run the primary action, always named in the footer |
| `Shift+Enter` | run the second action, also named in the footer |
| `Ctrl+Enter` | ask a model, streamed into the card |
| `Ctrl+K` | every other action this result has |
| `Ctrl+1` to `Ctrl+9` | run that row by the number down its left gutter, without moving |
| `Ctrl+P` | pin the selected row, so it leads every query it matches |
| `Down`, `Ctrl+N`, `Tab` | next |
| `Up`, `Ctrl+Shift+P`, `Shift+Tab` | previous |
| `PageDown` / `PageUp` | a screenful at a time |
| `Left` / `Right` | move a cell, in the grid, dashboard and calendar views |
| `Left` / `Right` | adjust, in the slider and timegrid views |
| `Escape` | four stages, in order |

Escape unwinds one stage per press: leave a streamed answer, then step back one
query in the trail you walked in on, then clear the box, then close. Hold it and
everything comes off in that order. A row that is still working is told to stop
first. With the action panel open, Escape closes only that.

`Left`, `Right`, `Home`, `End`, `Backspace` and the usual editing chords belong
to the text cursor and are not taken, except in the four views named above.

A pin lifts a row the way frecency does and by more, and neither ever crosses a
tier: a name that starts with what you typed still beats a pinned substring.
Calculator and web rows cannot be pinned, since their key is the text you typed.
Pins and recent queries live in `~/.local/state/omarchy/omacast-state.json`,
beside the frecency file rather than in your settings, which stay yours to edit.

---

## Every keyword

Aliases are listed with each one; any of them opens the same thing. A keyword
whose requirement is missing is not loaded at all, so it costs nothing and
appears in neither `?` nor your results.

### Finding things on this machine

| Keyword | Aliases | What | Needs |
|---|---|---|---|
| `file:` | `files`, `f` | filenames, narrowed with `format:pdf` and `in:~/Sync` | `fd` |
| `img:` | `image`, `images`, `pic`, `photo` | image thumbnails, newest first, with size and dimensions | `fd`; dimensions need ImageMagick |
| `recent:` | `recents`, `last`, `opened` | files you opened lately in any app, minus what has since been deleted | `~/.local/share/recently-used.xbel` |
| `win:` | `window`, `windows`, `w` | every open window by class or title; focus it or close it | Hyprland |
| `kill:` | `ps`, `proc`, `process`, `quit` | find a running process and end it | nothing extra |
| `ssh:` | `host`, `hosts` | a host from your ssh config, connected in a terminal | `~/.ssh/config` |
| `repo:` | `repos`, `project`, `projects` | your local git repos, most recently touched first, filterable with `branch:main` | `git`, `fd` |

`kill:` answers nothing for a bare `kill:` and wants two characters, so you
cannot fat-finger your way into the process list.

### Git, on disk

| Keyword | Aliases | What | Needs |
|---|---|---|---|
| `git:` | none | one repo as a panel: branch, what is uncommitted, drift, stash count, recent commits | `git` |
| `branch:` | `branches` | every local branch with ahead/behind against upstream and against trunk; Enter switches | `git` |
| `stash:` | `stashes` | what is actually inside each stash, per file, so you can read one before applying it | `git` |

All three answer about the repo your focused terminal is in, else the one you
touched last; naming one (`git:omarchy`) answers about that repo instead. There
is no `stash drop` anywhere, on purpose. `git:` deliberately does not show pull
requests or issues; that is `gh:`.

### GitHub

All four need `gh` and `jq` installed, `gh auth` signed in, and the network.
Without an account they say so on a titled row rather than looking empty.

| Keyword | Aliases | What |
|---|---|---|
| `gh:` | `github` | your repos, newest-pushed first; `gh:owner/repo`, `gh:owner/repo#123` or a pasted GitHub URL resolves directly |
| `pr:` | `prs`, `pulls` | your pull requests, a repo's open ones, or one specific PR with its checks, reviews and size |
| `issue:` | `issues` | issues assigned to you, a repo's open ones, or one specific issue |
| `ci:` | `workflow`, `workflows`, `actions` | workflow runs for a named repo. A bare `ci:` shows you the shape `ci:owner/repo` rather than guessing |

A slug, a URL or an `owner/repo#123` draws its card and is pressable **before**
any request goes out. `gh:` and `pr:` refresh themselves every 900ms while their
rows are on screen.

### Answers

| Keyword | Aliases | What | Needs |
|---|---|---|---|
| `calc:` | `math`, `=` | the sums you have already accepted, newest first; typing an expression puts the live answer on top | qalc, and a non-empty history |
| `unit:` | `units`, `convert`, `conv` | unit conversion, with the phrasing fixed up so `40 miles in km` and `180f in c` mean what you said | `qalc` |
| `def:` | `define`, `dict`, `syn`, `word` | every sense of a word by part of speech, with synonyms | `curl` and the network |
| `date:` | `when`, `day` | a plain-words date resolved: "next friday", "in 3 weeks", "2026-12-25" | GNU `date` |
| `cal:` | `calendar`, `month` | a month drawn as a month. `cal:december`, `cal:november 2027`, `cal:2027` for all twelve | `cal` |
| `tz:` | `time`, `timezone`, `zone`, `clock` | what time it is elsewhere, and what your time is there | `jq`, `python3` |
| `sys:` | `system`, `status`, `battery`, `info` | battery, uptime, memory, disk, address, temperature | nothing extra |

`unit:` knows its own traps, each found by testing: `in` is a preposition and
not inches, a bare `f` is Fahrenheit and not farads, a bare `k` is kelvin only
next to a temperature, and a word that is not a unit answers nothing rather than
qalc's `0 B`.

`def:` keeps what it fetched under `~/.cache/omacast/define` for 30 days.

`repo:` looks in `$OMACAST_REPO_ROOTS` (colon separated) when that is set, and
otherwise in whichever of `~/localhost`, `~/Projects`, `~/Work`, `~/src`,
`~/code`, `~/dev`, `~/repos`, `~/git` and `~/Developer` exist.

### Text you keep having to produce

| Keyword | Aliases | What | Needs |
|---|---|---|---|
| `emoji:` | `emojis`, `e`, `smiley`, `symbol` | the emoji by name, copied | Omarchy's emoji data |
| `snip:` | `snippet`, `snippets`, `text`, `expand` | boilerplate you keep retyping, matched by name or body | `~/.config/omarchy/omacast-snippets.json` |
| `ch:` | `clip`, `clipboard`, `paste` | what you copied, newest first, with the full text beside the list | Omarchy's clipboard history |
| `note:` | `notes`, `n`, `notepad` | your notes, and `note:new tuesday standup` to start one | nothing extra |
| `pass:` | `secret`, `password`, `1p` | an entry from `pass` or 1Password, copied, cleared after 45 seconds | `pass`, or `op` signed in |

The secret only ever reaches `wl-copy`; nothing is passed on a command line.

### Music and radio

| Keyword | Aliases | What | Needs |
|---|---|---|---|
| `spotify:` | `music`, `song`, `track`, `play` | bare: the player, with cover, scrubber and transport. With words: search and play, with no API account | the Spotify client; `curl`, `mpv` and the network for search |
| `sp:` | `spotify`, `track`, `album`, `artist` | the real Spotify Web API search: tracks, then albums, then artists, narrowed with `type:album` | a completed `omacast-spotify-auth` |
| `radio:` | `fm`, `station`, `stream` | internet radio from radio-browser.info, played through mpv | `mpv`, `curl`, the network |

Both music keywords claim `spotify` and `track`, so which one answers depends on
which is loaded; `sp:` and `music:` are the two names that are never ambiguous.

### This desktop

| Keyword | Aliases | What | Needs |
|---|---|---|---|
| `theme:` | `themes`, `colours`, `colors`, `appearance` | every Omarchy theme. Moving the selection applies it live; leaving without choosing puts yours back | Omarchy |
| `omarchy:` | `oma`, `menu`, `settings-menu`, `o` | every route in Omarchy's own menu, flattened into one searchable line each ("Theme · Style") | Omarchy |
| `vol:` | `volume`, `audio`, `sound`, `mute` | output and input volume as sliders, and mute. `vol:mic` for the input alone | `pactl` (PipeWire or PulseAudio) |
| `bri:` | `brightness`, `screen` | the focused display's brightness, as a slider | a controllable backlight under Hyprland |
| `wifi:` | `wlan`, `network` | networks in range and saved ones, active first; connect, enter a password, speedtest | `nmcli` (NetworkManager) |
| `bt:` | `bluetooth` | paired bluetooth devices, connected first; connect, disconnect, toggle the radio | `bluetoothctl`, and something paired |
| `docker:` | `container`, `containers` | your containers, running first, with logs, a shell, and start/stop | a docker daemon actually answering |
| `alarm:` | `timer`, `remind`, `reminder` | a reminder said the way you would say it: `alarm:25m tea is ready` | Omarchy |

`docker:` is gated on the daemon answering rather than on the binary existing,
so a stopped daemon hides the keyword instead of giving you an empty list.

### The launcher itself

| Keyword | Aliases | What |
|---|---|---|
| `?` | `:`, `h:`, `help:` | every keyword loaded right now, in three groups: built in, extensions, quicklinks |
| `settings:` | — | the extensions that declare settings; picking one opens its form |
| `apps:` | `app`, `launch` | applications only |
| `run:` | `commands`, `>` | Omarchy commands only |
| `web:` | `search`, `google`, `ddg`, `?` | search the web with the default engine |
| `do:` | `agent`, `ai` | hand a local coding agent an instruction, and watch what it does |

Three extensions declare settings today: `def:` (how long to keep definitions),
`repo:` (where your repos live) and `tz:` (which zones to show). The form saves
them to `extensionSettings` in your config, but **nothing reads them back yet**:
all three scripts take their configuration from somewhere else, listed with each
keyword above. Treat `settings:` as half built until they do.

### `/` actions

Only reachable with `/`, never unscoped, because an instruction that turns up
uninvited beside your search results is a way to clear your history by accident.

| Type | What |
|---|---|
| `/clear` | forget the recent queries |
| `/clear-pins` | forget the pins |
| `/clear-all` | both. Asks first: the second Enter is the answer |
| `/reload` | rescan `~/.config/omarchy/omacast/extensions` |
| `/settings` | types `settings:` for you |
| `/config` | open `~/.config/omarchy/omacast.json` in your editor |

An extension can add its own, shown as `/spotify auth`.

---

## Doing something: `do:`

`Ctrl+Enter` asks a model a question. `do:` hands a local agent an instruction
and lets it act.

    do: open a new workspace and split it into four terminals
    do: now put my editor in the top left one
    do: find every TODO in this repo and list them

It is a chat. `Enter` sends and empties the box, what you sent stays on the card
above the answer, and the next sentence continues the same session, so "that
file" and "now make it four" mean something. `do: /new` starts over, and
`do: @codex ...` picks which agent takes it.

While it works you get three lines: what it is doing now, the last few things it
did, and the answer growing under them. Each line names the thing rather than
the tool -- `Go to an empty workspace`, `Open 4 x terminal`, `Read Launcher.qml`
-- because "Bash" thirty times is a progress bar with extra steps. When it
finishes those collapse to a count and a clock, and the answer is what is left.

Where the line is:

- **It is allowed to act.** You typed the sentence into your own launcher, on
  your own machine, and pressed Enter. That is the consent, and asking again for
  every window is how a launcher becomes something you stop using. The shell,
  writing files and editing them are all pre-approved.
- **Confirmation is kept for what cannot be undone.** Deleting, `sudo`, package
  management, credentials, and anything that leaves this machine (`git push`,
  `gh`, `ssh`, `curl`) come back refused, named, with the reason. Type
  `do: /policy` to read the whole list.
- **`Ctrl+K` is the way through one.** It hands the same instruction to an
  interactive agent in a terminal, where the permission prompts exist and you
  answer them.
- **Typing runs nothing.** An instruction comes back as something to look at:
  which agent, which directory. `Enter` starts it.
- **`Enter` carries a token, not your sentence.** The row's command names a hash
  of what was previewed, so nothing you typed reaches a shell, and nothing can
  run that was not on screen first.
- **`Escape` stops it**, and stopping kills the process group rather than the
  one pid the agent told us about. Closing the launcher stops a run too, a
  couple of seconds later, which is why long unattended work belongs in a
  terminal.

The deny list is a speed bump on a model that means well, not a sandbox: `bash
-c` is still a shell. What actually keeps this safe is that a person typed the
sentence and pressed a key.

It knows this desktop. Hyprland here is configured in Lua, where `hyprctl
dispatch workspace 9` is not merely wrong but can return `ok` and do nothing;
the agent is told the real form, and `omacast-agent desk` gives it the
dispatchers already spelled right, waiting for windows to actually appear:

```
omacast-agent desk empty              # the lowest workspace with nothing on it
omacast-agent desk tile 4 terminal    # four of them, splitting the largest each time
omacast-agent desk help               # the rest
```

It needs `claude`, `codex` or `gemini` on `PATH`. With none of them there the
keyword still answers, saying so, rather than going quiet and looking broken.

---

## Asking a model: `Ctrl+Enter`

Streams an answer into the card without leaving the launcher.

Providers are tried in order and the first one installed wins, so if you already
have the Claude, Codex or Gemini CLI signed in this works with no setup. Ollama,
aichat and mods are in the list too. Availability is probed once at startup,
never per keystroke.

Pin one with `"askProvider": "gemini"`, or add your own. A provider's command
gets `{query}` shell-quoted and `{model}` unquoted, has to write to stdout as it
goes, and has to exit when it is done. It runs with stdin closed and stderr
folded in, because a CLI that reads stdin otherwise waits, and some print a
warning into the middle of the answer.

Escape leaves the answer. So does typing.

---

## Settings

`~/.config/omarchy/omacast.json`, watched, so an edit takes effect on the next
keystroke. `/config` opens it.

```json
{
  "recents": false,
  "defaultEngine": "google",
  "engineActions": ["google", "chatgpt", "ddg", "youtube", "github"],
  "quicklinks": [
    { "title": "GitHub", "keyword": "gh", "tags": ["dev"],
      "url": "https://github.com/search?q={}" },
    { "title": "Downloads", "keyword": "dl",
      "open": "nautilus --new-window ~/Downloads" }
  ],
  "extensions": { "radio": false },
  "notesDir": "~/Documents/Notes",
  "askProvider": "claude",
  "frecency": true,
  "maxRows": 9,
  "cardWidth": 620,
  "resetOnOpen": true
}
```

| Key | Default | What |
|---|---|---|
| `recents` | `false` | offer your last 20 queries when the box is empty |
| `defaultEngine` | `"google"` | which engine `Enter` uses on a web row |
| `engines` | six built in | merged over the built-ins **by id**, so adding one does not mean restating Google, DuckDuckGo, ChatGPT, Perplexity, YouTube and GitHub |
| `engineActions` | five of them | which engines appear under `Ctrl+K`, in that order. Perplexity ships configured but unlisted |
| `quicklinks` | `[]` | your own links, see below |
| `extensions` | `{}` | name one `false` to silence it. Absent means on, so an extension that arrives in an update starts working |
| `extensionSettings` | `{}` | what `settings:` writes, under each extension's id so two extensions wanting a `token` cannot read each other's |
| `notesDir` | `~/Documents/Notes` | where `note:` keeps its markdown |
| `askProvider` | `""` | force one `Ctrl+Enter` provider by id; a typo falls back to the list rather than going silent |
| `frecency` | `true` | rank by what you actually use. `false` ranks purely on match quality; pins still apply |
| `maxRows` | `9` | rows shown, and what PageUp/PageDown jump by |
| `cardWidth` | `620` | the card, in unscaled pixels |
| `resetOnOpen` | `true` | `false` reopens on your last query |

A quicklink is found two ways, because people reach for both: type part of its
title or tag and it appears among everything else, or type its keyword and the
rest of the line becomes the argument in `{}`. Finding it by name cannot also
supply an argument, since the words that found it are not what goes in the
placeholder. With no argument, the placeholder and everything after it is
trimmed, so `gh` alone opens the site rather than an empty search. `open`
replaces `url` when the link should run something instead. An extension that
owns the same keyword wins.

---

## Timezones

`tz:` reads its zones from `timezones` in `~/.config/omarchy/omacast.json`:

```json
{
  "timezones": [
    { "label": "Ana", "zone": "Europe/Lisbon" },
    { "label": "Kenji", "zone": "Asia/Tokyo" },
    { "label": "UTC", "zone": "UTC" }
  ]
}
```

A label is a name, not a caption. `tz:ana` finds Ana, and the answer says Ana
rather than Lisbon, because the question was never really about Lisbon. Zones
are the IANA names `timedatectl list-timezones` prints, and a zone that is not
in that list is dropped rather than silently read as UTC.

Without the key you still get a working `tz:`: Los Angeles, New York, London,
Berlin and Tokyo, which is most of a working day.

Zone names match loosely, so `tokyo` finds `Asia/Tokyo`, `sp` finds
`America/Sao_Paulo` and `ny` finds `America/New_York`. Initials beat substrings,
which is what keeps `la` on Los Angeles rather than on Blantyre. A country
resolves to its main city, so `spain` is Madrid.

`tz:3pm tokyo` reads the time as yours and answers in theirs. `tz:9am tokyo in
london` reads it as Tokyo's. That is the difference an explicit `in` makes, and
it is the way both sentences are meant out loud.

`tz:john:tokyo maria:spain` draws a day grid instead: one row per person, one
shaded cell per hour, so a meeting slot is a band of colour rather than a sum.
`me:` puts you in it.

Paste a Discord timestamp in and every zone reads it. `Ctrl+K` on any answer
copies it back out as one, in all nine of Discord's styles, since working out
that 3pm is 9pm for somebody else is usually the step before telling them.

---

## Snippets

`snip:` reads `~/.config/omarchy/omacast-snippets.json`, a flat object of name
to text:

```json
{
  "sig": "Luiz\nhttps://nkz.md",
  "addr": "1 Example Street\nLisbon"
}
```

`Enter` copies one. `Ctrl+K` offers typing it into whatever window had focus,
through `wtype`. Until that file exists the keyword is not loaded at all, so an
empty snippet list costs nothing and says nothing.

---

## Playing music without an account

`spotify:daft punk` searches and plays with no key, no account and no developer
app, through a chain worth knowing about because each link is doing work.

Deezer's search endpoint is keyless and returns an ISRC on every row.
MusicBrainz maps an ISRC to a Spotify track URL. Spotify's Linux client
implements MPRIS `OpenUri`. That resolves the exact track about six times in
ten; the rest open that search inside Spotify, which is one keypress from right
rather than zero.

Three things that had to be got right, each found by testing:

- With shuffle on, `OpenUri` plays a random track from the same context instead
  of the one asked for. Shuffle is turned off first.
- A bad track id is accepted silently and changes nothing, so success is the
  track id moving rather than the call returning.
- `xdg-open` does nothing for `spotify:` URIs even though it claims the handler.
  Only D-Bus works.

Searching Spotify's own catalogue properly needs the Web API, which needs a
Spotify developer app. That ships here too, as `sp:`, and stays silent until you
run `omacast-spotify-auth`. See [SPOTIFY-LIBRARY.md](SPOTIFY-LIBRARY.md).

---

## The built-in extensions

These ship inside this unit because none of them works without it. They are
scripts in `bin/` plus a JSON file in `config/omarchy/omacast/extensions/`, and
they are the working examples to copy when writing your own.

| Keyword | Script | Notes |
|---|---|---|
| `file:` | `omacast-search-files` | fd, re-ranked by depth and match position |
| `img:` | `omacast-search-images` | newest first, dimensions from ImageMagick when present |
| `win:` | `omacast-search-windows` | hyprctl, focuses and closes through the Lua dispatcher |
| `kill:` | `omacast-kill` | biggest first, two characters minimum |
| `emoji:` | `omacast-emoji` | reads Omarchy's own emoji data in place |
| `snip:` | `omacast-snippet` | silent until the snippets file exists |
| `recent:` | `omacast-recent` | recently-used.xbel, minus what has since been deleted |
| `repo:` | `omacast-repo` | one fd walk, git only for the rows actually shown |
| `git:` | `omacast-git` | the focused terminal's repo, else the one touched last |
| `branch:` | `omacast-git-branch` | one for-each-ref, ahead/behind against upstream and trunk |
| `stash:` | `omacast-git-stash` | one call per stash for its files; no drop, on purpose |
| `gh:` | `omacast-gh` | the shared GitHub engine; a slug or URL answers before the request |
| `pr:` `issue:` `ci:` | `omacast-gh-pr` etc | thin wrappers on the same engine, one mode each |
| `ssh:` | `omacast-ssh` | ~/.ssh/config, Include followed, wildcard hosts skipped |
| `docker:` | `omacast-docker` | gated on the daemon answering, not on the binary existing |
| `spotify:` | `omacast-search-music` | MPRIS for the player, Deezer for search |
| `sp:` | `omacast-spotify` | Web API search, after `omacast-spotify-auth` |
| `radio:` | `omacast-search-radio` | radio-browser.info, plays through mpv |
| `ch:` | `omacast-clipboard-history` | reads the file Omarchy's own overlay writes |
| `note:` | `omacast-note` | one markdown file per note |
| `alarm:` | `omacast-alarm` | plain language duration |
| `theme:` | `omacast-theme` | every theme, current one first, applied as you move |
| `omarchy:` | `omacast-omarchy` | flattens the real menu, so nothing here is a stale hand copy |
| `cal:` | `omacast-calendar` | sends the numbers, the view draws the grid |
| `date:` | `omacast-date` | answers unscoped, so its gate is deliberately narrow |
| `tz:` | `omacast-timezone` | zone names matched loosely, Discord timestamps both ways |
| `unit:` | `omacast-unit` | qalc, with the phrasing traps fixed |
| `def:` | `omacast-define` | dictionaryapi.dev, keyless, kept for 30 days |
| `sys:` | `omacast-system` | every reading optional, skipped when absent |
| `calc:` | `omacast-calc-history` | written when an answer is accepted, never by a keystroke |
| `pass:` | `omacast-pass` | `pass` or `op`, whichever is there; the secret only ever reaches wl-copy |
| `bt:` | `omacast-bluetooth` | bluetoothctl reads, `omarchy-bluetooth-device` acts, so rfkill is handled |
| `wifi:` | `omacast-wifi` | saved networks connect from the row, new ones go to the network panel |
| `vol:` | `omacast-volume` | sliders; output resolved through any DSP sink to the real one |
| `bri:` | `omacast-brightness` | a slider, through `omarchy-brightness-display`, which knows DDC from backlight |
| `do:` | `omacast-agent` | answers over a unix socket rather than a process per keystroke |

---

## Writing your own extension

`bo new extension weather` writes a unit that already answers. Add it, type
`weather:hello`, and the row comes back with hello in it. Then replace the body
of the script and keep the shape.

An extension is a JSON file in `~/.config/omarchy/omacast/extensions/` naming a
keyword and a command:

```json
{
  "id": "weather",
  "keyword": "wx",
  "aliases": ["forecast"],
  "title": "Weather",
  "search": "my-weather-lookup {query}",
  "when": "command -v my-weather-lookup",
  "view": "hero"
}
```

The command prints JSON, either an array or one row per line, so it can be a
shell script, a Python file, or anything else that writes to stdout. Anything
printed before the JSON starts is skipped, because tools like mise announce
themselves the first time a shimmed binary runs.

### What the file can say

| Field | Default | What |
|---|---|---|
| `id` | required | how it is addressed everywhere else, including settings |
| `keyword` | the id | what you type before the colon |
| `aliases` | `[]` | other names for the same thing |
| `search` | — | the command. `{query}` is the shell-quoted search text, `{anything}` is another filter's value, so `music:blue year:1959` arrives as two arguments |
| `socket` | — | a unix socket to ask instead of running a command. One of `search` or `socket` is required; with neither, the extension is dropped rather than sitting in the keyword list doing nothing |
| `when` | — | a shell test, run **once** at load. An extension for software you do not have costs nothing |
| `always` | `false` | answer unscoped queries too. Off, because a launcher that shells out to six services per keystroke is one nobody keeps |
| `view` | `"list"` | the layout, see below |
| `tier` | `"substring"` | where its rows sort against everything else: `calc`, `forced`, `prefix`, `substring`, `weak`, `file`, `web` |
| `minChars` | `1` | how much you must type before it runs |
| `debounceMs` | `200` | how long to wait after the last keystroke |
| `timeoutMs` | `4000` | when to give up |
| `maxRows` | `8` | how many rows to keep |
| `cacheMs` | `0` | keep an answer this long. Off by default on purpose: what is playing, which containers are up and what is on the clipboard are all wrong the moment you act on them, and nothing here can tell those from a dictionary lookup. The key is the exact command, so a cached answer can never reach a different question |
| `refreshMs` | `0` | re-run this often while these rows are on screen: no spinner, no flicker, the selection stays put. Only while the launcher is open, and it stops the moment the query changes |
| `settings` | — | fields `settings:` will ask for and write to `extensionSettings.<id>` in `omacast.json`, each `{ key, label, value, placeholder, secret }`. Your script must read that file itself: they are deliberately never passed on a command line, because a token on a command line is a token in everyone's process list. No shipped extension does this yet |
| `actions` | — | extra `/` actions, shown as `/weather refresh`, each `{ id, title, subtitle, keywords, exec, confirm }` |

### What a row can say

The minimum is `{ id, title, subtitle, exec }`. Beyond that: `detail`,
`accessory`, `icon`, `glyph`, `art`, `preview`, `group`, `mono`, `score`,
`progress`, `view`, and its own `actions`.

Only the **first** row's `view` is read, so put the row that decides the layout
first. A row's own `score` orders it against its siblings and never crosses a
tier, so an extension cannot outrank the calculator by returning a big number.

An action is `{ title, shortcut, exec }`. Add `query` and running it lands you
on that query instead of closing the launcher, which is how playing a track
returns you to the player. Add `keepOpen: true` when all the action does is
change something the launcher will show next; without it the launcher closes,
which is right for anything that starts a program and wrong for anything that
does not.

**Any field the launcher has not already named is passed through untouched.** A
view can therefore read fields nobody has heard of yet, which is how new views
get built without editing the row builder.

### `view` picks the layout

| view | For |
|---|---|
| `list` | a choice between named things. The default |
| `hero` | one answer that is the point: a sum, a date, a conversion |
| `cards` | things you recognise by their picture |
| `grid` | things you pick by looking |
| `split` | things whose content matters more than their name |
| `dashboard` | readings, some of which are proportions |
| `calendar` | a month |
| `player` | what is playing, with a position bar that ticks between readings |
| `slider` | a number you drag, written back with `setExec` as you move |
| `form` | fields to fill in before anything happens. Takes the keyboard from the box |
| `zones` | a column of clocks |
| `timegrid` | one row per person, one cell per hour |
| `gitrepo` | one repo: branch, uncommitted work, recent commits |
| `gitbranches` | branches with the marks that decide: checked out, ahead, stale |
| `gitstashes` | stashes, the selected one expanded into its files |
| `ghrepo` | one GitHub repo: open PRs, checks, head commit, newest release |
| `ghpr` | one pull request, its status drawn once and large |
| `agent` | a chat with something that acts |
| `answer` | a model's answer, growing as it arrives |
| `loading` | a skeleton in the shape of the answer, so the card never says "nothing matches" before it has looked |

See [EXTENSIONS.md](EXTENSIONS.md) for the socket protocol and the longer
version of all of this.

---

## Files

```
plugin/          the QML: Launcher.qml, one Result*.qml per view, the .js logic
bin/             one script per built-in extension
config/          the extension JSON, mirrored into ~/.config on add
```

Editing QML wants a full `omarchy restart shell` to be certain. After each
reload, check `journalctl --user -n 50 | grep -iE "TypeError|error"`: a
TypeError inside a delegate binding renders a blank row rather than failing
loudly, so nothing tells you otherwise.
