# cpu-meter

CPU load in the bar. Click it to open btop.

Omarchy ships no CPU widget, and `omarchy.monitor` is displays rather than load,
so this fills a real gap rather than duplicating one.

## How it reads the number

`/proc/stat`'s aggregate line, sampled every 5 seconds. A percentage of CPU
time needs two readings and the difference between them, so the first tick after
the shell starts shows nothing until the second arrives.

The number lives in the tooltip rather than the bar, and the bar shows a chip
glyph. A percentage that changes every five seconds is noise in the corner of
your eye; the icon tells you it is there and hovering tells you the number.

## Changing it

`plugin/Cpu.qml`. The interval is the `Timer` near the bottom. Saving reloads
the plugin, but QML changes want a full `omarchy restart shell` to be certain.

Move it in the bar with `omarchy bar move bo.cpu-meter --section right`.
