import Foundation
import Testing
@testable import NoteDad

@Suite("NoteDad storage and editor")
@MainActor
struct NoteDadTests {
    @Test func createsRootFolderAndDefaultMarkdownNote() throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }

        let store = NoteStore(rootURL: fixture.rootURL, defaults: fixture.defaults)
        store.bootstrap()

        #expect(FileManager.default.fileExists(atPath: fixture.rootURL.path))
        #expect(store.activeNote?.format == .markdown)
        #expect(store.notes.count == 1)
    }

    @Test func writesMarkdownAndRenamesFromFirstLine() throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }

        let store = NoteStore(rootURL: fixture.rootURL, defaults: fixture.defaults)
        store.bootstrap()
        store.activeContent = "# Başlık İçin Özet\nGövde"
        try store.flushNow()

        #expect(store.activeNote?.url.lastPathComponent == "Baslik Icin Ozet.md")
        #expect(try String(contentsOf: store.activeNote!.url, encoding: .utf8) == "# Başlık İçin Özet\nGövde")
    }

    @Test func supportsPlainTextFiles() throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }

        let store = NoteStore(rootURL: fixture.rootURL, defaults: fixture.defaults)
        store.bootstrap()
        try store.createNewNote(format: .plainText)
        store.activeContent = "Plain note\nNo styling"
        try store.flushNow()

        #expect(store.activeNote?.format == .plainText)
        #expect(store.activeNote?.url.pathExtension == "txt")
    }

    @Test func makesReadableUniqueFileNames() throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }

        let firstURL = fixture.rootURL.appendingPathComponent("Calisma Icin Ozet.md")
        try FileManager.default.createDirectory(at: fixture.rootURL, withIntermediateDirectories: true)
        try Data().write(to: firstURL)

        let secondURL = NoteNaming.uniqueURL(
            in: fixture.rootURL,
            title: "Çalışma İçin Özet",
            format: .markdown
        )

        #expect(NoteNaming.sanitizedBase(for: "Çalışma İçin Özet") == "Calisma Icin Ozet")
        #expect(NoteNaming.firstMeaningfulTitle(in: "#Başlık") == "Başlık")
        #expect(secondURL.lastPathComponent == "Calisma Icin Ozet 2.md")
    }

    @Test func searchRanksTitleMatchesBeforeContentMatches() throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }
        try FileManager.default.createDirectory(at: fixture.rootURL, withIntermediateDirectories: true)
        try "# Alpha Plan\nBody".write(
            to: fixture.rootURL.appendingPathComponent("Alpha Plan.md"),
            atomically: true,
            encoding: .utf8
        )
        try "# Meeting\nAlpha is mentioned here".write(
            to: fixture.rootURL.appendingPathComponent("Meeting.md"),
            atomically: true,
            encoding: .utf8
        )

        let store = NoteStore(rootURL: fixture.rootURL, defaults: fixture.defaults)
        store.bootstrap()
        let results = store.search("alpha")

        #expect(results.count == 2)
        #expect(results.first?.note.title == "Alpha Plan")
    }

    @Test func markdownHighlighterDetectsV1Styles() {
        let text = """
        #Başlık
        - item
        - [ ] task
        [x] done
        > quote
        `code`
        **bold**
        [link](https://example.com)
        """

        let kinds = Set(MarkdownHighlighter.spans(in: text).map(\.kind))

        #expect(kinds.contains(.heading1))
        #expect(kinds.contains(.unorderedList))
        #expect(kinds.contains(.taskUnchecked))
        #expect(kinds.contains(.blockquote))
        #expect(kinds.contains(.inlineCode))
        #expect(kinds.contains(.bold))
        #expect(kinds.contains(.link))
        #expect(kinds.contains(.collapsedMarkup))
    }

    @Test func markdownListContinuationKeepsWritingFlow() {
        #expect(MarkdownLineContinuation.action(for: "- item") == .continueWithPrefix("- "))
        #expect(MarkdownLineContinuation.action(for: "  3. item") == .continueWithPrefix("  4. "))
        #expect(MarkdownLineContinuation.action(for: "- [x] done") == .continueWithPrefix("- [ ] "))
        #expect(MarkdownLineContinuation.action(for: "[ ] task") == .continueWithPrefix("[ ] "))

        if case .exitList(let markerRange) = MarkdownLineContinuation.action(for: "- [ ] ") {
            #expect(markerRange == NSRange(location: 0, length: 6))
        } else {
            Issue.record("Expected an empty task item to exit the list")
        }
    }
}

private struct Fixture {
    let rootURL: URL
    let defaults: UserDefaults
    let defaultsSuiteName: String

    init() throws {
        self.rootURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("NoteDadTests-\(UUID().uuidString)", isDirectory: true)
        self.defaultsSuiteName = "NoteDadTests-\(UUID().uuidString)"
        self.defaults = UserDefaults(suiteName: defaultsSuiteName)!
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: rootURL)
        defaults.removePersistentDomain(forName: defaultsSuiteName)
    }
}
