import AppKit
import SwiftUI

struct CommandPaletteView: View {
    @EnvironmentObject private var store: NoteStore
    @EnvironmentObject private var appState: AppState

    @FocusState private var isSearchFocused: Bool
    @State private var query = ""
    @State private var selectedIndex = 0
    @State private var keyMonitor: Any?

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
                                        isSelected: index == selectedIndex
                                    )
                                    .id(index)
                                    .onTapGesture {
                                        selectedIndex = index
                                        openSelection()
                                    }
                                    .accessibilityIdentifier("command-palette-result-\(index)")
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 330)
                    .onChange(of: selectedIndex) { _, newValue in
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
            }
            .frame(width: 560)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 28, y: 18)
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
        let commandModifiers: NSEvent.ModifierFlags = [.command, .option, .control]
        guard appState.isCommandPalettePresented,
              event.modifierFlags.intersection(commandModifiers).isEmpty else {
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
}

private struct CommandPaletteRow: View {
    var result: SearchResult
    var isSelected: Bool

    var body: some View {
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
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Color.accentColor.opacity(0.16) : Color.clear)
        .contentShape(Rectangle())
    }
}
