import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: NoteStore
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                editorSurface

                editorFooter
            }
            .frame(minWidth: 700, minHeight: 520)
            .task {
                store.bootstrap()
            }
            .alert("NoteDad", isPresented: errorBinding) {
                Button("OK", role: .cancel) {
                    store.errorMessage = nil
                }
            } message: {
                Text(store.errorMessage ?? "Unknown error")
            }

            if appState.isCommandPalettePresented {
                CommandPaletteView()
                    .environmentObject(store)
                    .environmentObject(appState)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(10)
            }
        }
        .animation(.easeOut(duration: 0.12), value: appState.isCommandPalettePresented)
    }

    private var editorSurface: some View {
        ZStack(alignment: .topTrailing) {
            NoteTextEditor(
                text: $store.activeContent,
                format: store.activeNote?.format ?? store.defaultFormat,
                fontSize: store.editorFontSize,
                focusToken: store.focusRequestID
            )
            .background(Color(nsColor: .textBackgroundColor))

            floatingFormatControl
                .padding(.top, 10)
                .padding(.trailing, 14)
        }
    }

    private var editorFooter: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)

            Text(store.savingState.label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                appState.presentCommandPalette()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11, weight: .semibold))
                    Text("⌘P")
                        .font(.system(size: 11, weight: .semibold))
                }
                .padding(.horizontal, 7)
                .frame(height: 18)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color(nsColor: .separatorColor).opacity(0.24))
                )
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Search notes")
            .accessibilityLabel("Search notes")

            Text("\(store.notes.count) notes")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Button {
                store.openNotesFolder()
            } label: {
                Image(systemName: "folder")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(store.rootURL.path)
            .accessibilityLabel("Open notes folder")
        }
        .padding(.horizontal, 14)
        .frame(height: 24)
        .background(.bar)
    }

    private var floatingFormatControl: some View {
        HStack(spacing: 2) {
            formatButton(format: .markdown, systemImage: "number", help: "Markdown")
            formatButton(format: .plainText, systemImage: "text.alignleft", help: "Plain text")
        }
        .padding(3)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
        .accessibilityIdentifier("active-format-picker")
    }

    private func formatButton(format: NoteFormat, systemImage: String, help: String) -> some View {
        let isActive = (store.activeNote?.format ?? store.defaultFormat) == format

        return Button {
            store.setActiveFormat(format)
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 25, height: 23)
                .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isActive ? Color.accentColor.opacity(0.16) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }

    private var statusColor: Color {
        switch store.savingState {
        case .saved:
            .green
        case .saving:
            .orange
        case .failed:
            .red
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding {
            store.errorMessage != nil
        } set: { isPresented in
            if !isPresented {
                store.errorMessage = nil
            }
        }
    }
}
