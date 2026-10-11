<div align="center">
  <img src="Assets/Branding/WineShelf-Logo.png" width="112" alt="WineShelf app icon">
  <h1>WineShelf</h1>
  <p>A native Mac library for Wine runtimes, Windows apps, and games.</p>
  <p><a href="https://github.com/lAmirshahinxl/WineShelf/releases">Download the latest DMG</a> · macOS 14+ · Universal app</p>
  <img src="Assets/Branding/WineShelf-README.png" width="100%" alt="WineShelf game library and controller illustration">
</div>

WineShelf helps you set up Wine and Steam, organize Windows apps, and launch them with their own Wine prefixes. It can also import an existing GameToMac Counter-Strike 2 setup without moving its game files.

## Features

| Feature | What it does |
| --- | --- |
| Managed Wine setup | Checks requirements, downloads a pinned Wine build, and verifies its SHA-256 digest. |
| Steam setup | Downloads Valve's Steam Setup and installs it into a separate Wine prefix. |
| Game library | Adds Windows `.exe` apps with their Wine runtime, prefix, launch arguments, and environment settings. |
| Existing setup import | Finds and imports the supported GameToMac Counter-Strike 2 setup in place. |
| Session controls | Launches and stops Wine sessions, opens logs, and reveals app and prefix files in Finder. |

## Supported platforms

| Mac | WineShelf app | Managed Wine runtime | Notes |
| --- | --- | --- | --- |
| Intel Mac running macOS 14 or later | Native x86_64 | x86_64, native | Rosetta is not needed. |
| Apple silicon Mac running macOS 14 or later | Native arm64 | x86_64 through Rosetta 2 | Install Rosetta before using the managed Wine runtime. |
| Windows or Linux computer | Not supported | — | WineShelf is a native macOS app. |

The released app is a universal arm64 and x86_64 build. The Wine build offered by WineShelf is x86_64. Windows game compatibility varies by title, Wine behavior, graphics settings, and game-specific protections; not every game will run.

## Counter-Strike 2 FPS reports

These are individual community reports, not WineShelf benchmarks. The tests use different wrappers, macOS versions, maps, settings, and measurement methods, so read them as examples rather than a direct ranking or a performance guarantee. Two reports for the M2 MacBook Air show how much results can vary with setup and test conditions.

| Mac | Reported FPS | Test details | Source |
| --- | ---: | --- | --- |
| Base M2 MacBook Air, 8 GB | About 100 FPS; some maps lower | GameToMac; macOS 26.7; user reports Dust and most maps. | [Community report](https://www.reddit.com/r/cs2/comments/1wsc8hk/how_rare_is_this/) |
| M2 MacBook Air, configuration not stated | 30–40 FPS; about 15 ms frame time | GameToMac at the lowest settings. | [Community report](https://www.reddit.com/r/macgaming/comments/1wd02i4/cs2_on_mac/) |
| 14-inch MacBook Pro, M1 Pro, 16 GB | 75–115 FPS online | CrossOver 26.3 with DXMT and MSync; macOS 26.0; 1512 × 945. The user reported 24–32 ms frame times online. | [Community report](https://www.reddit.com/r/macgaming/comments/1waxdn9/cs2_crossover_inconsistent_frame_times/) |
| Base M4 Mac mini | 90–120 FPS | CrossOver with CXPatcher, after a patch; exact settings and test scene were not stated. | [Community report](https://www.reddit.com/r/macgaming/comments/1tni5zl/m4_mac_mini_base_crossover_patched/) |
| MacBook Pro, M2 Pro, 32 GB | 127.9 FPS in a reported 1,000-frame window | Separate Wine + DXMT + MSync setup; Ancient benchmark map, low settings. This uses a different stack from WineShelf's managed Wine build. | [Measured-results project](https://github.com/piwas-21/cs2-apple-silicon) |

Average FPS alone does not describe smoothness. Frame times, map, resolution, graphics settings, FPS cap, game build, wrapper, and heat can all change the result. For a useful report, include your exact Mac chip and memory, macOS version, Wine or CrossOver setup, map, resolution, graphics preset, and both FPS and frame-time readings.

## Download and install

1. Download the latest `.dmg` from [GitHub Releases](https://github.com/lAmirshahinxl/WineShelf/releases).
2. Open the disk image and drag `WineShelf.app` to the Applications shortcut.
3. If macOS blocks the first launch, Control-click `WineShelf.app` in Finder, choose **Open**, and confirm the prompt.

The app is ad-hoc signed and is not notarized by Apple, so macOS may require this one-time approval.

## Set up Wine and Steam

Open **Wine Setup** in WineShelf and follow its status checks:

| Requirement | WineShelf action |
| --- | --- |
| Rosetta 2 | On Apple silicon, WineShelf provides the install command. Run it in Terminal and accept Apple's license. |
| GStreamer | Downloads the official package, checks its SHA-256 digest, then opens Apple's Installer. The installer may ask for an administrator password. |
| Wine | Downloads the pinned x86_64 build, verifies its SHA-256 digest, and installs it under `~/Library/Application Support/WineShelf/Runtimes/`. |
| macOS approval | If Gatekeeper asks, approve the Wine runtime through Finder's **Open** command. WineShelf does not remove quarantine or disable Gatekeeper. |
| Steam | Downloads Valve's official Steam Setup and installs it into a separate Wine prefix. Sign in and install games inside Steam. |

Rosetta requires user acceptance of Apple's license, and GStreamer uses Apple's installer. WineShelf guides these steps but cannot accept licenses or administrator prompts for you.

## Add Windows apps

Choose **Add Windows App** and select the Windows executable, an initialized Wine prefix (the folder containing `system.reg`), and the `wine` and `wineserver` binaries. WineShelf can discover common Wine locations, including its managed runtime and GameToMac installs.

To create a Steam game shortcut, select the installed Steam executable and its Wine prefix. For a shortcut that launches a specific game, add the game's Steam App ID to the launch arguments. You can also launch Steam without arguments and manage games inside Steam.

## Library data and Wine sessions

WineShelf stores the library and logs here:

```text
~/Library/Application Support/WineShelf/
```

Removing an entry only removes its shortcut from WineShelf; it leaves game files, prefixes, and runtimes on disk. **Stop Wine** sends `wineserver -k` to that entry's prefix, which closes every Wine app sharing that prefix.

## Build from source

Requirements: macOS 14 or later and Xcode Command Line Tools with Swift 6.

```sh
./build-app.sh
```

The build script creates a universal `WineShelf.app`, generates the macOS icon from `Assets/Branding/WineShelf-Logo.png`, and packages it with an Applications shortcut:

```text
dist/WineShelf-0.2.0-universal.dmg
```

Local builds are ad-hoc signed by default. For direct distribution, sign with a **Developer ID Application** identity and notarize the app and disk image with Apple's notary service. Set `CODESIGN_IDENTITY` to the identity's full name to enable hardened runtime and secure timestamps.

Website assets are in [`Assets/Branding/`](Assets/Branding/): the original logo, README banner, 512 px and 192 px icons, Apple touch icon, and 32 px favicon.

## Runtime sources

| Component | Source | How WineShelf uses it |
| --- | --- | --- |
| Wine | [Gcenx macOS Wine builds](https://github.com/Gcenx/macOS_Wine_builds/releases) | Pinned x86_64 runtime; the version and digest are maintained in `RuntimeSetupModel.swift`. |
| GStreamer | [Official macOS downloads](https://gstreamer.freedesktop.org/download/) | Pinned runtime package; WineShelf verifies its digest before opening the installer. |
| Steam Setup | [Valve](https://store.steampowered.com/about/) | Downloaded from Valve's official site when the user chooses to install Steam. |

WineShelf does not bundle Wine, GStreamer, Steam, game files, or game licenses. Users are responsible for owning their games and following each software's license terms.
