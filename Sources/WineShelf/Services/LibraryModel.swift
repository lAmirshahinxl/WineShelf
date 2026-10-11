import AppKit
import Combine
import Foundation

@MainActor
final class LibraryModel: ObservableObject {
    @Published private(set) var entries: [GameEntry] = []
    @Published var selectedID: UUID?
    @Published private(set) var runningIDs: Set<UUID> = []
    @Published private(set) var preparingExecutable: String?
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

    var steamEntry: GameEntry? {
        entries.first {
            $0.name.caseInsensitiveCompare("Steam") == .orderedSame
                && $0.executableURL.lastPathComponent.caseInsensitiveCompare("steam.exe") == .orderedSame
        } ?? entries.first {
            $0.executableURL.lastPathComponent.caseInsensitiveCompare("steam.exe") == .orderedSame
        }
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

    func steamGameEntry(for game: SteamGame) -> GameEntry? {
        guard let steamEntry else { return nil }
        return entries.first {
            $0.executablePath == steamEntry.executablePath
                && $0.prefixPath == steamEntry.prefixPath
                && $0.arguments == ["-applaunch", game.appID]
        }
    }

    func isSteamGameInstalled(_ game: SteamGame) -> Bool {
        guard let steamEntry else { return false }
        let manifest = steamEntry.prefixURL.appendingPathComponent(
            "drive_c/Program Files (x86)/Steam/steamapps/appmanifest_\(game.appID).acf"
        )
        guard let contents = try? String(contentsOf: manifest, encoding: .utf8),
              let flagsLine = contents.split(whereSeparator: \.isNewline).first(where: { $0.contains("\"StateFlags\"") }) else {
            return false
        }
        let fields = flagsLine.split(separator: "\"")
        guard fields.count > 3, let flags = Int(fields[3]) else { return false }
        return flags & 4 != 0
    }

    func installSteamGame(_ game: SteamGame) {
        guard let steamEntry else {
            errorMessage = "Install Steam from Wine Setup before installing games."
            return
        }

        var installRequest = steamEntry
        installRequest.id = UUID()
        installRequest.name = "Install \(game.name)"
        installRequest.arguments = ["steam://install/\(game.appID)"]

        do {
            let requestID = installRequest.id
            let process = try WineRuntime.start(installRequest, logURL: logURL(for: installRequest)) { [weak self] _ in
                DispatchQueue.main.async {
                    self?.processes[requestID] = nil
                }
            }
            processes[requestID] = process

            if let existing = steamGameEntry(for: game) {
                selectedID = existing.id
            } else {
                add(steamGameShortcut(for: game, steamEntry: steamEntry))
            }
            notice = "Steam opened the install page for \(game.name). Complete the download in Steam, then launch it from your WineShelf library."
        } catch {
            errorMessage = "WineShelf couldn't open Steam for \(game.name):\n\(error.localizedDescription)"
        }
    }

    func addSteamGameShortcut(_ game: SteamGame) {
        guard let steamEntry else {
            errorMessage = "Install Steam from Wine Setup before adding a game shortcut."
            return
        }
        if let existing = steamGameEntry(for: game) {
            selectedID = existing.id
            notice = "\(game.name) is already in your WineShelf library."
            return
        }
        add(steamGameShortcut(for: game, steamEntry: steamEntry))
        notice = "Added \(game.name) to your WineShelf library."
    }

    func launchExecutable(_ executableURL: URL, using runtime: DetectedWineRuntime) {
        let executableURL = executableURL.standardizedFileURL
        let executablePath = GameEntry.normalizedPath(executableURL.path)
        guard executableURL.pathExtension.lowercased() == "exe" else {
            errorMessage = "Choose a Windows executable file ending in .exe."
            return
        }
        guard fileManager.isReadableFile(atPath: executablePath) else {
            errorMessage = "WineShelf can't read this executable:\n\(executablePath)"
            return
        }
        if let existing = entries.first(where: { $0.executablePath == executablePath }) {
            selectedID = existing.id
            launch(existing)
            return
        }
        guard preparingExecutable == nil else { return }

        let name = executableURL.deletingPathExtension().lastPathComponent
        let entry = GameEntry(
            name: name,
            executablePath: executablePath,
            prefixPath: supportDirectory.appendingPathComponent("Prefixes/Direct-\(UUID().uuidString)", isDirectory: true).path,
            winePath: runtime.winePath,
            wineServerPath: runtime.wineServerPath
        )
        let setupLogURL = supportDirectory.appendingPathComponent("Logs/prefix-\(entry.id.uuidString).log")
        preparingExecutable = name

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result { try WineRuntime.createPrefix(for: entry, logURL: setupLogURL) }
            DispatchQueue.main.async {
                guard let self else { return }
                self.preparingExecutable = nil
                switch result {
                case .success:
                    self.add(entry)
                    self.launch(entry)
                case .failure(let error):
                    self.errorMessage = "WineShelf couldn't prepare \(name):\n\(error.localizedDescription)"
                }
            }
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

    private func steamGameShortcut(for game: SteamGame, steamEntry: GameEntry) -> GameEntry {
        GameEntry(
            name: game.name,
            executablePath: steamEntry.executablePath,
            prefixPath: steamEntry.prefixPath,
            winePath: steamEntry.winePath,
            wineServerPath: steamEntry.wineServerPath,
            arguments: ["-applaunch", game.appID]
        )
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
