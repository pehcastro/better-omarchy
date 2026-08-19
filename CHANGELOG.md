# Changelog

Every notable change to better-omarchy. Commits follow Conventional Commits, and
versions follow SemVer: a breaking change to the unit format or the bo interface
is a major, a new unit or command is a minor, a fix is a patch.

A unit carries its own version in its unit.toml, bumped on its own schedule.
This file is about bo and the marketplace itself.

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


