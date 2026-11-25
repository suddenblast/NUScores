import ActivityKit
import Foundation
import SwiftUI

// Add this file to BOTH the app target and the widget extension target.
// Anything the Live Activity and the app both need (the state shape, brand colors) lives here.
nonisolated struct NUGameAttributes: ActivityAttributes {
    nonisolated struct ContentState: Codable, Hashable {
        var nuScore: Int
        var oppScore: Int
        var period: String       // "Q1"..."Q4", "OT", "Final"
        var periodIndex: Int     // 1...4, 5 for OT
        var clockLeft: String    // "13:31", empty when not applicable
        var lastGoal: String     // "Northwestern · Q4 13:31 left"
        var isFinal: Bool
        var note: String         // "shootout"
        var clockEnd: Double? = nil   // epoch secs when the running clock hits 0; nil = no countdown
    }

    var opponent: String
    var sport: String
    var oppColorHex: String? = nil
    var gameId: String? = nil   // lets the Worker match an activity's push token to its game
    var nuHome: Bool? = nil     // nil (older activities) counts as home
}

extension Color {
    static let nuPurple = Color(red: 0x4E / 255, green: 0x2A / 255, blue: 0x84 / 255)

    init?(hex: String?) {
        guard var s = hex?.trimmingCharacters(in: .whitespaces), !s.isEmpty else { return nil }
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
}
