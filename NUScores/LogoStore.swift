import Foundation
import UIKit

/// Downloads team logos (PNG, made by the Worker's /logo route) into the shared App Group folder, so the app and the
/// Live Activity can both read them. Runs after games load; files already saved are never downloaded again.
@MainActor
final class LogoStore {
    static let shared = LogoStore()
    private var tried = Set<String>()   // one attempt per file per app launch, so a missing logo isn't asked for repeatedly

    func sync(games: [Game]) async {
        guard let dir = AppGroup.logoFolder(create: true) else { return }
        var seos = Set(games.compactMap(\.oppSeo).filter { !$0.isEmpty })
        seos.insert("northwestern")
        var saved = false
        for seo in seos.sorted() {
            for dark in [false, true] {
                let name = dark ? seo + "-dark" : seo
                let file = dir.appendingPathComponent(name + ".png")
                if FileManager.default.fileExists(atPath: file.path) || tried.contains(name) { continue }
                tried.insert(name)
                guard let url = Config.url("/logo", query: ["seo": seo, "dark": dark ? "1" : "0"]) else { continue }
                do {
                    let (data, response) = try await URLSession.shared.data(from: url)
                    guard (response as? HTTPURLResponse)?.statusCode == 200, UIImage(data: data) != nil else { continue }
                    try data.write(to: file, options: .atomic)
                    saved = true
                } catch { continue }
            }
        }
        if saved { LogoCache.shared.reload() }
    }
}
