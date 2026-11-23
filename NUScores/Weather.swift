import Combine
import CoreLocation
import Foundation
import MapKit
import SwiftUI
import WeatherKit

struct GameWeather {
    let tempF: Int
    let feelsF: Int?
    let precipPct: Int?
    let windMph: Int?
    let condition: String
    let symbol: String      // SF Symbol name
}

// Loads the weather at a game's venue around its start time, straight from Apple WeatherKit.
// The venue's city is turned into coordinates with MapKit.
// Needs the WeatherKit capability on the app target. Without it the calls throw and nothing is shown.
@MainActor
final class WeatherLoader: ObservableObject {
    @Published var weather: GameWeather?
    @Published var attribution: WeatherAttribution?

    private static var cache: [String: GameWeather] = [:]
    private static var coords: [String: CLLocation] = [:]

    func load(for game: Game) async {
        guard let start = game.start, !game.venueCity.isEmpty else { return }
        let place = [game.venueCity, game.venueState].filter { !$0.isEmpty }.joined(separator: ", ")
        if let hit = Self.cache[game.id] {
            weather = hit
            attribution = try? await WeatherService.shared.attribution
            return
        }
        do {
            let location: CLLocation
            if let c = Self.coords[place] {
                location = c
            } else {
                guard let request = MKGeocodingRequest(addressString: place),
                      let found = try await request.mapItems.first?.location else { return }
                Self.coords[place] = found
                location = found
            }
            let forecast = try await WeatherService.shared.weather(
                for: location,
                including: .hourly(startDate: start.addingTimeInterval(-3600), endDate: start.addingTimeInterval(2 * 3600))
            )
            guard let hour = forecast.forecast.min(by: {
                abs($0.date.timeIntervalSince(start)) < abs($1.date.timeIntervalSince(start))
            }) else {
                print("[weather] no hourly data near \(start) for \(place)")
                return
            }
            let result = GameWeather(
                tempF: Int(hour.temperature.converted(to: .fahrenheit).value.rounded()),
                feelsF: Int(hour.apparentTemperature.converted(to: .fahrenheit).value.rounded()),
                precipPct: Int((hour.precipitationChance * 100).rounded()),
                windMph: Int(hour.wind.speed.converted(to: .milesPerHour).value.rounded()),
                condition: hour.condition.description,
                symbol: hour.symbolName
            )
            Self.cache[game.id] = result
            weather = result
            attribution = try? await WeatherService.shared.attribution
        } catch {
            print("[weather] failed for \(place): \(error)")
        }
    }
}

// Apple requires its mark and a link to the legal page next to WeatherKit data.
struct AppleWeatherAttribution: View {
    let attribution: WeatherAttribution
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 8) {
            AsyncImage(url: scheme == .dark ? attribution.combinedMarkDarkURL : attribution.combinedMarkLightURL) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Color.clear
            }
            .frame(height: 12)
            Spacer()
            Link("Other data sources", destination: attribution.legalPageURL)
                .font(.caption2)
        }
    }
}
