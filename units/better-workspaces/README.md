# better-workspaces

Workspace names in the bar instead of numbers, the empty ones out of the way,
and a way to reach a fresh one.

`Super+F2` renames the workspace you are on, or right-click any of them.
`Super+F3` goes to the first free workspace, which the `+` in the bar also does.

An empty, unnamed workspace is not drawn: a row of numbers standing in for
nothing is the reason names used to be cut short. A name is released when its
workspace has been used, emptied, and left for a while, so quitting everything
on "spotify" and going back to "coding" leaves a free workspace behind rather
than a label pointing at nothing. A name on a workspace you have not opened yet
is left alone.

## Settings

| | | |
|---|---|---|
| `hideEmpty` | `true` | draw only workspaces that have a window, a name, or your attention |
| `showNewButton` | `true` | the trailing `+` |
| `releaseEmptyNames` | `true` | drop a name once its workspace is finished with |
| `releaseAfterMs` | `45000` | how long after it empties |
| `maxLabelChars` | `18` | a ceiling, not a fixed width; the real width is measured against the bar |
| `labelShare` | `0.50` | how much of the bar the names may take before what is centred in it |

## Using it

`Super+F2` opens a panel under the workspace you are on. Type a name, press
Enter. Right-clicking any workspace in the bar opens the same panel for that
one.

The "keep number" switch decides between `coding` and `coding (2)`. Leaving the
box empty puts that workspace back to its number.

Names longer than 18 characters are cut with an ellipsis, and the full name
stays in the tooltip.

## Where the names live

In this widget's own entry in `~/.config/omarchy/shell.json`:

```json
{ "id": "bo.better-workspaces",
  "names": { "2": { "label": "coding", "keepNumber": true } } }
```

Not in a Hyprland config file, so renaming needs no reload. The widget also
renames the Hyprland workspace to match, so `hyprctl workspaces` agrees with
what you see.

Run `bo sync` after renaming to pull the change back into the checkout.

## Changing it

`plugin/Workspaces.qml`. Active is marked by opacity rather than weight, because
`WidgetButton` exposes no font-weight property and cannot elide either, which is
also why the truncation happens in JS.
