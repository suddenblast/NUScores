import Combine
import Foundation

@MainActor
final class GameStore: ObservableObject {
    @Published var games: [Game] = []
    @Published var errorText: String?
    @Published var lastUpdated: Date?
    @Published var loadedOnce = false

    func refresh() async {
        guard let url = Config.url("/games") else { return }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                errorText = http.statusCode == 403 ? "The Worker rejected the key. Check Config.swift." : "Server error (\(http.statusCode))."
                loadedOnce = true
                return
            }
            let dtos = try JSONDecoder().decode([GameDTO].self, from: data)
            games = dtos
                .sorted { ($0.updated ?? .distantPast) > ($1.updated ?? .distantPast) }
                .map(\.game)
            lastUpdated = Date()
            errorText = nil
        } catch {
            errorText = "Couldn't load games. Pull down to retry."
        }
        loadedOnce = true
    }
}
