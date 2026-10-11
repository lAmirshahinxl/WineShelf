This release makes first-time Wine setup more direct. Open Wine Setup and WineShelf automatically checks the Mac, downloads and verifies missing components, and continues after the required macOS steps.

The app now keeps manual Wine paths and launch options under Advanced settings, while direct `.exe` launch remains available from the library.

On Apple silicon, Rosetta still requires accepting Apple's license in Terminal. GStreamer uses Apple's Installer, and Gatekeeper may ask you to approve Wine in Finder. WineShelf guides these steps but does not bypass macOS security prompts.

Download the universal macOS `.dmg`, open it, and drag `WineShelf.app` to Applications. This build is ad-hoc signed and is not notarized by Apple, so macOS may require a one-time approval for WineShelf itself.
