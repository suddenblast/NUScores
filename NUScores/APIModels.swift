import Foundation

// JSON shapes served by the Worker's /games page, and their conversion into the app's Game model.
struct GameDTO: Decodable {
    struct Line: Decodable { let period: String; let nu: Int; let opp: Int }
    struct GoalItem: Decodable {
        let nuScored: Bool
        let period: String
        let timeLeft: String
        let nuScore: Int
        let oppScore: Int
    }

    let id: String
    let sport: String
    let opponent: String
    let oppColor: String?
    let detail: String
    let status: String
    let start: String?
    let nuScore: Int
    let oppScore: Int
    let periodLabel: String
    let clockLeft: String
    let note: String
    let lines: [Line]
    let goals: [GoalItem]
    let updatedAt: String?
}

private func parseISO(_ s: String?) -> Date? {
    guard let s else { return nil }
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = f.date(from: s) { return d }
    f.formatOptions = [.withInternetDateTime]
    return f.date(from: s)
}

extension GameDTO {
    var game: Game {
        let status: GameStatus
        switch self.status {
        case "live": status = .live
        case "final": status = .final
        default: status = .upcoming
        }
        return Game(
            id: id,
            sport: sport == "Lacrosse" ? .lacrosse : .fieldHockey,
            opponent: opponent,
            detail: detail,
            status: status,
            start: parseISO(start),
            nuScore: nuScore, oppScore: oppScore,
            periodLabel: periodLabel, clockLeft: clockLeft, note: note,
            lines: lines.map { LineScore(period: $0.period, nu: $0.nu, opp: $0.opp) },
            goals: goals.map {
                Goal(nuScored: $0.nuScored, period: $0.period,
                     timeLeft: $0.timeLeft.isEmpty ? "" : "\($0.timeLeft) left",
                     nuScore: $0.nuScore, oppScore: $0.oppScore)
            },
            oppColorHex: oppColor
        )
    }

    var updated: Date? { parseISO(updatedAt) }
}
