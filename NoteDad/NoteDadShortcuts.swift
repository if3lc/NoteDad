import SwiftUI

enum NoteDadShortcuts {
    static let newNote = Shortcut(key: "n", modifiers: .command)
    static let openNote = Shortcut(key: "p", modifiers: .command)
    static let markdownFormat = Shortcut(key: "1", modifiers: .command)
    static let plainTextFormat = Shortcut(key: "2", modifiers: .command)
    static let alwaysOnTop = Shortcut(key: "t", modifiers: [.command, .shift])

    struct Shortcut {
        let key: KeyEquivalent
        let modifiers: EventModifiers
    }
}
