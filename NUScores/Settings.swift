import Combine
import SwiftUI

enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    /// nil follows the phone's setting.
    var scheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// The app's few settings, kept in UserDefaults. The Worker learns the notification choices through the push-to-start
/// token registration (see PushRegistrar), together with a per-install id, so more than one phone could be served later.
@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private let defaults = UserDefaults.standard

    @Published var appearance: Appearance {
        didSet { defaults.set(appearance.rawValue, forKey: "appearance") }
    }
    @Published var notifyFieldHockey: Bool {
        didSet { defaults.set(notifyFieldHockey, forKey: "notifyFieldHockey"); PushRegistrar.shared.settingsChanged() }
    }
    @Published var notifyLacrosse: Bool {
        didSet { defaults.set(notifyLacrosse, forKey: "notifyLacrosse"); PushRegistrar.shared.settingsChanged() }
    }

    /// Stable for this install; the Worker keys a phone's tokens on it.
    let deviceId: String

    /// Sport names exactly as the Worker labels them. Both off is an empty list, which the Worker treats as "none".
    var notifySports: [String] {
        var list: [String] = []
        if notifyFieldHockey { list.append(Sport.fieldHockey.rawValue) }
        if notifyLacrosse { list.append(Sport.lacrosse.rawValue) }
        return list
    }

    private init() {
        appearance = Appearance(rawValue: defaults.string(forKey: "appearance") ?? "") ?? .system
        notifyFieldHockey = defaults.object(forKey: "notifyFieldHockey") as? Bool ?? true
        notifyLacrosse = defaults.object(forKey: "notifyLacrosse") as? Bool ?? true
        if let id = defaults.string(forKey: "deviceId") {
            deviceId = id
        } else {
            let id = UUID().uuidString
            defaults.set(id, forKey: "deviceId")
            deviceId = id
        }
    }
}

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Appearance", selection: $settings.appearance) {
                        ForEach(Appearance.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text("Live Activities on the Lock Screen and Dynamic Island always follow your phone's appearance.")
                }

                Section {
                    Toggle("Field hockey", isOn: $settings.notifyFieldHockey)
                    Toggle("Lacrosse", isOn: $settings.notifyLacrosse)
                } header: {
                    Text("Start Live Activities automatically")
                } footer: {
                    Text("Turn a sport off and its games no longer start on their own. A game you follow with the bell keeps updating either way.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
