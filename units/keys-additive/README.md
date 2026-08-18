# keys-additive

One of three units that decide what opens OmaCast. Exactly one at a time: each
names the other two in `conflicts`, so `bo` refuses the second.

The one that changes nothing. `Super+Shift+K` opens OmaCast and every Omarchy
default survives, including the keybindings cheatsheet on `Super+K`.

Start here if you are not sure. Switching later is two commands:

```bash
bo remove keys-additive && bo add keys-balanced
```

| Key | Before | After |
|---|---|---|
| `Super+Shift+K` | free | OmaCast |
| everything else | | unchanged |
