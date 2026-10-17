# Iart Cheat Dock

An always-on-top cheat sheet panel that docks to the edge of your Windows screen. Tabs for **Claude Code**, **Windows**, **Revit** and **Excel**, a global hotkey to show/hide it, search across all sheets, and click-to-copy.

No install, no compiler: it runs on the Windows PowerShell 5.1 + WPF that ship with Windows 10/11.

## Quick start

1. Download or clone this repo into a folder, e.g. `C:\Tools\CheatDock`.
2. Double-click **`Start-CheatDock.cmd`**.

A slim strip appears on the right edge of the screen (**CC / WIN / RVT / XLS**) plus a tray icon. Click a strip button to slide the panel open on that tab.

If nothing appears, right-click each file → **Properties** → tick **Unblock** (Windows blocks downloaded scripts), then try again.

### Start with Windows

```powershell
powershell -ExecutionPolicy Bypass -File .\CheatDock.ps1 -Install     # Start menu + Startup shortcut
powershell -ExecutionPolicy Bypass -File .\CheatDock.ps1 -Uninstall   # remove them
```

## Controls

| Where | Key / action | What it does |
|---|---|---|
| Anywhere | `Ctrl+Alt+Space` | Expand / collapse (cursor lands in search) |
| Anywhere | `Ctrl+Alt+Shift+1..9` | Jump straight to tab N |
| Anywhere | `Ctrl+Alt+Shift+H` | Hide / show the whole dock |
| Panel | `Ctrl+Tab` / `Ctrl+Shift+Tab` | Next / previous tab |
| Panel | `Ctrl+1..9` | Tab N |
| Panel | `Ctrl+F` | Search all sheets |
| Panel | `Esc` | Clear search, then collapse |
| Panel | Click a row | Copy the shortcut / command to the clipboard |

The panel auto-collapses when you click into another app; press the pin button to keep it open. Header buttons: pin, transparency, switch side, next monitor, open sheets folder, reload, exit. The tray icon has the same actions.

`Ctrl+Alt+digit` is deliberately avoided: on Italian, German and many other layouts it is AltGr, needed for `[ ] { }`.

## Editing the cheat sheets

On first run the app writes the built-in sheets to `sheets\`:

```
sheets\01-claude-code.json
sheets\02-windows.json
sheets\03-revit.json
sheets\04-excel.json
```

Edit them, or add new ones (e.g. `05-dynamo.json`), then press **Reload**. File name order is tab order. Format:

```json
{
  "title": "Dynamo",
  "short": "DYN",
  "sections": [
    { "name": "Canvas", "items": [
      { "k": "Ctrl+G", "d": "Group nodes" },
      { "k": "Ctrl+L", "d": "Auto-layout graph" }
    ]}
  ]
}
```

`short` is the label on the edge strip (keep it to about 3 characters).

## Settings

Window state is saved in `cheatdock.settings.json` next to the script (created on first run). You can edit it while the app is closed:

| Key | Default | Meaning |
|---|---|---|
| `Side` | `Right` | `Right` or `Left` |
| `Monitor` | `0` | `0` = primary, `1..N` = specific monitor |
| `PanelWidth` | `440` | Panel width in px |
| `KeyColumnWidth` | `165` | Width of the shortcut column |
| `FontSize` | `12.5` | Row text size |
| `Opacity` | `0.97` | Window opacity |
| `AutoCollapse` | `true` | Collapse when another app gets focus |
| `HotkeyToggle` | `Ctrl+Alt+Space` | Global expand/collapse |
| `HotkeyHide` | `Ctrl+Alt+Shift+H` | Global hide/show |
| `HotkeyTabs` | `Ctrl+Alt+Shift` | Modifier for tab hotkeys (+1..9) |

If a hotkey is already taken by another app, the panel footer says so; change it here.

## Troubleshooting

Run it with a visible console to see any error:

```powershell
powershell -STA -ExecutionPolicy Bypass -File .\CheatDock.ps1
```

Only one instance runs at a time; check the tray (including the `^` overflow) if it seems not to start.

## Notes

- Claude Code shortcuts follow the official docs as of October 2026; the tool changes often, so check `/help` in Claude Code.
- Revit entries are the default keyboard shortcuts. If yours are customized, type `KS` in Revit to see them.
