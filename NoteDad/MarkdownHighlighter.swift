import AppKit
import Foundation

enum MarkdownStyleKind: String, Equatable {
    case heading1
    case heading2
    case heading3
    case unorderedList
    case orderedList
    case blockquote
    case codeBlock
    case inlineCode
    case bold
    case italic
    case link
    case hiddenMarkup
    case collapsedMarkup
    case listMarker
    case taskMarker
    case taskUnchecked
    case taskChecked
}

struct MarkdownStyleSpan: Equatable {
    var kind: MarkdownStyleKind
    var range: NSRange
}

enum MarkdownLineContinuationAction: Equatable {
    case continueWithPrefix(String)
    case exitList(markerRange: NSRange)
}

enum MarkdownLineContinuation {
    static func action(for line: String) -> MarkdownLineContinuationAction? {
        let nsLine = line as NSString

        if let match = firstMatch(in: line, pattern: #"^(\s*)((?:[-*+]\s+)?)\[( |x|X)\]\s+(.*)$"#) {
            let content = nsLine.substring(with: match.range(at: 4)).trimmingCharacters(in: .whitespaces)
            if content.isEmpty {
                return .exitList(markerRange: match.range(at: 0))
            }

            let indent = nsLine.substring(with: match.range(at: 1))
            let bullet = nsLine.substring(with: match.range(at: 2))
            return .continueWithPrefix("\(indent)\(bullet)[ ] ")
        }

        if let match = firstMatch(in: line, pattern: #"^(\s*)([-*+])\s+(.*)$"#) {
            let content = nsLine.substring(with: match.range(at: 3)).trimmingCharacters(in: .whitespaces)
            if content.isEmpty {
                return .exitList(markerRange: match.range(at: 0))
            }

            let indent = nsLine.substring(with: match.range(at: 1))
            let marker = nsLine.substring(with: match.range(at: 2))
            return .continueWithPrefix("\(indent)\(marker) ")
        }

        if let match = firstMatch(in: line, pattern: #"^(\s*)(\d+)\.\s+(.*)$"#) {
            let content = nsLine.substring(with: match.range(at: 3)).trimmingCharacters(in: .whitespaces)
            if content.isEmpty {
                return .exitList(markerRange: match.range(at: 0))
            }

            let indent = nsLine.substring(with: match.range(at: 1))
            let number = Int(nsLine.substring(with: match.range(at: 2))) ?? 1
            return .continueWithPrefix("\(indent)\(number + 1). ")
        }

        if let match = firstMatch(in: line, pattern: #"^(\s{0,3})>\s+(.*)$"#) {
            let content = nsLine.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespaces)
            if content.isEmpty {
                return .exitList(markerRange: match.range(at: 0))
            }

            let indent = nsLine.substring(with: match.range(at: 1))
            return .continueWithPrefix("\(indent)> ")
        }

        return nil
    }

    private static func firstMatch(in text: String, pattern: String) -> NSTextCheckingResult? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        return regex.firstMatch(in: text, range: NSRange(location: 0, length: (text as NSString).length))
    }
}

enum MarkdownHighlighter {
    static func spans(in text: String) -> [MarkdownStyleSpan] {
        guard !text.isEmpty else { return [] }

        let nsText = text as NSString
        var spans: [MarkdownStyleSpan] = []
        var codeBlockRanges: [NSRange] = []
        var isInsideCodeBlock = false
        var codeBlockStart = 0

        nsText.enumerateSubstrings(
            in: NSRange(location: 0, length: nsText.length),
            options: [.byLines, .substringNotRequired]
        ) { _, lineRange, _, _ in
            let line = nsText.substring(with: lineRange)
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") {
                if isInsideCodeBlock {
                    let range = NSRange(location: codeBlockStart, length: NSMaxRange(lineRange) - codeBlockStart)
                    codeBlockRanges.append(range)
                    spans.append(MarkdownStyleSpan(kind: .codeBlock, range: range))
                    isInsideCodeBlock = false
                } else {
                    codeBlockStart = lineRange.location
                    isInsideCodeBlock = true
                }
                return
            }

            if isInsideCodeBlock {
                return
            }

            if let heading = headingKind(for: trimmed) {
                spans.append(MarkdownStyleSpan(kind: heading, range: lineRange))
                if let markerRange = markerRange(in: line, lineRange: lineRange, pattern: #"^\s{0,3}#{1,6}\s*"#) {
                    spans.append(MarkdownStyleSpan(kind: .collapsedMarkup, range: markerRange))
                }
            } else if let task = taskMarker(in: line, lineRange: lineRange) {
                spans.append(MarkdownStyleSpan(kind: .unorderedList, range: lineRange))
                spans.append(MarkdownStyleSpan(kind: .taskMarker, range: task.markerRange))
                spans.append(MarkdownStyleSpan(kind: task.isChecked ? .taskChecked : .taskUnchecked, range: task.checkboxRange))
            } else if matches(line, pattern: #"^\s*[-*+]\s+"#) {
                spans.append(MarkdownStyleSpan(kind: .unorderedList, range: lineRange))
                if let markerRange = markerRange(in: line, lineRange: lineRange, pattern: #"^\s*[-*+]\s+"#) {
                    spans.append(MarkdownStyleSpan(kind: .listMarker, range: markerRange))
                }
            } else if matches(line, pattern: #"^\s*\d+\.\s+"#) {
                spans.append(MarkdownStyleSpan(kind: .orderedList, range: lineRange))
            } else if matches(line, pattern: #"^\s{0,3}>\s+"#) {
                spans.append(MarkdownStyleSpan(kind: .blockquote, range: lineRange))
                if let markerRange = markerRange(in: line, lineRange: lineRange, pattern: #"^\s{0,3}>\s+"#) {
                    spans.append(MarkdownStyleSpan(kind: .hiddenMarkup, range: markerRange))
                }
            }
        }

        if isInsideCodeBlock {
            let range = NSRange(location: codeBlockStart, length: nsText.length - codeBlockStart)
            codeBlockRanges.append(range)
            spans.append(MarkdownStyleSpan(kind: .codeBlock, range: range))
        }

        spans.append(contentsOf: inlineSpans(in: text, excluding: codeBlockRanges))
        spans.append(contentsOf: hiddenInlineMarkupSpans(in: text, excluding: codeBlockRanges))
        return spans.sorted { lhs, rhs in
            if lhs.range.location == rhs.range.location {
                return lhs.range.length > rhs.range.length
            }
            return lhs.range.location < rhs.range.location
        }
    }

    static func apply(to textView: NSTextView, format: NoteFormat, fontSize: Double = 14) {
        let baseSize = CGFloat(fontSize)
        let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
        textView.font = NSFont.systemFont(ofSize: baseSize, weight: .regular)
        textView.textColor = .labelColor
        textView.typingAttributes = baseTypingAttributes(fontSize: baseSize)

        guard fullRange.length > 0, let textStorage = textView.textStorage else { return }

        textStorage.beginEditing()
        textStorage.setAttributes(baseTypingAttributes(fontSize: baseSize), range: fullRange)

        guard format == .markdown else {
            textStorage.endEditing()
            return
        }

        let styleSpans = spans(in: textView.string)
        for span in styleSpans where !span.kind.isHiddenMarkup && NSMaxRange(span.range) <= fullRange.length {
            textStorage.addAttributes(attributes(for: span.kind, fontSize: baseSize), range: span.range)
        }

        for span in styleSpans where span.kind.isHiddenMarkup && NSMaxRange(span.range) <= fullRange.length {
            textStorage.addAttributes(attributes(for: span.kind, fontSize: baseSize), range: span.range)
        }

        textStorage.endEditing()
    }

    private static func headingKind(for trimmedLine: String) -> MarkdownStyleKind? {
        let level = trimmedLine.prefix(while: { $0 == "#" }).count
        guard (1...3).contains(level) else { return nil }

        let index = trimmedLine.index(trimmedLine.startIndex, offsetBy: level)
        guard index == trimmedLine.endIndex || trimmedLine[index] != "#" else { return nil }

        switch level {
        case 1:
            return .heading1
        case 2:
            return .heading2
        case 3:
            return .heading3
        default:
            return nil
        }
    }

    private static func inlineSpans(in text: String, excluding excludedRanges: [NSRange]) -> [MarkdownStyleSpan] {
        let patterns: [(MarkdownStyleKind, String)] = [
            (.inlineCode, #"`[^`\n]+`"#),
            (.bold, #"\*\*[^*\n]+\*\*|__[^_\n]+__"#),
            (.italic, #"(?<!\*)\*[^*\n]+\*(?!\*)|(?<!_)_[^_\n]+_(?!_)"#),
            (.link, #"\[[^\]\n]+\]\([^)]+\)"#)
        ]

        return patterns.flatMap { kind, pattern in
            regexMatches(in: text, pattern: pattern)
                .filter { range in !excludedRanges.contains { NSIntersectionRange($0, range).length > 0 } }
                .map { MarkdownStyleSpan(kind: kind, range: $0) }
        }
    }

    private static func hiddenInlineMarkupSpans(in text: String, excluding excludedRanges: [NSRange]) -> [MarkdownStyleSpan] {
        let nsText = text as NSString
        var spans: [MarkdownStyleSpan] = []

        for range in regexMatches(in: text, pattern: #"`[^`\n]+`"#) where !intersects(range, excludedRanges) {
            spans.append(MarkdownStyleSpan(kind: .collapsedMarkup, range: NSRange(location: range.location, length: 1)))
            spans.append(MarkdownStyleSpan(kind: .collapsedMarkup, range: NSRange(location: NSMaxRange(range) - 1, length: 1)))
        }

        for range in regexMatches(in: text, pattern: #"\*\*[^*\n]+\*\*|__[^_\n]+__"#) where !intersects(range, excludedRanges) {
            spans.append(MarkdownStyleSpan(kind: .collapsedMarkup, range: NSRange(location: range.location, length: 2)))
            spans.append(MarkdownStyleSpan(kind: .collapsedMarkup, range: NSRange(location: NSMaxRange(range) - 2, length: 2)))
        }

        for range in regexMatches(in: text, pattern: #"(?<!\*)\*[^*\n]+\*(?!\*)|(?<!_)_[^_\n]+_(?!_)"#) where !intersects(range, excludedRanges) {
            spans.append(MarkdownStyleSpan(kind: .collapsedMarkup, range: NSRange(location: range.location, length: 1)))
            spans.append(MarkdownStyleSpan(kind: .collapsedMarkup, range: NSRange(location: NSMaxRange(range) - 1, length: 1)))
        }

        let linkPattern = #"\[[^\]\n]+\]\([^)]+\)"#
        for range in regexMatches(in: text, pattern: linkPattern) where !intersects(range, excludedRanges) {
            let link = nsText.substring(with: range) as NSString
            let closingBracketRange = link.range(of: "](")
            guard closingBracketRange.location != NSNotFound else { continue }

            spans.append(MarkdownStyleSpan(kind: .collapsedMarkup, range: NSRange(location: range.location, length: 1)))
            spans.append(MarkdownStyleSpan(
                kind: .collapsedMarkup,
                range: NSRange(location: range.location + closingBracketRange.location, length: range.length - closingBracketRange.location)
            ))
        }

        return spans
    }

    private static func attributes(for kind: MarkdownStyleKind, fontSize: CGFloat) -> [NSAttributedString.Key: Any] {
        switch kind {
        case .heading1:
            [
                .font: NSFont.systemFont(ofSize: fontSize * 1.75, weight: .bold),
                .foregroundColor: NSColor.labelColor
            ]
        case .heading2:
            [
                .font: NSFont.systemFont(ofSize: fontSize * 1.45, weight: .bold),
                .foregroundColor: NSColor.labelColor
            ]
        case .heading3:
            [
                .font: NSFont.systemFont(ofSize: fontSize * 1.22, weight: .semibold),
                .foregroundColor: NSColor.labelColor
            ]
        case .unorderedList, .orderedList:
            [
                .foregroundColor: NSColor.labelColor
            ]
        case .blockquote:
            [
                .font: NSFont.systemFont(ofSize: fontSize, weight: .regular).italicized(),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        case .codeBlock:
            [
                .font: NSFont.monospacedSystemFont(ofSize: max(fontSize - 1, 11), weight: .regular),
                .foregroundColor: NSColor.labelColor,
                .backgroundColor: NSColor.textBackgroundColor.withAlphaComponent(0.9)
            ]
        case .inlineCode:
            [
                .font: NSFont.monospacedSystemFont(ofSize: max(fontSize - 1, 11), weight: .regular),
                .foregroundColor: NSColor.labelColor,
                .backgroundColor: NSColor.separatorColor.withAlphaComponent(0.28)
            ]
        case .bold:
            [
                .font: NSFont.systemFont(ofSize: fontSize, weight: .bold)
            ]
        case .italic:
            [
                .font: NSFont.systemFont(ofSize: fontSize, weight: .regular).italicized()
            ]
        case .link:
            [
                .foregroundColor: NSColor.linkColor,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ]
        case .hiddenMarkup, .taskUnchecked, .taskChecked:
            [
                .foregroundColor: NSColor.clear
            ]
        case .listMarker:
            [
                .foregroundColor: NSColor.clear,
                .kern: max(3, fontSize * 0.24)
            ]
        case .taskMarker:
            [
                .foregroundColor: NSColor.clear,
                .kern: max(1.5, fontSize * 0.1)
            ]
        case .collapsedMarkup:
            [
                .font: NSFont.systemFont(ofSize: 0.1, weight: .regular),
                .foregroundColor: NSColor.clear
            ]
        }
    }

    private static func baseTypingAttributes(fontSize: CGFloat) -> [NSAttributedString.Key: Any] {
        [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .regular),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle(fontSize: fontSize)
        ]
    }

    private static func paragraphStyle(fontSize: CGFloat) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = max(3, fontSize * 0.18)
        style.paragraphSpacing = max(1, fontSize * 0.04)
        style.lineBreakMode = .byWordWrapping
        return style
    }

    private static func matches(_ text: String, pattern: String) -> Bool {
        !regexMatches(in: text, pattern: pattern).isEmpty
    }

    private static func markerRange(in line: String, lineRange: NSRange, pattern: String) -> NSRange? {
        guard let localRange = regexMatches(in: line, pattern: pattern).first else { return nil }
        return NSRange(location: lineRange.location + localRange.location, length: localRange.length)
    }

    private static func taskMarker(in line: String, lineRange: NSRange) -> (markerRange: NSRange, checkboxRange: NSRange, isChecked: Bool)? {
        let nsLine = line as NSString
        guard let markerRange = regexMatches(in: line, pattern: #"^\s*(?:[-*+]\s+)?\[( |x|X)\]\s+"#).first else {
            return nil
        }

        let marker = nsLine.substring(with: markerRange)
        guard let localCheckboxRange = regexMatches(in: marker, pattern: #"\[( |x|X)\]"#).first else {
            return nil
        }

        let checkboxRange = NSRange(
            location: lineRange.location + markerRange.location + localCheckboxRange.location,
            length: localCheckboxRange.length
        )
        let checkbox = (line as NSString).substring(with: NSRange(location: localCheckboxRange.location + markerRange.location, length: localCheckboxRange.length))
        return (
            NSRange(location: lineRange.location + markerRange.location, length: markerRange.length),
            checkboxRange,
            checkbox.localizedCaseInsensitiveContains("x")
        )
    }

    private static func intersects(_ range: NSRange, _ ranges: [NSRange]) -> Bool {
        ranges.contains { NSIntersectionRange($0, range).length > 0 }
    }

    private static func regexMatches(in text: String, pattern: String) -> [NSRange] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(location: 0, length: (text as NSString).length)
        return regex.matches(in: text, range: range).map(\.range)
    }
}

private extension MarkdownStyleKind {
    var isHiddenMarkup: Bool {
        switch self {
        case .hiddenMarkup, .collapsedMarkup, .listMarker, .taskMarker, .taskUnchecked, .taskChecked:
            true
        default:
            false
        }
    }
}

private extension NSFont {
    func italicized() -> NSFont {
        NSFontManager.shared.convert(self, toHaveTrait: .italicFontMask)
    }
}
