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
    @State private var pendingSteamGame: SteamGame?
    @State private var shouldResumeExecutableAfterSetup = false
    @State private var isFileDropTargeted = false

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedDestination) {
                Section("DISCOVER") {
                    Label("Steam Games", systemImage: "gamecontroller")
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
                        Button("Browse Steam Games", systemImage: "gamecontroller") {
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
                SteamGamesView(library: library, onSetUpSteam: beginSteamGameSetup)
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
                    Button("Explore Steam Games", systemImage: "gamecontroller") { selectedDestination = .games }
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

        guard let game = pendingSteamGame else { return }
        pendingSteamGame = nil
        guard library.steamEntry != nil else {
            library.notice = "Steam is not installed yet. Open Wine Setup, install Steam, and try this game again."
            return
        }
        library.installSteamGame(game)
    }

    private func beginSteamGameSetup(for game: SteamGame) {
        pendingSteamGame = game
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top, spacing: 18) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 72, height: 72)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 18))
                    VStack(alignment: .leading, spacing: 7) {
                        Text(entry.name)
                            .font(.largeTitle.weight(.semibold))
                        Label(isRunning ? "Wine session active" : "Ready to launch", systemImage: isRunning ? "circle.fill" : "checkmark.circle")
                            .font(.subheadline)
                            .foregroundStyle(isRunning ? Color.green : Color.secondary)
                    }
                    Spacer()
                    if isRunning {
                        Button(role: .destructive) { isShowingStopConfirmation = true } label: {
                            Label("Stop Wine", systemImage: "stop.fill")
                        }
                        .controlSize(.large)
                    } else {
                        Button(action: onLaunch) {
                            Label("Launch", systemImage: "play.fill")
                        }
                        .controlSize(.large)
                        .keyboardShortcut(.defaultAction)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 14) {
                    Text("SETUP")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    PathCard(title: "Wine prefix", path: entry.prefixPath, icon: "shippingbox", action: onShowPrefix)
                    PathCard(title: "Windows app", path: entry.executablePath, icon: "app.dashed", action: onShowFiles)
                    PathCard(title: "Wine runtime", path: entry.winePath, icon: "wineglass", action: nil)
                }

                HStack(spacing: 12) {
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
                            .frame(width: 28, height: 24)
                    }
                    .menuStyle(.borderlessButton)
                }
                .buttonStyle(.bordered)

                Text("WineShelf stores launch settings in your user Library and starts this entry with its own prefix. Importing or removing a shortcut does not move or delete game files.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(32)
            .frame(maxWidth: 820, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("Stop this Wine session?", isPresented: $isShowingStopConfirmation) {
            Button("Stop Wine", role: .destructive, action: onStop)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This sends wineserver -k to the selected prefix. It closes all Wine apps using this same prefix, including Steam if it is running there.")
        }
    }
}

private struct PathCard: View {
    let title: String
    let path: String
    let icon: String
    let action: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.medium))
                Text(path)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 8)
            if let action {
                Button(action: action) {
                    Image(systemName: "arrow.up.right.square")
                }
                .buttonStyle(.borderless)
                .help("Show in Finder")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.quaternary))
    }
}
