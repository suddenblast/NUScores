import SwiftUI

struct GameDetailView: View {
    let game: Game
    @StateObject private var wx = WeatherLoader()

    var body: some View {
        List {
            Section {
                VStack(spacing: 10) {
                    Text(game.status == .final
                         ? (game.note.isEmpty ? "Final" : "Final · \(game.note)")
                         : "\(game.periodLabel) \(game.clockLeft)")
                        .font(.footnote).foregroundStyle(.secondary)
                    HStack(spacing: 24) {
                        badge("NU", .nuPurple)
                        Text("\(game.nuScore) – \(game.oppScore)")
                            .font(.system(size: 36, weight: .medium))
                        badge(game.opponent, game.oppColor)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            if !game.venue.isEmpty || wx.weather != nil {
                Section(game.status == .final ? "Game info" : "Conditions") {
                    if !game.venue.isEmpty {
                        Label(game.venue, systemImage: "mappin.and.ellipse")
                    }
                    if let w = wx.weather {
                        HStack {
                            Label("\(w.tempF)°F · \(w.condition)", systemImage: w.symbol)
                            Spacer()
                            Text(weatherDetail(w)).font(.footnote).foregroundStyle(.secondary)
                        }
                        if let attr = wx.attribution { AppleWeatherAttribution(attribution: attr) }
                    }
                }
            }

            if !game.lines.isEmpty {
                Section("Score by period") {
                    VStack(spacing: 10) {
                        periodRow(label: "", values: game.lines.map(\.period), secondary: true)
                        periodRow(label: "NU", values: game.lines.map { "\($0.nu)" })
                        periodRow(label: game.opponent, values: game.lines.map { "\($0.opp)" })
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
                            Text("NU \(g.nuScore)–\(g.oppScore) \(game.opponent)")
                                .font(.footnote)
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task(id: game.id) { await wx.load(for: game) }
    }

    // "Northwestern · Q2 · 7:25 left". The team is only added when the scorer's name is the headline.
    private func goalCaption(_ g: Goal, team: String) -> String {
        let when = g.timeLeft.isEmpty ? g.period : "\(g.period) · \(g.timeLeft)"
        return g.scorer.isEmpty ? when : "\(team) · \(when)"
    }

    private func weatherDetail(_ w: GameWeather) -> String {
        var parts: [String] = []
        if let p = w.precipPct { parts.append("\(p)% rain") }
        if let wind = w.windMph { parts.append("\(wind) mph wind") }
        return parts.joined(separator: " · ")
    }

    private func badge(_ text: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Circle().fill(color).frame(width: 34, height: 34)
                .overlay(Circle().stroke(Color.secondary.opacity(0.3), lineWidth: 1))
            Text(text).font(.caption)
        }
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
