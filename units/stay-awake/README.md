# stay-awake

Never lock or start the screensaver on idle.

## How

It sets Omarchy's own stay-awake flag rather than zeroing `idle.lock` in
`shell.json`. That matters: the flag is what `Super+Ctrl+I` toggles and what the
bar indicator reads, so both keep working. Zeroing the timeout would have left
the toggle switching between two settings that both did nothing.

The flag lives at `~/.local/state/omarchy/indicators/stay-awake`.

## Turning it back on for a while

`Super+Ctrl+I`, or `omarchy toggle idle allow-idle`. Removing the unit does the
same thing permanently: `revert.sh` puts idle back.
