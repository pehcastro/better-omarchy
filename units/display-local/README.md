# display-local

Monitor layout is the one thing that cannot be shared: the same file on another
machine is wrong. So this unit ships an example and nothing else.

```bash
cd units/display-local/hypr
cp monitors.lua.example monitors.lua
$EDITOR monitors.lua
bo add display-local
```

`monitors.lua` is gitignored. `bo add` links whatever `.lua` it finds, so the
example alone links nothing.
