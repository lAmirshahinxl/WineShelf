WineShelf is an early beta. Download and open the `.dmg`, then drag `WineShelf.app` to the Applications shortcut. The app is ad-hoc signed and has not been notarized by Apple. On first launch, Control-click `WineShelf.app` in Finder, choose **Open**, and confirm the macOS prompt.

The first-run Wine Setup checks or guides users through Rosetta, the official GStreamer installer, and a checksum-verified Wine runtime download. Wine Setup also installs Valve's Steam Setup into a separate Wine prefix.

The Wine runtime is a third-party x86_64 build. On Apple silicon it requires Rosetta. WineShelf does not bundle Wine, GStreamer, Steam, or game files.
