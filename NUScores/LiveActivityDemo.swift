import ActivityKit
import SwiftUI
import Combine

// Fake updates that replay the real NU vs UConn game, for trying the Live Activity in the simulator.
@MainActor
final class LiveActivityDemo: ObservableObject {
    @Published var running = false
    private var activity: Activity<NUGameAttributes>?
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

    func start() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        running = true
        task = Task {
            let steps = Self.steps
            do {
                let attrs = NUGameAttributes(opponent: "UConn", sport: "Field hockey", oppColorHex: "#0C2340")
                activity = try Activity.request(attributes: attrs,
                                                content: .init(state: steps[0].state, staleDate: nil))
            } catch {
                running = false
                return
            }
            for (i, step) in steps.enumerated().dropFirst() {
                try? await Task.sleep(for: .seconds(5))
                if Task.isCancelled { return }
                let content = ActivityContent(state: step.state, staleDate: nil)
                if i == steps.count - 1 {
                    await activity?.end(content, dismissalPolicy: .default)
                } else if let a = step.alert {
                    let alert = AlertConfiguration(title: LocalizedStringResource(stringLiteral: a.title),
                                                   body: LocalizedStringResource(stringLiteral: a.body),
                                                   sound: .default)
                    await activity?.update(content, alertConfiguration: alert)
                } else {
                    await activity?.update(content)
                }
            }
            running = false
        }
    }

    func stop() {
        task?.cancel()
        let a = activity
        activity = nil
        running = false
        Task { await a?.end(nil, dismissalPolicy: .immediate) }
    }
}
