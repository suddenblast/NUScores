import SwiftUI

struct GameDetailView: View {
    let game: Game
    @StateObject private var wx = WeatherLoader()
    @Environment(\.colorScheme) private var scheme

    private var away: GameSide { game.awaySide }
    private var home: GameSide { game.homeSide }

    var body: some View {
        List {
            Section {
                scoreCard
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowBackground(Color.clear)
            }

            if !game.lines.isEmpty {
                Section {
                    VStack(spacing: 10) {
                        periodRow(label: cornerLabel, values: game.lines.map(\.period), secondary: true, total: "T")
                        periodRow(label: Text(away.short), values: game.lines.map { "\(game.nuHome ? $0.opp : $0.nu)" },
                                  total: "\(away.score)")
                        periodRow(label: Text(home.short), values: game.lines.map { "\(game.nuHome ? $0.nu : $0.opp)" },
                                  total: "\(home.score)")
                    }
                    .font(.subheadline)
                    .listRowBackground(Color.cardFill)
                } header: { sectionHeader("Score by period") }
            }

            if !game.goals.isEmpty {
                Section {
                    ForEach(game.goals) { g in
                        HStack(spacing: 10) {
                            Circle().fill(g.nuScored ? Color.nuPurple : game.oppColor)
                                .frame(width: 10, height: 10)
                            VStack(alignment: .leading) {
                                let team = g.nuScored ? "Northwestern" : game.opponent
                                Text(g.scorer.isEmpty ? "\(team) goal" : g.scorer)
                                Text(goalCaption(g, team: team))
                                    .font(.caption).foregroundStyle(.secondary)
                                    .lineLimit(1).minimumScaleFactor(0.8)   // stay on one line
                            }
                            .layoutPriority(1)   // the score on the right shrinks first, not this text
                            Spacer(minLength: 8)
                            Text(game.nuHome ? "\(game.opponent) \(g.oppScore)–\(g.nuScore) NU"
                                             : "NU \(g.nuScore)–\(g.oppScore) \(game.opponent)")
                                .font(.footnote)
                                .lineLimit(1).minimumScaleFactor(0.7)
                        }
                    }
                    .listRowBackground(Color.cardFill)
                } header: { sectionHeader("Goals") }
            }

            if game.goals.isEmpty && game.status == .final && game.note.isEmpty && (game.nuScore + game.oppScore) > 0 {
                Section {
                    Text("No scoring summary available")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .listRowBackground(Color.cardFill)
                } header: { sectionHeader("Goals") }
            }

            // Game info: plain small text, no box.
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    // "To be announced" only makes sense before the game; a played game with no listed location shows nothing.
                    if !game.venue.isEmpty {
                        Text(game.venue)
                    } else if game.status == .upcoming {
                        Text("Location to be announced")
                    }
                    if !infoLine.isEmpty { Text(infoLine) }
                    if wx.weather != nil, let attr = wx.attribution {
                        AppleWeatherAttribution(attribution: attr)
                            .environment(\.colorScheme, .dark)   // the white Apple Weather mark, for a dark background
                    }
                }
                .font(.footnote)
                .foregroundStyle(Color.white.opacity(0.8))   // sits on the team colors now
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            }
        }
        .scrollContentBackground(.hidden)
        .background { DetailBackground(away: away.color, home: home.color) }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)   // light status bar and back button over the dark gradient
        .tint(Color.white)
        .task(id: game.id) { await wx.load(for: game) }
    }

    // Section titles are white, since the team colors now run the whole length of the page.
    private func sectionHeader(_ title: String) -> some View {
        Text(title).foregroundStyle(Color.white.opacity(0.85))
    }

    // MARK: Score (sits directly on the team-color background, no box)

    private var scoreCard: some View {
        VStack(spacing: 14) {
            Text(caption).font(.footnote).opacity(0.85)
            HStack {
                teamBadge(away)
                Spacer(minLength: 8)
                scoreText
                Spacer(minLength: 8)
                teamBadge(home)
            }
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .padding(.bottom, 30)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var scoreText: some View {
        if game.status == .upcoming {
            Text(game.neutral ? "vs" : "@")
                .font(.system(size: 34, weight: .semibold))
                .opacity(0.85)
        } else {
            let dimAway = game.status == .final && away.score < home.score
            let dimHome = game.status == .final && home.score < away.score
            // Two-digit scores (lacrosse) get a smaller size and must never wrap.
            let big = away.score >= 10 || home.score >= 10
            HStack(spacing: big ? 6 : 10) {
                Text("\(away.score)").opacity(dimAway ? 0.75 : 1)
                Text("–").opacity(0.6)
                Text("\(home.score)").opacity(dimHome ? 0.75 : 1)
            }
            .font(.system(size: big ? 40 : 52, weight: .semibold))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    private func teamBadge(_ side: GameSide) -> some View {
        let markSize: CGFloat = scheme == .light ? 60 : 48
        return VStack(spacing: 6) {
            // Light mode: a white disc behind the logo, so a logo in the same color as the background (Indiana) still shows.
            // Wide logos (Maryland's M) need extra room inside the circle.
            TeamMark(seo: side.seo, color: side.color, size: markSize, backed: scheme == .light,
                     backingOpacity: 0.75, backingPadding: 0.17)
            Text(side.short)
                .font(.footnote.weight(side.isNU ? .bold : .regular))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if !side.record.isEmpty {
                Text(side.record)
                    .font(.caption2)
                    .monospacedDigit()
                    .opacity(0.8)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(width: 80)
        // Line the score up with the middle of the logo, not the middle of logo plus name.
        .alignmentGuide(VerticalAlignment.center) { _ in markSize / 2 }
    }

    // "NCAA tournament · Final · shootout", "Q4 13:31", or the start time for an upcoming game.
    private var caption: String {
        let status: String
        switch game.status {
        case .final:
            status = game.note.isEmpty ? "Final" : "Final · \(game.note)"
        case .live:
            status = "\(game.periodLabel) \(game.clockLeft)".trimmingCharacters(in: .whitespaces)
        case .upcoming:
            status = game.start?.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()) ?? ""
        }
        return [game.detail, status].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    // "Fri, Nov 20, 2026 · 52°F · Clear · 0% rain · 6 mph wind" (weather parts only when WeatherKit answered)
    private var infoLine: String {
        var parts: [String] = []
        if let s = game.start {
            parts.append(s.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().year()))
        }
        if let w = wx.weather {
            parts.append("\(w.tempF)°F · \(w.condition)")
            if let p = w.precipPct { parts.append("\(p)% rain") }
            if let wind = w.windMph { parts.append("\(wind) mph wind") }
        }
        return parts.joined(separator: " · ")
    }

    // "Northwestern · Q2 · 7:25 left". The team is only added when the scorer's name is the headline.
    private func goalCaption(_ g: Goal, team: String) -> String {
        let when = g.timeLeft.isEmpty ? g.period : "\(g.period) · \(g.timeLeft)"
        return g.scorer.isEmpty ? when : "\(team) · \(when)"
    }

    // Top-left of the table: "FINAL" (bold) plus "/OT" or "/SO" after extra time, "LIVE" during the game.
    private var cornerLabel: Text {
        switch game.status {
        case .final:
            let extra = game.note == "shootout" ? "/SO" : game.note == "OT" ? "/OT" : ""
            return Text("\(Text("FINAL").bold())\(extra)")
        case .live: return Text("LIVE").bold()
        case .upcoming: return Text("")
        }
    }

    private func periodRow(label: Text, values: [String], secondary: Bool = false, total: String? = nil) -> some View {
        HStack {
            label
                .frame(width: 90, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            ForEach(Array(values.enumerated()), id: \.offset) { _, v in
                Text(v).frame(maxWidth: .infinity)
            }
            if let total {
                Text(total)
                    .fontWeight(secondary ? .regular : .semibold)
                    .frame(width: 38)
                    .overlay(alignment: .leading) { Rectangle().fill(Color.secondary.opacity(0.35)).frame(width: 0.5) }
            }
        }
        .font(secondary ? .caption : .subheadline)
        .foregroundStyle(secondary ? Color.secondary : Color.primary)
    }
}

// Background for the game detail page: the away team's color on the left blending into the home team's on the right,
// darkened so white text reads, all the way down the page.
struct DetailBackground: View {
    let away: Color
    let home: Color
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Only a light touch of black, so each team's color stays recognizable on its own side. Darker in dark mode.
        let dim = scheme == .dark ? 0.4 : 0.12
        let a = away.mix(with: .black, by: dim)
        let h = home.mix(with: .black, by: dim)
        let mid = a.mix(with: h, by: 0.5)
        let deep = mid.mix(with: .black, by: 0.22)
        // Away color on the left, home color on the right, drifting slowly (still when Reduce Motion is on).
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
            MeshGradient(
                width: 3, height: 3,
                points: driftingMeshPoints(at: reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate),
                colors: [
                    a, mid, h,
                    a.mix(with: .black, by: 0.12), deep, h.mix(with: .black, by: 0.12),
                    a, mid, h,
                ]
            )
        }
        .ignoresSafeArea()
    }
}
