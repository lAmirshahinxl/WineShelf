import AppKit
import SwiftUI

struct LibraryView: View {
    @ObservedObject var library: LibraryModel
    @State private var isShowingEditor = false
    @State private var editingEntry: GameEntry?
    @State private var removalCandidate: GameEntry?
    @State private var isShowingRemovalConfirmation = false

    var body: some View {
        NavigationSplitView {
            List(selection: $library.selectedID) {
                Section("LIBRARY") {
                    ForEach(library.entries) { entry in
                        LibraryRow(entry: entry, isRunning: library.runningIDs.contains(entry.id))
                            .tag(entry.id)
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
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Import GameToMac CS2 Setup…", systemImage: "square.and.arrow.down") {
                            library.importCS2()
                        }
                        Button("Add Windows App…", systemImage: "plus.app") {
                            editingEntry = nil
                            isShowingEditor = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .help("Add a game or Windows app")
                }
            }
        } detail: {
            if let entry = library.selectedEntry {
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
                    Text("Import the existing Counter-Strike 2 setup or add a Windows app and its Wine prefix.")
                } actions: {
                    Menu("Add to Library") {
                        Button("Import GameToMac CS2 Setup…", systemImage: "square.and.arrow.down") { library.importCS2() }
                        Button("Add Windows App…", systemImage: "plus.app") {
                            editingEntry = nil
                            isShowingEditor = true
                        }
                    }
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
    }

    private func edit(_ entry: GameEntry) {
        editingEntry = entry
        isShowingEditor = true
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
