import Combine
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var isCommandPalettePresented = false
    @Published var isAlwaysOnTop: Bool {
        didSet {
            defaults.set(isAlwaysOnTop, forKey: AppPreferences.alwaysOnTopKey)
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.isAlwaysOnTop = defaults.bool(forKey: AppPreferences.alwaysOnTopKey)
    }

    func presentCommandPalette() {
        isCommandPalettePresented = true
    }

    func dismissCommandPalette() {
        isCommandPalettePresented = false
    }

    func setAlwaysOnTop(_ isEnabled: Bool) {
        isAlwaysOnTop = isEnabled
    }

    func toggleAlwaysOnTop() {
        isAlwaysOnTop.toggle()
    }
}
