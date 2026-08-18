# accents

Types accented characters on a US keyboard, with AltGr.

```
AltGr + a         á        AltGr + n         ñ
AltGr + `  then a à        AltGr + Shift + 6 then a  â
AltGr + Shift + '  then a  ä
```

Plain typing does not change. `'` and `"` still produce a quote straight away,
with no wait for a second key, which is the thing that makes most international
layouts unbearable to write code in.

Two that catch people out: `AltGr + c` is ©, not ç. For ç use the dead cedilla,
`AltGr + Shift + 5` then `c`. And CapsLock is the Compose key, which is
Omarchy's default, not something this unit does.

## What it sets

`kb_variant = altgr-intl` in `hypr/input.lua`. Nothing else: Omarchy already
sets repeat rate, repeat delay, numlock and the touchpad behaviour, so this
would only be restating them.

## Changing it

Edit `hypr/input.lua` in this unit and save. Hyprland reloads on its own.
`hyprctl getoption input:kb_variant` says what is live.
