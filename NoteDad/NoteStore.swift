import AppKit
import Combine
import Foundation

@MainActor
final class NoteStore: ObservableObject {
    @Published private(set) var notes: [Note] = []
    @Published private(set) var activeNote: Note?
    @Published var savingState: SavingState = .saved
    @Published var errorMessage: String?
    @Published var focusRequestID = 0
    @Published var quickNoteFocusRequestID = 0

    @Published var activeContent = "" {
        didSet {
            guard hasBootstrapped, !isApplyingActiveContent, oldValue != activeContent else { return }
            updateActiveNoteContent(activeContent)
            scheduleActiveSave()
        }
    }

    @Published var quickNoteContent = "" {
        didSet {
            guard hasBootstrapped, !isApplyingQuickNoteContent, oldValue != quickNoteContent else { return }
            scheduleQuickNoteSave()
        }
    }

    @Published var defaultFormat: NoteFormat {
        didSet {
            defaults.set(defaultFormat.rawValue, forKey: AppPreferences.defaultFormatKey)
        }
    }

    @Published var editorFontSize: Double {
        didSet {
            let clampedSize = min(max(editorFontSize, 12), 22)
            if clampedSize != editorFontSize {
                editorFontSize = clampedSize
                return
            }
            defaults.set(clampedSize, forKey: AppPreferences.editorFontSizeKey)
        }
    }

    let rootURL: URL

    private let fileManager: FileManager
    private let defaults: UserDefaults
    private var saveTask: Task<Void, Never>?
    private var quickNoteSaveTask: Task<Void, Never>?
    private var hasBootstrapped = false
    private var isApplyingActiveContent = false
    private var isApplyingQuickNoteContent = false

    init(
        rootURL: URL? = nil,
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.defaults = defaults

        if ProcessInfo.processInfo.environment["NOTEDAD_RESET_DEFAULTS"] == "1" {
            AppPreferences.clear(in: defaults)
        }

        if let rootURL {
            self.rootURL = rootURL
        } else if let override = ProcessInfo.processInfo.environment["NOTEDAD_STORAGE_PATH"], !override.isEmpty {
            self.rootURL = URL(fileURLWithPath: override, isDirectory: true)
        } else {
            let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            self.rootURL = documentsURL.appendingPathComponent("NoteDad", isDirectory: true)
        }

        let storedFormat = defaults.string(forKey: AppPreferences.defaultFormatKey)
            .flatMap(NoteFormat.init(rawValue:))
        self.defaultFormat = storedFormat ?? .markdown

        let storedFontSize = defaults.double(forKey: AppPreferences.editorFontSizeKey)
        self.editorFontSize = storedFontSize > 0 ? min(max(storedFontSize, 12), 22) : 14
    }

    deinit {
        saveTask?.cancel()
        quickNoteSaveTask?.cancel()
    }

    func bootstrap() {
        guard !hasBootstrapped else { return }

        do {
            try ensureRootFolder()
            try reloadNotes()
            if let note = preferredStartupNote() {
                try open(note)
            } else {
                try createNewNote(format: defaultFormat)
            }
            hasBootstrapped = true
        } catch {
            handle(error)
        }
    }

    func createNewNote(format: NoteFormat? = nil) throws {
        try flushActiveNote()
        try ensureRootFolder()

        let noteFormat = format ?? defaultFormat
        let title = NoteNaming.untitledBase()
        let url = NoteNaming.uniqueURL(in: rootURL, title: title, format: noteFormat, fileManager: fileManager)
        try Data().write(to: url, options: .atomic)

        let now = Date()
        let note = Note(
            url: url,
            title: url.deletingPathExtension().lastPathComponent,
            format: noteFormat,
            createdAt: now,
            modifiedAt: now,
            content: ""
        )
        notes.insert(note, at: 0)
        applyActive(note)
    }

    func open(_ note: Note) throws {
        try flushActiveNote()
        let content = try readContent(at: note.url)
        let refreshed = noteFromFile(url: note.url, contentOverride: content)
        replaceNote(matching: note.url, with: refreshed)
        applyActive(refreshed)
    }

    func openSearchResult(_ result: SearchResult) {
        do {
            try open(result.note)
        } catch {
            handle(error)
        }
    }

    func delete(_ note: Note) {
        do {
            try deleteNote(note)
        } catch {
            handle(error)
        }
    }

    func setActiveFormat(_ format: NoteFormat) {
        guard var note = activeNote, note.format != format else { return }

        do {
            try flushActiveNote()

            let baseTitle = note.url.deletingPathExtension().lastPathComponent
            let newURL = NoteNaming.uniqueURL(
                in: rootURL,
                title: baseTitle,
                format: format,
                excluding: note.url,
                fileManager: fileManager
            )

            try fileManager.moveItem(at: note.url, to: newURL)
            let oldURL = note.url
            note.url = newURL
            note.format = format
            note.modifiedAt = Date()
            replaceNote(matching: oldURL, with: note)
            applyActive(note)
            defaults.set(newURL.path, forKey: AppPreferences.lastNotePathKey)
            try activeContent.data(using: .utf8)?.write(to: newURL, options: .atomic)
        } catch {
            handle(error)
        }
    }

    func search(_ query: String) -> [SearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedQuery = normalized(trimmed)
        let searchableNotes = notes.map { note -> Note in
            guard activeNote?.url == note.url else { return note }
            var active = note
            active.content = activeContent
            active.title = NoteNaming.displayTitle(for: activeContent, fallbackURL: active.url)
            return active
        }

        guard !normalizedQuery.isEmpty else {
            return searchableNotes
                .sorted { $0.modifiedAt > $1.modifiedAt }
                .map { SearchResult(note: $0, snippet: snippet(for: $0.content, query: ""), score: 10) }
        }

        return searchableNotes.compactMap { note -> SearchResult? in
            let normalizedTitle = normalized(note.title)
            let normalizedContent = normalized(note.content)

            if normalizedTitle.hasPrefix(normalizedQuery) {
                return SearchResult(note: note, snippet: snippet(for: note.content, query: trimmed), score: 0)
            }

            if normalizedTitle.contains(normalizedQuery) {
                return SearchResult(note: note, snippet: snippet(for: note.content, query: trimmed), score: 1)
            }

            if normalizedContent.contains(normalizedQuery) {
                return SearchResult(note: note, snippet: snippet(for: note.content, query: trimmed), score: 2)
            }

            return nil
        }
        .sorted {
            if $0.score == $1.score {
                return $0.note.modifiedAt > $1.note.modifiedAt
            }
            return $0.score < $1.score
        }
    }

    func loadQuickNote() throws {
        let url = quickNoteURL
        if !fileManager.fileExists(atPath: url.path) {
            try "# Quick Note\n".data(using: .utf8)?.write(to: url, options: .atomic)
        }

        let content = try readContent(at: url)
        isApplyingQuickNoteContent = true
        quickNoteContent = content
        isApplyingQuickNoteContent = false

        try reloadNotes()
    }

    func openQuickNoteInMain() {
        do {
            try loadQuickNote()
            guard let quickNote = notes.first(where: { $0.url == quickNoteURL }) else { return }
            try open(quickNote)
        } catch {
            handle(error)
        }
    }

    func requestQuickNoteFocus() {
        quickNoteFocusRequestID += 1
    }

    func openNotesFolder() {
        NSWorkspace.shared.activateFileViewerSelecting([rootURL])
    }

    func flushNow() throws {
        try flushActiveNote()
        try flushQuickNote()
    }

    private var quickNoteURL: URL {
        rootURL.appendingPathComponent("Quick Note").appendingPathExtension(NoteFormat.markdown.fileExtension)
    }

    private func deleteNote(_ note: Note) throws {
        let isDeletingActiveNote = activeNote?.url == note.url

        if isDeletingActiveNote {
            saveTask?.cancel()
        }

        var trashedURL: NSURL?
        if fileManager.fileExists(atPath: note.url.path) {
            try fileManager.trashItem(at: note.url, resultingItemURL: &trashedURL)
        }

        notes.removeAll { $0.url == note.url }

        if isDeletingActiveNote {
            activeNote = nil
            isApplyingActiveContent = true
            activeContent = ""
            isApplyingActiveContent = false

            if let nextNote = notes.sorted(by: { $0.modifiedAt > $1.modifiedAt }).first {
                try open(nextNote)
            } else {
                defaults.removeObject(forKey: AppPreferences.lastNotePathKey)
                try createNewNote(format: defaultFormat)
            }
        }

        savingState = .saved
    }

    private func ensureRootFolder() throws {
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }

    private func reloadNotes() throws {
        try ensureRootFolder()
        let urls = try fileManager.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        notes = urls.compactMap { url in
            guard NoteFormat.fromFileExtension(url.pathExtension) != nil else { return nil }
            return noteFromFile(url: url)
        }
        .sorted { $0.modifiedAt > $1.modifiedAt }
    }

    private func noteFromFile(url: URL, contentOverride: String? = nil) -> Note {
        let format = NoteFormat.fromFileExtension(url.pathExtension) ?? .markdown
        let values = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
        let content = contentOverride ?? ((try? readContent(at: url)) ?? "")

        return Note(
            url: url,
            title: NoteNaming.displayTitle(for: content, fallbackURL: url),
            format: format,
            createdAt: values?.creationDate ?? Date.distantPast,
            modifiedAt: values?.contentModificationDate ?? Date.distantPast,
            content: content
        )
    }

    private func preferredStartupNote() -> Note? {
        if let lastPath = defaults.string(forKey: AppPreferences.lastNotePathKey),
           let lastNote = notes.first(where: { $0.url.path == lastPath }) {
            return lastNote
        }

        return notes.sorted { $0.modifiedAt > $1.modifiedAt }.first
    }

    private func applyActive(_ note: Note) {
        activeNote = note
        isApplyingActiveContent = true
        activeContent = note.content
        isApplyingActiveContent = false
        defaults.set(note.url.path, forKey: AppPreferences.lastNotePathKey)
        savingState = .saved
        focusRequestID += 1
    }

    private func scheduleActiveSave() {
        savingState = .saving
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 350_000_000)
                try Task.checkCancellation()
                self?.flushActiveNoteFromTask()
            } catch {
                return
            }
        }
    }

    private func scheduleQuickNoteSave() {
        quickNoteSaveTask?.cancel()
        quickNoteSaveTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 350_000_000)
                try Task.checkCancellation()
                self?.flushQuickNoteFromTask()
            } catch {
                return
            }
        }
    }

    private func flushActiveNoteFromTask() {
        do {
            try flushActiveNote()
        } catch {
            handle(error)
        }
    }

    private func flushQuickNoteFromTask() {
        do {
            try flushQuickNote()
        } catch {
            handle(error)
        }
    }

    private func flushActiveNote() throws {
        saveTask?.cancel()
        guard var note = activeNote else { return }

        var targetURL = note.url
        let oldURL = note.url
        let titleFromContent = NoteNaming.firstMeaningfulTitle(in: activeContent)

        if let titleFromContent, oldURL != quickNoteURL {
            targetURL = NoteNaming.uniqueURL(
                in: rootURL,
                title: titleFromContent,
                format: note.format,
                excluding: oldURL,
                fileManager: fileManager
            )

            if targetURL != oldURL {
                try fileManager.moveItem(at: oldURL, to: targetURL)
                note.url = targetURL
            }

            note.title = titleFromContent
        } else {
            note.title = NoteNaming.displayTitle(for: activeContent, fallbackURL: note.url)
        }

        try activeContent.data(using: .utf8)?.write(to: targetURL, options: .atomic)
        note.content = activeContent
        note.modifiedAt = Date()
        replaceNote(matching: oldURL, with: note)
        activeNote = note
        defaults.set(targetURL.path, forKey: AppPreferences.lastNotePathKey)
        savingState = .saved

        if targetURL == quickNoteURL {
            isApplyingQuickNoteContent = true
            quickNoteContent = activeContent
            isApplyingQuickNoteContent = false
        }
    }

    private func flushQuickNote() throws {
        quickNoteSaveTask?.cancel()
        try ensureRootFolder()
        try quickNoteContent.data(using: .utf8)?.write(to: quickNoteURL, options: .atomic)

        if activeNote?.url == quickNoteURL {
            isApplyingActiveContent = true
            activeContent = quickNoteContent
            isApplyingActiveContent = false
        }

        try reloadNotes()
    }

    private func updateActiveNoteContent(_ content: String) {
        guard var note = activeNote else { return }
        note.content = content
        note.title = NoteNaming.displayTitle(for: content, fallbackURL: note.url)
        activeNote = note
        replaceNote(matching: note.url, with: note)
    }

    private func replaceNote(matching oldURL: URL, with note: Note) {
        if let index = notes.firstIndex(where: { $0.url == oldURL || $0.url == note.url }) {
            notes[index] = note
        } else {
            notes.append(note)
        }

        notes.sort { $0.modifiedAt > $1.modifiedAt }
    }

    private func readContent(at url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }

    private func snippet(for content: String, query: String) -> String {
        let compactContent = content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard !query.isEmpty else {
            return String(compactContent.prefix(120))
        }

        let normalizedContent = normalized(compactContent)
        let normalizedQuery = normalized(query)
        guard let range = normalizedContent.range(of: normalizedQuery) else {
            return String(compactContent.prefix(120))
        }

        let lowerDistance = normalizedContent.distance(from: normalizedContent.startIndex, to: range.lowerBound)
        let startOffset = max(0, lowerDistance - 34)
        let start = compactContent.index(compactContent.startIndex, offsetBy: min(startOffset, compactContent.count))
        let end = compactContent.index(start, offsetBy: min(120, compactContent.distance(from: start, to: compactContent.endIndex)))
        return String(compactContent[start..<end])
    }

    private func normalized(_ value: String) -> String {
        NoteNaming.sanitizedBase(for: value, fallback: "")
            .lowercased()
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }

    private func handle(_ error: Error) {
        let message = error.localizedDescription
        errorMessage = message
        savingState = .failed(message)
    }
}
