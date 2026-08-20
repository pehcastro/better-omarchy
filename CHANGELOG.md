# Changelog

Every notable change to better-omarchy. Commits follow Conventional Commits, and
versions follow SemVer: a breaking change to the unit format or the bo interface
is a major, a new unit or command is a minor, a fix is a patch.

A unit carries its own version in its unit.toml, bumped on its own schedule.
This file is about bo and the marketplace itself.

## 0.4.0 (2026-08-20)

### Features

- **omacast:** Passwords, bluetooth, wi-fi, sliders and calculator history
- **omacast:** Cache answers, refresh in place, and let a daemon push rows
- **omacast:** Sliders, forms, settings, flows, accents and one chip per row
- **omacast:** Slash commands, for what the launcher does to itself
- **omacast:** Name people and see the day you share
- **workspace-names:** Hide the empty ones, and fit the names to the bar
- **Breaking:** **better-workspaces:** Rename the unit, and finish with a workspace properly
- **better-workspaces:** Let a finished workspace leave, visibly
- **omacast:** A meeting grid you can walk, and a slash command list
- **omacast:** A view built for times, and no UTC in the way
- **omacast:** Draw the answer's shape while it is still being fetched
- **omacast:** Three ways to ask what you can type
- **bo:** Let an extension say what it must still answer
- **omacast:** Git: knows what GitHub knows about the repo
- **omacast:** Git: is a panel, and local stops pretending to be remote
- **omacast:** An action can stay open
- **omacast:** Do:, plain language handed to an agent
- **omacast:** Decide what opening a repo means
- **omacast:** Gh: answers about a repo, a pull request, and your own queue
- **bo:** Audit every row every extension returns
- **omacast:** Branch: and stash:, the two questions git: could not answer
- **omacast:** Naming a repository asks about that repository
- **omacast:** Omarchy:, every setting from Omarchy's own menu
- **omacast:** Eight keywords stop being a list
- **omacast:** Shortcuts, a radio player, and git that opens the tool
- **omacast:** Bo:, a marketplace you browse inside the launcher
- **bo:** Units record what they change and put it back
- **omacast:** Herdr:, and eight keywords stop being a list

### Fixes

- **omacast:** Re-check a keyword that was unavailable when the shell started
- **omacast:** Stop the answer drawing outside its card
- **omacast:** Make every view clip to the card
- **better-workspaces:** Hide an empty workspace, keep its name
- **better-workspaces:** One fade, and one rule
- **omacast:** Stop the spinner that never stopped
- **better-workspaces:** Stop the row expanding, and release every stale name
- **omacast:** One name is a person, and the hero keeps its clocks
- **omacast:** Keep the grid while the sentence is still being typed
- **omacast:** Fewer actions, and Enter answers the row's own question
- **omacast:** Ctrl+K opens the panel again
- **omacast:** No pinning, no spinner, and every action proven to run
- **omacast:** Trim the git needle, and stop the skeleton on a local answer
- **omacast:** A finished process always stops the waiting
- **omacast:** A cache cannot outlive the scheme that wrote it
- **omacast:** Ignore anything printed before the JSON
- **omacast:** The repo cache is written atomically
- **omacast:** The debounce no longer kills the run it just started
- **omacast:** A conversion written with "in" is a conversion
- **omacast:** The units people type mean what they type
- **omacast:** Bare stash: is always the picker
- **omacast:** Searching a song does not need the player already open
- **omacast:** Herdr opens a session named for the repo, in the repo
- **omacast:** Read what people type, or answer nothing
- **omacast:** Do: acts the same way twice, and Enter runs what you typed

### Performance

- **omacast:** Bound every cache, and stop paying for closed windows

### Documentation

- **bo:** Teach cases where somebody writing an extension already is
- Describe what is here, and delete what was never true

### Tests

- **omacast:** The diff case names a repo with changes

## 0.3.0 (2026-08-19)

### Features

- **omacast:** Help, recent queries, row shortcuts and pins
- **omacast:** Timezones, unit conversion and a dictionary
- **omacast:** Repos, git, github, ssh hosts and containers

### Fixes

- **omacast:** Keep the action panel on screen, and stop blaming an empty query

### Documentation

- **omacast:** List the new keywords, and rebuild the registry

### Build and dependencies

- **changelog:** Cut v0.3.0

## 0.2.0 (2026-08-19)

### Features

- **omacast:** Add the launcher, with apps, maths, commands and web
- **units:** Add keys presets, display-local, and unit dependencies
- **omacast:** Answer keyword filters, and take extensions
- **units:** Add file, window and music search extensions
- **omacast:** Give results a view, actions, and settings
- **units:** Play music properly, and search the clipboard
- **omacast:** Add quicklinks and a grid view
- **units:** Browse images from the launcher with img:
- **omacast:** Ask a model on ctrl+enter, and stream the answer
- **units:** Add dates, a calendar and system status
- **omacast:** Draw system status and the calendar properly
- **units:** Search Spotify and start playback with sp:
- **units:** Add notes, alarms, theme switching, and hover selection
- **units:** Add notes, and select a result on hover
- **omacast:** Make music a player, and search it with no setup at all
- **spotify:** Make spotify a provider, and finish the transport
- **nkz-keys:** Copy a selected file's path with ctrl+shift+g
- **nkz-keys:** Copy a selected file's path with ctrl+b
- **omacast:** Rank by what you use, and say when there is nothing
- **nkz-keys:** Super+grave returns to the workspace you came from
- **omacast:** Add emoji, kill, snip and recent
- **bo:** Add bo test, and split the docs by audience
- **bo:** Keep bo itself current, and stop claiming a pull when ahead
- **bo:** Install plain Omarchy plugin repos too
- **bo:** An interactive bo, and tell the shell when its config changes
- **setup:** Make setup explain itself, and pick units with checkboxes

### Fixes

- **omacast:** Make image thumbnails readable
- **nkz-keys:** Hold the monitor scale at 1x
- **nkz-keys:** Unbind the monitor scaling keys
- **nkz-keys:** Stop the screen waking at 2x, and drop the screensaver
- **nkz-keys:** Let the Display panel and the config agree on scale
- **bo:** Escape means back everywhere, never quit
- **bo:** One marketplace per name, decided at the source

### Refactors

- **Breaking:** **omacast:** Rename omarchycast to omacast
- **Breaking:** **omacast:** Ship the launcher extensions inside the launcher
- **Breaking:** **units:** Cut to five, and put omacast's keys inside omacast

### Documentation

- **readme:** Cover the launcher, its filters and its extensions
- **marketplace:** Say why marketplaces exist at all
- Frame this as what Omarchy's plugins do not cover, not as a rival

### Build and dependencies

- **changelog:** Regenerate
- **changelog:** Regenerate
- **changelog:** Regenerate
- **changelog:** Regenerate
- **changelog:** Regenerate
- **changelog:** Regenerate
- **changelog:** Regenerate
- **changelog:** Regenerate
- **changelog:** Regenerate
- **changelog:** Cut v0.2.0 and rename the old scope

## 0.1.0 (2026-08-18)

### Features

- Split an Omarchy setup into units managed by bo
- Make bo a marketplace client, not a single repo

### Refactors

- **units:** Name units for what they do

### Documentation

- **readme:** Describe each unit in prose, drop the docs folder

### Build and dependencies

- **changelog:** Generate CHANGELOG.md with git-cliff
- **changelog:** Cut v0.1.0


