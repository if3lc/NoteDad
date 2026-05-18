import AppKit
import SwiftUI

struct CommandPaletteView: View {
    @EnvironmentObject private var store: NoteStore
    @EnvironmentObject private var appState: AppState

    @FocusState private var isSearchFocused: Bool
    @State private var query = ""
    @State private var selectedIndex = 0
    @State private var keyMonitor: Any?
    @State private var notePendingDeletion: Note?

    private var results: [SearchResult] {
        store.search(query)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .onTapGesture {
                    appState.dismissCommandPalette()
                }

            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)

                    TextField("Search notes", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 18))
                        .focused($isSearchFocused)
                        .onSubmit {
                            openSelection()
                        }
                        .accessibilityIdentifier("command-palette-search")
                }
                .padding(.horizontal, 16)
                .frame(height: 54)

                Divider()

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            if results.isEmpty {
                                emptyState
                            } else {
                                ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                                    CommandPaletteRow(
                                        result: result,
                                        isSelected: index == selectedIndex,
                                        onOpen: {
                                            selectedIndex = index
                                            openSelection()
                                        },
                                        onDelete: {
                                            notePendingDeletion = result.note
                                        }
                                    )
                                    .accessibilityIdentifier("command-palette-result-\(index)")
                                }
                            }
                        }
                    }
                    .background(ScrollViewScrollerConfigurator())
                    .frame(maxHeight: 330)
                    .onChange(of: selectedIndex) { _, newValue in
                        guard results.indices.contains(newValue) else { return }
                        proxy.scrollTo(results[newValue].id, anchor: .center)
                    }
                }
            }
            .frame(maxWidth: 560)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 28, y: 18)
            .padding(.horizontal, 12)
            .onAppear {
                selectedIndex = 0
                installKeyMonitor()
                DispatchQueue.main.async {
                    isSearchFocused = true
                }
            }
            .onDisappear {
                removeKeyMonitor()
            }
            .onChange(of: query) { _, _ in
                selectedIndex = 0
            }
            .onMoveCommand { direction in
                moveSelection(direction)
            }
            .onExitCommand {
                appState.dismissCommandPalette()
            }

            if notePendingDeletion != nil {
                Color.black.opacity(0.08)
                    .ignoresSafeArea()
                    .onTapGesture {
                        notePendingDeletion = nil
                    }
                    .transition(.opacity)
                    .zIndex(20)
            }

            if let notePendingDeletion {
                deleteConfirmation(for: notePendingDeletion)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(21)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 24))
                .foregroundStyle(.secondary)
            Text("No notes")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 42)
    }

    private func deleteConfirmation(for note: Note) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "trash")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.red)
                    .frame(width: 22, height: 22)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Delete note?")
                        .font(.system(size: 14, weight: .semibold))

                    Text("Move “\(note.title)” to Trash?")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            HStack(spacing: 8) {
                Spacer()

                Button {
                    notePendingDeletion = nil
                } label: {
                    Text("Cancel")
                        .font(.system(size: 12, weight: .medium))
                        .frame(height: 24)
                        .padding(.horizontal, 9)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .pointingHandCursor()

                Button {
                    delete(note)
                } label: {
                    Text("Delete")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(height: 24)
                        .padding(.horizontal, 9)
                        .foregroundStyle(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.red)
                        )
                }
                .buttonStyle(.plain)
                .pointingHandCursor()
            }
        }
        .padding(14)
        .frame(width: 330)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 24, y: 14)
        .accessibilityElement(children: .contain)
    }

    private func moveSelection(_ direction: MoveCommandDirection) {
        guard !results.isEmpty else { return }

        switch direction {
        case .down, .right:
            selectedIndex = min(selectedIndex + 1, results.count - 1)
        case .up, .left:
            selectedIndex = max(selectedIndex - 1, 0)
        default:
            break
        }
    }

    private func openSelection() {
        guard results.indices.contains(selectedIndex) else { return }
        store.openSearchResult(results[selectedIndex])
        appState.dismissCommandPalette()
    }

    @discardableResult
    private func requestDeleteSelection() -> Bool {
        guard notePendingDeletion == nil,
              results.indices.contains(selectedIndex) else {
            return false
        }

        notePendingDeletion = results[selectedIndex].note
        return true
    }

    private func delete(_ note: Note) {
        store.delete(note)
        notePendingDeletion = nil
        selectedIndex = min(selectedIndex, max(results.count - 1, 0))
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleKeyDown(event) ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        guard appState.isCommandPalettePresented else { return false }

        if let notePendingDeletion {
            return handleDeleteConfirmationKeyDown(event, note: notePendingDeletion)
        }

        if isCommandBackspace(event) {
            return requestDeleteSelection()
        }

        let commandModifiers: NSEvent.ModifierFlags = [.command, .option, .control]
        guard event.modifierFlags.intersection(commandModifiers).isEmpty else {
            return false
        }

        switch event.keyCode {
        case 126:
            moveSelection(.up)
            return true
        case 125:
            moveSelection(.down)
            return true
        case 36, 76:
            openSelection()
            return true
        case 53:
            appState.dismissCommandPalette()
            return true
        default:
            return false
        }
    }

    private func handleDeleteConfirmationKeyDown(_ event: NSEvent, note: Note) -> Bool {
        if isCommandBackspace(event) {
            delete(note)
            return true
        }

        let activeModifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard activeModifiers.isEmpty else { return false }

        switch event.keyCode {
        case 36, 76:
            delete(note)
        case 53:
            notePendingDeletion = nil
        default:
            break
        }

        return true
    }

    private func isCommandBackspace(_ event: NSEvent) -> Bool {
        let activeModifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        return event.keyCode == 51 && activeModifiers == .command
    }
}

private struct CommandPaletteRow: View {
    var result: SearchResult
    var isSelected: Bool
    var onOpen: () -> Void
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(result.note.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer()

                    Text(result.note.format.displayName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Text(result.snippet.isEmpty ? result.note.url.lastPathComponent : result.snippet)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .pointingHandCursor()
            .help("Delete note (⌘⌫)")
            .accessibilityLabel("Delete note")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Color.accentColor.opacity(0.16) : Color.clear)
        .contentShape(Rectangle())
    }
}

private extension View {
    func pointingHandCursor() -> some View {
        modifier(PointingHandCursorModifier())
    }
}

private struct PointingHandCursorModifier: ViewModifier {
    @State private var didPushCursor = false

    func body(content: Content) -> some View {
        content
            .overlay(PointingHandCursorRegion().allowsHitTesting(false))
            .onContinuousHover { phase in
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

private struct PointingHandCursorRegion: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        PointingHandCursorView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.window?.invalidateCursorRects(for: nsView)
    }
}

private final class PointingHandCursorView: NSView {
    private var trackingArea: NSTrackingArea?

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func updateTrackingAreas() {
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .inVisibleRect, .mouseEnteredAndExited, .mouseMoved],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        self.trackingArea = trackingArea

        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) {
        NSCursor.pointingHand.set()
    }

    override func mouseMoved(with event: NSEvent) {
        NSCursor.pointingHand.set()
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.arrow.set()
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

private struct ScrollViewScrollerConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configure(from: view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(from: nsView)
        }
    }

    private func configure(from view: NSView) {
        applyNoteDadScrollers(around: view)
    }
}
