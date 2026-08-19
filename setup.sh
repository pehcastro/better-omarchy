#!/bin/bash
# better-omarchy setup.
#
#   curl -fsSL https://raw.githubusercontent.com/pehcastro/better-omarchy/master/setup.sh | bash
#
# Installs the `bo` command, adds this repo as your first marketplace, and hands
# you the picker.
#
# Two things this deliberately does not do: it never turns a unit on without you
# choosing it, and it never overwrites a file it did not write. Anything already
# at a target path is moved aside with a .before-bo suffix.

set -uo pipefail

REPO_URL="${BO_REPO_URL:-https://github.com/pehcastro/better-omarchy.git}"
MARKET_NAME="${BO_MARKET_NAME:-better-omarchy}"
BRANCH="${BO_BRANCH:-master}"

DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/better-omarchy"
MARKETS_DIR="$DATA_DIR/marketplaces"
HOME_MARKET="$MARKETS_DIR/$MARKET_NAME"
BIN_DIR="$HOME/.local/bin"

bold() { printf '\033[1m%s\033[0m' "$1"; }
dim() { printf '\033[2m%s\033[0m' "$1"; }
green() { printf '\033[32m%s\033[0m' "$1"; }
yellow() { printf '\033[33m%s\033[0m' "$1"; }
cyan() { printf '\033[36m%s\033[0m' "$1"; }

die() {
  printf '\n\033[31mThat did not work\033[0m\n  %s\n\n' "$*" >&2
  exit 1
}

step() { printf '\n%s %s\n' "$(cyan '::')" "$(bold "$1")"; }
note() { printf '   %s\n' "$(dim "$1")"; }

# Piping this script through bash leaves stdin on the pipe, so anything that
# reads a key would read the rest of the script instead. /dev/tty is the
# terminal itself, which is still there.
# Opening it is the only honest test: the path exists in a piped shell but
# reading it fails, and a failed read here would print an error per prompt.
tty_available() { { : >/dev/tty; } 2>/dev/null; }

ask() {
  local prompt="$1" default="${2:-y}" answer

  tty_available || {
    printf '%s' "$default"
    return 0
  }

  printf '   %s %s ' "$prompt" "$(dim "$([[ $default == y ]] && echo '[Y/n]' || echo '[y/N]')")" >/dev/tty
  read -r answer </dev/tty
  answer="${answer:-$default}"
  [[ ${answer,,} == y* ]]
}

pause() {
  tty_available || return 0
  printf '   %s' "$(dim 'enter to continue')" >/dev/tty
  read -r </dev/tty
  printf '\r%*s\r' 30 "" >/dev/tty
}

# ---------------------------------------------------------------- what this is

cat <<'INTRO'

  better-omarchy

  A marketplace system for Omarchy, plus the units that ship with it.

  A unit is one customization: a launcher, a bar widget, a keybinding, a
  Hyprland rule. Unlike an Omarchy plugin it can be several of those at once,
  it says what it needs and which keys it claims, and removing it takes back
  exactly what it added.

  This installs one command, `bo`, and adds this repo as your first
  marketplace. Nothing is turned on until you pick it.

INTRO

# ---------------------------------------------------------------- checks

step "Checking this machine"

for tool in git python3; do
  command -v "$tool" >/dev/null ||
    die "$tool is required and is not installed. Try: omarchy pkg add $tool"
done
note "git and python3 are here"

command -v omarchy >/dev/null ||
  die "This is for Omarchy, and the omarchy command is not on your PATH."
note "Omarchy $(omarchy version 2>/dev/null | head -1)"

if command -v gum >/dev/null; then
  note "gum is here, so you get the interactive picker"
else
  printf '   %s gum is missing, so you will pick units by name rather than from a list.\n' "$(yellow '!')"
  note "Install it later with: omarchy pkg add gum"
fi

# ---------------------------------------------------------------- what it does

step "What is about to happen"
printf '   Install the %s command, and add this marketplace.\n' "$(bold bo)"
printf '\n'
printf '   %s\n' "$(dim 'Nothing else is written. Every unit you turn on later is a symlink')"
printf '   %s\n' "$(dim 'back into that clone, and bo remove takes it out again.')"
printf '\n'

if tty_available; then
  ask "Go ahead?" y || {
    printf '\n   %s\n\n' "Stopped. Nothing was changed."
    exit 0
  }
fi

# ---------------------------------------------------------------- clone

step "Getting the marketplace"
mkdir -p "$MARKETS_DIR"

if [[ -d "$HOME_MARKET/.git" ]]; then
  note "Already at $HOME_MARKET, fetching"
  git -C "$HOME_MARKET" fetch --quiet origin "$BRANCH" || die "git fetch failed"
  if git -C "$HOME_MARKET" merge --ff-only "origin/$BRANCH" --quiet 2>/dev/null; then
    note "Up to date"
  else
    printf '   %s You have local commits here, so nothing was pulled.\n' "$(yellow '!')"
  fi
else
  [[ -e $HOME_MARKET ]] &&
    die "$HOME_MARKET exists and is not a git checkout. Move it aside and run this again."
  git clone --quiet --branch "$BRANCH" "$REPO_URL" "$HOME_MARKET" ||
    die "Could not clone $REPO_URL"
  note "Cloned into $HOME_MARKET"
fi

[[ -f "$HOME_MARKET/registry.json" ]] ||
  die "$HOME_MARKET has no registry.json, so it is not a marketplace."

# ---------------------------------------------------------------- the command

step "Installing bo"
mkdir -p "$BIN_DIR"

if [[ -e "$BIN_DIR/bo" && ! -L "$BIN_DIR/bo" ]]; then
  mv "$BIN_DIR/bo" "$BIN_DIR/bo.before-bo.$(date +%s)"
  printf '   %s There was already a bo here. Moved it aside rather than replacing it.\n' "$(yellow '!')"
fi

ln -sf "$HOME_MARKET/bo" "$BIN_DIR/bo"
note "bo -> $HOME_MARKET/bo"

case ":$PATH:" in
*":$BIN_DIR:"*) ;;
*)
  printf '\n   %s %s is not on your PATH, so `bo` will not be found.\n' "$(yellow '!')" "$BIN_DIR"
  printf '   Add this to your shell rc, then open a new terminal:\n\n'
  printf '     %s\n' "$(cyan "export PATH=\"$BIN_DIR:\$PATH\"")"
  ;;
esac

# ---------------------------------------------------------------- pick

step "Choosing what to turn on"

if ! tty_available; then
  # Piped through bash: a picker here would read the rest of this script as
  # keystrokes. Say what to run instead of guessing.
  printf '   %s\n' "This was piped, so the picker cannot read your keyboard."
  printf '   Run %s when you are ready to choose.\n' "$(cyan 'bo add')"
elif ! command -v gum >/dev/null; then
  printf '   %s\n\n' "Without gum there is no picker. Turn one on by name:"
  "$HOME_MARKET/bo" list --plain 2>/dev/null | sed 's/^/   /'
  printf '\n   For example %s\n' "$(cyan 'bo add omacast')"
else
  printf '   %s\n' "$(dim 'Space marks one, enter installs what you marked.')"
  printf '   %s\n\n' "$(dim 'None of this is final. Change any of it later with bo.')"

  picked=$("$HOME_MARKET/bo" list --plain 2>/dev/null |
    gum choose --no-limit --height 12 \
      --cursor-prefix "[ ] " --selected-prefix "[x] " --unselected-prefix "[ ] " \
      --header "  what would you like?") || picked=""

  if [[ -n $picked ]]; then
    printf '\n'
    while read -r line; do
      [[ -z $line ]] && continue
      "$HOME_MARKET/bo" add "${line%% *}" 2>&1 | sed 's/^/   /'
    done <<<"$picked"
  else
    note "Nothing picked. Run bo at any time to choose."
  fi
fi

# ---------------------------------------------------------------- done

step "Done"
printf '\n'
"$HOME_MARKET/bo" version 2>/dev/null | sed 's/^/   /'
printf '\n'
# Padded before styling, because printf counts the escape bytes in a styled
# string and every column would be short by nine.
cheatsheet() { printf '   %s %s\n' "$(bold "$(printf '%-21s' "$1")")" "$2"; }

cheatsheet "bo" "the menu, if you would rather not remember commands"
cheatsheet "bo list" "everything available"
cheatsheet "bo add <unit>" "turn one on"
cheatsheet "bo status" "what is on, and any key conflicts"
cheatsheet "bo market add <url>" "someone else's units"
printf '\n'
printf '   %s\n' "$(dim 'Each unit has a README next to it explaining what it does.')"
printf '\n%s\n\n' "$(green '   Welcome.')"

if command -v omarchy >/dev/null && [[ -n $(command -v omarchy-shell) ]]; then
  omarchy restart shell >/dev/null 2>&1 &
fi
