import ActivityKit
import Foundation
import SwiftUI

// Add this file to BOTH the app target and the widget extension target.
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
    }
    
    var opponent: String
    var sport: String
    var oppColorHex: String? = nil
}

extension Color {
    init?(hex: String?) {
        guard var s = hex?.trimmingCharacters(in: .whitespaces), !s.isEmpty else { return nil }
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
}
