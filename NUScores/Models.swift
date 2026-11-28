import SwiftUI

enum Sport: String {
    case fieldHockey = "Field hockey"
    case lacrosse = "Lacrosse"
}

enum GameStatus {
    case upcoming
    case live
    case final
}

struct LineScore: Identifiable {
    let id = UUID()
    let period: String   // "1", "2", "3", "4", "OT", "SO"
    let nu: Int
    let opp: Int
}

struct Goal: Identifiable {
    let id = UUID()
    let nuScored: Bool
    let period: String     // "Q3"
    let timeLeft: String   // "12:20 left"
    let nuScore: Int
    let oppScore: Int
    var scorer: String = ""    // "Kiera Sack"; empty until the play-by-play has it
}

struct Game: Identifiable {
    let id: String
    let sport: Sport
    let opponent: String
    let detail: String          // "NCAA semifinal"
    let status: GameStatus
    let start: Date?
    let nuScore: Int
    let oppScore: Int
    let periodLabel: String     // "Q4", "Final", ""
    let clockLeft: String       // "13:31" while live
    let note: String            // "shootout"
    let lines: [LineScore]
    let goals: [Goal]
    var oppColorHex: String? = nil
    var oppSeo: String? = nil     // NCAA name used to find the opponent's logo
    var venue: String = ""
    var venueCity: String = ""
    var venueState: String = ""
    var nuHome: Bool = true      // the feed's home flag for NU
    var neutral: Bool = false    // NCAA tournament games count as neutral site
    var nuRecord: String = ""    // "15–3 (7–1)": overall (conference), worked out by the Worker; "" when unknown
    var oppRecord: String = ""
}

// One side of a game, so views can list the away team first and the home team second.
struct GameSide {
    let name: String
    let short: String
    let score: Int
    let color: Color
    let isNU: Bool
    var seo: String? = nil   // logo name
    var record: String = ""
}

extension Game {
    var isAway: Bool { !nuHome && !neutral }
    /// "@" when NU is at the opponent's place, "vs" at home or on a neutral site.
    var vs: String { isAway ? "@" : "vs" }
    private var nuSide: GameSide { GameSide(name: "Northwestern", short: "NU", score: nuScore, color: .nuPurple, isNU: true, seo: "northwestern", record: nuRecord) }
    private var oppSide: GameSide { GameSide(name: opponent, short: opponent, score: oppScore, color: oppColor, isNU: false, seo: oppSeo, record: oppRecord) }
    var awaySide: GameSide { nuHome ? oppSide : nuSide }
    var homeSide: GameSide { nuHome ? nuSide : oppSide }
}

extension Game {
    var oppColor: Color { Color(hex: oppColorHex) ?? .gray }
}

// Games are identified by id alone (the Worker's copy is newer than any older one with the same id).
extension Game: Hashable {
    static func == (l: Game, r: Game) -> Bool { l.id == r.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}

extension Color {
    /// The fill of list cards (white in light mode, dark gray in dark mode), see-through so the page color shows.
    static let cardFill = Color(.secondarySystemGroupedBackground).opacity(0.65)
}

/// Points for a 3x3 mesh gradient whose inner points drift slowly with time, for the animated page backgrounds.
/// Corners stay put and edge points only slide along their edge, so the mesh always fills the screen.
func driftingMeshPoints(at t: TimeInterval, center: SIMD2<Float> = [0.5, 0.5]) -> [SIMD2<Float>] {
    func wave(_ speed: Double, _ phase: Double) -> Float { Float(sin(t * speed + phase)) }
    return [
        [0, 0], [0.5 + 0.17 * wave(0.45, 0), 0], [1, 0],
        [0, 0.5 + 0.17 * wave(0.40, 1.3)],
        [center.x + 0.24 * wave(0.34, 2.1), center.y + 0.24 * wave(0.43, 0.7)],
        [1, 0.5 + 0.17 * wave(0.48, 3.0)],
        [0, 1], [0.5 + 0.17 * wave(0.37, 4.2), 1], [1, 1],
    ]
}
