import Foundation

enum NoteFormat: String, CaseIterable, Identifiable, Codable {
    case markdown
    case plainText

    var id: String { rawValue }

    var fileExtension: String {
        switch self {
        case .markdown:
            "md"
        case .plainText:
            "txt"
        }
    }

    var displayName: String {
        switch self {
        case .markdown:
            "Markdown"
        case .plainText:
            "Text"
        }
    }

    static func fromFileExtension(_ fileExtension: String) -> NoteFormat? {
        switch fileExtension.lowercased() {
        case "md", "markdown":
            .markdown
        case "txt", "text":
            .plainText
        default:
            nil
        }
    }
}

struct Note: Identifiable, Equatable {
    var url: URL
    var title: String
    var format: NoteFormat
    var createdAt: Date
    var modifiedAt: Date
    var content: String

    var id: String { url.path }
}

struct SearchResult: Identifiable, Equatable {
    var note: Note
    var snippet: String
    var score: Int

    var id: String { note.id }
}

enum SavingState: Equatable {
    case saved
    case saving
    case failed(String)

    var label: String {
        switch self {
        case .saved:
            "Saved"
        case .saving:
            "Saving..."
        case .failed:
            "Save failed"
        }
    }
}
