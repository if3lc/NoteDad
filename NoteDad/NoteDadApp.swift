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
                do {
                    try store.createNewNote()
                } catch {
                    store.errorMessage = error.localizedDescription
                }
            }
            .keyboardShortcut("n", modifiers: .command)
        }

        CommandGroup(replacing: .printItem) {
            Button("Open Note...") {
                appState.presentCommandPalette()
            }
            .keyboardShortcut("p", modifiers: .command)
        }

        CommandMenu("Notes") {
            Button("New Markdown Note") {
                do {
                    try store.createNewNote(format: .markdown)
                } catch {
                    store.errorMessage = error.localizedDescription
                }
            }

            Button("New Text Note") {
                do {
                    try store.createNewNote(format: .plainText)
                } catch {
                    store.errorMessage = error.localizedDescription
                }
            }

            Divider()

            Button("Open Notes Folder") {
                store.openNotesFolder()
            }
        }
    }
}
