import ActivityKit
import Combine
import Foundation

// Sends the two kinds of Live Activity tokens to the Worker so it can drive the Live Activity by push:
//  - "start":  the push-to-start token. The Worker uses it to start a Live Activity when a game begins,
//              even if the app isn't running.
//  - "update": a per-activity token. The Worker uses it to update and end that one activity.
// Tokens change, so every new value is re-sent. The Worker keeps the latest.
@MainActor
final class PushRegistrar {
    static let shared = PushRegistrar()
    private var started = false
    private var observed = Set<String>()

    func start() {
        guard !started else { return }
        started = true

        Task {
            for await data in Activity<NUGameAttributes>.pushToStartTokenUpdates {
                await Self.send(kind: "start", token: data.hexString, gameId: nil)
            }
        }
        Task {
            for await activity in Activity<NUGameAttributes>.activityUpdates {
                observe(activity)
            }
        }
        for activity in Activity<NUGameAttributes>.activities {
            observe(activity)
        }
    }

    private func observe(_ activity: Activity<NUGameAttributes>) {
        LiveActivityController.shared.watch(activity)
        guard observed.insert(activity.id).inserted else { return }
        let gameId = activity.attributes.gameId
        Task {
            for await data in activity.pushTokenUpdates {
                await Self.send(kind: "update", token: data.hexString, gameId: gameId)
            }
        }
    }

    private static func send(kind: String, token: String, gameId: String?) async {
        guard let url = Config.url("/register") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: String] = ["kind": kind, "token": token]
        if let gameId, !gameId.isEmpty { body["gameId"] = gameId }
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (_, response) = try await URLSession.shared.data(for: req)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            print("[push] registered \(kind) token -> HTTP \(code)")
        } catch {
            print("[push] register \(kind) failed: \(error.localizedDescription)")
        }
    }
}

private extension Data {
    var hexString: String { map { String(format: "%02x", $0) }.joined() }
}

/// Tracks which games have a Live Activity on this phone, and starts or ends one for a game from the app.
/// A game counts as "on" while an activity for it is active, so dismissing it from the lock screen turns it off.
@MainActor
final class LiveActivityController: ObservableObject {
    static let shared = LiveActivityController()
    @Published private(set) var activeGameIds = Set<String>()
    private var watched = Set<String>()

    var available: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    func isOn(_ gameId: String) -> Bool { activeGameIds.contains(gameId) }

    /// Called for every activity the system knows about, including ones the Worker started by push.
    func watch(_ activity: Activity<NUGameAttributes>) {
        guard let gameId = activity.attributes.gameId, !gameId.isEmpty else { return }
        if activity.activityState == .active || activity.activityState == .stale { activeGameIds.insert(gameId) }
        guard watched.insert(activity.id).inserted else { return }
        Task {
            for await state in activity.activityStateUpdates {
                switch state {
                case .active, .stale: activeGameIds.insert(gameId)
                case .ended, .dismissed: refresh(gameId)
                @unknown default: break
                }
            }
        }
    }

    private func refresh(_ gameId: String) {
        let stillOn = Activity<NUGameAttributes>.activities.contains {
            $0.attributes.gameId == gameId && ($0.activityState == .active || $0.activityState == .stale)
        }
        if stillOn { activeGameIds.insert(gameId) } else { activeGameIds.remove(gameId) }
    }

    func toggle(_ game: Game) {
        isOn(game.id) ? end(game.id) : start(game)
    }

    /// Starts a Live Activity for a game that is already under way. It registers a push token like the ones the
    /// Worker starts, so the Worker keeps updating it.
    func start(_ game: Game) {
        guard available, !isOn(game.id) else { return }
        let attrs = NUGameAttributes(opponent: game.opponent, sport: game.sport.rawValue, oppColorHex: game.oppColorHex,
                                     gameId: game.id, nuHome: game.nuHome, oppSeo: game.oppSeo)
        do {
            let activity = try Activity.request(attributes: attrs,
                                                content: .init(state: Self.state(for: game), staleDate: nil),
                                                pushType: .token)
            watch(activity)
            activeGameIds.insert(game.id)
        } catch {
            print("[activity] couldn't start for \(game.id): \(error.localizedDescription)")
        }
    }

    func end(_ gameId: String) {
        activeGameIds.remove(gameId)
        let mine = Activity<NUGameAttributes>.activities.filter { $0.attributes.gameId == gameId }
        Task { for a in mine { await a.end(nil, dismissalPolicy: .immediate) } }
    }

    /// The same numbers the Worker puts in its pushes (see contentState in push.mjs).
    private static func state(for game: Game) -> NUGameAttributes.ContentState {
        let label = game.periodLabel
        let index: Int
        if label.count == 2, label.hasPrefix("Q"), let n = Int(label.dropFirst()), (1...4).contains(n) { index = n }
        else if label.contains("OT") { index = 5 }
        else if label == "Final" { index = game.note.isEmpty ? 4 : 5 }
        else { index = min(max(game.lines.count, 1), 4) }

        var lastGoal = ""
        if let g = game.goals.last {
            let who = g.nuScored ? "Northwestern" : game.opponent
            let when = [g.period, g.timeLeft].filter { !$0.isEmpty }.joined(separator: " ")
            lastGoal = when.isEmpty ? who : "\(who) · \(when)"
        }

        var clockEnd: Double? = nil
        let parts = game.clockLeft.split(separator: ":")
        if game.status == .live, label.hasPrefix("Q"), parts.count == 2, let m = Int(parts[0]), let s = Int(parts[1]), m * 60 + s > 0 {
            clockEnd = Date().timeIntervalSince1970 + Double(m * 60 + s)
        }
        return .init(nuScore: game.nuScore, oppScore: game.oppScore, period: label, periodIndex: index,
                     clockLeft: game.clockLeft, lastGoal: lastGoal, isFinal: game.status == .final,
                     note: game.note, clockEnd: clockEnd)
    }
}
