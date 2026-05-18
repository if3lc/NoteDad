import Combine
import Foundation

enum NoteFindDirection: Equatable {
    case next
    case previous
}

struct NoteFindNavigationRequest: Equatable {
    var direction: NoteFindDirection = .next
    var token = 0
}

@MainActor
final class AppState: ObservableObject {
    @Published var isCommandPalettePresented = false
    @Published var isFindPresented = false
    @Published var findPresentationToken = 0
    @Published var findNavigationRequest = NoteFindNavigationRequest()
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

    func presentFind() {
        isFindPresented = true
        findPresentationToken += 1
    }

    func dismissFind() {
        isFindPresented = false
    }

    func findNext() {
        isFindPresented = true
        findNavigationRequest = NoteFindNavigationRequest(
            direction: .next,
            token: findNavigationRequest.token + 1
        )
    }

    func findPrevious() {
        isFindPresented = true
        findNavigationRequest = NoteFindNavigationRequest(
            direction: .previous,
            token: findNavigationRequest.token + 1
        )
    }

    func setAlwaysOnTop(_ isEnabled: Bool) {
        isAlwaysOnTop = isEnabled
    }

    func toggleAlwaysOnTop() {
        isAlwaysOnTop.toggle()
    }
}
