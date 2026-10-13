<div align="center">
  <img src="Assets/Branding/WineShelf-Logo-2026.png" width="104" alt="WineShelf app icon">
  <h1>WineShelf</h1>
  <p><strong>Your Windows game library, ready for macOS.</strong><br>Set up Wine and Steam, organize game prefixes, and launch your Windows apps from one place.</p>
  <p>
    <a href="https://github.com/lAmirshahinxl/WineShelf/releases/latest"><img src="https://img.shields.io/github/v/release/lAmirshahinxl/WineShelf?display_name=tag&label=latest%20release&style=flat-square&color=00cbd4" alt="Latest release"></a>
    <a href="LICENSE"><img src="https://img.shields.io/github/license/lAmirshahinxl/WineShelf?style=flat-square&color=081b3a" alt="MIT License"></a>
    <img src="https://img.shields.io/badge/macOS-14%2B-081b3a?style=flat-square&logo=apple&logoColor=white" alt="macOS 14 or later">
    <img src="https://img.shields.io/badge/app-universal-081b3a?style=flat-square" alt="Universal arm64 and x86_64 app">
    <img src="https://img.shields.io/badge/Swift-6-F05138?style=flat-square&logo=swift&logoColor=white" alt="Built with Swift 6">
  </p>
  <p><a href="https://github.com/lAmirshahinxl/WineShelf/releases/latest"><img src="https://img.shields.io/badge/Download-Latest%20DMG-00cbd4?style=for-the-badge&logo=apple&logoColor=white&labelColor=081b3a" alt="Download latest DMG"></a></p>
  <p><a href="https://github.com/lAmirshahinxl/WineShelf/issues">💬 Issues and feedback</a></p>
  <img src="Assets/Branding/WineShelf-README.png" width="100%" alt="WineShelf game library and controller illustration">
</div>

WineShelf is a native macOS app for managing Wine runtimes, Steam, Windows games, and game prefixes.

## ✨ Features

| | Feature | What it does |
| --- | --- | --- |
| 🍷 | Managed Wine setup | Checks requirements, downloads a pinned Wine build, and verifies its SHA-256 digest. |
| 🎮 | Game Profiles | Browse edition-specific guides based on the WineShelf website catalog, grouped by native Mac support and Steam popularity with storefront, account, requirements, and setup information. |
| 🚀 | **Run a Windows `.exe` directly** | **Choose or drag an executable into WineShelf; it prepares a Wine prefix, launches the file, and saves it in your library.** |
| 📚 | One game library | Keeps Steam game shortcuts and Windows apps together with their Wine prefixes and settings. |
| 🧰 | Session controls | Start or stop Wine sessions, open logs, and reveal app and prefix files in Finder. |

## 🖥️ Supported platforms

| Mac | WineShelf app | Managed Wine runtime | Notes |
| --- | --- | --- | --- |
| Intel Mac · macOS 14 or later | Native x86_64 | x86_64, native | Rosetta is not needed. |
| Apple silicon · macOS 14 or later | Native arm64 | x86_64 through Rosetta 2 | Install Rosetta before using the managed Wine runtime. |
| Windows or Linux | Not supported | — | WineShelf is a native macOS app. |

The released app is a universal arm64 and x86_64 build. The managed Wine build is x86_64. Game compatibility and performance vary by title, Wine behavior, graphics settings, and game-specific protections; not every game will run.

## 🎮 Steam game FPS reports

These are short community reports from Wine-based setups, mostly CrossOver. They are not WineShelf benchmarks, so actual results in WineShelf can differ. Settings and conditions vary; the sources provide context.

| Game / Mac | FPS reported | Other useful info |
| --- | ---: | --- |
| Counter-Strike 2 · M2 MacBook Air | 30–40 FPS in one report; about 100 FPS in another | Separate community reports: [30–40 FPS](https://www.reddit.com/r/macgaming/comments/1wd02i4/cs2_on_mac/) · [about 100 FPS, 8 GB](https://www.reddit.com/r/cs2/comments/1wsc8hk/how_rare_is_this/) |
| Counter-Strike 2 · 14-inch MacBook Pro, M1 Pro, 16 GB | 75–115 FPS | CrossOver: [report](https://www.reddit.com/r/macgaming/comments/1waxdn9/cs2_crossover_inconsistent_frame_times/) |
| Counter-Strike 2 · Base M4 Mac mini | 90–120 FPS | CrossOver + CXPatcher: [report](https://www.reddit.com/r/macgaming/comments/1tni5zl/m4_mac_mini_base_crossover_patched/) |
| Counter-Strike 2 · MacBook Pro, M2 Pro, 32 GB | About 128 FPS | Wine + DXMT: [benchmark](https://github.com/piwas-21/cs2-apple-silicon/blob/main/docs/project/measured-results.md) |
| Grand Theft Auto V (Legacy) · M1 MacBook Air, 8 GB | 70–80 FPS | Steam + CrossOver 23.7, custom DXVK: [report](https://www.reddit.com/r/macgaming/comments/1anh0gd/stutter_on_gta_v_crossover_macbook_m1_8gb/) |
| The Witcher 3 · M1 MacBook Air, 8 GB | 40–60 FPS | Steam + CrossOver, medium settings: [report](https://applesilicongames.com/games/GdnUQRXMTXJshNj2xHHPq3/witcher-3) |
| Elden Ring · Base M4 Mac mini, 16 GB | 50–60 FPS | CrossOver + D3DMetal: [reports](https://macgamingdb.app/games/elden-ring) |

Online play, anti-cheat, launchers, and individual game updates can affect whether a title works at all. Check a game's current compatibility before buying it for Wine.

## 📦 Download and install

1. Download the latest `.dmg` from [GitHub Releases](https://github.com/lAmirshahinxl/WineShelf/releases).
2. Open the disk image and drag `WineShelf.app` to the Applications shortcut.
3. If macOS blocks the first launch, Control-click `WineShelf.app` in Finder, choose **Open**, and confirm the prompt.

The app is ad-hoc signed and is not notarized by Apple, so macOS may require this one-time approval.

## 🍷 Set up Wine and Steam

Open **Wine Setup** and WineShelf starts checking this Mac automatically. It detects installed components, downloads and verifies missing Wine support, and continues when you return from the required macOS steps.

| Requirement | WineShelf action |
| --- | --- |
| Rosetta 2 | On Apple silicon, WineShelf opens Terminal with the install command ready. Run it and accept Apple's license. |
| GStreamer | WineShelf downloads the official package, checks its SHA-256 digest, and opens Apple's Installer. Complete the installer; it may ask for an administrator password. |
| Wine | WineShelf downloads the pinned x86_64 build, verifies its SHA-256 digest, and installs it under `~/Library/Application Support/WineShelf/Runtimes/`. |
| macOS approval | If Gatekeeper asks, WineShelf opens the runtime in Finder. Control-click it, choose **Open**, confirm, then continue in WineShelf. |
| Steam | Downloads Valve's official Steam Setup and installs it into a separate Wine prefix. Sign in and install games inside Steam. |

WineShelf begins setup when you open this screen and resumes after Rosetta or GStreamer is installed. Apple still requires you to accept Rosetta's license, complete the GStreamer installer, and approve Wine in Finder if Gatekeeper prompts.

## ➕ Add Windows apps

**Run a Windows `.exe` directly:** choose **Run Windows .exe…** from the **+** menu or drag an `.exe` onto the WineShelf window. WineShelf prepares a fresh prefix, launches the file, and adds it to your library. If Wine is not ready, WineShelf opens Wine Setup first.

For custom configurations, choose **Add Windows App** and select the executable, an initialized Wine prefix (the folder containing `system.reg`), and the `wine` and `wineserver` binaries. WineShelf can discover Wine runtimes in common install locations.

## 🎮 Browse game profiles

Choose **Game Profiles** in the sidebar to browse the game catalog published on [wineshelf.site](https://wineshelf.site/games/). WineShelf downloads the profile list from the website when you open the page and keeps its included profiles available when you are offline. WineShelf groups games without a native macOS version first, then popular Steam games with native Mac versions. Select a title to see its supported edition, storefronts, account requirements, system requirements, known limitations, and setup guide.

For Steam games, WineShelf opens the title's store page inside its Wine Steam prefix so you can check edition access and start the install. After Steam confirms the game is fully installed, WineShelf adds a launch shortcut to your library. If you close Steam before the download finishes, the game stays pending and does not appear as installed. **WineShelf does not guarantee compatibility:** game-specific launchers, anti-cheat, DRM, Wine, and Mac hardware affect whether a game runs.

## 🗂️ Library data and Wine sessions

WineShelf stores the library and logs here:

```text
~/Library/Application Support/WineShelf/
```

Removing an entry only removes its shortcut from WineShelf; it leaves game files, prefixes, and runtimes on disk. **Stop Wine** sends `wineserver -k` to that entry's prefix, which closes every Wine app sharing that prefix.

## 🛠️ Build from source

Requirements: macOS 14 or later and Xcode Command Line Tools with Swift 6.

```sh
./build-app.sh
```

The build script creates a universal `WineShelf.app`, generates the macOS icon from `Assets/Branding/WineShelf-Logo-2026.png`, and packages it with an Applications shortcut:

```text
dist/WineShelf-0.5.1-universal.dmg
```

Local builds are ad-hoc signed by default. For direct distribution, sign with a **Developer ID Application** identity and notarize the app and disk image with Apple's notary service. Set `CODESIGN_IDENTITY` to the identity's full name to enable hardened runtime and secure timestamps.

Website assets are in [`Assets/Branding/`](Assets/Branding/): the app logo, README banner, 512 px and 192 px icons, Apple touch icon, and 32 px favicon.

## 🔗 Runtime sources

| Component | Source | How WineShelf uses it |
| --- | --- | --- |
| Wine | [Gcenx macOS Wine builds](https://github.com/Gcenx/macOS_Wine_builds/releases) | Pinned x86_64 runtime; the version and digest are maintained in `RuntimeSetupModel.swift`. |
| GStreamer | [Official macOS downloads](https://gstreamer.freedesktop.org/download/) | Pinned runtime package; WineShelf verifies its digest before opening the installer. |
| Steam Setup | [Valve](https://store.steampowered.com/about/) | Downloaded from Valve's official site when the user chooses to install Steam. |

WineShelf does not bundle Wine, GStreamer, Steam, game files, or game licenses. Users are responsible for owning their games and following each software's license terms.

## 📄 License

WineShelf is licensed under the [MIT License](LICENSE). This license applies to the WineShelf project; Wine, GStreamer, Steam, and games remain under their own licenses.
