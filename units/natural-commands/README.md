# natural-commands

Two Omarchy commands that read better typed than clicked, wired to the
launcher.

```bash
bo add natural-commands
```

## alarm:

A reminder, in the words you would say out loud.

```
alarm:30 minutes and 45 seconds tea is ready
alarm:5m
alarm:1h30m
alarm:90s
alarm:in 2 hours call mum
alarm:half an hour
alarm:                        what is already pending
```

Whatever is left after the duration is the message. `an hour`, `half an hour`
and a bare number (minutes, same as `omarchy reminder`) all work, and `timer:`,
`remind:` and `reminder:` reach the same place.

`omarchy reminder` only takes whole minutes, so anything finer rounds up and the
row says so: `30 minutes and 45 seconds` sets 31 minutes, and the row reads
`Rounded up from 30m 45s`. It rounds up rather than down because an alarm that
fires early is a broken alarm.

The row is the confirmation: the message large, the wall-clock time it will fire
under it. Nothing is set until you press `Enter`.

A bare `alarm:` lists what is pending, with the time each one fires. `Enter` on
one cancels that reminder; the last row clears them all.

## theme:

```
theme:            every theme, the current one first
theme:tokyo       the ones that match
```

`Enter` applies it. Matching ignores spaces and dashes, so `theme:tokyonight`
finds Tokyo Night.
