import SwiftUI

extension Color {
    static let nuPurple = Color(red: 0x4E / 255, green: 0x2A / 255, blue: 0x84 / 255)
    static let oppNavy = Color(red: 0x0C / 255, green: 0x23 / 255, blue: 0x40 / 255)
}

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
}

extension Game {
    var oppColor: Color { Color(hex: oppColorHex) ?? .gray }
    
}
