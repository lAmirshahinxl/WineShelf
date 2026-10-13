WineShelf now loads its **Game Profiles** catalog from the public [WineShelf game directory](https://wineshelf.site/games/). The app refreshes the list when you open Game Profiles, so catalog updates on the website can reach the app without another app release. The built-in profiles remain available when you are offline.

The website publishes the same game data as a static JSON feed at [wineshelf.site/game-profiles.json](https://wineshelf.site/game-profiles.json). The directory includes supported editions and storefronts, account requirements, macOS requirements, known limitations, and setup guides.

Steam profiles now open the title's store page inside Wine Steam so you can confirm that your account owns the selected edition before installing. WineShelf tracks the install and adds a library shortcut after Steam reports the game is fully installed. It also removes stale shortcuts when a game is no longer installed. Battle.net profiles link to Blizzard's Windows installer and explain the manual WineShelf setup steps.

The library detail page now includes game artwork and clearer environment information. The expanded view fills the window with a consistent background, and the app branding has been refreshed.

GameToMac compatibility summaries are informational. WineShelf does not include GameToMac's compatibility components or certify that a title, online mode, or anti-cheat system will work on a particular Mac. Steam requires a license for paid titles; a store page can show purchase options when the signed-in account does not own that edition.

On Apple silicon, Rosetta still requires accepting Apple's license in Terminal. GStreamer uses Apple's Installer, and Gatekeeper may ask you to approve Wine in Finder. WineShelf guides these steps but does not bypass macOS security prompts.

Download the universal macOS `.dmg`, open it, and drag `WineShelf.app` to Applications. This build is ad-hoc signed and is not notarized by Apple, so macOS may require a one-time approval for WineShelf itself.
