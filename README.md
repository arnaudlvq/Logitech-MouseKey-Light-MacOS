# mousekeys

Mouse buttons → Ctrl+Up/Left/Right (Mission Control, Spaces). Ctrl+Down is not mapped. ~4 MB RAM, 0% CPU when idle.

## Install

```bash
xcode-select --install   # once, only if Swift is missing
./install.sh             # builds, installs to ~/.local/bin, starts now and at every login
```

## Permission

macOS asks on its own a few seconds after install: allow it, and mousekeys starts within 10 s.
If no prompt shows (or after a reinstall it stays off): System Settings → Privacy & Security →
**Accessibility**, remove the old `mousekeys` entry (**−**), then **+** → Cmd+Shift+G → `~/.local/bin/mousekeys`.

## Mapping

`~/.config/mousekeys.conf`, one `input action` per line:

```
button4 up
hscroll+ left
hscroll- right
```

Inputs: `button2` middle, `button3` back, `button4` forward, `hscroll+`/`hscroll-` wheel tilt.
Actions: `up`, `left`, `right` (`down` is ignored).

Or record it by pressing the buttons (for Up, Left, Right, in that order):

```bash
~/.local/bin/mousekeys learn
```

## Commands

```bash
launchctl kickstart -k gui/$(id -u)/local.mousekeys   # restart (after editing the mapping)
launchctl bootout gui/$(id -u)/local.mousekeys        # stop
cat /tmp/mousekeys.log                                # "Active: 3 inputs mapped" = working
```

## Uninstall

```bash
launchctl bootout gui/$(id -u)/local.mousekeys        # stop it (deleting the binary alone doesn't)
rm ~/Library/LaunchAgents/local.mousekeys.plist ~/.local/bin/mousekeys
rm ~/.config/mousekeys.conf                           # optional: your mapping
```

Then System Settings → Privacy & Security → **Accessibility** → select `mousekeys` → **−**.
