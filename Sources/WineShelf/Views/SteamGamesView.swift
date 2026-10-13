import AppKit
import SwiftUI

private struct SteamGameSection: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let symbol: String
    let games: [SteamGame]
}

struct SteamGamesView: View {
    @ObservedObject var library: LibraryModel
    let onSetUpStore: (SteamGame, GameStorefront) -> Void

    @StateObject private var store = SteamGameStoreModel()
    @StateObject private var catalog = GameProfileCatalogStore.shared
    @State private var searchText = ""
    @State private var selectedGameID = "counter-strike-2"
    @State private var selectedStorefrontID = GameStorefront.steam.rawValue
    @State private var installationStateRevision = 0

    private let columns = [GridItem(.adaptive(minimum: 145, maximum: 220), spacing: 12, alignment: .top)]

    private var matchingGames: [SteamGame] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return catalog.games }
        return catalog.games.filter {
            $0.name.localizedCaseInsensitiveContains(query) || $0.genre.localizedCaseInsensitiveContains(query) || $0.edition.localizedCaseInsensitiveContains(query) || $0.storefronts.contains { $0.name.localizedCaseInsensitiveContains(query) }
        }
    }

    private var gameSections: [SteamGameSection] {
        let unsupported = matchingGames
            .filter { !hasNativeMacVersion($0) }
            .sorted { popularityOrder($0, before: $1) }
        let popularMacGames = matchingGames
            .filter { hasNativeMacVersion($0) && store.popularityRank(for: $0) != nil }
            .sorted { popularityOrder($0, before: $1) }

        return [
            SteamGameSection(
                id: "unsupported",
                title: "No native Mac version",
                subtitle: "Steam-ranked titles first; other supported editions follow alphabetically",
                symbol: "wineglass",
                games: unsupported
            ),
            SteamGameSection(
                id: "popular",
                title: "Popular on Steam",
                subtitle: "Native Mac releases currently in Steam’s top 100",
                symbol: "chart.bar.fill",
                games: popularMacGames
            )
        ].filter { !$0.games.isEmpty }
    }

    private var listedGames: [SteamGame] {
        gameSections.flatMap(\.games)
    }

    private var selectedGame: SteamGame? {
        listedGames.first(where: { $0.id == selectedGameID }) ?? listedGames.first
    }

    private func hasNativeMacVersion(_ game: SteamGame) -> Bool {
        store.games[game.id]?.platforms?.mac ?? game.hasNativeMacVersion
    }

    private func popularityOrder(_ lhs: SteamGame, before rhs: SteamGame) -> Bool {
        let lhsRank = store.popularityRank(for: lhs) ?? Int.max
        let rhsRank = store.popularityRank(for: rhs) ?? Int.max
        if lhsRank != rhsRank { return lhsRank < rhsRank }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    var body: some View {
        VStack(spacing: 0) {
            pageHeader
            Divider()
            HStack(spacing: 0) {
                gameGrid
                Divider()
                gameGuide
            }
        }
        .frame(minWidth: 760, minHeight: 620)
        .task {
            await catalog.load()
            await store.load(catalog.games)
            library.refreshGameProfiles(catalog.games)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            library.refreshPendingSteamGameInstalls(catalog.games.filter { $0.appID != nil })
            installationStateRevision += 1
        }
        .onChange(of: listedGames.map(\.id)) { _, gameIDs in
            if !gameIDs.contains(selectedGameID), let first = gameIDs.first {
                selectedGameID = first
            }
        }
        .onChange(of: selectedGameID) { _, gameID in
            selectedStorefrontID = catalog.games.first(where: { $0.id == gameID })?.storefronts.first?.rawValue ?? GameStorefront.steam.rawValue
            installationStateRevision += 1
        }
        .accessibilityIdentifier("game-profiles-page")
    }

    private var pageHeader: some View {
        HStack(spacing: 16) {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 25, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 48, height: 48)
                .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 4) {
                Text("Mac Game Profiles")
                    .font(.title2.weight(.semibold))
                Text("Edition-specific setup, requirements, and play limits for \(catalog.games.count) games.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(catalog.isUsingWebsiteCatalog
                    ? "Synced from wineshelf.site"
                    : catalog.loadError == nil
                        ? "Using the included catalog"
                        : "Website list unavailable · using the included catalog")
                    .font(.caption2)
                    .foregroundStyle(catalog.isUsingWebsiteCatalog ? Color.accentColor : Color.secondary)
            }
            Spacer(minLength: 12)
            Button("WineShelf Game Directory", systemImage: "arrow.up.right") {
                NSWorkspace.shared.open(SteamGameCatalog.directoryURL)
            }
            .buttonStyle(.bordered)
            .help("Browse the game profiles on wineshelf.site")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 17)
    }

    private var gameGrid: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 10) {
                TextField("Search games", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Search game profiles")
                Text("\(listedGames.count)")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.quaternary.opacity(0.6), in: Capsule())
                    .accessibilityLabel("\(listedGames.count) games")
            }

            if listedGames.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        ForEach(gameSections) { section in
                            VStack(alignment: .leading, spacing: 11) {
                                sectionHeading(section)
                                LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                                    ForEach(section.games) { game in
                                        gameCard(game)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.bottom, 4)
                }
            }
        }
        .padding(16)
        .frame(minWidth: 320, idealWidth: 420, maxWidth: 500)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func sectionHeading(_ section: SteamGameSection) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: section.symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(section.id == "unsupported" ? Color.orange : Color.accentColor)
                .frame(width: 27, height: 27)
                .background((section.id == "unsupported" ? Color.orange : Color.accentColor).opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(section.title)
                    .font(.subheadline.weight(.semibold))
                Text(section.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 2)
            Text("\(section.games.count)")
                .font(.caption2.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(.quaternary.opacity(0.55), in: Capsule())
        }
        .accessibilityElement(children: .combine)
    }

    private func gameCard(_ game: SteamGame) -> some View {
        let isSelected = game.id == selectedGameID
        let metadata = store.games[game.id]

        return Button {
            selectedGameID = game.id
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                SteamArtworkView(
                    url: metadata?.headerImage,
                    symbol: game.symbol,
                    isLoading: store.loadingIDs.contains(game.id)
                )
                .aspectRatio(460 / 215, contentMode: .fit)
                .overlay(alignment: .topLeading) {
                    Text(cardTag(for: game))
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(0.5)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.black.opacity(0.58), in: Capsule())
                        .padding(9)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(metadata?.name ?? game.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                    Text(game.genre)
                        .font(.caption2)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.up.right.circle")
                        Text("View install guide")
                    }
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .padding(.top, 3)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 13))
            .overlay {
                RoundedRectangle(cornerRadius: 13)
                    .strokeBorder(isSelected ? Color.accentColor.opacity(0.9) : Color.primary.opacity(0.08), lineWidth: isSelected ? 2 : 1)
            }
            .shadow(color: .black.opacity(isSelected ? 0.1 : 0.035), radius: isSelected ? 8 : 4, y: 2)
            .contentShape(RoundedRectangle(cornerRadius: 13))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityLabel("\(metadata?.name ?? game.name), \(game.genre), view install guide")
    }

    private func cardTag(for game: SteamGame) -> String {
        if !hasNativeMacVersion(game) { return "NO MAC VERSION" }
        if let rank = store.popularityRank(for: game) { return "STEAM #\(rank)" }
        return game.cost == "Free to play" ? "FREE TO PLAY" : "POPULAR"
    }

    @ViewBuilder
    private var gameGuide: some View {
        if let game = selectedGame {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    gameOverview(game)
                    storefrontPicker(for: game)
                    compatibilityProfile(for: game)
                    compatibilityNote
                    installSteps(for: game)
                    installAction(for: game)
                    profileSourceLink(for: game)
                }
                .padding(22)
                .frame(maxWidth: 520, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .id(installationStateRevision)
        } else {
            ContentUnavailableView("No games found", systemImage: "magnifyingglass", description: Text("Try a different search."))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func gameOverview(_ game: SteamGame) -> some View {
        let metadata = store.games[game.id]
        let storefront = selectedStorefront(for: game)

        return VStack(alignment: .leading, spacing: 13) {
            SteamArtworkView(
                url: metadata?.headerImage,
                symbol: game.symbol,
                isLoading: store.loadingIDs.contains(game.id)
            )
            .frame(height: 176)
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .overlay(alignment: .bottomLeading) {
                Text(game.hasNativeMacVersion ? "WINDOWS EDITION PROFILE" : "NO NATIVE MAC RELEASE")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(0.65)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.6), in: Capsule())
                    .padding(12)
            }
            .overlay(RoundedRectangle(cornerRadius: 15).strokeBorder(.quaternary))

            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(metadata?.name ?? game.name)
                        .font(.title2.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(game.edition)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text(game.genre)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer(minLength: 0)
                Button {
                    NSWorkspace.shared.open(game.storePageURL(for: storefront))
                } label: {
                    Image(systemName: "arrow.up.right.square")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .help("Open this game in \(storefront.name)")
                .accessibilityLabel("Open \(game.name) in \(storefront.name)")
            }

            Text(game.summary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 7) {
                CatalogBadge(text: game.cost, symbol: "tag")
                CatalogBadge(text: storefront.name, symbol: storefront == .steam ? "gamecontroller" : "globe")
                CatalogBadge(text: "macOS \(game.minimumMacOS)", symbol: "laptopcomputer")
            }
        }
        .padding(.bottom, 15)
        .overlay(alignment: .bottom) { Divider() }
    }

    @ViewBuilder
    private func storefrontPicker(for game: SteamGame) -> some View {
        if game.storefronts.count > 1 {
            VStack(alignment: .leading, spacing: 8) {
                Text("Choose your store")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Picker("Store", selection: $selectedStorefrontID) {
                    ForEach(game.storefronts) { storefront in
                        Text(storefront.name).tag(storefront.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Choose store for \(game.name)")
            }
        }
    }

    private func selectedStorefront(for game: SteamGame) -> GameStorefront {
        game.storefronts.first(where: { $0.rawValue == selectedStorefrontID }) ?? game.storefronts[0]
    }

    private func compatibilityProfile(for game: SteamGame) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 9) {
                Image(systemName: "laptopcomputer")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 30, height: 30)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Compatibility profile")
                        .font(.headline)
                    Text("Requirements and play modes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("GAMETOMAC")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
            }

            profileFact("Mac", value: "Apple Silicon · M1 or later", symbol: "cpu")
            profileFact("Minimum system", value: "macOS \(game.minimumMacOS)", symbol: "laptopcomputer")
            profileFact("Supported experience", value: game.supportedExperience, symbol: "gamecontroller")

            if !game.accountRequirements.isEmpty {
                profileFact("Accounts", value: game.accountRequirements.joined(separator: " · "), symbol: "person.crop.circle")
            }

            if let storage = game.storageRequirement {
                profileFact("Storage", value: storage, symbol: "internaldrive")
            }

            if !game.setupNotes.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Before you install")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(game.setupNotes, id: \.self) { note in
                        Label(note, systemImage: "checkmark.circle")
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, 2)
            }

            if !game.limitations.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Known limits")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                    ForEach(game.limitations, id: \.self) { limitation in
                        Label(limitation, systemImage: "exclamationmark.circle.fill")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(11)
                .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(15)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.quaternary))
    }

    private func profileFact(_ title: String, value: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 18)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Text(value)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func installSteps(for game: SteamGame) -> some View {
        let name = store.games[game.id]?.name ?? game.name
        let storefront = selectedStorefront(for: game)
        let wineReady = RuntimeSetupModel.runtimeReadyForDirectLaunch() != nil
        let steamReady = library.steamEntry != nil

        if storefront == .steam, game.appID != nil {
            let gameInstalled = library.isSteamGameInstalled(game)
            let shortcutAdded = library.steamGameEntry(for: game) != nil
            let installPending = library.isSteamGamePendingInstall(game)

            return AnyView(VStack(alignment: .leading, spacing: 0) {
                guideHeading()
                    .padding(.bottom, 12)
                GuideStepRow(number: 1, title: "Prepare Wine", detail: wineReady ? "Wine and its requirements are ready." : "WineShelf will install missing components.", isComplete: wineReady)
                GuideStepRow(number: 2, title: "Set up Steam", detail: steamReady ? "Steam is installed in WineShelf." : "Sign in to your Steam account after installing Steam.", isComplete: steamReady)
                GuideStepRow(number: 3, title: "Install \(game.edition)", detail: gameInstalled ? "Steam reports this game is installed." : installPending ? "Check edition access or continue the download in Steam." : "Open the Steam page to check access and install this edition.", isComplete: gameInstalled)
                GuideStepRow(number: 4, title: "Launch from WineShelf", detail: shortcutAdded && gameInstalled ? "The installed game is ready in your library." : gameInstalled ? "WineShelf can add the launch shortcut." : "Completes after Steam confirms the install is complete.", isComplete: gameInstalled && shortcutAdded, isLast: true)
            }
            .padding(15)
            .background(.background, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.quaternary)))
        }

        let battleNetEntryExists = library.entries.contains {
            $0.name.localizedCaseInsensitiveContains("battle.net")
                || $0.executableURL.lastPathComponent.localizedCaseInsensitiveContains("battle.net.exe")
        }

        return AnyView(VStack(alignment: .leading, spacing: 0) {
            guideHeading()
                .padding(.bottom, 12)
            GuideStepRow(number: 1, title: "Prepare Wine", detail: wineReady ? "Wine and its requirements are ready." : "Install Wine before running the Windows launcher.", isComplete: wineReady)
            GuideStepRow(number: 2, title: "Install Battle.net", detail: battleNetEntryExists ? "The installer has a WineShelf entry." : "Download the PC installer, then choose + → Run Windows .exe…", isComplete: battleNetEntryExists)
            GuideStepRow(number: 3, title: "Set up the launcher", detail: "After setup, edit that entry to use Battle.net.exe in the same Wine prefix.", isComplete: false)
            GuideStepRow(number: 4, title: "Install \(name)", detail: "Sign in to Battle.net, install your PC edition, then play from its library.", isComplete: false, isLast: true)
        }
        .padding(15)
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.quaternary)))
    }

    private func guideHeading() -> some View {
        HStack {
            Text("Your install guide")
                .font(.headline)
            Spacer()
            Text("4 STEPS")
                .font(.caption2.weight(.bold))
                .tracking(0.7)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func installAction(for game: SteamGame) -> some View {
        let wineReady = RuntimeSetupModel.runtimeReadyForDirectLaunch() != nil
        let storefront = selectedStorefront(for: game)

        if !wineReady {
            Button {
                onSetUpStore(game, storefront)
            } label: {
                Label("Set Up Wine", systemImage: "wineglass")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Text("Wine Setup prepares the runtime WineShelf uses for Windows apps.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if storefront == .battleNet {
            Button {
                NSWorkspace.shared.open(GameStorefront.battleNet.downloadURL)
            } label: {
                Label("Get Battle.net PC installer", systemImage: "arrow.down.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Text("Download the Windows installer, then choose + → Run Windows .exe…. After setup, edit its WineShelf entry to use Battle.net.exe in the same prefix, then install and launch the game from Battle.net.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            steamInstallAction(for: game)
        }
    }

    @ViewBuilder
    private func steamInstallAction(for game: SteamGame) -> some View {
        let name = store.games[game.id]?.name ?? game.name
        let steamReady = library.steamEntry != nil
        let gameInstalled = library.isSteamGameInstalled(game)
        let shortcut = library.steamGameEntry(for: game)
        let installPending = library.isSteamGamePendingInstall(game)

        if !steamReady {
            Button {
                onSetUpStore(game, .steam)
            } label: {
                Label("Set Up Steam", systemImage: "wineglass")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Text("Wine Setup opens automatically. Install Steam there, then return to this profile.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if gameInstalled, let shortcut {
            Button {
                library.launch(shortcut)
            } label: {
                Label("Launch \(name)", systemImage: "play.fill")
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
        } else if installPending {
            Button {
                library.openSteamGamePage(game)
            } label: {
                Label("Continue in Steam", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Text("Check that this Steam account has access to the edition, then start or continue its install there.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Button {
                library.openSteamGamePage(game)
            } label: {
                Label("Open in Steam", systemImage: "arrow.up.right.square")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Text("Steam shows the install options for this edition. If it shows a purchase option, this account doesn’t have access yet.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func profileSourceLink(for game: SteamGame) -> some View {
        Link(destination: game.guideURL) {
            HStack(spacing: 7) {
                Image(systemName: "arrow.up.right")
                Text("Read the GameToMac setup guide")
            }
            .font(.caption.weight(.medium))
        }
        .help("Open GameToMac’s public guide for this game")
    }

    private var compatibilityNote: some View {
        Label {
            Text("Profiles summarize GameToMac’s public directory. WineShelf does not include GameToMac’s compatibility components, so results and online behavior may differ. Steam installation is integrated; Battle.net requires the Windows .exe flow and a manual launcher path update.")
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.orange)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}

@MainActor
final class SteamGameStoreModel: ObservableObject {
    @Published private(set) var games: [String: SteamStoreGameData] = [:]
    @Published private(set) var loadingIDs: Set<String> = []
    @Published private(set) var popularityRanks = SteamGameCatalog.fallbackPopularityRanks

    private var requestedIDs: Set<String> = []

    func load(_ catalog: [SteamGame]) async {
        async let livePopularityRanks = SteamChartsAPI.fetchPopularityRanks()
        let pending = catalog.filter { $0.appID != nil && !requestedIDs.contains($0.id) }
        requestedIDs.formUnion(pending.map(\.id))
        loadingIDs.formUnion(pending.map(\.id))

        for offset in stride(from: 0, to: pending.count, by: 6) {
            let batch = Array(pending[offset..<min(offset + 6, pending.count)])
            let results = await withTaskGroup(of: (String, SteamStoreGameData?).self) { group in
                for game in batch {
                    guard let appID = game.appID else { continue }
                    group.addTask {
                        (game.id, await SteamStoreAPI.fetchGameData(appID: appID))
                    }
                }
                var values: [(String, SteamStoreGameData?)] = []
                for await value in group { values.append(value) }
                return values
            }

            for (appID, data) in results {
                loadingIDs.remove(appID)
                if let data { games[appID] = data }
            }
        }

        if let ranks = await livePopularityRanks, !ranks.isEmpty {
            popularityRanks = ranks
        }
    }

    func popularityRank(for game: SteamGame) -> Int? {
        game.appID.flatMap { popularityRanks[$0] }
    }
}

private enum SteamChartsAPI {
    static func fetchPopularityRanks() async -> [String: Int]? {
        guard let url = URL(string: "https://api.steampowered.com/ISteamChartsService/GetMostPlayedGames/v1/") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else { return nil }
            let result = try JSONDecoder().decode(SteamChartsEnvelope.self, from: data)
            return Dictionary(uniqueKeysWithValues: result.response.ranks.map { (String($0.appID), $0.rank) })
        } catch {
            return nil
        }
    }
}

private struct SteamChartsEnvelope: Decodable {
    let response: SteamChartsResponse
}

private struct SteamChartsResponse: Decodable {
    let ranks: [SteamChartRank]
}

private struct SteamChartRank: Decodable {
    let rank: Int
    let appID: Int

    enum CodingKeys: String, CodingKey {
        case rank
        case appID = "appid"
    }
}

private enum SteamStoreAPI {
    static func fetchGameData(appID: String) async -> SteamStoreGameData? {
        guard let url = URL(string: "https://store.steampowered.com/api/appdetails?appids=\(appID)&l=en") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else { return nil }
            let result = try JSONDecoder().decode([String: SteamStoreAPIResponse].self, from: data)[appID]
            guard result?.success == true else { return nil }
            return result?.data
        } catch {
            return nil
        }
    }
}

private struct SteamStoreAPIResponse: Decodable, Sendable {
    let success: Bool
    let data: SteamStoreGameData?
}

struct SteamStoreGameData: Decodable, Sendable {
    let name: String?
    let headerImage: URL?
    let shortDescription: String?
    let isFree: Bool?
    let platforms: SteamStorePlatforms?

    enum CodingKeys: String, CodingKey {
        case name
        case headerImage = "header_image"
        case shortDescription = "short_description"
        case isFree = "is_free"
        case platforms
    }
}

struct SteamStorePlatforms: Decodable, Sendable {
    let mac: Bool?
}

struct SteamArtworkView: View {
    let url: URL?
    let symbol: String
    var isLoading = false

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                    } else if phase.error != nil {
                        fallback
                    } else {
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(maxWidth: .infinity)
        .clipped()
        .accessibilityLabel("Game artwork")
    }

    private var fallback: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.025, green: 0.08, blue: 0.18), Color(red: 0.02, green: 0.40, blue: 0.48)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(Color.cyan.opacity(0.18))
                .frame(width: 120, height: 120)
                .blur(radius: 24)
                .offset(x: 55, y: 20)
            Image(systemName: symbol)
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(.white.opacity(0.88))
            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .tint(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(9)
            }
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
