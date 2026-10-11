This release adds a **Steam Games** page with a searchable catalog and a guided install flow. WineShelf opens the selected title's install page in its Wine Steam prefix, adds a launch shortcut to the library, and detects when Steam finishes installing the game.

The add menu no longer repeats Wine Setup or offers a Counter-Strike-only import action. Game compatibility varies; the catalog does not certify that a title will run on a particular Mac.

On Apple silicon, Rosetta still requires accepting Apple's license in Terminal. GStreamer uses Apple's Installer, and Gatekeeper may ask you to approve Wine in Finder. WineShelf guides these steps but does not bypass macOS security prompts.

Download the universal macOS `.dmg`, open it, and drag `WineShelf.app` to Applications. This build is ad-hoc signed and is not notarized by Apple, so macOS may require a one-time approval for WineShelf itself.
