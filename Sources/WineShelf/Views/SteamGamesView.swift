import AppKit
import SwiftUI

struct SteamGame: Identifiable, Hashable {
    let appID: String
    let name: String
    let genre: String
    let cost: String
    let summary: String
    let symbol: String

    var id: String { appID }
    var storePageURL: URL { URL(string: "https://store.steampowered.com/app/\(appID)/")! }
}

private enum SteamGameCatalog {
    static let games = [
        SteamGame(appID: "570", name: "Dota 2", genre: "Strategy · Multiplayer", cost: "Free to play", summary: "A team strategy game with a large roster of heroes and frequent updates.", symbol: "shield.lefthalf.filled"),
        SteamGame(appID: "440", name: "Team Fortress 2", genre: "Action · Multiplayer", cost: "Free to play", summary: "A class-based team shooter with objective and competitive modes.", symbol: "person.3.fill"),
        SteamGame(appID: "620", name: "Portal 2", genre: "Puzzle · Co-op", cost: "Paid", summary: "A first-person puzzle adventure with a full cooperative campaign.", symbol: "circle.hexagongrid.fill"),
        SteamGame(appID: "413150", name: "Stardew Valley", genre: "Simulation · RPG", cost: "Paid", summary: "Build a farm, meet the townspeople, and explore the valley at your own pace.", symbol: "leaf.fill"),
        SteamGame(appID: "105600", name: "Terraria", genre: "Sandbox · Adventure", cost: "Paid", summary: "Explore, build, craft, and fight through a large 2D world.", symbol: "mountain.2.fill"),
        SteamGame(appID: "1145360", name: "Hades", genre: "Action · Roguelike", cost: "Paid", summary: "Fight your way out of the Underworld in a story-driven action game.", symbol: "flame.fill"),
        SteamGame(appID: "550", name: "Left 4 Dead 2", genre: "Action · Co-op", cost: "Paid", summary: "Team up in a cooperative campaign against large infected hordes.", symbol: "cross.case.fill"),
        SteamGame(appID: "292030", name: "The Witcher 3: Wild Hunt", genre: "RPG · Adventure", cost: "Paid", summary: "Explore a story-rich open world as a monster hunter for hire.", symbol: "swords"),
        SteamGame(appID: "730", name: "Counter-Strike 2", genre: "Action · Multiplayer", cost: "Free to play", summary: "A tactical, round-based first-person shooter from Valve.", symbol: "target")
    ]
}

struct SteamGamesView: View {
    @ObservedObject var library: LibraryModel
    let onSetUpSteam: (SteamGame) -> Void

    @State private var searchText = ""
    @State private var selectedGameID = SteamGameCatalog.games[0].id
    @State private var installationStateRevision = 0

    private var filteredGames: [SteamGame] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return SteamGameCatalog.games }
        return SteamGameCatalog.games.filter {
            $0.name.localizedCaseInsensitiveContains(query) || $0.genre.localizedCaseInsensitiveContains(query)
        }
    }

    private var selectedGame: SteamGame? {
        filteredGames.first(where: { $0.id == selectedGameID }) ?? filteredGames.first
    }

    var body: some View {
        VStack(spacing: 0) {
            pageHeader
            Divider()
            HStack(spacing: 0) {
                gameList
                Divider()
                gameGuide
            }
        }
        .frame(minWidth: 760, minHeight: 560)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            installationStateRevision += 1
        }
        .onChange(of: filteredGames.map(\.id)) { _, gameIDs in
            if !gameIDs.contains(selectedGameID), let first = gameIDs.first {
                selectedGameID = first
            }
        }
        .accessibilityIdentifier("steam-games-page")
    }

    private var pageHeader: some View {
        HStack(spacing: 16) {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 25, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 48, height: 48)
                .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 4) {
                Text("Explore Steam Games")
                    .font(.title2.weight(.semibold))
                Text("Choose a game and WineShelf will guide the install in Steam.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Browse all Steam games", systemImage: "arrow.up.right") {
                NSWorkspace.shared.open(URL(string: "https://store.steampowered.com/search/")!)
            }
            .buttonStyle(.bordered)
            .help("Browse the full Steam catalog in your web browser")
        }
        .padding(20)
    }

    private var gameList: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Search games", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Search Steam games")

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(filteredGames) { game in
                        gameRow(game)
                    }
                    if filteredGames.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                            .padding(.top, 30)
                    }
                }
            }
        }
        .padding(14)
        .frame(width: 270)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func gameRow(_ game: SteamGame) -> some View {
        let isSelected = game.id == selectedGameID
        return Button {
            selectedGameID = game.id
        } label: {
            HStack(spacing: 11) {
                Image(systemName: game.symbol)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .frame(width: 34, height: 34)
                    .background(.quaternary.opacity(0.7), in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 3) {
                    Text(game.name)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    Text(game.cost)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.accentColor.opacity(0.11) : Color.clear, in: RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var gameGuide: some View {
        if let game = selectedGame {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    gameOverview(game)
                    compatibilityNote
                    installSteps(for: game)
                    installAction(for: game)
                }
                .padding(24)
                .frame(maxWidth: 650, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .id(installationStateRevision)
        } else {
            ContentUnavailableView("No games found", systemImage: "magnifyingglass", description: Text("Try a different search.")).frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func gameOverview(_ game: SteamGame) -> some View {
        HStack(alignment: .top, spacing: 18) {
            Image(systemName: game.symbol)
                .font(.system(size: 29, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 74, height: 74)
                .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 20))
            VStack(alignment: .leading, spacing: 8) {
                Text(game.name)
                    .font(.largeTitle.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text(game.genre)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    CatalogBadge(text: game.cost, symbol: "tag")
                    CatalogBadge(text: "Wine compatibility varies", symbol: "questionmark.circle")
                }
                HStack {
                    Spacer()
                    Button("Steam Store", systemImage: "arrow.up.right") {
                        NSWorkspace.shared.open(game.storePageURL)
                    }
                    .buttonStyle(.link)
                    .help("View the current price, ownership, and details on Steam")
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.bottom, 14)
        .overlay(alignment: .bottom) { Divider() }
    }

    private var compatibilityNote: some View {
        Label {
            Text("WineShelf can send this game to Steam, but it does not certify that the game will run. Compatibility, anti-cheat, and performance vary by title and Mac.")
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.orange)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    private func installSteps(for game: SteamGame) -> some View {
        let wineReady = RuntimeSetupModel.runtimeReadyForDirectLaunch() != nil
        let steamReady = library.steamEntry != nil
        let gameInstalled = library.isSteamGameInstalled(game)
        let shortcutAdded = library.steamGameEntry(for: game) != nil

        return VStack(alignment: .leading, spacing: 0) {
            Text("Install step by step")
                .font(.headline)
                .padding(.bottom, 12)
            GuideStepRow(number: 1, title: "Prepare Wine", detail: wineReady ? "Wine and its requirements are ready." : "WineShelf will install missing components.", isComplete: wineReady)
            GuideStepRow(number: 2, title: "Set up Steam", detail: steamReady ? "Steam is installed in WineShelf." : "Sign in to your Steam account after installing Steam.", isComplete: steamReady)
            GuideStepRow(number: 3, title: "Install \(game.name)", detail: gameInstalled ? "Steam reports this game is installed." : "Steam handles the download and asks you to confirm the install.", isComplete: gameInstalled)
            GuideStepRow(number: 4, title: "Launch from WineShelf", detail: shortcutAdded ? "A launch shortcut is in your library." : "WineShelf adds a launch shortcut when you start the install.", isComplete: shortcutAdded, isLast: true)
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.quaternary))
    }

    @ViewBuilder
    private func installAction(for game: SteamGame) -> some View {
        let wineReady = RuntimeSetupModel.runtimeReadyForDirectLaunch() != nil
        let steamReady = library.steamEntry != nil
        let gameInstalled = library.isSteamGameInstalled(game)
        let shortcut = library.steamGameEntry(for: game)

        if !wineReady || !steamReady {
            Button {
                onSetUpSteam(game)
            } label: {
                Label(wineReady ? "Set Up Steam" : "Set Up Wine and Steam", systemImage: "wineglass")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Text("Wine Setup opens automatically. If Steam is missing, choose Install Steam there to continue.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if gameInstalled, let shortcut {
            Button {
                library.launch(shortcut)
            } label: {
                Label("Launch \(game.name)", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        } else if gameInstalled {
            Button {
                library.addSteamGameShortcut(game)
            } label: {
                Label("Add to WineShelf Library", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        } else {
            Button {
                library.installSteamGame(game)
            } label: {
                Label(shortcut == nil ? "Install with Steam" : "Open Install Page in Steam", systemImage: "arrow.down.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Text("Steam will open in Wine. Confirm the install there; the game shortcut will appear in your library.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct CatalogBadge: View {
    let text: String
    let symbol: String

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(.quaternary.opacity(0.7), in: Capsule())
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct GuideStepRow: View {
    let number: Int
    let title: String
    let detail: String
    let isComplete: Bool
    var isLast = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(isComplete ? Color.green.opacity(0.14) : Color.accentColor.opacity(0.11))
                    if isComplete {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.green)
                    } else {
                        Text("\(number)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .frame(width: 26, height: 26)
                if !isLast {
                    Rectangle()
                        .fill(.quaternary)
                        .frame(width: 1, height: 31)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 3)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}
