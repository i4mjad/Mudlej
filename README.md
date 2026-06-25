<div align="center">

<img src="docs/icon.png" alt="Mudlej icon" width="160" />

# Mudlej (مُدْلِج)

**A menu-bar-only macOS app that keeps your Mac awake while AI coding agents run** —
so long overnight tasks aren't cut short when you step away.

</div>

## What "مدلج" means

The Arabic root **د‑ل‑ج** means to journey through the night — *الإدلاج / الدُّلجة*
is travel in the dark, especially the final push before dawn. A **مُدْلِج** is one
who travels by night. While you sleep, your Mac keeps *journeying through the
night* so the agents reach their destination by morning. The machine is the مدلج.

## What it does

Mudlej lives in the menu bar (next to Control Center) — no Dock icon, no window.
It holds off **idle system sleep** using
`ProcessInfo.processInfo.beginActivity(...)` and releases it when it's no longer
needed. The menu-bar glyph reflects state:

- 🥷 — awake, holding sleep off (journeying)
- `moon.zzz` — idle, the Mac is free to sleep

### Three modes

- **Auto** (default) — every ~5 s it checks for running agents and holds sleep
  off only while at least one is detected.
- **Keep awake** — sleep is always held off, regardless of detection.
- **Allow sleep** — sleep is never held off.

### Toggles

- **Keep display awake too** — also blocks display sleep.
- **Keep awake with lid closed** — see below.
- **Launch at login** — start Mudlej automatically.

### Keeping awake with the lid closed

A power assertion (`beginActivity`) only blocks **idle** sleep. Closing a laptop
lid triggers a separate **clamshell sleep** path that ignores all power
assertions — the only software override is `pmset disablesleep`, which needs root.

The **Keep awake with lid closed** toggle runs that command via the native macOS
admin prompt (no background daemon, no extra install). Because `disablesleep` is
a **system-wide, persistent** setting, Mudlej:

- prompts again to restore normal sleep when you turn the toggle off or quit, and
- shows a ⚠️ warning in the menu the whole time it's active.

> [!WARNING]
> While this toggle is on, your Mac will not sleep at all — even on battery.
> If Mudlej is force-quit or crashes while it's enabled, sleep stays disabled;
> just relaunch and turn the toggle off (or run `sudo pmset -a disablesleep 0`)
> to restore it.

### Language

The UI is localized in **English** and **Arabic** (a `Localizable.xcstrings`
String Catalog). It follows the system language by default. Open **About Mudlej**
from the menu to switch between *System / English / العربية* on the fly — the
menu and About panel re-render in the chosen language (Arabic also flips the
About layout to right-to-left). The choice is persisted.

## Build & run

Requires **macOS 14+** and Xcode.

```sh
open Mudlej.xcodeproj      # then press Run
# or from the command line:
xcodebuild -project Mudlej.xcodeproj -scheme Mudlej -configuration Debug build
```

After launch, look for the glyph in the menu bar — there is intentionally no Dock
icon and no window.

## Setup notes (why it's configured this way)

- **`LSUIElement = YES`** (Application is agent) — makes it menu-bar-only: no
  Dock icon, no main window. Set as the `INFOPLIST_KEY_LSUIElement` build setting.
- **App Sandbox is OFF.** Agent detection shells out to `/bin/ps`, and the
  lid-close toggle runs `pmset` with admin privileges — both blocked by the
  sandbox. This is a personal tool (not App Store), so `ENABLE_APP_SANDBOX` is
  `NO`. The manual **Keep awake** / **Allow sleep** modes work even if detection
  is unavailable.

## Customizing the detected agents

Detection lowercases the output of `ps -Axo comm=` and substring-matches it
against a pattern list. The defaults are `claude`, `codex`, `cursor-agent`,
`aider`. To change them without rebuilding, edit the `AgentPatterns` default and
relaunch:

```sh
defaults write com.amjadkhalfan.Mudlej AgentPatterns -array claude codex cursor-agent aider mytool
```

To find the exact string for your tool, run this **while the agent is active**
and look for its process name:

```sh
ps -Axo comm=
```

## Caveats

1. **Lid-close sleep needs the toggle (and a password).** Without **Keep awake
   with lid closed** enabled, closing a laptop lid still sleeps the Mac. With it
   enabled, sleep is disabled system-wide until you turn it off — read the
   warning above.

2. **Detection is a substring match.** It can false-positive (an unrelated
   process with `codex` in its name) or false-negative (an agent running under a
   `node` or other wrapper, so `comm` shows the wrapper, not the agent). If your
   agent isn't detected, run `ps -Axo comm=` while it's active to find the real
   string and add it to the patterns list (above).

## License

[MIT](LICENSE)
