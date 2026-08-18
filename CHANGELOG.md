# Changelog

Every notable change to better-omarchy. Commits follow Conventional Commits, and
versions follow SemVer: a breaking change to the unit format or the bo interface
is a major, a new unit or command is a minor, a fix is a patch.

A unit carries its own version in its unit.toml, bumped on its own schedule.
This file is about bo and the marketplace itself.

## Unreleased

### Features

- **omarchycast:** Add the launcher, with apps, maths, commands and web
- **units:** Add keys presets, display-local, and unit dependencies
- **omarchycast:** Answer keyword filters, and take extensions
- **units:** Add file, window and music search extensions
- **omarchycast:** Give results a view, actions, and settings
- **units:** Play music properly, and search the clipboard
- **omarchycast:** Add quicklinks and a grid view
- **units:** Browse images from the launcher with img:
- **omarchycast:** Ask a model on ctrl+enter, and stream the answer
- **units:** Add dates, a calendar and system status
- **omarchycast:** Draw system status and the calendar properly
- **units:** Search Spotify and start playback with sp:
- **units:** Add notes, alarms, theme switching, and hover selection
- **units:** Add notes, and select a result on hover

### Fixes

- **omarchycast:** Make image thumbnails readable

### Refactors

- **Breaking:** **omacast:** Rename omarchycast to omacast

### Documentation

- **readme:** Cover the launcher, its filters and its extensions

### Build and dependencies

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


