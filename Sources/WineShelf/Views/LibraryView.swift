import AppKit
import SwiftUI
import UniformTypeIdentifiers

private enum LibraryDestination: Hashable {
    case games
    case app(UUID)
}

struct LibraryView: View {
    @ObservedObject var library: LibraryModel
    @State private var selectedDestination: LibraryDestination = .games
    @State private var didInitializeDestination = false
    @State private var isShowingEditor = false
    @State private var editingEntry: GameEntry?
    @State private var removalCandidate: GameEntry?
    @State private var isShowingRemovalConfirmation = false
    @State private var isShowingRuntimeSetup = false
    @State private var pendingExecutableURL: URL?
    @State private var pendingGameSetup: (game: SteamGame, storefront: GameStorefront)?
    @State private var shouldResumeExecutableAfterSetup = false
    @State private var isFileDropTargeted = false

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedDestination) {
                Section("DISCOVER") {
                    Label("Game Profiles", systemImage: "gamecontroller")
                        .tag(LibraryDestination.games)
                }
                Section("LIBRARY") {
                    ForEach(library.entries) { entry in
                        LibraryRow(entry: entry, isRunning: library.runningIDs.contains(entry.id))
                            .tag(LibraryDestination.app(entry.id))
                            .contextMenu {
                                Button("Edit Settings…", systemImage: "slider.horizontal.3") { edit(entry) }
                                    .disabled(library.runningIDs.contains(entry.id))
                                Button("Show in Finder", systemImage: "folder") { library.reveal(entry.executableURL) }
                                Divider()
                                Button("Remove from Library…", systemImage: "minus.circle", role: .destructive) {
                                    removalCandidate = entry
                                    isShowingRemovalConfirmation = true
                                }
                            }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("WineShelf")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        isShowingRuntimeSetup = true
                    } label: {
                        Label("Wine Setup", systemImage: "wineglass")
                    }
                    .help("Check or install Wine and its macOS requirements")
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Browse Game Profiles", systemImage: "gamecontroller") {
                            selectedDestination = .games
                        }
                        Divider()
                        Button("Run Windows .exe…", systemImage: "play.rectangle") {
                            chooseExecutableToRun()
                        }
                        .disabled(library.preparingExecutable != nil)
                        Button("Add Windows App…", systemImage: "plus.app") {
                            editingEntry = nil
                            isShowingEditor = true
                        }
                        .disabled(library.preparingExecutable != nil)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .help("Add a game or Windows app")
                }
            }
        } detail: {
            if selectedDestination == .games {
                SteamGamesView(library: library, onSetUpStore: beginGameSetup)
            } else if let entry = library.selectedEntry {
                GameDetailView(
                    entry: entry,
                    isRunning: library.runningIDs.contains(entry.id),
                    onLaunch: { library.launch(entry) },
                    onStop: { library.stop(entry) },
                    onEdit: { edit(entry) },
                    onOpenLog: { library.openLog(for: entry) },
                    onShowFiles: { library.reveal(entry.executableURL) },
                    onShowPrefix: { library.reveal(entry.prefixURL) },
                    onRemove: {
                        removalCandidate = entry
                        isShowingRemovalConfirmation = true
                    }
                )
            } else {
                ContentUnavailableView {
                    Label("No Games Yet", systemImage: "wineglass")
                } description: {
                    Text("Choose a Windows .exe to launch it in Wine, or add an app to your library. You can also drag an .exe onto this window.")
                } actions: {
                    Button("Explore Game Profiles", systemImage: "gamecontroller") { selectedDestination = .games }
                    Button("Run Windows .exe…", systemImage: "play.rectangle", action: chooseExecutableToRun)
                        .disabled(library.preparingExecutable != nil)
                }
            }
        }
        .sheet(isPresented: $isShowingEditor) {
            EntryEditorView(entry: editingEntry) { savedEntry in
                if editingEntry == nil { library.add(savedEntry) } else { library.update(savedEntry) }
                isShowingEditor = false
            } onCancel: {
                isShowingEditor = false
            }
            .frame(minWidth: 640, minHeight: 560)
        }
        .sheet(isPresented: $isShowingRuntimeSetup, onDismiss: resumeAfterSetup) {
            RuntimeSetupView(onSteamAdded: { steamEntry in
                if let existing = library.entries.first(where: {
                    $0.prefixPath == steamEntry.prefixPath && $0.executablePath == steamEntry.executablePath
                }) {
                    library.selectedID = existing.id
                    library.notice = "Steam is already in your WineShelf library."
                } else {
                    library.add(steamEntry)
                    library.notice = "Steam was added. Sign in and install games from Steam."
                }
            }, onDone: {
                shouldResumeExecutableAfterSetup = true
            })
        }
        .alert("Remove this entry?", isPresented: $isShowingRemovalConfirmation, presenting: removalCandidate) { entry in
            Button("Remove Entry", role: .destructive) { library.remove(entry) }
            Button("Cancel", role: .cancel) { removalCandidate = nil }
        } message: { entry in
            Text("This removes \(entry.name) from WineShelf. Its game files, prefix, and Wine runtime stay on disk.")
        }
        .alert("WineShelf", isPresented: Binding(
            get: { library.errorMessage != nil },
            set: { if !$0 { library.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { library.errorMessage = nil }
        } message: {
            Text(library.errorMessage ?? "")
        }
        .alert("WineShelf", isPresented: Binding(
            get: { library.notice != nil },
            set: { if !$0 { library.notice = nil } }
        )) {
            Button("OK", role: .cancel) { library.notice = nil }
        } message: {
            Text(library.notice ?? "")
        }
        .onDrop(of: [UTType.fileURL], isTargeted: $isFileDropTargeted, perform: receiveDroppedFile)
        .onAppear {
            guard !didInitializeDestination else { return }
            didInitializeDestination = true
            selectedDestination = library.selectedID.map(LibraryDestination.app) ?? .games
        }
        .onChange(of: selectedDestination) { _, destination in
            if case .app(let id) = destination { library.selectedID = id }
        }
        .onChange(of: library.selectedID) { _, id in
            guard selectedDestination != .games else { return }
            selectedDestination = id.map(LibraryDestination.app) ?? .games
        }
        .overlay(alignment: .top) {
            if isFileDropTargeted {
                Label("Drop a Windows .exe to launch it", systemImage: "arrow.down.doc.fill")
                    .font(.callout.weight(.medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.top, 12)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Drop a Windows executable to launch it")
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if let name = library.preparingExecutable {
                HStack(spacing: 9) {
                    ProgressView().controlSize(.small)
                    Text("Preparing \(name)…")
                        .font(.callout)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: Capsule())
                .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
                .padding(18)
                .accessibilityElement(children: .combine)
            }
        }
        .background {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()
        }
    }

    private func edit(_ entry: GameEntry) {
        editingEntry = entry
        isShowingEditor = true
    }

    private func chooseExecutableToRun() {
        let panel = NSOpenPanel()
        panel.title = "Choose a Windows executable to run"
        panel.message = "WineShelf will create a Wine prefix, launch the executable, and add it to your library."
        panel.allowedContentTypes = [UTType(filenameExtension: "exe") ?? .data]
        panel.allowsOtherFileTypes = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        pendingExecutableURL = url
        launchPendingExecutableIfReady()
    }

    private func launchPendingExecutableIfReady() {
        guard let url = pendingExecutableURL else { return }
        guard let runtime = RuntimeSetupModel.runtimeReadyForDirectLaunch() else {
            isShowingRuntimeSetup = true
            return
        }
        pendingExecutableURL = nil
        library.launchExecutable(url, using: runtime)
    }

    private func resumeAfterSetup() {
        if let url = pendingExecutableURL {
            pendingExecutableURL = nil
            if shouldResumeExecutableAfterSetup {
                shouldResumeExecutableAfterSetup = false
                guard let runtime = RuntimeSetupModel.runtimeReadyForDirectLaunch() else {
                    library.errorMessage = "Wine isn't ready yet. Finish the required steps in Wine Setup, then choose the .exe again."
                    return
                }
                library.launchExecutable(url, using: runtime)
            }
        }

        guard let setup = pendingGameSetup else { return }
        pendingGameSetup = nil
        if setup.storefront == .steam {
            guard library.steamEntry != nil else {
                library.notice = "Steam is not installed yet. Open Wine Setup, install Steam, and try this game again."
                return
            }
            library.openSteamGamePage(setup.game)
        } else {
            library.notice = "Wine is ready. Download the Battle.net PC installer, choose + → Run Windows .exe…, then edit its WineShelf entry to use Battle.net.exe in the same prefix."
        }
    }

    private func beginGameSetup(for game: SteamGame, storefront: GameStorefront) {
        pendingGameSetup = (game, storefront)
        isShowingRuntimeSetup = true
    }

    private func receiveDroppedFile(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            let url = (item as? URL) ?? (item as? Data).flatMap { URL(dataRepresentation: $0, relativeTo: nil) }
            guard let url else { return }
            DispatchQueue.main.async {
                pendingExecutableURL = url
                launchPendingExecutableIfReady()
            }
        }
        return true
    }
}

private struct LibraryRow: View {
    let entry: GameEntry
    let isRunning: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(isRunning ? Color.green : Color.accentColor)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.name).lineLimit(1)
                Text(isRunning ? "Running" : "Wine app")
                    .font(.caption)
                    .foregroundStyle(isRunning ? Color.green : Color.secondary)
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }
}

private struct GameDetailView: View {
    let entry: GameEntry
    let isRunning: Bool
    let onLaunch: () -> Void
    let onStop: () -> Void
    let onEdit: () -> Void
    let onOpenLog: () -> Void
    let onShowFiles: () -> Void
    let onShowPrefix: () -> Void
    let onRemove: () -> Void

    @State private var isShowingStopConfirmation = false
    @StateObject private var artworkStore = SteamGameStoreModel()
    @ObservedObject private var profileCatalog = GameProfileCatalogStore.shared

    private var catalogGame: SteamGame? {
        profileCatalog.game(named: entry.name)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                gameHero
                environmentSection
                detailActions
                storageNote
            }
            .padding(32)
            .frame(maxWidth: 1120, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task(id: entry.id) {
            guard let catalogGame else { return }
            await artworkStore.load([catalogGame])
        }
        .alert("Stop this Wine session?", isPresented: $isShowingStopConfirmation) {
            Button("Stop Wine", role: .destructive, action: onStop)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This sends wineserver -k to the selected prefix. It closes all Wine apps using this same prefix, including Steam if it is running there.")
        }
    }

    private var gameHero: some View {
        ZStack(alignment: .leading) {
            gameArtwork
                .frame(maxWidth: .infinity)
                .frame(height: 280)

            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.42), location: 0),
                    .init(color: .black.opacity(0.06), location: 0.48),
                    .init(color: .black.opacity(0.82), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Text("WINE LIBRARY")
                        .font(.caption.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    primaryAction
                }

                Spacer(minLength: 20)

                VStack(alignment: .leading, spacing: 8) {
                    Text(entry.name)
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    Text(catalogGame?.genre ?? "Windows app")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.8))
                    Label(
                        isRunning ? "Wine session active" : "Ready to launch",
                        systemImage: isRunning ? "circle.fill" : "checkmark.circle.fill"
                    )
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(isRunning ? Color.green : Color.white)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background(.white.opacity(0.14), in: Capsule())
                    .padding(.top, 3)
                }
            }
            .padding(26)
        }
        .frame(height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.12))
        }
    }

    @ViewBuilder
    private var gameArtwork: some View {
        if let catalogGame {
            SteamArtworkView(
                url: artworkStore.games[catalogGame.id]?.headerImage,
                symbol: catalogGame.symbol,
                isLoading: artworkStore.loadingIDs.contains(catalogGame.id)
            )
        } else {
            SteamArtworkView(url: nil, symbol: "gamecontroller.fill")
        }
    }

    @ViewBuilder
    private var primaryAction: some View {
        if isRunning {
            Button(role: .destructive) { isShowingStopConfirmation = true } label: {
                Label("Stop Wine", systemImage: "stop.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.large)
        } else {
            Button(action: onLaunch) {
                Label("Launch", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
    }

    private var environmentSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Wine environment")
                    .font(.title3.weight(.semibold))
                Text("The files WineShelf uses to run this entry.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                PathCard(title: "Wine prefix", path: entry.prefixPath, icon: "shippingbox", action: onShowPrefix)
                HStack(spacing: 12) {
                    PathCard(title: "Windows app", path: entry.executablePath, icon: "app.dashed", action: onShowFiles)
                    PathCard(title: "Wine runtime", path: entry.winePath, icon: "wineglass", action: nil)
                }
            }
        }
    }

    private var detailActions: some View {
        HStack(spacing: 10) {
            Button(action: onEdit) { Label("Edit Settings", systemImage: "slider.horizontal.3") }
                .disabled(isRunning)
            Button(action: onOpenLog) { Label("Open Last Log", systemImage: "doc.text") }
            Menu {
                Button("Show Game File in Finder", systemImage: "folder", action: onShowFiles)
                Button("Show Wine Prefix in Finder", systemImage: "shippingbox", action: onShowPrefix)
                Divider()
                Button("Stop Wine Apps Using This Prefix", systemImage: "stop.fill", role: .destructive) {
                    isShowingStopConfirmation = true
                }
                Divider()
                Button("Remove from Library…", systemImage: "minus.circle", role: .destructive, action: onRemove)
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 32, height: 24)
            }
            .menuStyle(.borderlessButton)
            .help("More actions")
        }
        .buttonStyle(.bordered)
    }

    private var storageNote: some View {
        Label {
            Text("WineShelf keeps these files in your Library. Removing this entry does not delete them.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct PathCard: View {
    let title: String
    let path: String
    let icon: String
    let action: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Label(title, systemImage: icon)
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 8)
                if let action {
                    Button(action: action) {
                        Image(systemName: "arrow.up.right.square")
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.borderless)
                    .help("Show in Finder")
                    .accessibilityLabel("Show \(title) in Finder")
                }
            }

            Text(path)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .help(path)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 114, alignment: .topLeading)
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.quaternary))
    }
}
