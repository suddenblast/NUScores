import SwiftUI

struct HomeView: View {
    @StateObject private var store = GameStore()
    @StateObject private var demo = LiveActivityDemo()

    var body: some View {
        NavigationStack {
            List {
                if let err = store.errorText {
                    Section { Text(err).font(.footnote).foregroundStyle(.secondary) }
                }
                section("Live", store.games.filter { $0.status == .live }) { LiveCard(game: $0) }
                section("Upcoming", store.games.filter { $0.status == .upcoming }) { UpcomingRow(game: $0) }
                section("Recent", store.games.filter { $0.status == .final }) { FinalRow(game: $0) }
                if store.loadedOnce && store.games.isEmpty && store.errorText == nil {
                    Section { Text("No games yet.").foregroundStyle(.secondary) }
                }
            }
            .overlay { if !store.loadedOnce { ProgressView() } }
            .navigationTitle("Northwestern")
            .navigationDestination(for: Game.self) { g in
                GameDetailView(game: store.games.first { $0.id == g.id } ?? g)
            }
            #if DEBUG
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(demo.running ? "Stop demo" : "Demo") { demo.toggle() }
                }
            }
            #endif
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
            Section(title) {
                ForEach(items) { g in
                    NavigationLink(value: g) { row(g) }
                        .listRowBackground(g.status == .live ? Color.nuPurple : nil)
                }
            }
        }
    }
}

struct LiveCard: View {
    let game: Game
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text([game.sport.rawValue, game.detail].filter { !$0.isEmpty }.joined(separator: " · "))
                Spacer()
                Text("\(game.periodLabel) \(game.clockLeft)")
            }
            .font(.caption)
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Northwestern")
                    Text(game.opponent).opacity(0.85)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(game.nuScore)")
                    Text("\(game.oppScore)")
                }
                .font(.title2.weight(.medium))
            }
        }
        .foregroundStyle(.white)
        .padding(.vertical, 6)
    }
}

struct UpcomingRow: View {
    let game: Game
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("vs \(game.opponent)")
                Text([game.sport.rawValue, game.venue.components(separatedBy: " · ").last ?? ""]
                        .filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let s = game.start {
                Text(s.formatted(.dateTime.weekday(.abbreviated).hour().minute()))
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}

struct FinalRow: View {
    let game: Game
    private var won: Bool { game.nuScore > game.oppScore }
    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(won ? Color.green : Color.red)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading) {
                Text("\(won ? "W" : "L") vs \(game.opponent)")
                Text(game.note.isEmpty ? game.sport.rawValue : "\(game.sport.rawValue) · \(game.note)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(game.nuScore)–\(game.oppScore)").fontWeight(.medium)
        }
    }
}
