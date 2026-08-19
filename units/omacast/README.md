# omacast

A launcher. One box that answers with apps, arithmetic, files, music, your notes
and the web, and draws each of those the way it deserves rather than as one long
list.

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

## What you can type

Type anything and apps, Omarchy commands and your own quicklinks come back
ranked together. Beyond that, a `keyword:value` filter narrows to one source and
tells it what you want.

| Type | Get |
|---|---|
| `firefox` | apps, commands and quicklinks, ranked together |
| `2+2*10`, `10 usd to eur`, `40 miles in km` | the answer, large |
| `27 november 2027`, `next friday` | the day of week, the week number, how far away |
| `tz:`, `tz:tokyo`, `tz:3pm tokyo` | the time there, and the day when it is not yours |
| `unit:20 miles`, `unit:180f in c` | the conversion, and the ones you did not ask for |
| `def:ephemeral` | every sense, its part of speech, and the synonyms |
| `file:report format:pdf` | files, filtered by extension |
| `img:` or `img:holiday in:~/work` | thumbnails, with dimensions and size |
| `win:chrome` | jump to that open window, or close it |
| `kill:chrome` | a running process, with its memory, and the signal to end it |
| `emoji:` or `emoji:heart` | the emoji, copied |
| `snip:sig` | a snippet of text you keep retyping |
| `recent:` | the files you opened lately, in any app |
| `repo:` or `repo:oma branch:main` | your git repos, with branch, dirty state and age |
| `git:` or `git:omarchy` | one repo: branch, what is uncommitted, how many stashes, recent commits |
| `branch:` or `branch:omarchy` | its branches, with the one you are on, what is unpushed and how stale each is. Enter switches |
| `stash:` or `stash:omarchy login` | its stashes, with the files in each, so you can read one before applying it |
| `gh:` or `gh:oma` | your GitHub repos, then a search of the rest of GitHub |
| `gh:basecamp/omarchy` | one repository: is its default branch broken, what is waiting to be merged, what shipped |
| `gh:owner/repo#7398` or a pasted GitHub URL | one pull request: every check by name, who reviewed it, how big it is |
| `pr:` | your open pull requests and the ones waiting on your review, each with the mark that says whether it passed |
| `issue:` | assigned to you, and mentioning you |
| `ci:owner/repo` | workflow runs, failures first |
| `ssh:prod` | a host from your ssh config, connected in a terminal |
| `docker:` | containers, running first, with logs, a shell and start/stop |
| `spotify:` | the player: cover, scrubber, transport |
| `spotify:daft punk` | search and play, no account needed |
| `radio:jazz` | internet radio, through mpv |
| `ch:token` | what you copied, with the full text beside it |
| `note:standup` | that note, or the offer to write it |
| `alarm:25m tea is ready` | a reminder, said the way you would say it |
| `theme:tokyo` | switch theme by name |
| `cal:` or `cal:november 2027` | a month, drawn |
| `sys:` | battery, memory, disk, uptime, address, kernel |
| `calc:` | the sums you have already done, newest first |
| `pass:github` | an entry from `pass` or 1Password, copied, cleared after 45s |
| `bt:` | paired bluetooth devices, connected first, connect and disconnect |
| `wifi:` | networks in range, with signal, and the saved ones connected in one key |
| `vol:` | output and input volume, as sliders |
| `bri:` | screen brightness, as a slider |
| `do:open a new workspace and split it into four terminals` | an agent does it, and you watch which step it is on |
| `?` | every keyword the launcher knows, built from what is loaded |
| nothing at all | the last twenty queries that led somewhere |
| anything with no match | search the web |

`=`, `>`, `?` and `/` are one-character shorthands for calc, commands, web and
file. `?` on its own is the exception: with nothing after it there is nothing to
search for, so it lists the keywords instead. `Enter` on one leaves it in the
box ready for the rest of the line.

## Keys

| Key | What |
|---|---|
| `Enter` | run the primary action |
| `Shift+Enter` | run the second one, named in the footer |
| `Ctrl+Enter` | ask a model, streamed into the card |
| `Ctrl+K` | every other action this result has |
| `Ctrl+1` to `Ctrl+9` | run that row, by the number down the left |
| `Ctrl+P` | pin the selected row, so it leads every query it matches |
| `Up` / `Down`, `Ctrl+Shift+P` / `Ctrl+N`, `Tab` | move |
| `Left` / `Right` | move, in the grid and calendar views |
| `Escape` | leave an answer, then clear the box, then close |

The footer always names what `Enter` does, so it is never a guess.

A pin lifts a row the way frecency does and by more, and neither ever crosses a
tier: a name that starts with what you typed still beats a pinned substring.
Pins and recent queries live in `~/.local/state/omarchy/omacast-state.json`,
beside the frecency file rather than in your settings, which stay yours to edit.

## Doing something: `do:`

`Ctrl+Enter` asks a model a question. `do:` hands a local agent an instruction
and lets it act.

    do: open a new workspace and split it into four terminals
    do: now put my editor in the top left one
    do: find every TODO in this repo and list them

It is a chat. `Enter` sends and empties the box, what you sent stays on the card
above the answer, and the next sentence continues the same session, so "that
file" and "now make it four" mean something. `do: /new` starts over.

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

It needs `claude` or `codex` on `PATH`. With neither there the keyword still
answers, saying so, rather than going quiet and looking broken.

## Asking a model

`Ctrl+Enter` streams an answer into the card without leaving the launcher.

Providers are tried in order and the first one installed wins, so if you already
have the Claude, Codex or Gemini CLI signed in this works with no setup. Ollama,
aichat and mods are in the list too.

Pin one with `"askProvider": "gemini"`, or add your own. A provider's command
gets `{query}` shell-quoted and `{model}` unquoted, has to write to stdout as it
goes, and has to exit when it is done. It runs with stdin closed and stderr
folded in, because a CLI that reads stdin otherwise waits, and some print a
warning into the middle of the answer.

## Settings

`~/.config/omarchy/omacast.json`, watched, so an edit takes effect on the next
keystroke.

```json
{
  "defaultEngine": "google",
  "quicklinks": [
    { "title": "GitHub", "keyword": "gh", "tags": ["dev"],
      "url": "https://github.com/search?q={}" },
    { "title": "Downloads", "keyword": "dl",
      "open": "nautilus --new-window ~/Downloads" }
  ],
  "extensions": { "radio": false },
  "notesDir": "~/Documents/Notes",
  "askProvider": "claude",
  "maxRows": 9,
  "cardWidth": 620,
  "resetOnOpen": true
}
```

A quicklink is found two ways, because people reach for both: type part of its
title and it appears among everything else, or type its keyword and the rest of
the line becomes the argument in `{}`. A link with no `{}` just opens.

`extensions` silences one of the built-ins. Absent means on, so a new one that
arrives in an update starts working rather than waiting to be listed.

Engines merge by id rather than replacing the list, so adding one does not mean
restating Google, DuckDuckGo, ChatGPT, Perplexity, YouTube and GitHub.

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

Without the key you still get a working `tz:`: UTC, San Francisco, New York,
London, Berlin and Tokyo, which is most of a working day.

Zone names match loosely, so `tokyo` finds `Asia/Tokyo`, `sp` finds
`America/Sao_Paulo` and `ny` finds `America/New_York`. Initials beat substrings,
which is what keeps `la` on Los Angeles rather than on Blantyre.

`tz:3pm tokyo` reads the time as yours and answers in theirs. `tz:9am tokyo in
london` reads it as Tokyo's. That is the difference an explicit `in` makes, and
it is the way both sentences are meant out loud.

Paste a Discord timestamp in and every zone reads it. `Ctrl+K` on any answer
copies it back out as one, in all nine of Discord's styles, since working out
that 3pm is 9pm for somebody else is usually the step before telling them.

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

## The built-in extensions

These ship inside this unit because none of them works without it. They are
scripts in `bin/` plus a JSON file in
`config/omarchy/omacast/extensions/`, and they are the working examples to copy
when writing your own.

| Keyword | Script | Notes |
|---|---|---|
| `file:` `format:` `in:` | `omacast-search-files` | fd, re-ranked by depth and match position |
| `img:` | `omacast-search-images` | newest first, dimensions from ImageMagick when present |
| `win:` | `omacast-search-windows` | hyprctl, focuses and closes through the Lua dispatcher |
| `kill:` | `omacast-kill` | biggest first, two characters minimum |
| `emoji:` | `omacast-emoji` | reads Omarchy's own emoji data in place |
| `snip:` | `omacast-snippet` | silent until the snippets file exists |
| `recent:` | `omacast-recent` | recently-used.xbel, minus what has since been deleted |
| `repo:` | `omacast-repo` | one cached fd walk, git only for the rows actually shown |
| `git:` | `omacast-git` | the focused terminal's repo, else the one touched last |
| `branch:` | `omacast-git-branch` | one for-each-ref, cached on the newest mtime in .git |
| `stash:` | `omacast-git-stash` | one call per stash for its files, cached on refs/stash |
| `gh:` `pr:` `issue:` `ci:` | `omacast-gh` | one request per answer, cached on disk per credential, warmed behind your back |
| `ssh:` | `omacast-ssh` | ~/.ssh/config, Include followed, wildcard hosts skipped |
| `docker:` | `omacast-docker` | gated on the daemon answering, not on the binary existing |
| `spotify:` `music:` | `omacast-search-music` | MPRIS for the player, Deezer for search |
| `radio:` | `omacast-search-radio` | radio-browser.info, plays through mpv |
| `ch:` | `omacast-clipboard-history` | reads the file Omarchy's own overlay writes |
| `note:` | `omacast-note` | one markdown file per note, opened in Omawrite |
| `alarm:` | `omacast-alarm` | plain language duration, rounded up to whole minutes |
| `theme:` | `omacast-theme` | every theme, current one first |
| `sp:` | `omacast-spotify` | playlists and library, after `omacast-spotify-auth` |
| `cal:` | `omacast-calendar` | sends the numbers, the view draws the grid |
| `date:` | `omacast-date` | answers unscoped, so its gate is deliberately narrow |
| `tz:` `time:` | `omacast-timezone` | zone names matched loosely, Discord timestamps both ways |
| `unit:` | `omacast-unit` | qalc again, but scoped, so the gate can be permissive |
| `def:` | `omacast-define` | dictionaryapi.dev, keyless, cached for a month |
| `sys:` | `omacast-system` | every reading optional, skipped when absent |
| `calc:` | `omacast-calc-history` | written by `record` when an answer is accepted, never by a keystroke |
| `pass:` | `omacast-pass` | `pass` or `op`, whichever is there; the secret only ever reaches wl-copy |
| `bt:` | `omacast-bluetooth` | bluetoothctl reads, `omarchy-bluetooth-device` acts, so rfkill is handled |
| `wifi:` | `omacast-wifi` | saved networks connect from the row, new ones go to the network panel |
| `vol:` | `omacast-volume` | sliders; output resolved through any DSP sink to the real one |
| `bri:` | `omacast-brightness` | a slider, through `omarchy-brightness-display`, which knows DDC from backlight |

## Playing music without an account

`spotify:daft punk` searches and plays with no key, no account and no developer
app, through a chain worth knowing about because each link is load bearing.

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

Playlists and your saved library need the Web API, which needs a Spotify
developer app. That ships here too, as `sp:`, and stays silent until you run
`omacast-spotify-auth`. See [SPOTIFY-LIBRARY.md](SPOTIFY-LIBRARY.md).

## Writing your own extension

`bo new extension weather` writes a unit that already answers. Add it, type
`weather:hello`, and the row comes back with hello in it. Then replace the body
of the script and keep the shape.

An extension is a JSON file naming a keyword and a command:

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

The command prints JSON, either an array or one row per line, so it can be a
shell script, a Python file, or anything else that writes to stdout.

A row is `{ id, title, subtitle, exec }` plus, optionally: `detail`,
`accessory`, `art`, `preview`, `score`, `progress`, `group`, `mono`, `view`, and
its own `actions`.

An action is `{ title, shortcut, exec }`. Give it a `query` as well and running
it lands you on that query instead of closing the launcher, which is how playing
a track returns you to the player.

`view` picks the layout:

| view | For |
|---|---|
| `list` | a choice between named things |
| `hero` | one answer that is the point: a sum, a date, a confirmation |
| `cards` | things you recognise by their picture |
| `grid` | things you pick by looking |
| `split` | things whose content matters more than their name |
| `dashboard` | readings, some of which are proportions |
| `calendar` | a month |
| `player` | what is playing |

`when` is checked once when the extension loads, never per keystroke, so an
extension for software you do not have costs nothing.

Unscoped, an extension stays quiet unless it sets `"always": true`. Shelling out
to six services on every keystroke is how a launcher becomes slow enough to
abandon. `date:` is the one built-in that opts in, and its gate is narrow for
exactly that reason: `date -d` reads "may" as a month and "1" as a day of this
month, which would put a date on top of every search for a file called 1.

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
