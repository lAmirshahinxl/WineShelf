import AppKit
import Foundation

enum WineRuntime {
    static func baseEnvironment(for entry: GameEntry) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let managedPrefixes = ["WINE", "WINEDLL", "DYLD_", "ROSETTA_", "MTL_", "D3DM_", "DXMT_", "GST_", "AOELAB_", "SDL_", "MVK_"]
        for key in Array(environment.keys) where managedPrefixes.contains(where: key.hasPrefix) {
            environment.removeValue(forKey: key)
        }
        environment["WINEPREFIX"] = entry.prefixURL.path
        environment["WINELOADER"] = entry.wineURL.path
        environment["WINESERVER"] = entry.wineServerURL.path
        environment["WINEDEBUG"] = "-all"
        environment.merge(entry.environment) { _, custom in custom }
        // A custom override must never redirect Wine to another app's prefix or runtime.
        environment["WINEPREFIX"] = entry.prefixURL.path
        environment["WINELOADER"] = entry.wineURL.path
        environment["WINESERVER"] = entry.wineServerURL.path
        return environment
    }

    static func start(_ entry: GameEntry, logURL: URL, onTermination: ((Int32) -> Void)? = nil) throws -> Process {
        try validate(entry)
        try FileManager.default.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: logURL)
        let process = Process()
        process.executableURL = entry.wineURL
        process.arguments = [entry.executablePath] + entry.arguments
        process.environment = baseEnvironment(for: entry)
        process.currentDirectoryURL = entry.workingDirectoryURL
        process.standardOutput = handle
        process.standardError = handle
        process.terminationHandler = { process in onTermination?(process.terminationStatus) }
        do {
            try process.run()
            try? handle.close()
            return process
        } catch {
            try? handle.close()
            throw error
        }
    }

    static func stop(_ entry: GameEntry) throws -> Int32 {
        guard FileManager.default.isExecutableFile(atPath: entry.wineServerPath) else {
            throw WineShelfError.missingFile(entry.wineServerPath)
        }
        let process = Process()
        process.executableURL = entry.wineServerURL
        process.arguments = ["-k"]
        process.environment = baseEnvironment(for: entry)
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }

    static func createPrefix(for entry: GameEntry, logURL: URL) throws {
        guard FileManager.default.isExecutableFile(atPath: entry.winePath) else { throw WineShelfError.missingFile(entry.winePath) }
        if FileManager.default.fileExists(atPath: entry.prefixURL.appendingPathComponent("system.reg").path) {
            throw WineShelfError.alreadyInitialized(entry.prefixPath)
        }
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: entry.prefixPath), !contents.isEmpty {
            throw WineShelfError.occupiedPrefix(entry.prefixPath)
        }
        try FileManager.default.createDirectory(at: entry.prefixURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: logURL)
        let process = Process()
        process.executableURL = entry.wineURL
        process.arguments = ["wineboot", "--init"]
        process.environment = baseEnvironment(for: entry)
        process.currentDirectoryURL = entry.prefixURL
        process.standardOutput = handle
        process.standardError = handle
        do {
            try process.run()
            process.waitUntilExit()
            try? handle.close()
        } catch {
            try? handle.close()
            throw error
        }
        guard process.terminationStatus == 0,
              FileManager.default.fileExists(atPath: entry.prefixURL.appendingPathComponent("system.reg").path) else {
            throw WineShelfError.processFailed("Wine could not initialize the prefix. Open the latest log for details.\n\(logURL.path)")
        }
    }

    static func validate(_ entry: GameEntry) throws {
        guard FileManager.default.isExecutableFile(atPath: entry.winePath) else { throw WineShelfError.missingFile(entry.winePath) }
        guard FileManager.default.isReadableFile(atPath: entry.executablePath) else { throw WineShelfError.missingFile(entry.executablePath) }
        guard FileManager.default.fileExists(atPath: entry.prefixURL.appendingPathComponent("system.reg").path) else {
            throw WineShelfError.invalidPrefix(entry.prefixPath)
        }
        for key in entry.environment.keys where !GameEntry.validEnvironmentKey(key) {
            throw WineShelfError.invalidEnvironment(key)
        }
    }
}
