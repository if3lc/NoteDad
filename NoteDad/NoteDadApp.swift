import SwiftUI

@main
struct NoteDadApp: App {
    @StateObject private var store = NoteStore()
    @StateObject private var appState = AppState()
    @AppStorage(AppPreferences.quickNoteEnabledKey) private var quickNoteEnabled = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(appState)
        }
        .commands {
            NoteDadCommands(store: store, appState: appState)
        }

        Settings {
            SettingsView(store: store, quickNoteEnabled: $quickNoteEnabled)
        }

        MenuBarExtra("NoteDad", systemImage: "note.text", isInserted: $quickNoteEnabled) {
            QuickNoteView(store: store)
        }
        .menuBarExtraStyle(.window)
    }
}

struct NoteDadCommands: Commands {
    @ObservedObject var store: NoteStore
    @ObservedObject var appState: AppState

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Note") {
                createNote()
            }
            .noteDadShortcut(NoteDadShortcuts.newNote)
        }

        CommandGroup(replacing: .printItem) {
            Button("Open Note...") {
                appState.presentCommandPalette()
            }
            .noteDadShortcut(NoteDadShortcuts.openNote)
        }

        CommandGroup(after: .pasteboard) {
            Button("Find in Note") {
                appState.presentFind()
            }
            .noteDadShortcut(NoteDadShortcuts.findInNote)

            Button("Find Next") {
                appState.findNext()
            }
            .noteDadShortcut(NoteDadShortcuts.findNext)

            Button("Find Previous") {
                appState.findPrevious()
            }
            .noteDadShortcut(NoteDadShortcuts.findPrevious)
        }

        CommandMenu("Notes") {
            Button("New Markdown Note") {
                createNote(format: .markdown)
            }

            Button("New Text Note") {
                createNote(format: .plainText)
            }

            Divider()

            Button("Use Markdown Format") {
                store.setActiveFormat(.markdown)
            }
            .noteDadShortcut(NoteDadShortcuts.markdownFormat)

            Button("Use Text Format") {
                store.setActiveFormat(.plainText)
            }
            .noteDadShortcut(NoteDadShortcuts.plainTextFormat)

            Divider()

            Button(appState.isAlwaysOnTop ? "Disable Always on Top" : "Enable Always on Top") {
                appState.toggleAlwaysOnTop()
            }
            .noteDadShortcut(NoteDadShortcuts.alwaysOnTop)

            Divider()

            Button("Open Notes Folder") {
                store.openNotesFolder()
            }
        }
    }

    private func createNote(format: NoteFormat? = nil) {
        do {
            try store.createNewNote(format: format)
        } catch {
            store.errorMessage = error.localizedDescription
        }
    }
}

private extension View {
    func noteDadShortcut(_ shortcut: NoteDadShortcuts.Shortcut) -> some View {
        keyboardShortcut(shortcut.key, modifiers: shortcut.modifiers)
    }
}
