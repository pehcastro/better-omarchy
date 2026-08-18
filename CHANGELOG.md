# Changelog

Every notable change to better-omarchy. Commits follow Conventional Commits, and
versions follow SemVer: a breaking change to the unit format or the bo interface
is a major, a new unit or command is a minor, a fix is a patch.

A unit carries its own version in its unit.toml, bumped on its own schedule.
This file is about bo and the marketplace itself.

## Unreleased

### Features

- Split an Omarchy setup into units managed by bo
- Make bo a marketplace client, not a single repo

### Refactors

- **units:** Name units for what they do

### Documentation

- **readme:** Describe each unit in prose, drop the docs folder


