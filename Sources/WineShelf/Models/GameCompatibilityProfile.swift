import Foundation

enum GameStorefront: String, CaseIterable, Hashable, Identifiable, Sendable {
    case steam
    case battleNet

    var id: String { rawValue }

    var name: String {
        switch self {
        case .steam: "Steam"
        case .battleNet: "Battle.net"
        }
    }

    var downloadURL: URL {
        switch self {
        case .steam:
            URL(string: "https://store.steampowered.com/")!
        case .battleNet:
            URL(string: "https://www.blizzard.com/en-us/apps/battle.net/desktop")!
        }
    }
}

struct GameCompatibilityProfile: Identifiable, Hashable, Sendable {
    let id: String
    let appID: String?
    let name: String
    let edition: String
    let genre: String
    let cost: String
    let summary: String
    let symbol: String
    let hasNativeMacVersion: Bool
    let storefronts: [GameStorefront]
    let minimumMacOS: String
    let accountRequirements: [String]
    let supportedExperience: String
    let limitations: [String]
    let setupNotes: [String]
    let storageRequirement: String?
    let guideURL: URL

    var isFreeToPlay: Bool { cost.localizedCaseInsensitiveContains("free to play") }

    func storePageURL(for storefront: GameStorefront) -> URL {
        switch storefront {
        case .steam:
            guard let appID else { return storefront.downloadURL }
            return URL(string: "https://store.steampowered.com/app/\(appID)/")!
        case .battleNet:
            return storefront.downloadURL
        }
    }
}

enum SteamGameCatalog {
    static let directoryURL = URL(string: "https://www.gametomac.com/games")!

    static let games: [GameCompatibilityProfile] = [
        GameCompatibilityProfile(
            id: "gta-iv-complete", appID: "12210", name: "Grand Theft Auto IV: The Complete Edition",
            edition: "The Complete Edition", genre: "Action · Open world", cost: "Paid",
            summary: "The Complete Edition includes GTA IV and Episodes from Liberty City.", symbol: "car.fill",
            hasNativeMacVersion: false, storefronts: [.steam], minimumMacOS: "26+",
            accountRequirements: ["Rockstar account"], supportedExperience: "Single-player campaign",
            limitations: ["Multiplayer is unavailable in the Complete Edition."],
            setupNotes: ["Use the Steam Complete Edition, then finish Rockstar sign-in and account linking."],
            storageRequirement: nil, guideURL: guide("gta-4-mac")
        ),
        GameCompatibilityProfile(
            id: "gta-v-enhanced", appID: "3240220", name: "Grand Theft Auto V Enhanced",
            edition: "Enhanced · Story Mode", genre: "Action · Open world", cost: "Paid",
            summary: "Return to Los Santos in the Enhanced edition of Grand Theft Auto V.", symbol: "car.side.fill",
            hasNativeMacVersion: false, storefronts: [.steam], minimumMacOS: "26+",
            accountRequirements: ["Rockstar account"], supportedExperience: "Story Mode",
            limitations: ["GTA Online is not supported.", "This profile covers Enhanced, not Legacy."],
            setupNotes: ["Choose the Enhanced edition in Steam and complete Rockstar sign-in when prompted."],
            storageRequirement: nil, guideURL: guide("gta-5-enhanced-mac")
        ),
        GameCompatibilityProfile(
            id: "red-dead-redemption-2", appID: "1174180", name: "Red Dead Redemption 2",
            edition: "Steam PC edition", genre: "Action · Open world", cost: "Paid",
            summary: "Ride through the American frontier in Rockstar’s story-driven western.", symbol: "sun.max.fill",
            hasNativeMacVersion: false, storefronts: [.steam], minimumMacOS: "26+",
            accountRequirements: ["Rockstar account"], supportedExperience: "Story Mode",
            limitations: ["Red Dead Online has not been validated."],
            setupNotes: ["Complete Rockstar sign-in and account linking when prompted."],
            storageRequirement: "At least 150 GB free, plus room for updates.", guideURL: guide("red-dead-redemption-2-mac")
        ),
        GameCompatibilityProfile(
            id: "the-witcher-3", appID: "292030", name: "The Witcher 3: Wild Hunt",
            edition: "Remastered · Steam", genre: "RPG · Open world", cost: "Paid",
            summary: "Explore a story-rich open world as Geralt of Rivia.", symbol: "swords",
            hasNativeMacVersion: false, storefronts: [.steam], minimumMacOS: "26+",
            accountRequirements: [], supportedExperience: "The Remastered Steam edition",
            limitations: ["GOG and console editions are outside this profile."],
            setupNotes: ["Install in Steam’s default library. Use APFS storage for external drives."],
            storageRequirement: "At least 80 GB free, plus room for updates.", guideURL: guide("witcher-3-mac")
        ),
        GameCompatibilityProfile(
            id: "diablo-ii-resurrected", appID: nil, name: "Diablo II: Resurrected",
            edition: "Battle.net PC edition", genre: "Action · RPG", cost: "Paid",
            summary: "Return to Sanctuary in Blizzard’s remastered action RPG.", symbol: "flame.fill",
            hasNativeMacVersion: false, storefronts: [.battleNet], minimumMacOS: "26.5+",
            accountRequirements: ["Battle.net account"], supportedExperience: "Battle.net PC edition",
            limitations: ["This profile covers Resurrected, not the original Diablo II.", "Battle.net is the only store in this profile."],
            setupNotes: ["Install the Battle.net Windows app in WineShelf, sign in to the account with the PC license, then install the game."],
            storageRequirement: "Follow Battle.net’s current estimate and leave room for updates.", guideURL: guide("diablo-2-resurrected-mac")
        ),
        GameCompatibilityProfile(
            id: "elden-ring", appID: "1245620", name: "Elden Ring",
            edition: "Steam PC edition", genre: "Action · RPG", cost: "Paid",
            summary: "Explore the Lands Between in FromSoftware’s open-world action RPG.", symbol: "sparkles",
            hasNativeMacVersion: false, storefronts: [.steam], minimumMacOS: "26+",
            accountRequirements: [], supportedExperience: "Offline single-player",
            limitations: ["Online multiplayer is unavailable.", "DLC has not been validated for this profile."],
            setupNotes: ["Start the game in offline mode and allow first-launch preparation to finish."],
            storageRequirement: nil, guideURL: guide("elden-ring-mac")
        ),
        GameCompatibilityProfile(
            id: "gta-san-andreas-definitive", appID: "1547000", name: "GTA: San Andreas – The Definitive Edition",
            edition: "Definitive Edition · Steam", genre: "Action · Open world", cost: "Paid",
            summary: "Revisit San Andreas in the remastered Definitive Edition.", symbol: "car.rear.fill",
            hasNativeMacVersion: false, storefronts: [.steam], minimumMacOS: "26+",
            accountRequirements: ["Rockstar account"], supportedExperience: "Definitive Edition story campaign",
            limitations: ["The original 2004 release is not covered by this profile."],
            setupNotes: ["Sign in to Rockstar when prompted during the first launch."],
            storageRequirement: nil, guideURL: guide("gta-san-andreas-mac")
        ),
        GameCompatibilityProfile(
            id: "skyrim-special-edition", appID: "489830", name: "Skyrim Special Edition",
            edition: "Special Edition · Steam", genre: "RPG · Open world", cost: "Paid",
            summary: "Explore Skyrim in the Special Edition of The Elder Scrolls V.", symbol: "snowflake",
            hasNativeMacVersion: false, storefronts: [.steam], minimumMacOS: "26+",
            accountRequirements: [], supportedExperience: "Single-player",
            limitations: [],
            setupNotes: ["Open the Skyrim launcher and choose Play."],
            storageRequirement: nil, guideURL: guide("skyrim-mac")
        ),
        GameCompatibilityProfile(
            id: "hogwarts-legacy", appID: "990080", name: "Hogwarts Legacy",
            edition: "Steam PC edition", genre: "Action · RPG", cost: "Paid",
            summary: "Discover life as a student at Hogwarts in the late 1800s.", symbol: "wand.and.stars",
            hasNativeMacVersion: false, storefronts: [.steam], minimumMacOS: "26.5+",
            accountRequirements: [], supportedExperience: "Single-player story",
            limitations: [],
            setupNotes: ["Let shader preparation finish on the first launch before starting the game."],
            storageRequirement: nil, guideURL: guide("hogwarts-legacy-mac")
        ),
        GameCompatibilityProfile(
            id: "path-of-exile-2", appID: "2694490", name: "Path of Exile 2",
            edition: "Steam access", genre: "Action · RPG", cost: "Steam access required",
            summary: "Return to Wraeclast in Grinding Gear Games’ action RPG.", symbol: "bolt.fill",
            hasNativeMacVersion: false, storefronts: [.steam], minimumMacOS: "26.5+",
            accountRequirements: ["Steam account with access to Path of Exile 2"], supportedExperience: "Online play; internet connection required",
            limitations: [],
            setupNotes: ["Make sure your Steam account has access to Path of Exile 2."],
            storageRequirement: "Allow about 150 GB, plus room for updates.", guideURL: guide("path-of-exile-2-mac")
        ),
        GameCompatibilityProfile(
            id: "diablo-iv", appID: "2344520", name: "Diablo IV",
            edition: "PC edition · Steam or Battle.net", genre: "Action · RPG", cost: "Paid",
            summary: "Enter Sanctuary in Blizzard’s online action RPG.", symbol: "flame.fill",
            hasNativeMacVersion: false, storefronts: [.steam, .battleNet], minimumMacOS: "26.5+",
            accountRequirements: ["Battle.net account", "Internet connection"], supportedExperience: "Online play through the store edition you own",
            limitations: [],
            setupNotes: ["Choose Steam or Battle.net to match your license; a Battle.net account is required."],
            storageRequirement: nil, guideURL: guide("diablo-4-mac")
        ),
        GameCompatibilityProfile(
            id: "age-of-mythology-retold", appID: "1934680", name: "Age of Mythology: Retold",
            edition: "Retold · Steam", genre: "Strategy · RTS", cost: "Paid",
            summary: "Command mythological armies in this modern retelling of the classic RTS.", symbol: "building.2.fill",
            hasNativeMacVersion: false, storefronts: [.steam], minimumMacOS: "26+",
            accountRequirements: [], supportedExperience: "Campaign and multiplayer",
            limitations: [],
            setupNotes: ["To resume a multiplayer save, use Multiplayer → Host → Game Mode → Saved Game."],
            storageRequirement: nil, guideURL: guide("age-of-mythology-retold-mac")
        ),
        GameCompatibilityProfile(
            id: "age-of-empires-iii-definitive", appID: "933110", name: "Age of Empires III: Definitive Edition",
            edition: "Definitive Edition · Steam", genre: "Strategy · RTS", cost: "Paid",
            summary: "Build an empire and lead historical civilizations in the Definitive Edition.", symbol: "building.2.fill",
            hasNativeMacVersion: false, storefronts: [.steam], minimumMacOS: "26+",
            accountRequirements: [], supportedExperience: "Definitive Edition campaign and skirmish",
            limitations: [],
            setupNotes: ["Let the intro videos play before skipping to help avoid a startup connection warning."],
            storageRequirement: nil, guideURL: guide("age-of-empires-3-mac")
        ),
        GameCompatibilityProfile(
            id: "heroes-of-might-and-magic-iii", appID: "4921760", name: "Heroes of Might and Magic III Complete Edition",
            edition: "Complete Edition · Steam", genre: "Strategy · Turn-based", cost: "Paid",
            summary: "Play Heroes III with Armageddon’s Blade and The Shadow of Death expansions.", symbol: "crown.fill",
            hasNativeMacVersion: false, storefronts: [.steam], minimumMacOS: "26+",
            accountRequirements: [], supportedExperience: "Complete Edition, including both expansions",
            limitations: ["The separate HD Edition is not covered by this profile."],
            setupNotes: ["Choose Heroes of Might and Magic III Complete Edition in Steam, not the HD Edition."],
            storageRequirement: nil, guideURL: guide("heroes-of-might-and-magic-3-mac")
        ),
        GameCompatibilityProfile(
            id: "red-alert-2", appID: "2229850", name: "Command & Conquer: Red Alert 2",
            edition: "Red Alert 2 + Yuri’s Revenge · Steam", genre: "Strategy · RTS", cost: "Paid",
            summary: "Command Allied and Soviet forces in Red Alert 2 and Yuri’s Revenge.", symbol: "antenna.radiowaves.left.and.right",
            hasNativeMacVersion: false, storefronts: [.steam], minimumMacOS: "26+",
            accountRequirements: [], supportedExperience: "Single-player; community multiplayer through CnCNet",
            limitations: ["For multiplayer, friends need CnCNet and the same game mode."],
            setupNotes: ["The Steam release includes Red Alert 2 and Yuri’s Revenge."],
            storageRequirement: nil, guideURL: guide("red-alert-2-mac")
        ),
        GameCompatibilityProfile(
            id: "generals-zero-hour", appID: "2732960", name: "Command & Conquer: Generals Zero Hour",
            edition: "Zero Hour · Steam", genre: "Strategy · RTS", cost: "Paid",
            summary: "Lead a modern army in the Generals expansion Zero Hour.", symbol: "scope",
            hasNativeMacVersion: false, storefronts: [.steam], minimumMacOS: "26+",
            accountRequirements: [], supportedExperience: "Campaign and skirmish; community multiplayer through GeneralsOnline",
            limitations: ["Community multiplayer uses GeneralsOnline."],
            setupNotes: ["Use GeneralsOnline if you want the community multiplayer route."],
            storageRequirement: nil, guideURL: guide("generals-zero-hour-mac")
        ),
        GameCompatibilityProfile(
            id: "age-of-empires-ii-definitive", appID: "813780", name: "Age of Empires II: Definitive Edition",
            edition: "Windows Steam edition", genre: "Strategy · RTS", cost: "Paid",
            summary: "Play the Windows Steam edition with and against Windows players.", symbol: "building.2.fill",
            hasNativeMacVersion: true, storefronts: [.steam], minimumMacOS: "26+",
            accountRequirements: [], supportedExperience: "Windows cross-play using the Windows Steam edition",
            limitations: ["The separate native Mac release has Mac-only multiplayer."],
            setupNotes: ["Install the Windows Steam edition for cross-play with Windows players."],
            storageRequirement: nil, guideURL: guide("age-of-empires-2-mac")
        ),
        GameCompatibilityProfile(
            id: "age-of-empires-iv", appID: "1466860", name: "Age of Empires IV",
            edition: "Anniversary Edition · Steam", genre: "Strategy · RTS", cost: "Paid",
            summary: "Build a civilization and command armies across medieval history.", symbol: "building.2.fill",
            hasNativeMacVersion: false, storefronts: [.steam], minimumMacOS: "26+",
            accountRequirements: [], supportedExperience: "Online matches with Windows players on tested builds",
            limitations: ["Online compatibility depends on using a supported game build."],
            setupNotes: ["Use the Steam Anniversary Edition."],
            storageRequirement: nil, guideURL: guide("age-of-empires-4-mac")
        ),
        GameCompatibilityProfile(
            id: "company-of-heroes-3", appID: "1677280", name: "Company of Heroes 3",
            edition: "Steam PC edition", genre: "Strategy · RTS", cost: "Paid",
            summary: "Lead Allied and Axis forces across the Mediterranean theater.", symbol: "shield.fill",
            hasNativeMacVersion: false, storefronts: [.steam], minimumMacOS: "26+",
            accountRequirements: [], supportedExperience: "Online matches with Windows players on tested builds",
            limitations: ["Online compatibility depends on using a supported game build."],
            setupNotes: ["Use your Steam copy and keep the game on a supported build."],
            storageRequirement: nil, guideURL: guide("company-of-heroes-3-mac")
        ),
        GameCompatibilityProfile(
            id: "overwatch", appID: "2357570", name: "Overwatch",
            edition: "Steam PC edition", genre: "Shooter · Team-based", cost: "Free to play",
            summary: "Team up with a roster of heroes in Blizzard’s free-to-play shooter.", symbol: "person.3.fill",
            hasNativeMacVersion: false, storefronts: [.steam], minimumMacOS: "26+",
            accountRequirements: ["Steam account", "Battle.net account"], supportedExperience: "Online play through the Steam edition",
            limitations: [],
            setupNotes: ["Link your Battle.net account. New maps and effects may stutter while graphics are cached."],
            storageRequirement: "Allow about 50 GB, plus room for cached graphics and updates.", guideURL: guide("overwatch-mac")
        ),
        GameCompatibilityProfile(
            id: "counter-strike-2", appID: "730", name: "Counter-Strike 2",
            edition: "Steam PC edition", genre: "Shooter · Tactical", cost: "Free to play",
            summary: "A tactical, round-based first-person shooter from Valve.", symbol: "target",
            hasNativeMacVersion: false, storefronts: [.steam], minimumMacOS: "26+",
            accountRequirements: ["Steam account", "Internet connection"], supportedExperience: "Windows Steam version; online services vary by mode",
            limitations: ["Support for every competitive mode or third-party anti-cheat service should not be assumed."],
            setupNotes: ["Allow first-launch graphics preparation to finish before playing."],
            storageRequirement: "Allow about 85 GB, plus room for updates and compatibility components.", guideURL: guide("counter-strike-2-mac")
        )
    ]

    // Keep the catalog useful offline; live Steam charts replace these ranks when available.
    static let fallbackPopularityRanks: [String: Int] = [
        "730": 1, "2357570": 12, "292030": 18, "3240220": 29,
        "1174180": 42, "489830": 53, "1245620": 60, "813780": 85
    ]

    static var steamGames: [GameCompatibilityProfile] { games.filter { $0.appID != nil } }

    static func game(appID: String) -> GameCompatibilityProfile? {
        games.first { $0.appID == appID }
    }

    static func game(named name: String) -> GameCompatibilityProfile? {
        games.first { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }
    }

    private static func guide(_ slug: String) -> URL {
        URL(string: "https://www.gametomac.com/games/\(slug)")!
    }
}

typealias SteamGame = GameCompatibilityProfile
