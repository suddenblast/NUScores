import ActivityKit
import Foundation
import SwiftUI

// Add this file to BOTH the app target and the widget extension target.
// Anything the Live Activity and the app both need (the state shape, brand colors) lives here.
nonisolated struct NUGameAttributes: ActivityAttributes {
    nonisolated struct ContentState: Codable, Hashable {
        var nuScore: Int
        var oppScore: Int
        var period: String       // "Q1"..."Q4", "OT", "Final"
        var periodIndex: Int     // 1...4, 5 for OT
        var clockLeft: String    // "13:31", empty when not applicable
        var lastGoal: String     // "Northwestern · Q4 13:31 left"
        var isFinal: Bool
        var note: String         // "shootout"
        var clockEnd: Double? = nil   // epoch secs when the running clock hits 0; nil = no countdown
    }

    var opponent: String
    var sport: String
    var oppColorHex: String? = nil
    var gameId: String? = nil   // lets the Worker match an activity's push token to its game
    var nuHome: Bool? = nil     // nil (older activities) counts as home
    var oppSeo: String? = nil   // NCAA name of the opponent ("penn-st"), used to find its logo asset
}

/// Where the app saves team logos so the Live Activity can read them. Needs the App Groups capability, with this id,
/// on both the app target and the widget target. Without it there is no folder and teams show their color circle.
enum AppGroup {
    static let id = "group.com.jonasblum.NUScores"

    static func logoFolder(create: Bool = false) -> URL? {
        guard let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) else { return nil }
        let dir = base.appendingPathComponent("Logos", isDirectory: true)
        if create { try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true) }
        return dir
    }
}

/// Reads logo files ("<seo>.png", and "<seo>-dark.png" for dark backgrounds) from the shared folder.
/// The app downloads them ahead of time (LogoStore); the Live Activity only reads what is already there.
@MainActor
final class LogoCache: ObservableObject {
    static let shared = LogoCache()
    @Published private(set) var revision = 0
    private let images = NSCache<NSString, UIImage>()

    func image(seo: String?, dark: Bool) -> UIImage? {
        guard let seo, !seo.isEmpty, let dir = AppGroup.logoFolder() else { return nil }
        for name in dark ? [seo + "-dark", seo] : [seo] {
            if let hit = images.object(forKey: name as NSString) { return hit }
            if let img = UIImage(contentsOfFile: dir.appendingPathComponent(name + ".png").path) {
                images.setObject(img, forKey: name as NSString)
                return img
            }
        }
        return nil
    }

    /// Call after new files were saved so views redraw.
    func reload() {
        images.removeAllObjects()
        revision += 1
    }
}

/// A team's logo when it has been downloaded, otherwise the team-color circle. `backed` puts a white disc behind the
/// logo, for dark or colored backgrounds (it also always uses the regular logo, never the dark-mode one).
struct TeamMark: View {
    let seo: String?
    let color: Color
    let size: CGFloat
    var ringWidth: CGFloat = 2
    var ring: Color = .white
    var backed = false

    @ObservedObject private var cache = LogoCache.shared
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        if let logo = cache.image(seo: seo, dark: !backed && scheme == .dark) {
            Image(uiImage: logo)
                .resizable()
                .scaledToFit()
                .padding(backed ? size * 0.12 : 0)
                .frame(width: size, height: size)
                .background { if backed { Circle().fill(Color.white) } }
        } else {
            Circle().fill(color)
                .frame(width: size, height: size)
                .overlay(Circle().stroke(ring, lineWidth: ringWidth))
        }
    }
}

extension Color {
    static let nuPurple = Color(red: 0x4E / 255, green: 0x2A / 255, blue: 0x84 / 255)

    init?(hex: String?) {
        guard var s = hex?.trimmingCharacters(in: .whitespaces), !s.isEmpty else { return nil }
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
}
