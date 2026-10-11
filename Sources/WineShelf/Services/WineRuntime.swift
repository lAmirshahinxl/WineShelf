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

    static func importExistingCS2() throws -> GameEntry {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let root = home.appendingPathComponent("Library/Application Support/Game Library/Games/cs2", isDirectory: true)
        let prefix = root.appendingPathComponent("prefix", isDirectory: true)
        let steam = prefix.appendingPathComponent("drive_c/Program Files (x86)/Steam", isDirectory: true)
        let steamExecutable = steam.appendingPathComponent("steam.exe")
        let gameExecutable = steam.appendingPathComponent("steamapps/common/Counter-Strike Global Offensive/game/bin/win64/cs2.exe")

        guard FileManager.default.fileExists(atPath: prefix.appendingPathComponent("system.reg").path) else {
            throw WineShelfError.invalidPrefix(prefix.path)
        }
        guard FileManager.default.isExecutableFile(atPath: steamExecutable.path) else {
            throw WineShelfError.missingFile(steamExecutable.path)
        }
        guard FileManager.default.isExecutableFile(atPath: gameExecutable.path) else {
            throw WineShelfError.missingFile(gameExecutable.path)
        }

        let engine = try findCurrentEngine(in: root)
        let wine = engine.appendingPathComponent("bin/wine")
        let server = engine.appendingPathComponent("bin/wineserver")
        guard FileManager.default.isExecutableFile(atPath: wine.path) else { throw WineShelfError.missingFile(wine.path) }
        guard FileManager.default.isExecutableFile(atPath: server.path) else { throw WineShelfError.missingFile(server.path) }

        let frameworks = root.appendingPathComponent("deps/Frameworks", isDirectory: true)
        let gstreamer = frameworks.appendingPathComponent("GStreamer.framework/Versions/1.0/lib", isDirectory: true)
        let graphicsRoot = root.appendingPathComponent("graphics", isDirectory: true)
        let recipeRoot = graphicsRoot.appendingPathComponent("recipes", isDirectory: true)
        let recipe = (try? FileManager.default.contentsOfDirectory(at: recipeRoot, includingPropertiesForKeys: nil))?
            .filter { $0.hasDirectoryPath }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .first

        var environment = [
            "WINEDEBUG": "-all",
            "WINEDLLPATH": engine.appendingPathComponent("lib/wine").path,
            "ROSETTA_ADVERTISE_AVX": "1",
            "WINEMSYNC": "1",
            "WINEESYNC": "0",
            "MTL_HUD_ENABLED": "0",
            "D3DM_ENABLE_METALFX": "0",
            "MVK_CONFIG_LOG_LEVEL": "1",
            "DYLD_FALLBACK_LIBRARY_PATH": "\(frameworks.path):\(gstreamer.path):/usr/lib",
            "GST_PLUGIN_PATH": gstreamer.appendingPathComponent("gstreamer-1.0").path,
            "GST_REGISTRY": root.appendingPathComponent("gstreamer-registry.bin").path,
            "WINEDLLOVERRIDES": "winemenubuilder.exe=;mscoree,mshtml=;gameoverlayrenderer,gameoverlayrenderer64=;dxgi,d3d11,d3d10core,winemetal=b;nvapi64,nvngx=",
            "AOELAB_STEAM_SINGLEPROCESS": "1",
            "SDL_JOYSTICK_ALLOW_BACKGROUND_EVENTS": "1",
            "DXMT_CS2_EARLY_COMPILE": "1",
            "DXMT_SHADER_CACHE_PATH": graphicsRoot.appendingPathComponent("shader-cache").path,
            "DXMT_CS2_PIPELINE_CACHE": graphicsRoot.appendingPathComponent("game-archives").path,
            "DXMT_LOG_PATH": root.appendingPathComponent("logs").path
        ]
        if let recipe { environment["DXMT_CS2_RECIPE_DIR"] = recipe.path }

        return GameEntry(
            name: "Counter-Strike 2",
            executablePath: steamExecutable.path,
            prefixPath: prefix.path,
            winePath: wine.path,
            wineServerPath: server.path,
            arguments: ["-cef-disable-gpu", "-applaunch", "730"],
            environment: environment
        )
    }

    static func findCurrentEngine(in root: URL) throws -> URL {
        let selectionURL = root.appendingPathComponent("engine-selection.json")
        if let data = try? Data(contentsOf: selectionURL),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: String],
           let current = object["current"] {
            let candidate = root.appendingPathComponent("engine-\(current)", isDirectory: true)
            if FileManager.default.fileExists(atPath: candidate.appendingPathComponent("bin/wine").path) { return candidate }
        }
        let candidates = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        if let engine = candidates.first(where: { $0.lastPathComponent.hasPrefix("engine-wine") && FileManager.default.fileExists(atPath: $0.appendingPathComponent("bin/wine").path) }) {
            return engine
        }
        throw WineShelfError.missingFile(root.appendingPathComponent("engine-…/bin/wine").path)
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
        guard FileManager.default.isExecutableFile(atPath: entry.executablePath) else { throw WineShelfError.missingFile(entry.executablePath) }
        guard FileManager.default.fileExists(atPath: entry.prefixURL.appendingPathComponent("system.reg").path) else {
            throw WineShelfError.invalidPrefix(entry.prefixPath)
        }
        for key in entry.environment.keys where !GameEntry.validEnvironmentKey(key) {
            throw WineShelfError.invalidEnvironment(key)
        }
    }
}
