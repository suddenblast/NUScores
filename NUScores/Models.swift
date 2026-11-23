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
}

extension Game {
    var oppColor: Color { Color(hex: oppColorHex) ?? .gray }
}

// Games are identified by id alone (the Worker's copy is newer than any older one with the same id).
extension Game: Hashable {
    static func == (l: Game, r: Game) -> Bool { l.id == r.id }
    func hash(into h: inout Hasher) { h.combine(id) }
}
