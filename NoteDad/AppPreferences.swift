import Foundation

enum AppPreferences {
    static let lastNotePathKey = "lastNotePath"
    static let defaultFormatKey = "defaultFormat"
    static let editorFontSizeKey = "editorFontSize"
    static let quickNoteEnabledKey = "quickNoteEnabled"
    static let alwaysOnTopKey = "alwaysOnTop"

    static func clear(in defaults: UserDefaults) {
        defaults.removeObject(forKey: lastNotePathKey)
        defaults.removeObject(forKey: defaultFormatKey)
        defaults.removeObject(forKey: editorFontSizeKey)
        defaults.removeObject(forKey: quickNoteEnabledKey)
        defaults.removeObject(forKey: alwaysOnTopKey)
    }
}
