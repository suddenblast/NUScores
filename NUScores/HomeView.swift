import SwiftUI

struct HomeView: View {
    @StateObject private var store = GameStore()
    @State private var chosenSport: Sport?   // nil until the user taps the picker; then their choice wins
    @State private var seasonOverride: Int?   // nil = the current academic year
    @State private var showSettings = false
    @Environment(\.colorScheme) private var scheme

    private static var currentSeason: Int { Game.academicYear(of: Date()) }
    private var allGames: [Game] { store.games }
    private var season: Int { seasonOverride ?? Self.currentSeason }

    // There is no "All" view. Until the user picks a sport, show the one in play: a live game's sport first, else the
    // sport whose game in this season is closest to today (so field hockey in the fall, lacrosse in the spring).
    private var filter: Sport {
        if let chosenSport { return chosenSport }
        let inSeason = allGames.filter { $0.academicYear == nil || $0.academicYear == season }
        if let live = inSeason.first(where: { $0.status == .live }) { return live.sport }
        let now = Date()
        let nearest = inSeason.compactMap { g in g.start.map { (g.sport, abs($0.timeIntervalSince(now))) } }
            .min { $0.1 < $1.1 }
        return nearest?.0 ?? .fieldHockey
    }

    // Every academic year that has games, plus the current one, newest first.
    private var seasons: [Int] {
        Set(allGames.compactMap(\.academicYear)).union([Self.currentSeason]).sorted(by: >)
    }

    private func seasonLabel(_ year: Int) -> String {
        "\(year)–" + String(format: "%02d", (year + 1) % 100)
    }

    // Overall record for the selected sport and season. Counts one game per opponent per day,
    // so a game that was stored twice (live recording plus backfill) is not counted twice.
    private var record: String? {
        var seen = Set<String>()
        var w = 0, l = 0, t = 0
        for g in shown where g.status == .final {
            let key: String
            if let start = g.start {
                key = "\(g.sport.rawValue)|\(g.opponent)|\(Calendar.current.startOfDay(for: start).timeIntervalSince1970)"
            } else {
                key = g.id
            }
            guard seen.insert(key).inserted else { continue }
            if g.nuScore > g.oppScore { w += 1 } else if g.nuScore < g.oppScore { l += 1 } else { t += 1 }
        }
        guard w + l + t > 0 else { return nil }
        return t > 0 ? "\(w)–\(l)–\(t)" : "\(w)–\(l)"
    }

    // Games with no start time are always shown, so a live game can never disappear.
    private var shown: [Game] {
        allGames.filter { g in
            g.sport == filter && (g.academicYear == nil || g.academicYear == season)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    // Academic year (Aug 1 to Jul 31), defaulting to the current one. The record sits on the right.
                    HStack {
                        Menu {
                            Picker("Season", selection: Binding(get: { season }, set: { seasonOverride = $0 })) {
                                ForEach(seasons, id: \.self) { y in Text(seasonLabel(y)).tag(y) }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text("\(seasonLabel(season)) season")
                                Image(systemName: "chevron.down").font(.caption.weight(.bold))
                            }
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(scheme == .dark ? Color(red: 0xB5 / 255, green: 0x9B / 255, blue: 0xE6 / 255) : Color.nuPurple)
                        }
                        Spacer()
                        if let record {
                            HStack(spacing: 4) {
                                Text(record).font(.callout.weight(.bold)).monospacedDigit()
                                Text("overall").font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))

                    Picker("Sport", selection: Binding(get: { filter }, set: { chosenSport = $0 })) {
                        Text("Field hockey").tag(Sport.fieldHockey)
                        Text("Lacrosse").tag(Sport.lacrosse)
                    }
                    .pickerStyle(.segmented)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 0, trailing: 0))
                } header: {
                    // The title is the first section's header: a row would be clipped by the list's rounded corner.
                    HStack {
                        Text("Northwestern")
                            .font(.largeTitle.bold())
                            .foregroundStyle(Color(uiColor: .label))   // a plain color: .primary gets dimmed by the header style
                            .accessibilityAddTraits(.isHeader)
                        Spacer()
                        Button { showSettings = true } label: {
                            Image(systemName: "gearshape").font(.title3)
                                .foregroundStyle(Color(uiColor: .secondaryLabel))
                        }
                        .accessibilityLabel("Settings")
                    }
                    .textCase(nil)
                    .padding(.leading, -16)   // lines up with the rows below, like the other headers
                    .padding(.trailing, -16)
                    .padding(.bottom, 2)
                }
                .listRowBackground(Color.clear)
                if let err = store.errorText {
                    Section { Text(err).font(.footnote).foregroundStyle(.secondary) }
                }

                // Live games: a gradient card with no section header.
                let live = shown.filter { $0.status == .live }
                if !live.isEmpty {
                    Section {
                        ForEach(live.map(LiveItem.init)) { item in
                            let g = item.game
                            ZStack {
                                LiveCard(game: g)
                                NavigationLink(value: g) { EmptyView() }.opacity(0)   // hides the chevron
                            }
                            .overlay(alignment: .topTrailing) {
                                LiveActivityButton(game: g).padding(.top, 8).padding(.trailing, 12)
                            }
                            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                            .listRowBackground(Color.clear)
                        }
                    }
                }

                section("Recent", shown.filter { $0.status == .final }
                    .sorted { ($0.start ?? .distantPast) > ($1.start ?? .distantPast) }) { FinalRow(game: $0) }
                section("Upcoming", shown.filter { $0.status == .upcoming }
                    .sorted { ($0.start ?? .distantFuture) < ($1.start ?? .distantFuture) }) { UpcomingRow(game: $0) }
                if store.loadedOnce && shown.isEmpty && store.errorText == nil {
                    Section { Text("No \(filter.rawValue.lowercased()) games in \(seasonLabel(season)) yet.").foregroundStyle(.secondary) }
                        .listRowBackground(Color.cardFill)
                }
            }
            .scrollContentBackground(.hidden)
            .listSectionSpacing(.compact)
            .environment(\.defaultMinListRowHeight, 24)   // lets the small season row stay small
            .background { HomeBackground() }
            .overlay { if !store.loadedOnce { ProgressView() } }
            .toolbar(.hidden, for: .navigationBar)   // the title is the first row of the list, so there is no empty bar above it
            .sheet(isPresented: $showSettings) { SettingsView() }
            .navigationDestination(for: Game.self) { g in
                let current = allGames.first { $0.id == g.id } ?? g
                GameDetailView(game: current).id(current.changeKey)
            }
            .refreshable { await store.refresh() }
            .task {
                while !Task.isCancelled {
                    await store.refresh()
                    try? await Task.sleep(for: .seconds(30))
                }
            }
        }
    }

    @ViewBuilder
    private func section<Row: View>(_ title: String, _ items: [Game], @ViewBuilder row: @escaping (Game) -> Row) -> some View {
        if !items.isEmpty {
            Section {
                ForEach(items) { g in
                    NavigationLink(value: g) { row(g) }
                }
                .listRowBackground(Color.cardFill)
            } header: {
                Text(title).padding(.leading, -16)   // lines the header up with the card edge and the title
            }
        }
    }
}

// Game == compares ids only, so SwiftUI thinks a live game never changes. This wrapper's id includes the score
// and clock, so the live card is rebuilt whenever they change.
private struct LiveItem: Identifiable {
    let game: Game
    var id: String { game.changeKey }
}

// A thin stripe in the opponent's color down the left edge of a row.
private struct OpponentStripe: ViewModifier {
    let color: Color

    // The team's own color, with a slight white stroke so dark colors still show on dark rows.
    func body(content: Content) -> some View {
        content
            .padding(.leading, 17)
            .overlay(alignment: .leading) {
                Capsule().fill(color)
                    .overlay(Capsule().stroke(Color.white.opacity(0.6), lineWidth: 1))
                    .frame(width: 5)
                    .padding(.vertical, 2)
            }
    }
}

private extension View {
    func opponentStripe(_ color: Color) -> some View { modifier(OpponentStripe(color: color)) }
}

// The leading score is bold and the trailing one thin. A tie leaves both regular.
private func scoreWeight(_ score: Int, other: Int) -> Font.Weight {
    score > other ? .bold : score < other ? .light : .regular
}

// Turns the lock-screen Live Activity for one game on or off. It reads "on" while an activity for the game exists,
// so dismissing the activity from the lock screen switches it off too.
private struct LiveActivityButton: View {
    let game: Game
    @ObservedObject private var controller = LiveActivityController.shared

    var body: some View {
        if controller.available {
            let on = controller.isOn(game.id)
            Button { controller.toggle(game) } label: {
                Image(systemName: on ? "bell.fill" : "bell.slash")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(.white.opacity(on ? 0.28 : 0.14)))
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(on ? "Turn off Live Activity" : "Turn on Live Activity")
        }
    }
}

struct LiveCard: View {
    let game: Game
    var body: some View {
        let sides = [game.awaySide, game.homeSide]
        let a = game.awaySide.color.mix(with: .black, by: 0.12)
        let h = game.homeSide.color.mix(with: .black, by: 0.12)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Circle().fill(Color.red).frame(width: 8, height: 8)
                    Text("LIVE").fontWeight(.bold)
                    if !game.detail.isEmpty { Text("· " + game.detail).opacity(0.85) }
                }
                Spacer()
                Text("\(game.periodLabel) \(game.clockLeft)").fontWeight(.semibold)
                    .padding(.trailing, LiveActivityController.shared.available ? 28 : 0)   // room for the bell button
            }
            .font(.caption)
            // Away team first, home team second.
            ForEach(Array(sides.enumerated()), id: \.offset) { _, side in
                HStack(spacing: 12) {
                    TeamMark(seo: side.seo, color: side.color, size: 34, backed: true)
                    Text(side.name)
                        .font(.title3)
                        .fontWeight(side.isNU ? .bold : .regular)
                        .opacity(side.isNU ? 1 : 0.9)
                    Spacer()
                    Text("\(side.score)")
                        .font(.system(size: 34, weight: scoreWeight(side.score, other: sides.first { $0.isNU != side.isNU }?.score ?? 0)))
                        .monospacedDigit()
                }
            }
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            LinearGradient(stops: [
                .init(color: a, location: 0.0),
                .init(color: a, location: 0.12),
                .init(color: h, location: 0.88),
                .init(color: h, location: 1.0),
            ], startPoint: .leading, endPoint: .trailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct UpcomingRow: View {
    let game: Game
    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading) {
                Text("\(game.vs) \(game.opponent)")
                let place = game.venue.components(separatedBy: " · ").last ?? ""
                if !place.isEmpty { Text(place).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer()
            if let s = game.start {
                VStack(alignment: .trailing) {
                    Text(s.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                        .fontWeight(.medium)
                    Text(s.formatted(.dateTime.hour().minute()))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .opponentStripe(game.oppColor)
    }
}

struct FinalRow: View {
    let game: Game
    private var won: Bool { game.nuScore > game.oppScore }
    private var caption: String {
        var parts: [String] = []
        if !game.note.isEmpty { parts.append(game.note) }
        if let s = game.start { parts.append(s.formatted(.dateTime.month(.abbreviated).day())) }
        return parts.joined(separator: " · ")
    }
    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading) {
                Text("\(Text(won ? "W" : "L").fontWeight(.bold).foregroundStyle(won ? Color.green : Color.red)) \(game.vs) \(game.opponent)")
                Text(caption)
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(Text("\(game.nuScore)").fontWeight(scoreWeight(game.nuScore, other: game.oppScore)))–\(Text("\(game.oppScore)").fontWeight(scoreWeight(game.oppScore, other: game.nuScore)))")
                .monospacedDigit()
        }
        .opponentStripe(game.oppColor)
    }
}

// Soft purple-led gradient behind the home list. Pastel in light mode, deep in dark mode.
struct HomeBackground: View {
    @Environment(\.colorScheme) private var scheme

    private var colors: [Color] {
        let hexes: [UInt32] = scheme == .dark
            ? [0x2B1055, 0x4E2A84, 0x1F3A8A,
               0x5B2A86, 0x7B3FA0, 0x2A4D9B,
               0x3A1C71, 0x6A2C91, 0x0F5B7A]
            : [0xE9DDFB, 0xD6C8F5, 0xCFE0FA,
               0xF3D9F0, 0xE2CCF7, 0xC9E6F5,
               0xFBE3E8, 0xEBD7F7, 0xD4EEF0]
        return hexes.map {
            Color(red: Double(($0 >> 16) & 0xFF) / 255, green: Double(($0 >> 8) & 0xFF) / 255, blue: Double($0 & 0xFF) / 255)
        }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Drifts slowly; still when Reduce Motion is on.
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
            MeshGradient(
                width: 3, height: 3,
                points: driftingMeshPoints(at: reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate,
                                           center: [0.6, 0.4]),
                colors: colors
            )
        }
        .ignoresSafeArea()
    }
}

extension Game {
    /// Changes whenever anything shown on a live card or detail screen changes.
    var changeKey: String {
        "\(id)|\(nuScore)-\(oppScore)|\(periodLabel)|\(clockLeft)|\(status)|\(goals.count)|\(note)"
    }

    /// The academic year a game belongs to, as its starting year: Aug 1, 2026 to Jul 31, 2027 is 2026.
    var academicYear: Int? { start.map { Game.academicYear(of: $0) } }

    static func academicYear(of date: Date) -> Int {
        let c = Calendar.current.dateComponents([.year, .month], from: date)
        let year = c.year ?? 0
        return (c.month ?? 1) >= 8 ? year : year - 1
    }
}
