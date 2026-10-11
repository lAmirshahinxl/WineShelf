# WineShelf

WineShelf is a small local macOS library for starting Windows games and apps through Wine. It stores shortcuts and launch settings in your macOS Application Support folder; it does not install or distribute games or Wine.

## Build

Requirements: macOS 14 or later and Xcode Command Line Tools (Swift 6).

From this folder, run:

```sh
./build-app.sh
```

The app bundle is created at `dist/WineShelf.app`. You can move it to `/Applications` yourself if you want it there.

## Add an existing Wine app

Open WineShelf and choose **Add Windows App**. Select the Windows `.exe`, its initialized Wine prefix (the folder containing `system.reg`), the `wine` executable, and the matching `wineserver` executable. Each entry can have separate arguments and environment-variable overrides. Arguments are entered one per line; environment overrides use `NAME=value` one per line.

WineShelf validates the selected paths and starts the Windows executable with the selected prefix. It records stdout and stderr under:

```text
~/Library/Application Support/WineShelf/Logs/
```

The shortcut library is saved at `~/Library/Application Support/WineShelf/library.json`.

## Import GameToMac's existing Counter-Strike 2 setup

Choose **Import GameToMac CS2 Setup**. WineShelf looks for the known local GameToMac CS2 layout under:

```text
~/Library/Application Support/Game Library/Games/cs2
```

It checks the existing prefix, Steam executable, CS2 executable, and selected Wine engine, then records a WineShelf entry using that setup's paths and CS2 launch environment. Import does not copy, relocate, or initialize the prefix. Use the imported entry's **Launch** button to start Steam with Counter-Strike 2.

To install another Steam game in that same prefix, edit the imported entry and clear its three launch-argument lines (`-cef-disable-gpu`, `-applaunch`, `730`), then save and launch it to open Steam normally. Install the game in Steam. To keep a separate shortcut for each title, add another entry using the same `steam.exe`, prefix, and Wine runtime, then set its arguments to `-applaunch` and that game's Steam App ID on separate lines. Configure any game-specific environment variables for that entry as needed.

## Safety notes

- Removing an entry removes only its WineShelf shortcut.
- **Stop Wine** runs `wineserver -k` for that entry's prefix. This closes every Wine app currently sharing that prefix, so Steam and any other game in that prefix will also close.
- WineShelf does not download games, bypass Steam ownership, or replace Wine runtime files.
