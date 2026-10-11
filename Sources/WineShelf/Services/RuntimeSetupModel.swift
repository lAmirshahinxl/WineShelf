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

private enum AutomaticSetupPause: Equatable {
    case rosetta
    case gstreamer
    case wineApproval
}

@MainActor
final class RuntimeSetupModel: ObservableObject {
    @Published private(set) var runtimes: [DetectedWineRuntime] = []
    @Published var selectedRuntimeID: String?
    @Published private(set) var isRosettaAvailable = false
    @Published private(set) var isGStreamerInstalled = false
    @Published private(set) var isDownloadingWine = false
    @Published private(set) var isDownloadingGStreamer = false
    @Published private(set) var isVerifyingDownload = false
    @Published private(set) var downloadProgress: Double?
    @Published private(set) var isInstallingSteam = false
    @Published private(set) var isPreparingWine = false
    @Published private(set) var statusMessage: String?
    @Published var errorMessage: String?

    private var automaticSetupPause: AutomaticSetupPause?
    private var isAutomaticSetupActive = false

    private let fileManager = FileManager.default

    static let wineVersion = "11.18"
    static let wineSHA256 = "aa0ea4c82e636ae7bca2076387cb0a5affa26509ad13f119ecd0d62bd7ba6f82"
    static let wineSource = URL(string: "https://github.com/Gcenx/macOS_Wine_builds/releases/download/11.18/wine-devel-11.18-osx64.tar.xz")!
    static let gstreamerVersion = "1.28.7"
    static let gstreamerSHA256 = "529fdf4a4027d942e59b5b3564f6400adaa008f63ce5f3fed4ffe35d73911994"
    static let gstreamerSource = URL(string: "https://gstreamer.freedesktop.org/data/pkg/osx/1.28.7/gstreamer-1.0-1.28.7-universal.pkg")!
    static let steamSetupSource = URL(string: "https://cdn.fastly.steamstatic.com/client/installer/SteamSetup.exe")!
    private static let approvedRuntimePathsKey = "WineShelf.approvedRuntimePaths"

    static func runtimeReadyForDirectLaunch() -> DetectedWineRuntime? {
        let setup = RuntimeSetupModel()
        guard let runtime = setup.selectedRuntime else { return nil }
        guard !setup.isAppleSilicon || setup.isRosettaAvailable else { return nil }
        guard setup.isGStreamerInstalled else { return nil }
        guard !setup.requiresManualWineApproval else { return nil }
        return runtime
    }

    var selectedRuntime: DetectedWineRuntime? {
        runtimes.first { $0.id == selectedRuntimeID } ?? runtimes.first
    }

    var isReadyForWindowsApps: Bool {
        (!isAppleSilicon || isRosettaAvailable)
            && isGStreamerInstalled
            && selectedRuntime != nil
            && automaticSetupPause != .wineApproval
            && !requiresManualWineApproval
    }

    var isWaitingForWineApproval: Bool { automaticSetupPause == .wineApproval }
    var isWaitingForGStreamerInstaller: Bool { automaticSetupPause == .gstreamer }

    private var requiresManualWineApproval: Bool {
        guard let runtime = selectedRuntime,
              let bundlePath = runtime.bundlePath,
              bundlePath.contains("/WineShelf/Runtimes/") else { return false }
        let approvedPaths = UserDefaults.standard.stringArray(forKey: Self.approvedRuntimePathsKey) ?? []
        return !approvedPaths.contains(runtime.winePath)
    }

    var nextSetupActionTitle: String {
        if isDownloadingGStreamer {
            if isVerifyingDownload { return "Verifying GStreamer…" }
            if let downloadProgress { return "Downloading GStreamer… \(Int(downloadProgress * 100))%" }
            return "Downloading GStreamer…"
        }
        if isDownloadingWine {
            if isVerifyingDownload { return "Verifying Wine…" }
            if let downloadProgress { return "Downloading Wine… \(Int(downloadProgress * 100))%" }
            return "Downloading Wine…"
        }
        if isPreparingWine {
            return "Preparing Wine…"
        }
        if automaticSetupPause == .wineApproval {
            return "Continue after Approval"
        }
        if automaticSetupPause == .gstreamer {
            return "Open GStreamer Installer"
        }
        if automaticSetupPause == .rosetta {
            return "Continue Rosetta Setup"
        }
        if isAppleSilicon && !isRosettaAvailable {
            return "Set Up Rosetta"
        }
        if !isGStreamerInstalled {
            return "Install Required Components"
        }
        if selectedRuntime == nil {
            return "Install Wine"
        }
        return "Check Setup"
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

    func prepareWineAutomatically() async {
        if automaticSetupPause == .wineApproval {
            revealSelectedRuntime()
            return
        }
        guard !isPreparingWine else { return }
        isPreparingWine = true
        isAutomaticSetupActive = true
        defer { isPreparingWine = false }

        errorMessage = nil
        refresh()

        if isAppleSilicon && !isRosettaAvailable {
            if automaticSetupPause != .rosetta {
                automaticSetupPause = .rosetta
            }
            openRosettaInstructions()
            return
        }
        if automaticSetupPause == .rosetta { automaticSetupPause = nil }

        if !isGStreamerInstalled {
            await installGStreamer()
            if errorMessage == nil, !Task.isCancelled { automaticSetupPause = .gstreamer }
            return
        }
        if automaticSetupPause == .gstreamer { automaticSetupPause = nil }

        if selectedRuntime == nil {
            await installWine()
            guard errorMessage == nil, selectedRuntime != nil else { return }
        }

        if requiresManualWineApproval {
            automaticSetupPause = .wineApproval
            revealSelectedRuntime()
            statusMessage = "In Finder, Control-click the Wine app, choose Open, and confirm the macOS prompt. Then return here and continue after approval."
            return
        }

        automaticSetupPause = nil
        isAutomaticSetupActive = false
        statusMessage = "Wine and its required components are ready for Windows apps."
    }

    func resumeAutomaticSetupAfterSystemStep() async {
        guard isAutomaticSetupActive, !isPreparingWine else { return }
        refresh()

        switch automaticSetupPause {
        case .rosetta where isRosettaAvailable:
            automaticSetupPause = nil
        case .gstreamer where isGStreamerInstalled:
            automaticSetupPause = nil
        default:
            return
        }

        await prepareWineAutomatically()
    }

    func continueAfterWineApproval() {
        guard automaticSetupPause == .wineApproval else { return }
        if let path = selectedRuntime?.winePath {
            var approvedPaths = UserDefaults.standard.stringArray(forKey: Self.approvedRuntimePathsKey) ?? []
            if !approvedPaths.contains(path) {
                approvedPaths.append(path)
                UserDefaults.standard.set(approvedPaths, forKey: Self.approvedRuntimePathsKey)
            }
        }
        automaticSetupPause = nil
        isAutomaticSetupActive = false
        statusMessage = "Wine setup is complete. You can now add Windows apps or install Steam."
    }

    func installWine() async {
        guard !isDownloadingWine else { return }
        isDownloadingWine = true
        isVerifyingDownload = false
        downloadProgress = 0
        statusMessage = "Downloading Wine (\(Self.wineVersion))…"
        defer {
            isDownloadingWine = false
            isVerifyingDownload = false
            downloadProgress = nil
        }

        do {
            let downloads = try downloadDirectory()
            let archive = try await verifiedDownload(
                from: Self.wineSource,
                fileName: "wine-devel-\(Self.wineVersion)-osx64.tar.xz",
                expectedSHA256: Self.wineSHA256,
                in: downloads,
                onProgress: { [weak self] received, expected in
                    let progress = expected > 0 ? min(1, Double(received) / Double(expected)) : nil
                    Task { @MainActor [weak self] in
                        guard let self, self.isDownloadingWine, !self.isVerifyingDownload else { return }
                        self.downloadProgress = progress
                        self.isVerifyingDownload = false
                    }
                },
                onVerificationStarted: { [weak self] in
                    self?.downloadProgress = nil
                    self?.isVerifyingDownload = true
                    self?.statusMessage = "Verifying Wine (\(Self.wineVersion))…"
                }
            )
            statusMessage = "Checking the Wine archive…"
            let install = try installWineArchive(archive)
            refresh()
            selectedRuntimeID = install.winePath
            statusMessage = "Wine is installed. Approve the Wine app in Finder before using it."
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
            statusMessage = nil
        }
    }

    func installGStreamer() async {
        guard !isDownloadingGStreamer else { return }
        isDownloadingGStreamer = true
        isVerifyingDownload = false
        downloadProgress = 0
        statusMessage = "Downloading GStreamer (\(Self.gstreamerVersion))…"
        defer {
            isDownloadingGStreamer = false
            isVerifyingDownload = false
            downloadProgress = nil
        }

        do {
            let downloads = try downloadDirectory()
            let package = try await verifiedDownload(
                from: Self.gstreamerSource,
                fileName: "gstreamer-1.0-\(Self.gstreamerVersion)-universal.pkg",
                expectedSHA256: Self.gstreamerSHA256,
                in: downloads,
                onProgress: { [weak self] received, expected in
                    let progress = expected > 0 ? min(1, Double(received) / Double(expected)) : nil
                    Task { @MainActor [weak self] in
                        guard let self, self.isDownloadingGStreamer, !self.isVerifyingDownload else { return }
                        self.downloadProgress = progress
                        self.isVerifyingDownload = false
                    }
                },
                onVerificationStarted: { [weak self] in
                    self?.downloadProgress = nil
                    self?.isVerifyingDownload = true
                    self?.statusMessage = "Verifying GStreamer (\(Self.gstreamerVersion))…"
                }
            )
            guard NSWorkspace.shared.open(package) else {
                throw RuntimeSetupError.install("The verified package is saved here:\n\(package.path)\nOpen it in Finder to continue.")
            }
            statusMessage = "Installer is open. Complete the GStreamer installation, then choose Check again. macOS may ask for an administrator password."
        } catch {
            guard !Task.isCancelled else { return }
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
        _ = NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app", isDirectory: true))
        statusMessage = "Terminal is open and the Rosetta command is copied. Paste it, accept Apple's license, then return here; WineShelf will continue setup."
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

    private func verifiedDownload(
        from source: URL,
        fileName: String,
        expectedSHA256: String,
        in directory: URL,
        onProgress: @escaping @Sendable (Int64, Int64) -> Void = { _, _ in },
        onVerificationStarted: () -> Void = {}
    ) async throws -> URL {
        let destination = directory.appendingPathComponent(fileName)
        if fileManager.fileExists(atPath: destination.path) {
            onVerificationStarted()
            if try sha256(of: destination) == expectedSHA256 {
                return destination
            }
        }
        try? fileManager.removeItem(at: destination)

        var request = URLRequest(url: source)
        request.timeoutInterval = 90
        let downloader = ProgressDownloadDelegate(onProgress: onProgress)
        let (temporaryURL, response) = try await downloader.download(request)
        defer { try? fileManager.removeItem(at: temporaryURL) }
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw RuntimeSetupError.download("The download server did not return the requested file.")
        }
        onVerificationStarted()
        let actualHash = try sha256(of: temporaryURL)
        guard actualHash.caseInsensitiveCompare(expectedSHA256) == .orderedSame else {
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
        candidates += existingLibraryWineBinaries(under: home.appendingPathComponent("Library/Application Support/Game Library/Games", isDirectory: true))

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

    private static func existingLibraryWineBinaries(under root: URL) -> [URL] {
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

private final class ProgressDownloadDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let onProgress: @Sendable (Int64, Int64) -> Void
    private let lock = NSLock()
    private var continuation: CheckedContinuation<(URL, URLResponse), Error>?
    private var session: URLSession?
    private var task: URLSessionDownloadTask?
    private var didComplete = false
    private var wasCancelled = false
    private var lastReportedPercent = -1

    init(onProgress: @escaping @Sendable (Int64, Int64) -> Void) {
        self.onProgress = onProgress
    }

    func download(_ request: URLRequest) async throws -> (URL, URLResponse) {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                lock.lock()
                self.continuation = continuation
                lock.unlock()

                let configuration = URLSessionConfiguration.default
                configuration.timeoutIntervalForRequest = 90
                configuration.timeoutIntervalForResource = 60 * 30
                let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
                let task = session.downloadTask(with: request)

                lock.lock()
                self.session = session
                self.task = task
                let shouldCancel = wasCancelled
                lock.unlock()

                if shouldCancel {
                    task.cancel()
                } else {
                    task.resume()
                }
            }
        } onCancel: {
            self.cancel()
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        if totalBytesExpectedToWrite > 0 {
            let percent = Int(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite) * 100)
            guard percent != lastReportedPercent else { return }
            lastReportedPercent = percent
        }
        onProgress(totalBytesWritten, totalBytesExpectedToWrite)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let response = downloadTask.response else {
            finish(.failure(RuntimeSetupError.download("The download finished without a server response.")))
            return
        }

        let retainedFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("WineShelf-download-\(UUID().uuidString)")
        do {
            try FileManager.default.moveItem(at: location, to: retainedFile)
            finish(.success((retainedFile, response)))
        } catch {
            do {
                try FileManager.default.copyItem(at: location, to: retainedFile)
                finish(.success((retainedFile, response)))
            } catch {
                finish(.failure(error))
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            finish(.failure(error))
        }
    }

    private func finish(_ result: Result<(URL, URLResponse), Error>) {
        lock.lock()
        guard !didComplete else {
            lock.unlock()
            return
        }
        didComplete = true
        let continuation = self.continuation
        self.continuation = nil
        let session = self.session
        self.session = nil
        self.task = nil
        lock.unlock()

        continuation?.resume(with: result)
        session?.finishTasksAndInvalidate()
    }

    private func cancel() {
        lock.lock()
        wasCancelled = true
        let task = self.task
        lock.unlock()
        task?.cancel()
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
