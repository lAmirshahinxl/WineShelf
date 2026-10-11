import Foundation

struct GameEntry: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var executablePath: String
    var prefixPath: String
    var winePath: String
    var wineServerPath: String
    var arguments: [String] = []
    var environment: [String: String] = [:]
    var addedAt: Date = Date()

    var executableURL: URL { URL(fileURLWithPath: executablePath) }
    var prefixURL: URL { URL(fileURLWithPath: prefixPath, isDirectory: true) }
    var wineURL: URL { URL(fileURLWithPath: winePath) }
    var wineServerURL: URL { URL(fileURLWithPath: wineServerPath) }

    var workingDirectoryURL: URL {
        executableURL.deletingLastPathComponent()
    }

    var argumentEditorText: String {
        get { arguments.joined(separator: "\n") }
        set {
            arguments = newValue
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
    }

    var environmentEditorText: String {
        get {
            environment.keys.sorted().map { "\($0)=\(environment[$0] ?? "")" }.joined(separator: "\n")
        }
        set {
            var parsed: [String: String] = [:]
            for line in newValue.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, !trimmed.hasPrefix("#"), let separator = trimmed.firstIndex(of: "=") else { continue }
                let key = String(trimmed[..<separator]).trimmingCharacters(in: .whitespaces)
                let value = String(trimmed[trimmed.index(after: separator)...])
                guard Self.validEnvironmentKey(key) else { continue }
                parsed[key] = value
            }
            environment = parsed
        }
    }

    static func validEnvironmentKey(_ key: String) -> Bool {
        guard let first = key.first, first == "_" || first.isASCII && first.isLetter else { return false }
        return key.dropFirst().allSatisfy { $0 == "_" || $0.isASCII && $0.isLetter || $0.isASCII && $0.isNumber }
    }

    static func normalizedPath(_ path: String) -> String {
        let expanded = (path as NSString).expandingTildeInPath
        return URL(fileURLWithPath: expanded).standardizedFileURL.path
    }
}

enum WineShelfError: LocalizedError {
    case missingFile(String)
    case invalidPrefix(String)
    case invalidEnvironment(String)
    case alreadyInitialized(String)
    case occupiedPrefix(String)
    case processFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingFile(let path): return "Can't find this file or folder:\n\(path)"
        case .invalidPrefix(let path): return "This doesn't look like an initialized Wine prefix:\n\(path)"
        case .invalidEnvironment(let key): return "The environment variable name ‘\(key)’ is invalid. Use letters, numbers, and underscores."
        case .alreadyInitialized(let path): return "That prefix already contains a Wine registry, so WineShelf left it unchanged:\n\(path)"
        case .occupiedPrefix(let path): return "Choose an empty folder for the new Wine prefix. WineShelf left this folder unchanged:\n\(path)"
        case .processFailed(let message): return message
        }
    }
}
