# WineShelf

![WineShelf game library and controller illustration](Assets/Branding/WineShelf-README.png)

WineShelf is a macOS library for installing and managing Wine runtimes, Windows apps, and game shortcuts. It can set up the Wine dependencies, install Windows Steam into a dedicated Wine prefix, and launch games through Steam.

## Download

Download the latest WineShelf `.dmg` from [GitHub Releases](https://github.com/lAmirshahinxl/WineShelf/releases), open it, and drag `WineShelf.app` to the Applications shortcut in the disk image. This beta is not signed with a Developer ID certificate or notarized. The first launch may require Control-clicking WineShelf in Finder, choosing **Open**, and confirming the macOS prompt.

## First-time setup

1. Open WineShelf and choose **Wine Setup**.
2. On Apple silicon, install Rosetta if the app reports it missing. WineShelf copies Apple's `softwareupdate --install-rosetta` command; run it in Terminal and accept Apple's license.
3. Install GStreamer from Wine Setup. WineShelf downloads the official package, verifies its SHA-256 digest, and opens Apple's Installer. The package installs the framework for all users and may ask for an administrator password.
4. Download Wine from Wine Setup. WineShelf verifies the published SHA-256 digest and extracts the runtime under `~/Library/Application Support/WineShelf/Runtimes/`.
5. In Finder, Control-click the Wine app and choose **Open** if macOS asks you to approve it. WineShelf does not remove quarantine attributes or turn off Gatekeeper.
6. Choose **Install Steam** in Wine Setup. WineShelf downloads Steam Setup from Valve's official Steam site, creates a separate Wine prefix, and runs the installer. Complete the installer windows, then sign in and install your games in Steam.

The Wine build currently offered is x86_64. Apple silicon Macs need Rosetta to run it. Wine and GStreamer are downloaded when requested; neither is bundled in the WineShelf app.

## Add other Windows apps

Choose **Add Windows App** and select a Windows `.exe`, an initialized Wine prefix (the folder containing `system.reg`), and the `wine` and `wineserver` binaries. WineShelf discovers common Wine locations, including its managed runtime and GameToMac installs. Each entry can keep separate launch arguments and environment overrides.

To add a Steam game shortcut, use the installed Steam executable, its Wine prefix, and the selected Wine runtime. For an app that should start a title directly, enter that game's Steam App ID as a launch argument. You can also launch Steam without arguments and install/manage games in its own interface.

WineShelf stores its library and logs under:

```text
~/Library/Application Support/WineShelf/
```

Removing a library entry does not delete game files, prefixes, or runtimes. **Stop Wine** sends `wineserver -k` to that entry's prefix and closes every Wine app sharing it.

## Build from source

Requirements: macOS 14 or later and Xcode Command Line Tools with Swift 6.

```sh
./build-app.sh
```

The script builds arm64 and x86_64 release binaries, combines them into a universal `WineShelf.app`, creates its macOS icon from `Assets/Branding/WineShelf-Logo.png`, and packages the app with an Applications shortcut in `dist/WineShelf-0.2.0-universal.dmg`. By default, it ad-hoc signs the app for local testing. For direct public distribution, configure a **Developer ID Application** identity and notarize the app and final disk image with Apple's notary service. Set `CODESIGN_IDENTITY` to the identity's full name to sign with hardened runtime and a secure timestamp.

The selected logo is saved at `Assets/Branding/WineShelf-Logo.png` and can also be used on the project website. Smaller web icon sizes are included alongside it.

## Runtime sources

- Wine: [Gcenx macOS Wine builds](https://github.com/Gcenx/macOS_Wine_builds/releases). WineShelf pins the Wine version and release-asset digest in `RuntimeSetupModel.swift`.
- GStreamer: [official GStreamer macOS downloads](https://gstreamer.freedesktop.org/download/). WineShelf pins the universal runtime package and its SHA-256 digest in `RuntimeSetupModel.swift`.
- Steam Setup: [Valve's official Steam installation page](https://store.steampowered.com/about/).

WineShelf does not include Steam games or game data. Users remain responsible for game ownership, account access, and any applicable software license terms.
