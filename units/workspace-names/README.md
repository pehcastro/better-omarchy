# workspace-names

Workspace names in the bar instead of numbers, and `Super+F2` to change one.

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
{ "id": "bo.workspace-names",
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
