import AppKit
import Combine
import Foundation

@MainActor
final class LibraryModel: ObservableObject {
    @Published private(set) var entries: [GameEntry] = []
    @Published var selectedID: UUID?
    @Published private(set) var runningIDs: Set<UUID> = []
    @Published var notice: String?
    @Published var errorMessage: String?

    private var processes: [UUID: Process] = [:]
    private let fileManager = FileManager.default

    private var supportDirectory: URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WineShelf", isDirectory: true)
    }

    private var libraryURL: URL {
        supportDirectory.appendingPathComponent("library.json")
    }

    var selectedEntry: GameEntry? {
        entries.first { $0.id == selectedID }
    }

    init() {
        do {
            try fileManager.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
            let data = try Data(contentsOf: libraryURL)
            entries = try JSONDecoder().decode([GameEntry].self, from: data)
            selectedID = entries.first?.id
        } catch CocoaError.fileReadNoSuchFile {
            entries = []
        } catch {
            errorMessage = "WineShelf couldn't read its library. The saved file is still available at:\n\(libraryURL.path)\n\n\(error.localizedDescription)"
        }
    }

    func add(_ entry: GameEntry) {
        entries.append(entry)
        selectedID = entry.id
        persist()
    }

    func update(_ entry: GameEntry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[index] = entry
        persist()
    }

    func importCS2() {
        do {
            let entry = try WineRuntime.importExistingCS2()
            if let duplicate = entries.first(where: {
                $0.prefixPath == entry.prefixPath && $0.executablePath == entry.executablePath
            }) {
                selectedID = duplicate.id
                notice = "Counter-Strike 2 is already in your library. WineShelf selected the existing entry."
                return
            }
            add(entry)
            notice = "Counter-Strike 2 was added. WineShelf only saved its paths and launch settings; the game files and prefix were left in place."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func remove(_ entry: GameEntry) {
        guard !runningIDs.contains(entry.id) else {
            errorMessage = "Stop this Wine session before removing its library entry."
            return
        }
        entries.removeAll { $0.id == entry.id }
        if selectedID == entry.id { selectedID = entries.first?.id }
        persist()
    }

    func launch(_ entry: GameEntry) {
        guard !runningIDs.contains(entry.id) else { return }
        let logURL = logURL(for: entry)
        do {
            let process = try WineRuntime.start(entry, logURL: logURL) { [weak self] status in
                DispatchQueue.main.async {
                    self?.processFinished(id: entry.id, status: status)
                }
            }
            processes[entry.id] = process
            runningIDs.insert(entry.id)
            notice = "Started \(entry.name)."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stop(_ entry: GameEntry) {
        do {
            let status = try WineRuntime.stop(entry)
            guard status == 0 else {
                errorMessage = "Wine's wineserver returned exit code \(status). Check the session log for details."
                return
            }
            notice = "Sent a stop request to Wine for \(entry.name)'s prefix."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openLog(for entry: GameEntry) {
        let url = logURL(for: entry)
        guard fileManager.fileExists(atPath: url.path) else {
            errorMessage = "There isn't a launch log for this game yet. Launch it once, then try again."
            return
        }
        NSWorkspace.shared.open(url)
    }

    func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func logURL(for entry: GameEntry) -> URL {
        supportDirectory.appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("\(entry.id.uuidString).log")
    }

    private func processFinished(id: UUID, status: Int32) {
        processes[id] = nil
        runningIDs.remove(id)
        if status == 0 {
            notice = "Wine closed normally."
        } else {
            notice = "The Wine launcher exited with code \(status). The game may still be running; use Stop Wine to check the prefix."
        }
    }

    private func persist() {
        do {
            try fileManager.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(entries)
            try data.write(to: libraryURL, options: .atomic)
        } catch {
            errorMessage = "WineShelf couldn't save its library:\n\(error.localizedDescription)"
        }
    }
}
