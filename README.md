<div align="center">

# NotchNook

**Your MacBook notch is a black rectangle doing nothing. NotchNook gives it a job.**

[![License: Noncommercial, source-only](https://img.shields.io/badge/license-noncommercial%20%C2%B7%20source--only-a64dff?style=flat-square)](LICENSE.md)
![macOS](https://img.shields.io/badge/macOS-14.4%2B-000000?style=flat-square&logo=apple&logoColor=white)
![Swift](https://img.shields.io/badge/Swift-SwiftUI%20%2B%20AppKit-F05138?style=flat-square&logo=swift&logoColor=white)

</div>

> [!NOTE]
> This is a personal fork of NotchNook. See [What's changed in this fork](#-whats-changed-in-this-fork) for how it differs from the original.

---

## ✨ What it does

NotchNook draws an interactive UI around the MacBook notch. Hover over it and **the Nook** expands into a strip of widgets:

| | Widget | |
|---|---|---|
| 🎵 | **Media Player** | Now playing, album art, and playback controls for any media source |
| 📅 | **Calendar** | Upcoming events with a smooth, scrollable day strip |
| 📝 | **Notes** | Rich-text notes, right in the notch |
| ✅ | **Todos** | A quick checklist, kept in a "NotchNook" list in Reminders so it syncs to your other devices |
| ⏱️ | **Timer** | Scroll-wheel timer with haptics and a Liquid Glass pill |
| 🪞 | **Mirror** | A one-tap camera mirror before that call |
| ⚡ | **Shortcuts** | Run your macOS Shortcuts from the notch |
| ✳️ | **Claude Usage** | What Claude Code is doing now, plan limits, prompt-cache hit rate, and today's tokens and API value, per account |

It also has:

- 📥 **The Tray**: drag files onto the notch to park them, then drag them out later.
- 🎯 **Drop area**: a target for files in transit.
- 🔴 **Live activities**: battery, Bluetooth, and media indicators next to the notch, plus an animated Claude indicator with a running clock while Claude Code works and a short alert when it finishes.
- 🖥️ **Multi-display support**: one notch per screen, rebuilt on the fly when displays change.
- 🌍 **Localization**, crowdsourced through Crowdin.

## 🔀 What's changed in this fork

**Added**

- **Claude Usage widget.** Follows Claude Code from its local session logs: the turn running now, how long it has run, today's tokens and estimated API value, and the 5-hour and weekly plan limits the Claude desktop app records. Accounts without plan limits (enterprise plans) show the prompt-cache hit rate instead. Separate config folders (for example a `CLAUDE_CONFIG_DIR=~/.claude-personal` alias) show as separate accounts, and sessions from the desktop app's Code tab are counted against the desktop app's account. Subagents count as work. Nothing leaves the Mac, and prompts, replies and tool output are never stored.
- **Claude live activities.** While the widget is in the Nook, the closed notch shows an animated Claude mark and a running clock whenever Claude is working, and a short alert when a turn longer than a set threshold finishes (10 seconds by default). Both take priority over music.
- **To-dos in Reminders.** The to-do widget reads and writes a "NotchNook" list in Reminders, created on first use, so tasks sync through iCloud and survive anything that happens to the app. The star is Reminders' High priority.

**Removed**

- The trial and licence/registration system. The app runs unrestricted.
- The successor promotion, donation banners and links to the original authors' site, community and other apps, both here and in the About settings.

**Known issue**

- Notes are still stored in SwiftData's default location (`~/Library/Application Support/default.store`), which macOS's iCloud Mail agent also uses and can wipe.

## 🛠️ Building from source

**Requirements:** macOS 14.4+, Xcode with the macOS 26 SDK (for the Liquid Glass code paths).

```sh
git clone https://github.com/searleb/nootch-oc.git
cd nootch-oc
open NotchNook.xcodeproj
```

Xcode resolves every Swift package on first open. Select the `NotchNook` scheme and press **Run**.

### Build variants

| Variant | How | Notes |
|---|---|---|
| **Standalone** | Default `Debug` / `Release` | Uses [Sparkle](https://sparkle-project.org) for auto-updates |
| **Setapp** | `SETAPP_BUILD` compilation condition | No Sparkle |

Code that touches updates or the About screen needs to compile under **both** variants (`#if !SETAPP_BUILD`).

> ⚠️ **Check for Updates** still points at the original NotchNook update feed. Installing an update from there replaces this fork with an official build that has none of the changes above.

Release tooling (signing, notarization, appcast) lives in [`scripts/`](scripts/README.md). You'll need your own Developer ID certificate.

## 🧠 Architecture, briefly

- **AppKit-hosted, SwiftUI-rendered.** `WindowsManager` owns one borderless, transparent window per screen. Each window roots a `RootView` → `NotchView`.
- **Settings live in [`Defaults`](https://github.com/sindresorhus/Defaults).** Each settings group is one `Codable` struct in `extensions/Defaults.swift`. `RootView` injects every group into the SwiftUI environment.
- **Widget data**: notes are stored with **SwiftData** in one shared `ModelContainer`; to-dos live in Reminders through **EventKit** (`RemindersTodoStore`).
- **Claude Usage** is a Foundation-only engine under `models/claude/` that tails Claude Code's session logs; `ClaudeUsageStore` polls it and drives the widget and live activities.
- **Widgets** sit on a 50pt grid (`NookGrid`) under `components/Notch/Nook/Widgets/`.
- **Liquid Glass** on macOS 26 uses Apple's private `CABackdropLayer` stack. Older systems fall back to a Metal refraction lens, then to a plain capsule. Every private symbol is resolved at runtime and degrades gracefully instead of crashing.

> ⚠️ NotchNook isn't distributed on the Mac App Store, so it **uses private APIs on purpose**. Don't send PRs that remove them for App Store compliance.

[`CLAUDE.md`](CLAUDE.md) has the full write-up. It's written for AI agents, but it's useful for humans too.

## 🤝 Contributing

PRs are welcome.

1. Fork, branch, and make your change.
2. Make sure it builds. The Xcode build is the source of truth, not editor squiggles.
3. Use `String(localized: "…")` for user-facing strings.
4. Respect `GeneralSettings.disableHaptics` if you add haptics.
5. Open the PR.

Translations go through Crowdin, not PRs to `Localizable.xcstrings`.

## 📜 License

NotchNook is released under the **[NotchNook License](LICENSE.md)**: the PolyForm Noncommercial License 1.0.0 plus a source-only distribution clause.

You **can** read, fork, modify, learn from, and share the **source code** for any noncommercial purpose.
You **can** build it for your own use on your own Macs.
You **can't** sell it or use it commercially in any way.
You **can't** distribute compiled builds (`.app`, `.dmg`, `.zip`, release assets, mirrors, anything), free or paid.
Linking to official builds is fine. That includes package managers like Homebrew, as long as they download the official release.

See [`LICENSE.md`](LICENSE.md) for the full terms, including commercial licensing.
