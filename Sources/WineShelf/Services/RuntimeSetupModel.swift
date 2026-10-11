import AppKit
import Combine
import CryptoKit
import Foundation

struct DetectedWineRuntime: Identifiable, Hashable {
    let name: String
    let winePath: String
    let wineServerPath: String
    let bundlePath: String?

    var id: String { winePath }
    var bundleURL: URL? { bundlePath.map { URL(fileURLWithPath: $0, isDirectory: true) } }
}

@MainActor
final class RuntimeSetupModel: ObservableObject {
    @Published private(set) var runtimes: [DetectedWineRuntime] = []
    @Published var selectedRuntimeID: String?
    @Published private(set) var isRosettaAvailable = false
    @Published private(set) var isGStreamerInstalled = false
    @Published private(set) var isDownloadingWine = false
    @Published private(set) var isDownloadingGStreamer = false
    @Published private(set) var isInstallingSteam = false
    @Published private(set) var statusMessage: String?
    @Published var errorMessage: String?

    private let fileManager = FileManager.default

    static let wineVersion = "11.18"
    static let wineSHA256 = "aa0ea4c82e636ae7bca2076387cb0a5affa26509ad13f119ecd0d62bd7ba6f82"
    static let wineSource = URL(string: "https://github.com/Gcenx/macOS_Wine_builds/releases/download/11.18/wine-devel-11.18-osx64.tar.xz")!
    static let gstreamerVersion = "1.28.7"
    static let gstreamerSHA256 = "529fdf4a4027d942e59b5b3564f6400adaa008f63ce5f3fed4ffe35d73911994"
    static let gstreamerSource = URL(string: "https://gstreamer.freedesktop.org/data/pkg/osx/1.28.7/gstreamer-1.0-1.28.7-universal.pkg")!
    static let steamSetupSource = URL(string: "https://cdn.fastly.steamstatic.com/client/installer/SteamSetup.exe")!

    var selectedRuntime: DetectedWineRuntime? {
        runtimes.first { $0.id == selectedRuntimeID } ?? runtimes.first
    }

    var isAppleSilicon: Bool {
        var machine = utsname()
        uname(&machine)
        return withUnsafePointer(to: &machine.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) == "arm64" }
        }
    }

    init() {
        refresh()
    }

    func refresh() {
        let previousSelection = selectedRuntimeID
        runtimes = RuntimeDiscovery.findRuntimes()
        if let previousSelection, runtimes.contains(where: { $0.id == previousSelection }) {
            selectedRuntimeID = previousSelection
        } else {
            selectedRuntimeID = runtimes.first?.id
        }
        isRosettaAvailable = !isAppleSilicon || fileManager.fileExists(atPath: "/Library/Apple/usr/libexec/oah/libRosettaRuntime")
        isGStreamerInstalled = fileManager.fileExists(atPath: "/Library/Frameworks/GStreamer.framework/Versions/Current")
    }

    func installWine() async {
        guard !isDownloadingWine else { return }
        isDownloadingWine = true
        statusMessage = "Downloading and verifying Wine (Self.wineVersion)…"
        defer { isDownloadingWine = false }

        do {
            let downloads = try downloadDirectory()
            let archive = try await verifiedDownload(
                from: Self.wineSource,
                fileName: "wine-devel-\(Self.wineVersion)-osx64.tar.xz",
                expectedSHA256: Self.wineSHA256,
                in: downloads
            )
            statusMessage = "Checking the Wine archive…"
            let install = try installWineArchive(archive)
            refresh()
            selectedRuntimeID = install.winePath
            statusMessage = "Wine is installed. Approve the Wine app in Finder before using it."
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = nil
        }
    }

    func installGStreamer() async {
        guard !isDownloadingGStreamer else { return }
        isDownloadingGStreamer = true
        statusMessage = "Downloading and verifying GStreamer (Self.gstreamerVersion)…"
        defer { isDownloadingGStreamer = false }

        do {
            let downloads = try downloadDirectory()
            let package = try await verifiedDownload(
                from: Self.gstreamerSource,
                fileName: "gstreamer-1.0-\(Self.gstreamerVersion)-universal.pkg",
                expectedSHA256: Self.gstreamerSHA256,
                in: downloads
            )
            guard NSWorkspace.shared.open(package) else {
                throw RuntimeSetupError.install("The verified package is saved here:\n\(package.path)\nOpen it in Finder to continue.")
            }
            statusMessage = "Installer is open. Complete the GStreamer installation, then choose Check again. macOS may ask for an administrator password."
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = nil
        }
    }

    func installSteam() async -> GameEntry? {
        guard !isInstallingSteam else { return nil }
        guard isRosettaAvailable, isGStreamerInstalled, let runtime = selectedRuntime else {
            errorMessage = "Finish the Rosetta and GStreamer requirements and choose a Wine runtime before installing Steam."
            return nil
        }
        isInstallingSteam = true
        statusMessage = "Preparing a Wine prefix for Steam…"
        defer { isInstallingSteam = false }

        do {
            let prefix = supportDirectory.appendingPathComponent("Prefixes/Steam", isDirectory: true)
            let steamExecutable = prefix.appendingPathComponent("drive_c/Program Files (x86)/Steam/steam.exe")
            if fileManager.isReadableFile(atPath: steamExecutable.path) {
                statusMessage = "Steam is already installed in WineShelf's Steam prefix."
                return steamEntry(runtime: runtime, prefix: prefix, executable: steamExecutable)
            }

            let downloads = try downloadDirectory()
            let installer = try await downloadSteamSetup(in: downloads)
            let setupLog = supportDirectory.appendingPathComponent("Logs/steam-setup.log")
            let setupEntry = GameEntry(
                name: "Steam Setup",
                executablePath: installer.path,
                prefixPath: prefix.path,
                winePath: runtime.winePath,
                wineServerPath: runtime.wineServerPath
            )

            if !fileManager.fileExists(atPath: prefix.appendingPathComponent("system.reg").path) {
                statusMessage = "Creating the Steam Wine prefix…"
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    DispatchQueue.global(qos: .userInitiated).async {
                        do {
                            try WineRuntime.createPrefix(for: setupEntry, logURL: setupLog)
                            continuation.resume()
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }
            }

            statusMessage = "Steam Setup is running in Wine. Complete its windows to install Steam."
            let process = try WineRuntime.start(setupEntry, logURL: setupLog)
            let exitStatus = await withCheckedContinuation { (continuation: CheckedContinuation<Int32, Never>) in
                DispatchQueue.global(qos: .userInitiated).async {
                    process.waitUntilExit()
                    continuation.resume(returning: process.terminationStatus)
                }
            }
            guard fileManager.isReadableFile(atPath: steamExecutable.path) else {
                throw RuntimeSetupError.install("Steam Setup closed before steam.exe appeared. If you completed the installation, choose Check again and retry. Setup log:\n\(setupLog.path) (exit code \(exitStatus))")
            }
            statusMessage = "Steam is installed. WineShelf added it to your library."
            return steamEntry(runtime: runtime, prefix: prefix, executable: steamExecutable)
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = nil
            return nil
        }
    }

    func revealSelectedRuntime() {
        guard let bundle = selectedRuntime?.bundleURL else {
            errorMessage = "This Wine installation is a command-line runtime and has no app bundle to approve in Finder."
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([bundle])
        statusMessage = "In Finder, Control-click the Wine app, choose Open, and confirm the macOS prompt. Then choose Check again here."
    }

    func openRosettaInstructions() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("softwareupdate --install-rosetta", forType: .string)
        statusMessage = "Copied the command. Run it in Terminal and accept Apple's license when prompted, then choose Check again."
    }

    func openWineSource() {
        NSWorkspace.shared.open(URL(string: "https://github.com/Gcenx/macOS_Wine_builds/releases/tag/\(Self.wineVersion)")!)
    }

    func openGStreamerSource() {
        NSWorkspace.shared.open(URL(string: "https://gstreamer.freedesktop.org/download/")!)
    }

    private func downloadDirectory() throws -> URL {
        let url = supportDirectory.appendingPathComponent("Downloads", isDirectory: true)
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private var supportDirectory: URL {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WineShelf", isDirectory: true)
    }

    private func verifiedDownload(from source: URL, fileName: String, expectedSHA256: String, in directory: URL) async throws -> URL {
        let destination = directory.appendingPathComponent(fileName)
        if fileManager.fileExists(atPath: destination.path), try sha256(of: destination) == expectedSHA256 {
            return destination
        }
        try? fileManager.removeItem(at: destination)

        var request = URLRequest(url: source)
        request.timeoutInterval = 60 * 30
        let (temporaryURL, response) = try await URLSession.shared.download(for: request)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw RuntimeSetupError.download("The download server did not return the requested file.")
        }
        let actualHash = try sha256(of: temporaryURL)
        guard actualHash.caseInsensitiveCompare(expectedSHA256) == .orderedSame else {
            try? fileManager.removeItem(at: temporaryURL)
            throw RuntimeSetupError.integrity(fileName)
        }
        try fileManager.moveItem(at: temporaryURL, to: destination)
        return destination
    }

    private func downloadSteamSetup(in directory: URL) async throws -> URL {
        let destination = directory.appendingPathComponent("SteamSetup.exe")
        try? fileManager.removeItem(at: destination)
        var request = URLRequest(url: Self.steamSetupSource)
        request.timeoutInterval = 60 * 10
        let (temporaryURL, response) = try await URLSession.shared.download(for: request)
        guard let response = response as? HTTPURLResponse,
              (200..<300).contains(response.statusCode),
              let host = response.url?.host,
              host == "store.steampowered.com" || host.hasSuffix(".steamstatic.com") else {
            throw RuntimeSetupError.download("Steam Setup did not come from Valve's Steam website or CDN.")
        }
        let file = try FileHandle(forReadingFrom: temporaryURL)
        let header = try file.read(upToCount: 2) ?? Data()
        try? file.close()
        guard header == Data([0x4d, 0x5a]) else {
            try? fileManager.removeItem(at: temporaryURL)
            throw RuntimeSetupError.download("The Steam Setup download was not a Windows executable.")
        }
        try fileManager.moveItem(at: temporaryURL, to: destination)
        return destination
    }

    private func steamEntry(runtime: DetectedWineRuntime, prefix: URL, executable: URL) -> GameEntry {
        GameEntry(
            name: "Steam",
            executablePath: executable.path,
            prefixPath: prefix.path,
            winePath: runtime.winePath,
            wineServerPath: runtime.wineServerPath
        )
    }

    private func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1024 * 1024), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private func installWineArchive(_ archive: URL) throws -> DetectedWineRuntime {
        let root = supportDirectory.appendingPathComponent("Runtimes", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        let stage = root.appendingPathComponent(".install-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: stage, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: stage) }

        let listing = try runTar(arguments: ["-tJf", archive.path])
        let entries = listing.split(whereSeparator: \.isNewline).map(String.init)
        guard !entries.isEmpty,
              entries.allSatisfy({ isSafeWineArchiveEntry($0) }),
              entries.contains(where: { $0.hasPrefix("Wine Devel.app/") }) else {
            throw RuntimeSetupError.archive("The Wine archive did not contain the expected Wine Devel.app bundle.")
        }
        _ = try runTar(arguments: ["-xJf", archive.path, "-C", stage.path])

        let extractedBundle = stage.appendingPathComponent("Wine Devel.app", isDirectory: true)
        let wine = extractedBundle.appendingPathComponent("Contents/Resources/wine/bin/wine")
        let server = extractedBundle.appendingPathComponent("Contents/Resources/wine/bin/wineserver")
        guard fileManager.isExecutableFile(atPath: wine.path), fileManager.isExecutableFile(atPath: server.path) else {
            throw RuntimeSetupError.archive("Wine was extracted, but its wine and wineserver binaries were not found.")
        }

        let installedBundle = root.appendingPathComponent("Wine Devel \(Self.wineVersion).app", isDirectory: true)
        if fileManager.fileExists(atPath: installedBundle.path) {
            let existingWine = installedBundle.appendingPathComponent("Contents/Resources/wine/bin/wine")
            let existingServer = installedBundle.appendingPathComponent("Contents/Resources/wine/bin/wineserver")
            if fileManager.isExecutableFile(atPath: existingWine.path), fileManager.isExecutableFile(atPath: existingServer.path) {
                return DetectedWineRuntime(name: "Wine Devel \(Self.wineVersion) (WineShelf)", winePath: existingWine.path, wineServerPath: existingServer.path, bundlePath: installedBundle.path)
            }
            throw RuntimeSetupError.install("An incomplete WineShelf runtime already exists at:\n\(installedBundle.path)\nRemove that folder in Finder and try again.")
        }
        try fileManager.moveItem(at: extractedBundle, to: installedBundle)
        let installedWine = installedBundle.appendingPathComponent("Contents/Resources/wine/bin/wine")
        let installedServer = installedBundle.appendingPathComponent("Contents/Resources/wine/bin/wineserver")
        return DetectedWineRuntime(name: "Wine Devel \(Self.wineVersion) (WineShelf)", winePath: installedWine.path, wineServerPath: installedServer.path, bundlePath: installedBundle.path)
    }

    private func isSafeWineArchiveEntry(_ entry: String) -> Bool {
        guard !entry.hasPrefix("/") else { return false }
        let components = entry.split(separator: "/", omittingEmptySubsequences: true)
        return !components.contains("..") && components.first == "Wine Devel.app"
    }

    private func runTar(arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let output = String(data: data, encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw RuntimeSetupError.archive(output.isEmpty ? "The Wine archive could not be read." : output)
        }
        return output
    }

}

private enum RuntimeDiscovery {
    static func findRuntimes() -> [DetectedWineRuntime] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        var candidates: [URL] = [
            URL(fileURLWithPath: "/opt/homebrew/bin/wine"),
            URL(fileURLWithPath: "/usr/local/bin/wine"),
            URL(fileURLWithPath: "/opt/local/bin/wine")
        ]
        let support = home.appendingPathComponent("Library/Application Support/WineShelf/Runtimes", isDirectory: true)
        candidates += wineBinaries(in: support)
        candidates += wineBinaries(in: URL(fileURLWithPath: "/Applications", isDirectory: true))
        candidates += wineBinaries(in: home.appendingPathComponent("Applications", isDirectory: true))
        candidates += gameToMacWineBinaries(under: home.appendingPathComponent("Library/Application Support/Game Library/Games", isDirectory: true))

        var seen = Set<String>()
        return candidates.compactMap { candidate in
            let resolved = candidate.resolvingSymlinksInPath().standardizedFileURL
            let winePath = resolved.path
            let server = resolved.deletingLastPathComponent().appendingPathComponent("wineserver")
            guard seen.insert(winePath).inserted,
                  fm.isExecutableFile(atPath: winePath),
                  fm.isExecutableFile(atPath: server.path) else { return nil }
            let bundle = containingAppBundle(for: resolved)
            let name = bundle?.deletingPathExtension().lastPathComponent ?? resolved.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent
            return DetectedWineRuntime(name: name, winePath: winePath, wineServerPath: server.path, bundlePath: bundle?.path)
        }.sorted { lhs, rhs in
            if lhs.name.contains("WineShelf") != rhs.name.contains("WineShelf") { return lhs.name.contains("WineShelf") }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private static func wineBinaries(in root: URL) -> [URL] {
        guard let items = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey]) else { return [] }
        var results: [URL] = []
        for item in items where item.pathExtension == "app" || item.lastPathComponent.hasPrefix("engine-") {
            results.append(contentsOf: [
                item.appendingPathComponent("Contents/Resources/wine/bin/wine"),
                item.appendingPathComponent("Contents/Resources/bin/wine"),
                item.appendingPathComponent("bin/wine")
            ])
        }
        return results
    }

    private static func gameToMacWineBinaries(under root: URL) -> [URL] {
        guard let games = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey]) else { return [] }
        return games.flatMap { game in
            (try? FileManager.default.contentsOfDirectory(at: game, includingPropertiesForKeys: [.isDirectoryKey]))?.compactMap { engine in
                guard engine.lastPathComponent.hasPrefix("engine-") else { return nil }
                return engine.appendingPathComponent("bin/wine")
            } ?? []
        }
    }

    private static func containingAppBundle(for url: URL) -> URL? {
        var current = url.deletingLastPathComponent()
        while current.path != "/" {
            if current.pathExtension == "app" { return current }
            current.deleteLastPathComponent()
        }
        return nil
    }
}

private enum RuntimeSetupError: LocalizedError {
    case download(String)
    case integrity(String)
    case archive(String)
    case install(String)

    var errorDescription: String? {
        switch self {
        case .download(let message): return "WineShelf couldn't download the required file.\n\n\(message)"
        case .integrity(let name): return "The downloaded file failed its SHA-256 check and was discarded:\n\(name)"
        case .archive(let message): return "WineShelf couldn't unpack the Wine runtime.\n\n\(message)"
        case .install(let message): return message
        }
    }
}
