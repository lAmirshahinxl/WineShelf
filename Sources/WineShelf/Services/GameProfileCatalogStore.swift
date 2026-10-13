import Combine
import Foundation

private struct GameProfileCatalogDocument: Decodable {
    let schemaVersion: Int
    let games: [GameCompatibilityProfile]
}

@MainActor
final class GameProfileCatalogStore: ObservableObject {
    static let shared = GameProfileCatalogStore()

    @Published private(set) var games = SteamGameCatalog.games
    @Published private(set) var isUsingWebsiteCatalog = false
    @Published private(set) var loadError: String?

    func game(appID: String) -> GameCompatibilityProfile? {
        games.first { $0.appID == appID }
    }

    func game(named name: String) -> GameCompatibilityProfile? {
        games.first { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }
    }

    func load() async {
        var request = URLRequest(url: SteamGameCatalog.feedURL)
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse,
                  (200..<300).contains(response.statusCode) else {
                throw CatalogError.badResponse
            }

            let document = try JSONDecoder().decode(GameProfileCatalogDocument.self, from: data)
            guard document.schemaVersion == 1,
                  !document.games.isEmpty,
                  Self.isValid(document.games) else {
                throw CatalogError.invalidCatalog
            }

            games = document.games
            isUsingWebsiteCatalog = true
            loadError = nil
        } catch {
            isUsingWebsiteCatalog = false
            loadError = error.localizedDescription
        }
    }

    private static func isValid(_ games: [GameCompatibilityProfile]) -> Bool {
        let ids = games.map(\.id)
        guard Set(ids).count == ids.count else { return false }

        return games.allSatisfy { game in
            let hasValidAppID = game.appID.map { appID in
                !appID.isEmpty && appID.allSatisfy { $0.isASCII && $0.isNumber }
            } ?? true
            return !game.id.isEmpty
                && !game.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !game.storefronts.isEmpty
                && game.guideURL.scheme == "https"
                && game.guideURL.host != nil
                && hasValidAppID
        }
    }

    private enum CatalogError: LocalizedError {
        case badResponse
        case invalidCatalog

        var errorDescription: String? {
            switch self {
            case .badResponse:
                "The WineShelf game catalog could not be downloaded."
            case .invalidCatalog:
                "The WineShelf game catalog has an unsupported or invalid format."
            }
        }
    }
}
