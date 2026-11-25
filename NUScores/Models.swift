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
    var venue: String = ""
    var venueCity: String = ""
    var venueState: String = ""
    var nuHome: Bool = true      // the feed's home flag for NU
    var neutral: Bool = false    // NCAA tournament games count as neutral site
}

// One side of a game, so views can list the away team first and the home team second.
struct GameSide {
    let name: String
    let short: String
    let score: Int
    let color: Color
    let isNU: Bool
}

extension Game {
    var isAway: Bool { !nuHome && !neutral }
    /// "@" when NU is at the opponent's place, "vs" at home or on a neutral site.
    var vs: String { isAway ? "@" : "vs" }
    private var nuSide: GameSide { GameSide(name: "Northwestern", short: "NU", score: nuScore, color: .nuPurple, isNU: true) }
    private var oppSide: GameSide { GameSide(name: opponent, short: opponent, score: oppScore, color: oppColor, isNU: false) }
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
