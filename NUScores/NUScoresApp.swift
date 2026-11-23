import SwiftUI

@main
struct NUScoresApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
                // After the first frame, so the Live Activity service can't hold up launch.
                .task { PushRegistrar.shared.start() }
        }
    }
}
