#!/bin/bash
# better-omarchy setup.
#
#   curl -fsSL https://raw.githubusercontent.com/pehcastro/better-omarchy/master/setup.sh | bash
#
# Installs the `bo` command, adds this repo as your first marketplace, and hands
# you the picker. Nothing is turned on without you choosing it, and anything
# already at a target path is moved aside with a .before-bo suffix rather than
# overwritten.

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

die() {
  printf '\033[31mERROR\033[0m %s\n' "$*" >&2
  exit 1
}

step() { printf '\n%s %s\n' "$(dim '::')" "$(bold "$1")"; }

# ---------------------------------------------------------------- checks

for tool in git python3; do
  command -v "$tool" >/dev/null || die "$tool is required and is not installed"
done

command -v omarchy >/dev/null ||
  die "this is for Omarchy, and the omarchy command is not on your PATH"

command -v gum >/dev/null || {
  printf '%s gum is not installed, so setup will skip the picker.\n' "$(yellow WARN)"
  printf '  Install it with: omarchy pkg add gum\n'
}

# ---------------------------------------------------------------- clone

step "Getting $MARKET_NAME"
mkdir -p "$MARKETS_DIR"

if [[ -d "$HOME_MARKET/.git" ]]; then
  printf 'Already at %s, fetching.\n' "$HOME_MARKET"
  git -C "$HOME_MARKET" fetch --quiet origin "$BRANCH" || die "fetch failed"
  git -C "$HOME_MARKET" merge --ff-only "origin/$BRANCH" --quiet ||
    printf '%s local commits here, leaving them alone\n' "$(yellow WARN)"
else
  [[ -e $HOME_MARKET ]] && die "$HOME_MARKET exists and is not a git checkout"
  git clone --quiet --branch "$BRANCH" "$REPO_URL" "$HOME_MARKET" || die "clone failed"
  printf 'Cloned into %s\n' "$HOME_MARKET"
fi

[[ -f "$HOME_MARKET/registry.json" ]] ||
  die "$HOME_MARKET has no registry.json, so it is not a marketplace"

# ---------------------------------------------------------------- the command

step "Installing bo"
mkdir -p "$BIN_DIR"

if [[ -e "$BIN_DIR/bo" && ! -L "$BIN_DIR/bo" ]]; then
  mv "$BIN_DIR/bo" "$BIN_DIR/bo.before-bo.$(date +%s)"
  printf '%s moved an existing bo out of the way\n' "$(yellow WARN)"
fi

ln -sf "$HOME_MARKET/bo" "$BIN_DIR/bo"
printf 'bo -> %s\n' "$HOME_MARKET/bo"

case ":$PATH:" in
*":$BIN_DIR:"*) ;;
*)
  printf '\n%s %s is not on your PATH. Add this to your shell rc:\n' "$(yellow WARN)" "$BIN_DIR"
  printf '  export PATH="%s:$PATH"\n' "$BIN_DIR"
  ;;
esac

# ---------------------------------------------------------------- pick

step "Choosing units"
if command -v gum >/dev/null && [[ -t 0 ]]; then
  "$BIN_DIR/bo" add
else
  # Piping this script through bash leaves stdin on the pipe, so an interactive
  # picker would read the rest of the script as keystrokes. Say what to run.
  printf 'Run %s when you are ready to pick.\n' "$(bold 'bo add')"
fi

# ---------------------------------------------------------------- done

step "Done"
"$BIN_DIR/bo" version
printf '\n'
printf '  %s   everything available\n' "$(bold 'bo list')"
printf '  %s    turn units on\n' "$(bold 'bo add')"
printf '  %s what is on, and any key conflicts\n' "$(bold 'bo status')"
printf '  %s add someone else%ss marketplace\n' "$(bold 'bo market add <git-url>')" "'"
printf '\n%s\n' "$(green 'Welcome.')"
