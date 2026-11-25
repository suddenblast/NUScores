import SwiftUI

struct GameDetailView: View {
    let game: Game
    @StateObject private var wx = WeatherLoader()

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
                Section("Score by period") {
                    VStack(spacing: 10) {
                        periodRow(label: "", values: game.lines.map(\.period), secondary: true)
                        periodRow(label: away.short, values: game.lines.map { "\(game.nuHome ? $0.opp : $0.nu)" })
                        periodRow(label: home.short, values: game.lines.map { "\(game.nuHome ? $0.nu : $0.opp)" })
                    }
                    .font(.subheadline)
                }
            }

            if !game.goals.isEmpty {
                Section("Goals") {
                    ForEach(game.goals) { g in
                        HStack(spacing: 10) {
                            Circle().fill(g.nuScored ? Color.nuPurple : game.oppColor)
                                .frame(width: 10, height: 10)
                            VStack(alignment: .leading) {
                                let team = g.nuScored ? "Northwestern" : game.opponent
                                Text(g.scorer.isEmpty ? "\(team) goal" : g.scorer)
                                Text(goalCaption(g, team: team))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(game.nuHome ? "\(game.opponent) \(g.oppScore)–\(g.nuScore) NU"
                                             : "NU \(g.nuScore)–\(g.oppScore) \(game.opponent)")
                                .font(.footnote)
                        }
                    }
                }
            }

            if game.goals.isEmpty && game.status == .final && game.note.isEmpty && (game.nuScore + game.oppScore) > 0 {
                Section("Goals") {
                    Text("No scoring summary available")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
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
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
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
        VStack(spacing: 6) {
            TeamMark(seo: side.seo, color: side.color, size: 48)
            Text(side.short)
                .font(.footnote.weight(side.isNU ? .bold : .regular))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(width: 80)
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

    private func periodRow(label: String, values: [String], secondary: Bool = false) -> some View {
        HStack {
            Text(label)
                .frame(width: 90, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            ForEach(Array(values.enumerated()), id: \.offset) { _, v in
                Text(v).frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(secondary ? Color.secondary : Color.primary)
    }
}

// Background for the game detail page: the away team's color on the left blending into the home team's on the right,
// darkened so white text reads, and fading into the normal grouped background below the score.
struct DetailBackground: View {
    let away: Color
    let home: Color

    var body: some View {
        // Only a light touch of black, so each team's color stays recognizable on its own side.
        let a = away.mix(with: .black, by: 0.12)
        let h = home.mix(with: .black, by: 0.12)
        let base = Color(.systemGroupedBackground)
        ZStack {
            LinearGradient(stops: [
                .init(color: a, location: 0.0),
                .init(color: a, location: 0.15),
                .init(color: h, location: 0.85),
                .init(color: h, location: 1.0),
            ], startPoint: .leading, endPoint: .trailing)
            LinearGradient(stops: [
                .init(color: base.opacity(0), location: 0.0),
                .init(color: base.opacity(0), location: 0.12),
                .init(color: base, location: 0.38),
            ], startPoint: .top, endPoint: .bottom)
        }
        .ignoresSafeArea()
    }
}
