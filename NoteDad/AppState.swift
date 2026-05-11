import Combine
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var isCommandPalettePresented = false

    func presentCommandPalette() {
        isCommandPalettePresented = true
    }

    func dismissCommandPalette() {
        isCommandPalettePresented = false
    }
}
