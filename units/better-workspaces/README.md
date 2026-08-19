# better-workspaces

Workspace names in the bar instead of numbers, the empty ones out of the way,
and a way to reach a fresh one.

`Super+F2` renames the workspace you are on, or right-click any of them.
`Super+=` goes to the first free workspace, which the `+` in the bar also does.

A workspace you have finished with leaves. Nothing running on it and you are
not on it, so after five seconds it fades out of the bar and its name goes back
to being a number. Quitting everything on "spotify" and going back to "coding"
leaves a free workspace behind, not a label pointing at nothing.

Leaving and being renamed are the same event. `releaseEmptyNames` turns the
whole thing off if you would rather names stayed.

## Settings

| | | |
|---|---|---|
| `hideEmpty` | `true` | draw only workspaces that have a window, a name, or your attention |
| `showNewButton` | `true` | the trailing `+` |
| `releaseEmptyNames` | `true` | give the name back when the workspace leaves |
| `releaseAfterMs` | `5000` | how long after it goes quiet |
| `emptyLingerMs` | `5000` | how long an emptied workspace stays in the row |
| `leaveMs` | `260` | the fade as it goes |
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
