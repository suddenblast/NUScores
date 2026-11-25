import ActivityKit
import SwiftUI
import WidgetKit

// Lighter purple for the quarter bar in the Dynamic Island (NU purple itself is Color.nuPurple, shared with the app).
private let nuPurpleLight = Color(red: 0x8B / 255, green: 0x6F / 255, blue: 0xC7 / 255)

struct NUGameLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NUGameAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(.nuPurple)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let s = context.state
            let nuHome = context.attributes.nuHome ?? true
            let nuBadge = TeamBadge(name: "NU", color: .nuPurple, seo: "northwestern")
            let oppBadge = TeamBadge(name: context.attributes.opponent, color: Color(hex: context.attributes.oppColorHex) ?? .gray, seo: context.attributes.oppSeo)
            return DynamicIsland {
                // Away team on the left, home team on the right.
                DynamicIslandExpandedRegion(.leading) {
                    if nuHome { oppBadge } else { nuBadge }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if nuHome { nuBadge } else { oppBadge }
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(nuHome ? "\(s.oppScore) – \(s.nuScore)" : "\(s.nuScore) – \(s.oppScore)")
                            .font(.system(size: 30, weight: .medium))
                        StatusLine(s: s).font(.caption).foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        QuarterBar(index: s.periodIndex, tint: nuPurpleLight)
                        if !s.lastGoal.isEmpty {
                            Text("Last goal: \(s.lastGoal)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            } compactLeading: {
                Text("NU \(s.nuScore)–\(s.oppScore)").font(.caption.weight(.medium))
            } compactTrailing: {
                CompactStatus(s: s)
                    .font(.caption.weight(.medium))
            } minimal: {
                Text("\(s.nuScore)–\(s.oppScore)").font(.caption2.weight(.medium))
            }
        }
    }
}

// The quarter clock. While a quarter is running the push carries clockEnd (when the clock should hit
// 0:00) and the phone counts down by itself, snapping to the feed's clock at every push. Otherwise
// (break, OT, final, or no data) it shows the plain clockLeft text.
private struct ClockView: View {
    let s: NUGameAttributes.ContentState
    var width: CGFloat = 40
    var body: some View {
        if !s.isFinal, (s.clockEnd ?? 0) > 0 {
            let end = Date(timeIntervalSince1970: s.clockEnd ?? 0)
            Text(timerInterval: Date.now...max(end, Date.now), pauseTime: nil, countsDown: true, showsHours: false)
                .monospacedDigit()
                .frame(width: width, alignment: .leading)
        } else {
            Text(s.clockLeft)
        }
    }
}

private struct StatusLine: View {
    let s: NUGameAttributes.ContentState
    var body: some View {
        if s.isFinal {
            Text(s.note.isEmpty ? "Final" : "Final · \(s.note)")
        } else if s.clockLeft.isEmpty && (s.clockEnd ?? 0) == 0 {
            Text(s.period)
        } else {
            HStack(spacing: 4) {
                Text(s.period)
                Text("·")
                ClockView(s: s)
            }
        }
    }
}

private struct CompactStatus: View {
    let s: NUGameAttributes.ContentState
    var body: some View {
        if s.isFinal {
            Text("Final")
        } else {
            HStack(spacing: 3) {
                Text(s.period)
                ClockView(s: s, width: 34)
            }
        }
    }
}

private struct TeamBadge: View {
    let name: String
    let color: Color
    var seo: String? = nil
    var body: some View {
        VStack(spacing: 4) {
            TeamMark(seo: seo, color: color, size: 30, ringWidth: 1, ring: .white.opacity(0.25), backed: true)
            Text(name).font(.caption).lineLimit(1).minimumScaleFactor(0.7)
        }
    }
}

private struct QuarterBar: View {
    let index: Int
    let tint: Color
    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...4, id: \.self) { i in
                Capsule().fill(i <= index ? tint : Color.gray.opacity(0.4)).frame(height: 3)
            }
        }
    }
}

private struct LockScreenView: View {
    let context: ActivityViewContext<NUGameAttributes>
    var body: some View {
        let s = context.state
        VStack(spacing: 10) {
            HStack {
                Text(context.attributes.sport).font(.caption)
                Spacer()
                StatusLine(s: s).font(.caption)
            }
            // Away team first, home team second.
            let nuHome = context.attributes.nuHome ?? true
            let nu = (name: "Northwestern", score: s.nuScore)
            let opp = (name: context.attributes.opponent, score: s.oppScore)
            let top = nuHome ? opp : nu
            let bottom = nuHome ? nu : opp
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(top.name).opacity(nuHome ? 0.85 : 1)
                    Text(bottom.name).opacity(nuHome ? 1 : 0.85)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(top.score)")
                    Text("\(bottom.score)")
                }
                .font(.title2.weight(.medium))
            }
            QuarterBar(index: s.periodIndex, tint: .white)
            if !s.lastGoal.isEmpty {
                Text("Last goal: \(s.lastGoal)").font(.caption).opacity(0.85)
            }
        }
        .foregroundStyle(.white)
        .padding(16)
    }
}
