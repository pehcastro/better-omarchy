#!/bin/bash
# Omarchy's stay-awake flag, rather than zeroing idle.lock in shell.json, so the
# SUPER+CTRL+I toggle and the bar indicator keep working.
set -euo pipefail
omarchy toggle idle stay-awake >/dev/null
