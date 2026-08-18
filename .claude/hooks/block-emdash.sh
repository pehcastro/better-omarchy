#!/bin/sh
# PreToolUse hook. It blocks a Write or an Edit whose input holds an em dash (U+2014).
#
# This is the POSIX form of block-emdash.ps1. The two scripts do the same job, and a host
# runs whichever one it can. `.claude/settings.json` names the one this machine uses. On a
# Windows host with no `sh` on the path, point that command back at the `.ps1` file.
#
# The test compares raw bytes. `LC_ALL=C` stops grep from decoding the input into
# characters, so the three UTF-8 bytes of U+2014 match whatever the locale of the host is.
# Do not replace this test with a tool that decodes the input first. `.githooks/commit-msg`
# carries the same rule and the same reason.

emdash=$(printf '\342\200\224')

if LC_ALL=C grep -qF "$emdash"; then
    printf '%s\n' "BLOCKED: an em dash (U+2014) is forbidden in this repository. Use a comma, a colon, a period, parentheses, or a plain hyphen." >&2
    exit 2
fi

exit 0
