import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: NoteStore
    @EnvironmentObject private var appState: AppState
    @State private var isFloatingControlHovered = false
    @State private var hoveredFloatingControlID: String?
    @State private var findQuery = ""
    @State private var findMatches: [NSRange] = []
    @State private var findSelectedIndex = 0
    @State private var findSelectionToken = 0
    @FocusState private var isFindFocused: Bool

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
        .animation(.easeOut(duration: 0.12), value: appState.isFindPresented)
        .onChange(of: appState.findPresentationToken) { _, _ in
            updateFindMatches(resetSelection: true)
            focusFindField()
        }
        .onChange(of: appState.findNavigationRequest) { _, request in
            handleFindNavigation(request)
        }
        .onChange(of: findQuery) { _, _ in
            updateFindMatches(resetSelection: true)
        }
        .onChange(of: store.activeContent) { _, _ in
            guard appState.isFindPresented else { return }
            updateFindMatches(resetSelection: false)
        }
        .onChange(of: store.activeNote?.id) { _, _ in
            guard appState.isFindPresented else { return }
            updateFindMatches(resetSelection: true)
        }
    }

    private var windowTitle: String {
        guard let title = store.activeNote?.title.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty else {
            return "NoteDad"
        }

        return title
    }

    private var activeFindSelection: NoteFindSelection {
        guard appState.isFindPresented,
              findMatches.indices.contains(findSelectedIndex) else {
            return NoteFindSelection(selectedRange: nil, token: findSelectionToken)
        }

        return NoteFindSelection(selectedRange: findMatches[findSelectedIndex], token: findSelectionToken)
    }

    private var trimmedFindQuery: String {
        findQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var findStatusLabel: String {
        guard !trimmedFindQuery.isEmpty else { return "" }
        guard findMatches.indices.contains(findSelectedIndex) else { return "0/0" }
        return "\(findSelectedIndex + 1)/\(findMatches.count)"
    }

    private var editorSurface: some View {
        ZStack(alignment: .top) {
            NoteTextEditor(
                text: $store.activeContent,
                format: store.activeNote?.format ?? store.defaultFormat,
                fontSize: store.editorFontSize,
                focusToken: store.focusRequestID,
                findSelection: activeFindSelection
            )
            .background(Color(nsColor: .textBackgroundColor))

            HStack(alignment: .top, spacing: 8) {
                if appState.isFindPresented {
                    findBar
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Spacer(minLength: 8)

                floatingFormatControl
            }
            .padding(.top, 10)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .zIndex(2)
        }
    }

    private var findBar: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            TextField("Find in note", text: $findQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($isFindFocused)
                .onSubmit {
                    moveFindSelection(.next)
                }

            if !trimmedFindQuery.isEmpty {
                Text(findStatusLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .frame(minWidth: 34, alignment: .trailing)
            }

            findNavigationButton(systemImage: "chevron.up", direction: .previous)
            findNavigationButton(systemImage: "chevron.down", direction: .next)

            Divider()
                .frame(height: 14)

            Button {
                appState.dismissFind()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Close find")
            .accessibilityLabel("Close find")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: 340)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onAppear {
            focusFindField()
        }
        .onExitCommand {
            appState.dismissFind()
        }
    }

    private func findNavigationButton(systemImage: String, direction: NoteFindDirection) -> some View {
        Button {
            moveFindSelection(direction)
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(findMatches.isEmpty ? Color.secondary.opacity(0.55) : Color.secondary)
        .disabled(findMatches.isEmpty)
        .help(direction == .next ? "Find next" : "Find previous")
        .accessibilityLabel(direction == .next ? "Find next" : "Find previous")
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

    private func handleFindNavigation(_ request: NoteFindNavigationRequest) {
        guard request.token > 0 else { return }

        if trimmedFindQuery.isEmpty {
            updateFindMatches(resetSelection: true)
            focusFindField()
            return
        }

        updateFindMatches(resetSelection: false)
        moveFindSelection(request.direction)

        focusFindField()
    }

    private func updateFindMatches(resetSelection: Bool) {
        findMatches = NoteTextSearch.ranges(in: store.activeContent, matching: trimmedFindQuery)

        if resetSelection {
            findSelectedIndex = 0
        } else {
            findSelectedIndex = min(findSelectedIndex, max(findMatches.count - 1, 0))
        }

        findSelectionToken += 1
    }

    private func moveFindSelection(_ direction: NoteFindDirection) {
        guard !findMatches.isEmpty else {
            findSelectionToken += 1
            return
        }

        switch direction {
        case .next:
            findSelectedIndex = (findSelectedIndex + 1) % findMatches.count
        case .previous:
            findSelectedIndex = (findSelectedIndex - 1 + findMatches.count) % findMatches.count
        }

        findSelectionToken += 1
    }

    private func focusFindField() {
        DispatchQueue.main.async {
            isFindFocused = true
        }
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

private enum NoteTextSearch {
    static func ranges(in text: String, matching query: String) -> [NSRange] {
        guard !query.isEmpty else { return [] }

        let nsText = text as NSString
        guard nsText.length > 0 else { return [] }

        let options: NSString.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        var ranges: [NSRange] = []
        var searchRange = NSRange(location: 0, length: nsText.length)

        while searchRange.length > 0 {
            let match = nsText.range(of: query, options: options, range: searchRange)
            guard match.location != NSNotFound, match.length > 0 else { break }

            ranges.append(match)

            let nextLocation = NSMaxRange(match)
            guard nextLocation < nsText.length else { break }
            searchRange = NSRange(location: nextLocation, length: nsText.length - nextLocation)
        }

        return ranges
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
