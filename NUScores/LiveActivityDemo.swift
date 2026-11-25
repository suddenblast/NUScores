import ActivityKit
import SwiftUI
import Combine

// Fake updates that replay the real NU vs UConn game, for trying the Live Activity in the simulator.
@MainActor
final class LiveActivityDemo: ObservableObject {
    @Published var running = false
    /// The test game shown in the app's own list while the demo runs (nil when it is not running).
    @Published var game: Game?
    static let gameId = "demo-test-game"
    // Looked up each time, so the bell on the card can end the activity and start a new one mid-demo.
    private var activities: [Activity<NUGameAttributes>] {
        Activity<NUGameAttributes>.activities.filter { $0.attributes.gameId == Self.gameId }
    }
    private var task: Task<Void, Never>?

    struct Step {
        let state: NUGameAttributes.ContentState
        let alert: (title: String, body: String)?
    }

    private static func s(_ nu: Int, _ opp: Int, _ period: String, _ idx: Int, _ clock: String,
                          goal: String = "", final: Bool = false, note: String = "") -> NUGameAttributes.ContentState {
        .init(nuScore: nu, oppScore: opp, period: period, periodIndex: idx, clockLeft: clock,
              lastGoal: goal, isFinal: final, note: note)
    }

    static let steps: [Step] = [
        Step(state: s(0, 0, "Q1", 1, "15:00"), alert: nil),
        Step(state: s(0, 0, "Q3", 3, "15:00"), alert: ("Start of Q3", "NU 0–0 UConn")),
        Step(state: s(1, 0, "Q3", 3, "12:20", goal: "Northwestern · Q3 12:20 left"),
             alert: ("Goal, Northwestern", "NU 1–0 UConn · Q3 12:20 left")),
        Step(state: s(1, 0, "Q4", 4, "15:00", goal: "Northwestern · Q3 12:20 left"),
             alert: ("Start of Q4", "NU 1–0 UConn")),
        Step(state: s(2, 0, "Q4", 4, "13:31", goal: "Northwestern · Q4 13:31 left"),
             alert: ("Goal, Northwestern", "NU 2–0 UConn · Q4 13:31 left")),
        Step(state: s(2, 1, "Q4", 4, "2:32", goal: "UConn · Q4 2:32 left"),
             alert: ("Goal, UConn", "NU 2–1 UConn · Q4 2:32 left")),
        Step(state: s(2, 2, "Q4", 4, "1:03", goal: "UConn · Q4 1:03 left"),
             alert: ("Goal, UConn", "NU 2–2 UConn · Q4 1:03 left")),
        Step(state: s(2, 2, "OT", 5, "", goal: "UConn · Q4 1:03 left"),
             alert: ("Start of OT", "NU 2–2 UConn")),
        Step(state: s(3, 2, "Final", 5, "", goal: "UConn · Q4 1:03 left", final: true, note: "shootout"),
             alert: ("Final, Northwestern wins", "NU 3–2 UConn · shootout")),
    ]

    func toggle() { running ? stop() : start() }

    /// The in-app copy of the game as of step `i`, built from the same steps the Live Activity replays.
    private func appGame(upTo i: Int) -> Game {
        var goals: [Goal] = []
        for step in Self.steps[0...i] {
            guard let a = step.alert, a.title.hasPrefix("Goal") else { continue }
            let st = step.state
            goals.append(Goal(nuScored: a.title.contains("Northwestern"), period: st.period,
                              timeLeft: st.clockLeft + " left", nuScore: st.nuScore, oppScore: st.oppScore,
                              scorer: "Test Player"))
        }
        let st = Self.steps[i].state
        return Game(id: Self.gameId, sport: .fieldHockey, opponent: "UConn", detail: "Test game",
                    status: st.isFinal ? .final : .live, start: Date(),
                    nuScore: st.nuScore, oppScore: st.oppScore,
                    periodLabel: st.period, clockLeft: st.clockLeft, note: st.note,
                    lines: [], goals: goals, oppColorHex: "#0C2340", oppSeo: "uconn")
    }

    func start() {
        running = true
        game = appGame(upTo: 0)
        task = Task {
            let steps = Self.steps
            // The Live Activity is optional: if it can't start, the in-app game still plays.
            if ActivityAuthorizationInfo().areActivitiesEnabled {
                let attrs = NUGameAttributes(opponent: "UConn", sport: "Field hockey", oppColorHex: "#0C2340", gameId: Self.gameId, oppSeo: "uconn")
                _ = try? Activity.request(attributes: attrs,
                                          content: .init(state: steps[0].state, staleDate: nil))
            }
            for (i, step) in steps.enumerated().dropFirst() {
                try? await Task.sleep(for: .seconds(5))
                if Task.isCancelled { return }
                game = appGame(upTo: i)
                let content = ActivityContent(state: step.state, staleDate: nil)
                if i == steps.count - 1 {
                    for a in activities { await a.end(content, dismissalPolicy: .default) }
                } else if let a = step.alert {
                    let alert = AlertConfiguration(title: LocalizedStringResource(stringLiteral: a.title),
                                                   body: LocalizedStringResource(stringLiteral: a.body),
                                                   sound: .default)
                    for a in activities { await a.update(content, alertConfiguration: alert) }
                } else {
                    for a in activities { await a.update(content) }
                }
            }
            running = false
        }
    }

    func stop() {
        task?.cancel()
        let mine = activities
        game = nil
        running = false
        Task { for a in mine { await a.end(nil, dismissalPolicy: .immediate) } }
    }
}
