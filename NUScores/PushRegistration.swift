import ActivityKit
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
