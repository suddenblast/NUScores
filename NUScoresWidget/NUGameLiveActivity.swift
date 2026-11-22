import ActivityKit
import SwiftUI
import WidgetKit

private let nuPurple = Color(red: 0x4E / 255, green: 0x2A / 255, blue: 0x84 / 255)
private let nuPurpleLight = Color(red: 0x8B / 255, green: 0x6F / 255, blue: 0xC7 / 255)
private let oppNavy = Color(red: 0x0C / 255, green: 0x23 / 255, blue: 0x40 / 255)

struct NUGameLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: NUGameAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(nuPurple)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let s = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    TeamBadge(name: "NU", color: nuPurple)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TeamBadge(name: context.attributes.opponent, color: Color(hex: context.attributes.oppColorHex) ?? .gray)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text("\(s.nuScore) – \(s.oppScore)")
                            .font(.system(size: 30, weight: .medium))
                        Text(statusText(s)).font(.caption).foregroundStyle(.secondary)
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
                Text(s.isFinal ? "Final" : "\(s.period) \(s.clockLeft)")
                    .font(.caption.weight(.medium))
            } minimal: {
                Text("\(s.nuScore)–\(s.oppScore)").font(.caption2.weight(.medium))
            }
        }
    }
}

private func statusText(_ s: NUGameAttributes.ContentState) -> String {
    if s.isFinal { return s.note.isEmpty ? "Final" : "Final · \(s.note)" }
    return s.clockLeft.isEmpty ? s.period : "\(s.period) · \(s.clockLeft)"
}

private struct TeamBadge: View {
    let name: String
    let color: Color
    var body: some View {
        VStack(spacing: 4) {
            Circle().fill(color).frame(width: 28, height: 28)
                .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1))
            Text(name).font(.caption)
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
                Text(statusText(s)).font(.caption)
            }
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Northwestern")
                    Text(context.attributes.opponent).opacity(0.85)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(s.nuScore)")
                    Text("\(s.oppScore)")
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
