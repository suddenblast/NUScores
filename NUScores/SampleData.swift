import Foundation

// Sample data. The finished game is the real NU vs UConn semifinal (Nov 20, 2026).
// The upcoming games are placeholders, not the real schedule.
enum SampleData {
    static let uconn = Game(
        id: "6644572",
        sport: .fieldHockey,
        opponent: "UConn",
        detail: "NCAA semifinal",
        status: .final,
        start: nil,
        nuScore: 3, oppScore: 2,
        periodLabel: "Final", clockLeft: "", note: "shootout",
        lines: [
            LineScore(period: "1", nu: 0, opp: 0),
            LineScore(period: "2", nu: 0, opp: 0),
            LineScore(period: "3", nu: 1, opp: 0),
            LineScore(period: "4", nu: 1, opp: 2),
            LineScore(period: "OT", nu: 0, opp: 0),
            LineScore(period: "SO", nu: 5, opp: 4),
        ],
        goals: [
            Goal(nuScored: true,  period: "Q3", timeLeft: "12:20 left", nuScore: 1, oppScore: 0),
            Goal(nuScored: true,  period: "Q4", timeLeft: "13:31 left", nuScore: 2, oppScore: 0),
            Goal(nuScored: false, period: "Q4", timeLeft: "2:32 left",  nuScore: 2, oppScore: 1),
            Goal(nuScored: false, period: "Q4", timeLeft: "1:03 left",  nuScore: 2, oppScore: 2),
        ]
    )

    static let live = Game(
        id: "sample-live",
        sport: .fieldHockey,
        opponent: "UConn",
        detail: "NCAA semifinal",
        status: .live,
        start: nil,
        nuScore: 2, oppScore: 1,
        periodLabel: "Q4", clockLeft: "13:31", note: "",
        lines: uconn.lines,
        goals: Array(uconn.goals.prefix(3))
    )

    static func upcoming(_ opponent: String, daysAhead: Int, hour: Int) -> Game {
        let cal = Calendar.current
        let day = cal.date(byAdding: .day, value: daysAhead, to: Date())!
        let start = cal.date(bySettingHour: hour, minute: 0, second: 0, of: day)
        return Game(id: "sample-\(opponent)", sport: .lacrosse, opponent: opponent,
                    detail: "", status: .upcoming, start: start,
                    nuScore: 0, oppScore: 0, periodLabel: "", clockLeft: "", note: "",
                    lines: [], goals: [])
    }

    static let all: [Game] = [
        live,
        upcoming("Sample opponent A", daysAhead: 1, hour: 13),
        upcoming("Sample opponent B", daysAhead: 4, hour: 18),
        uconn,
    ]
}
