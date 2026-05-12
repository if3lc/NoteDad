import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: NoteStore
    @EnvironmentObject private var appState: AppState
    @State private var isFloatingControlHovered = false
    @State private var hoveredFloatingControlID: String?

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                editorSurface

                editorFooter
            }
            .frame(minWidth: 280, minHeight: 180)
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
        .background(
            WindowChromeUpdater(
                title: windowTitle,
                representedURL: store.activeNote?.url,
                isAlwaysOnTop: appState.isAlwaysOnTop
            )
        )
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
                .zIndex(2)
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
                .lineLimit(1)

            Spacer()

            Text("\(store.notes.count) notes")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

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
            Divider()
                .frame(height: 14)
                .padding(.horizontal, 2)
            alwaysOnTopButton
        }
        .padding(3)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .opacity(isFloatingControlHovered ? 1 : 0.48)
        .pointingHandOnHover()
        .onHover { isHovering in
            isFloatingControlHovered = isHovering
            if !isHovering {
                hoveredFloatingControlID = nil
            }
        }
        .animation(.easeOut(duration: 0.12), value: isFloatingControlHovered)
        .accessibilityIdentifier("active-format-picker")
    }

    private var alwaysOnTopButton: some View {
        let isHovered = hoveredFloatingControlID == "alwaysOnTop"
        let isAlwaysOnTop = appState.isAlwaysOnTop

        return Button {
            appState.toggleAlwaysOnTop()
        } label: {
            Image(systemName: isAlwaysOnTop ? "pin.fill" : "pin")
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 25, height: 23)
                .foregroundStyle(isAlwaysOnTop ? Color.accentColor : (isHovered ? Color.primary : Color.secondary))
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(floatingButtonFill(isSelected: isAlwaysOnTop, isHovered: isHovered))
                )
        }
        .buttonStyle(.plain)
        .help(isAlwaysOnTop ? "Keep window normal" : "Keep window on top")
        .accessibilityLabel("Keep window on top")
        .accessibilityValue(isAlwaysOnTop ? "On" : "Off")
        .onHover { isHovering in
            hoveredFloatingControlID = isHovering ? "alwaysOnTop" : nil
        }
    }

    private func formatButton(format: NoteFormat, systemImage: String, help: String) -> some View {
        let isActive = (store.activeNote?.format ?? store.defaultFormat) == format
        let controlID = "format-\(format.rawValue)"
        let isHovered = hoveredFloatingControlID == controlID

        return Button {
            store.setActiveFormat(format)
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 25, height: 23)
                .foregroundStyle(isActive ? Color.accentColor : (isHovered ? Color.primary : Color.secondary))
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(floatingButtonFill(isSelected: isActive, isHovered: isHovered))
                )
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
        .onHover { isHovering in
            hoveredFloatingControlID = isHovering ? controlID : nil
        }
    }

    private func floatingButtonFill(isSelected: Bool, isHovered: Bool) -> Color {
        if isSelected {
            return Color.accentColor.opacity(0.16)
        }

        if isHovered {
            return Color(nsColor: .controlAccentColor).opacity(0.08)
        }

        return .clear
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

private extension View {
    func pointingHandOnHover() -> some View {
        modifier(PointingHandHoverModifier())
    }
}

private struct PointingHandHoverModifier: ViewModifier {
    @State private var didPushCursor = false

    func body(content: Content) -> some View {
        content.onContinuousHover { phase in
            switch phase {
            case .active:
                pushCursorIfNeeded()
                NSCursor.pointingHand.set()
            case .ended:
                popCursorIfNeeded()
            }
        }
    }

    private func pushCursorIfNeeded() {
        guard !didPushCursor else { return }
        NSCursor.pointingHand.push()
        didPushCursor = true
    }

    private func popCursorIfNeeded() {
        guard didPushCursor else { return }
        NSCursor.pop()
        didPushCursor = false
    }
}

private struct WindowChromeUpdater: NSViewRepresentable {
    var title: String
    var representedURL: URL?
    var isAlwaysOnTop: Bool

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
        window.level = isAlwaysOnTop ? .floating : .normal
    }
}
