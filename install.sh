#!/bin/bash
# better-omarchy installer.
#
#   git clone <this repo> ~/localhost/better-omarchy
#   cd ~/localhost/better-omarchy && ./install.sh
#
# Picks units, links them, and puts `bo` on PATH. Nothing here is destructive:
# anything already at a target path is moved aside with a .before-bo suffix.

set -uo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"

die() {
  printf '\033[31mERROR\033[0m %s\n' "$*" >&2
  exit 1
}

command -v omarchy >/dev/null || die "this needs Omarchy (the omarchy command is missing)"
command -v hyprctl >/dev/null || die "this needs Hyprland"

mode="pick"
case "${1:-}" in
--all) mode="all" ;;
--none) mode="none" ;;
"") ;;
*) die "usage: install.sh [--all|--none]" ;;
esac

# `bo` first, so the rest of the install is just bo calls.
mkdir -p "$BIN_DIR"
if [[ ! -L "$BIN_DIR/bo" ]]; then
  ln -sf "$ROOT/bo" "$BIN_DIR/bo"
  printf 'Linked bo into %s\n' "$BIN_DIR"
fi

case "$PATH" in
*"$BIN_DIR"*) ;;
*) printf '\033[33mWARN\033[0m %s is not on your PATH; add it to use `bo`\n' "$BIN_DIR" >&2 ;;
esac

# The shell config is copied rather than symlinked: every writer replaces the
# file instead of editing it, so a symlink would be dropped on the first
# `omarchy bar set`. Widget settings such as workspace names live in here.
if [[ -f "$ROOT/config/shell.json" ]]; then
  live="$HOME/.config/omarchy/shell.json"
  if [[ -f $live ]] && ! cmp -s "$live" "$ROOT/config/shell.json"; then
    cp "$live" "$live.before-bo.$(date +%s)"
    printf 'Backed up your existing shell.json\n'
  fi
  mkdir -p "$(dirname "$live")"
  cp "$ROOT/config/shell.json" "$live"
fi

case "$mode" in
all)
  while read -r unit; do "$ROOT/bo" add "$unit"; done < <(
    for d in "$ROOT"/units/*/; do [[ -f "$d/unit.toml" ]] && basename "$d"; done
  )
  ;;
none) printf 'No units turned on. Run `bo add` when you want some.\n' ;;
pick)
  command -v gum >/dev/null || die "gum is missing; run install.sh --all or --none, then use bo add"
  "$ROOT/bo" add
  ;;
esac

printf '\n'
"$ROOT/bo" status
printf '\nRestarting the shell.\n'
omarchy restart shell >/dev/null 2>&1
printf 'Done. `bo list` shows everything available.\n'
