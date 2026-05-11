import AppKit
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
        .background(WindowTitleUpdater(title: windowTitle, representedURL: store.activeNote?.url))
        .animation(.easeOut(duration: 0.12), value: appState.isCommandPalettePresented)
    }

    private var windowTitle: String {
        guard let title = store.activeNote?.title.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty else {
            return "NoteDad"
        }

        return title
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

            Text("\(store.notes.count) notes")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Button {
                appState.presentCommandPalette()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11, weight: .semibold))
                    Text("⌘P")
                        .font(.system(size: 11, weight: .semibold))
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Search notes")
            .accessibilityLabel("Search notes")

            Button {
                store.openNotesFolder()
            } label: {
                Image(systemName: "folder")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(store.rootURL.path)
            .accessibilityLabel("Open notes folder")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .frame(minHeight: 32)
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

private struct WindowTitleUpdater: NSViewRepresentable {
    var title: String
    var representedURL: URL?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            updateWindow(from: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            updateWindow(from: nsView)
        }
    }

    private func updateWindow(from view: NSView) {
        guard let window = view.window else { return }
        window.title = title
        window.representedURL = representedURL
    }
}
