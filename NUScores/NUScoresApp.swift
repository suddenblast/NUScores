import SwiftUI

@main
struct NUScoresApp: App {
    @StateObject private var settings = AppSettings.shared

    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme(settings.appearance.scheme)
                // After the first frame, so the Live Activity service can't hold up launch.
                .task { PushRegistrar.shared.start() }
        }
    }
}
