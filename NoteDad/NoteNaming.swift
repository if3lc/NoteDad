import Foundation

enum NoteNaming {
    private static let turkishCharacterMap: [Character: String] = [
        "ç": "c", "Ç": "C",
        "ğ": "g", "Ğ": "G",
        "ı": "i", "I": "I",
        "İ": "I", "i": "i",
        "ö": "o", "Ö": "O",
        "ş": "s", "Ş": "S",
        "ü": "u", "Ü": "U"
    ]

    static func firstMeaningfulTitle(in content: String) -> String? {
        for rawLine in content.components(separatedBy: .newlines) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let stripped = stripMarkdownMarkers(from: trimmed)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return stripped.isEmpty ? nil : stripped
        }

        return nil
    }

    static func displayTitle(for content: String, fallbackURL: URL) -> String {
        firstMeaningfulTitle(in: content) ?? fallbackURL.deletingPathExtension().lastPathComponent
    }

    static func untitledBase(now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH.mm"
        return "Untitled \(formatter.string(from: now))"
    }

    static func sanitizedBase(for title: String, fallback: String = "Untitled") -> String {
        let stripped = stripMarkdownMarkers(from: title)
        var transliterated = ""
        transliterated.reserveCapacity(stripped.count)

        for character in stripped {
            if let replacement = turkishCharacterMap[character] {
                transliterated.append(replacement)
            } else {
                transliterated.append(character)
            }
        }

        let folded = transliterated.folding(options: [.diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        let invalid = CharacterSet(charactersIn: "/\\?%*|\"<>:").union(.controlCharacters)
        let scalars = folded.unicodeScalars.map { scalar in
            invalid.contains(scalar) ? " " : String(scalar)
        }
        let compacted = scalars.joined()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let base = compacted.isEmpty ? fallback : compacted
        return String(base.prefix(90)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func uniqueURL(
        in folderURL: URL,
        title: String,
        format: NoteFormat,
        excluding existingURL: URL? = nil,
        fileManager: FileManager = .default
    ) -> URL {
        let base = sanitizedBase(for: title)
        let currentPath = existingURL?.standardizedFileURL.path
        var candidate = folderURL.appendingPathComponent(base).appendingPathExtension(format.fileExtension)
        var suffix = 2

        while fileManager.fileExists(atPath: candidate.path),
              candidate.standardizedFileURL.path != currentPath {
            candidate = folderURL
                .appendingPathComponent("\(base) \(suffix)")
                .appendingPathExtension(format.fileExtension)
            suffix += 1
        }

        return candidate
    }

    private static func stripMarkdownMarkers(from value: String) -> String {
        var text = value
        let replacements: [(String, String)] = [
            (#"^\s{0,3}#{1,6}\s*"#, ""),
            (#"^\s{0,3}>\s+"#, ""),
            (#"^\s*[-*+]\s+"#, ""),
            (#"^\s*\d+\.\s+"#, ""),
            (#"^`{1,3}(.+?)`{1,3}$"#, "$1"),
            (#"^\*\*(.+?)\*\*$"#, "$1"),
            (#"^__(.+?)__$"#, "$1"),
            (#"^\*(.+?)\*$"#, "$1"),
            (#"^_(.+?)_$"#, "$1")
        ]

        for (pattern, template) in replacements {
            text = text.replacingOccurrences(of: pattern, with: template, options: .regularExpression)
        }

        return text
    }
}
