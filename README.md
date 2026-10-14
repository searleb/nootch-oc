<div align="center">

<a href="https://www.patreon.com/loficafe">
  <img src=".github/assets/patreon-banner.svg" alt="PATRON ME FOR GOD'S SAKE — i deserve some freaking pennies" width="100%">
</a>

<br>

<a href="https://www.patreon.com/loficafe">
  <img src="https://img.shields.io/badge/%F0%9F%92%B8%20BECOME%20A%20PATRON-NOW-ff424d?style=for-the-badge&logo=patreon&logoColor=white&labelColor=1a0033" alt="Become a patron" height="42">
</a>

<br><br>

### 🌈 𝗣 𝗔 𝗧 𝗥 𝗢 𝗡 　 𝗠 𝗘 　 𝗙 𝗢 𝗥 　 𝗚 𝗢 𝗗 ' 𝗦 　 𝗦 𝗔 𝗞 𝗘 🌈

**🟥🟧🟨🟩🟦🟪 ⟪ 𝒾 𝒹𝑒𝓈𝑒𝓇𝓋𝑒 𝓈𝑜𝓂𝑒 𝒻𝓇𝑒𝒶𝓀𝒾𝓃𝑔 𝓅𝑒𝓃𝓃𝒾𝑒𝓈 ⟫ 🟪🟦🟩🟨🟧🟥**

`░▒▓█` &nbsp; ⓣⓗⓘⓢ ⓐⓟⓟ ⓘⓢ ⓕⓡⓔⓔ · ⓣⓗⓔ ⓓⓔⓥ ⓘⓢ ⓝⓞⓣ &nbsp; `█▓▒░`

🪙 💸 🪙 💰 🪙 💸 🪙 💰 🪙 💸 🪙 💰 🪙 💸 🪙

**[→ 𝚙𝚊𝚝𝚛𝚎𝚘𝚗.𝚌𝚘𝚖/𝚕𝚘𝚏𝚒𝚌𝚊𝚏𝚎 ←](https://www.patreon.com/loficafe)**

<sub>every single penny keeps the notch alive. no pressure. (lots of pressure.)</sub>

<br>

---

<br>

# NotchNook

**Your MacBook notch is a black rectangle doing nothing. NotchNook gives it a job.**

[![License: Noncommercial, source-only](https://img.shields.io/badge/license-noncommercial%20%C2%B7%20source--only-a64dff?style=flat-square)](LICENSE.md)
![macOS](https://img.shields.io/badge/macOS-14.4%2B-000000?style=flat-square&logo=apple&logoColor=white)
![Swift](https://img.shields.io/badge/Swift-SwiftUI%20%2B%20AppKit-F05138?style=flat-square&logo=swift&logoColor=white)
[![Patreon](https://img.shields.io/badge/Patreon-loficafe-ff424d?style=flat-square&logo=patreon&logoColor=white)](https://www.patreon.com/loficafe)

</div>

> [!TIP]
> ### 🚀 Meet [Nootch](https://lo.fi/nootch), the successor
> **[Nootch](https://lo.fi/nootch)** is NotchNook's commercial and spiritual successor. If you just want a polished notch app that keeps getting updates, get it at **[lo.fi/nootch](https://lo.fi/nootch)**.
> This repo stays here as the open-source original, for tinkering, learning, and building for yourself.

---

## ✨ What it does

NotchNook draws an interactive UI around the MacBook notch. Hover over it and **the Nook** expands into a strip of widgets:

| | Widget | |
|---|---|---|
| 🎵 | **Media Player** | Now playing, album art, and playback controls for any media source |
| 📅 | **Calendar** | Upcoming events with a smooth, scrollable day strip |
| 📝 | **Notes** | Rich-text notes, right in the notch |
| ✅ | **Todos** | A quick checklist that stays out of the way |
| ⏱️ | **Timer** | Scroll-wheel timer with haptics and a Liquid Glass pill |
| 🪞 | **Mirror** | A one-tap camera mirror before that call |
| ⚡ | **Shortcuts** | Run your macOS Shortcuts from the notch |

It also has:

- 📥 **The Tray**: drag files onto the notch to park them, then drag them out later.
- 🎯 **Drop area**: a target for files in transit.
- 🔴 **Live activities**: battery, Bluetooth, and media indicators next to the notch.
- 🖥️ **Multi-display support**: one notch per screen, rebuilt on the fly when displays change.
- 🌍 **Localization**, crowdsourced through Crowdin.

## 🛠️ Building from source

**Requirements:** macOS 14.4+, Xcode with the macOS 26 SDK (for the Liquid Glass code paths).

```sh
git clone https://github.com/lo-cafe/nootch-oc.git
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

Release tooling (signing, notarization, appcast) lives in [`scripts/`](scripts/README.md). You'll need your own Developer ID certificate.

## 🧠 Architecture, briefly

- **AppKit-hosted, SwiftUI-rendered.** `WindowsManager` owns one borderless, transparent window per screen. Each window roots a `RootView` → `NotchView`.
- **Settings live in [`Defaults`](https://github.com/sindresorhus/Defaults).** Each settings group is one `Codable` struct in `extensions/Defaults.swift`. `RootView` injects every group into the SwiftUI environment.
- **Widget data** (notes, todos) is stored with **SwiftData** in one shared `ModelContainer`.
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
You **can't** distribute compiled builds (`.app`, `.dmg`, `.zip`, release assets, mirrors, anything), free or paid. Only [lo.cafe](https://lo.cafe) ships official builds.
Linking to official builds is fine. That includes package managers like Homebrew, as long as they download the official release.

Want a ready-to-run app instead? Get **[Nootch](https://lo.fi/nootch)**.

Commercial licensing: contact [lo.cafe](https://lo.cafe).

<div align="center">

<br>

---

### 🙏 Made it this far? You know what to do.

<a href="https://www.patreon.com/loficafe">
  <img src="https://img.shields.io/badge/%E2%98%95%20FUND%20THE%20NOTCH-patreon.com%2Floficafe-ff424d?style=for-the-badge&logo=patreon&logoColor=white&labelColor=05001a" alt="Fund the notch" height="36">
</a>

<sub>Made with ☕ and questionable amounts of private API by <a href="https://lo.cafe">lo.cafe</a></sub>

</div>
