-- US international with AltGr dead keys, for Portuguese accents on a US board.
-- Plain typing is unchanged: ' and " do not wait for a second key.
--
-- Omarchy already sets repeat_rate 40, repeat_delay 250, numlock_by_default,
-- clickfinger_behavior and scroll_factor 0.4, so only the variant is set here.

hl.config({
  input = {
    kb_variant = "altgr-intl",
  },
})
