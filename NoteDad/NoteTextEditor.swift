import AppKit
import SwiftUI

struct NoteFindSelection: Equatable {
    var selectedRange: NSRange?
    var token: Int

    static let empty = NoteFindSelection(selectedRange: nil, token: 0)
}

struct NoteTextEditor: NSViewRepresentable {
    @Binding var text: String
    var format: NoteFormat
    var fontSize: Double
    var focusToken: Int
    var findSelection: NoteFindSelection = .empty

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        applyNoteDadScroller(to: scrollView)

        let textView = RawCopyTextView()
        textView.isMarkdownMode = format == .markdown
        textView.delegate = context.coordinator
        textView.string = text
        textView.font = NSFont.systemFont(ofSize: fontSize)
        textView.textColor = .labelColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isRichText = true
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 16, height: 10)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.setAccessibilityIdentifier("note-editor")

        scrollView.documentView = textView
        context.coordinator.textView = textView
        MarkdownHighlighter.apply(to: textView, format: format, fontSize: fontSize)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = context.coordinator.textView else { return }
        textView.isMarkdownMode = format == .markdown
        textView.textContainerInset = NSSize(width: 16, height: 10)

        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
        }

        MarkdownHighlighter.apply(to: textView, format: format, fontSize: fontSize)
        textView.needsDisplay = true

        if context.coordinator.lastFocusToken != focusToken {
            context.coordinator.lastFocusToken = focusToken
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
            }
        }

        if context.coordinator.lastFindSelectionToken != findSelection.token {
            context.coordinator.lastFindSelectionToken = findSelection.token
            showFindSelection(findSelection, in: textView)
        }
    }

    private func showFindSelection(_ selection: NoteFindSelection, in textView: NSTextView) {
        guard let range = selection.selectedRange else { return }

        let contentLength = (textView.string as NSString).length
        guard range.location != NSNotFound,
              range.length > 0,
              NSMaxRange(range) <= contentLength else {
            return
        }

        textView.setSelectedRange(range)
        textView.scrollRangeToVisible(range)
        textView.showFindIndicator(for: range)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NoteTextEditor
        fileprivate weak var textView: RawCopyTextView?
        var lastFocusToken = -1
        var lastFindSelectionToken = -1

        init(_ parent: NoteTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            MarkdownHighlighter.apply(to: textView, format: parent.format, fontSize: parent.fontSize)
        }
    }
}

private final class RawCopyTextView: NSTextView {
    var isMarkdownMode = false

    override func mouseDown(with event: NSEvent) {
        if isMarkdownMode, toggleTaskCheckbox(at: event) {
            return
        }

        super.mouseDown(with: event)
    }

    override func insertNewline(_ sender: Any?) {
        if isMarkdownMode, continueMarkdownLineIfNeeded() {
            return
        }

        super.insertNewline(sender)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        if isMarkdownMode {
            drawMarkdownMarkers()
        }
    }

    override func copy(_ sender: Any?) {
        guard let selectedRange = selectedRanges.first?.rangeValue, selectedRange.length > 0 else {
            super.copy(sender)
            return
        }

        let selectedText = (string as NSString).substring(with: selectedRange)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(selectedText, forType: .string)
    }

    private func toggleTaskCheckbox(at event: NSEvent) -> Bool {
        guard let characterIndex = characterIndex(for: event) else { return false }
        let nsString = string as NSString
        guard nsString.length > 0 else { return false }

        let lineRange = nsString.lineRange(for: NSRange(location: min(characterIndex, nsString.length - 1), length: 0))
        let line = nsString.substring(with: lineRange)
        guard let task = taskMarker(in: line, lineRange: lineRange),
              NSLocationInRange(characterIndex, task.markerRange) else {
            return false
        }

        let replacement = task.isChecked ? "[ ]" : "[x]"
        let updated = NSMutableString(string: string)
        updated.replaceCharacters(in: task.checkboxRange, with: replacement)
        string = updated as String
        setSelectedRange(NSRange(location: task.checkboxRange.location + replacement.count, length: 0))
        delegate?.textDidChange?(Notification(name: NSText.didChangeNotification, object: self))
        needsDisplay = true
        return true
    }

    private func continueMarkdownLineIfNeeded() -> Bool {
        let selectedRange = selectedRange()
        guard selectedRange.location != NSNotFound, selectedRange.length == 0 else { return false }

        let nsString = string as NSString
        let cursor = min(selectedRange.location, nsString.length)
        let lineRange = nsString.lineRange(for: NSRange(location: cursor, length: 0))
        let linePrefixLength = max(0, cursor - lineRange.location)
        let linePrefix = nsString.substring(with: NSRange(location: lineRange.location, length: linePrefixLength))

        guard let action = MarkdownLineContinuation.action(for: linePrefix) else { return false }

        switch action {
        case .continueWithPrefix(let prefix):
            insertText("\n\(prefix)", replacementRange: selectedRange)
        case .exitList(let markerRange):
            let globalMarkerRange = NSRange(
                location: lineRange.location + markerRange.location,
                length: min(markerRange.length, max(0, cursor - lineRange.location - markerRange.location))
            )
            guard globalMarkerRange.length > 0 else { return false }
            guard replaceText(in: globalMarkerRange, with: "") else { return false }
        }

        needsDisplay = true
        return true
    }

    private func drawMarkdownMarkers() {
        let nsString = string as NSString
        guard nsString.length > 0 else { return }

        nsString.enumerateSubstrings(
            in: NSRange(location: 0, length: nsString.length),
            options: [.byLines, .substringNotRequired]
        ) { _, lineRange, _, _ in
            let line = nsString.substring(with: lineRange)

            if let task = self.taskMarker(in: line, lineRange: lineRange) {
                self.drawCheckbox(in: task.checkboxRange, isChecked: task.isChecked)
            } else if let markerRange = self.markerRange(in: line, lineRange: lineRange, pattern: #"^\s*[-*+]\s+"#) {
                self.drawBullet(in: markerRange)
            }
        }
    }

    private func drawCheckbox(in range: NSRange, isChecked: Bool) {
        guard let rect = boundingRect(forCharacterRange: range) else { return }
        let side = max(14, min(19, rect.height * 0.72))
        let box = NSRect(
            x: rect.minX + 1,
            y: rect.midY - side / 2,
            width: side,
            height: side
        )

        let path = NSBezierPath(roundedRect: box, xRadius: 3.2, yRadius: 3.2)
        (isChecked ? NSColor.controlAccentColor.withAlphaComponent(0.18) : NSColor.quaternaryLabelColor.withAlphaComponent(0.18)).setFill()
        path.fill()
        (isChecked ? NSColor.controlAccentColor : NSColor.tertiaryLabelColor).setStroke()
        path.lineWidth = 1.25
        path.stroke()

        guard isChecked else { return }

        let check = NSBezierPath()
        check.move(to: NSPoint(x: box.minX + side * 0.22, y: box.midY))

        if isFlipped {
            check.line(to: NSPoint(x: box.minX + side * 0.43, y: box.maxY - side * 0.26))
            check.line(to: NSPoint(x: box.maxX - side * 0.18, y: box.minY + side * 0.24))
        } else {
            check.line(to: NSPoint(x: box.minX + side * 0.43, y: box.minY + side * 0.26))
            check.line(to: NSPoint(x: box.maxX - side * 0.18, y: box.maxY - side * 0.24))
        }

        (isChecked ? NSColor.controlAccentColor : NSColor.labelColor).setStroke()
        check.lineWidth = max(1.7, side * 0.13)
        check.lineCapStyle = .round
        check.lineJoinStyle = .round
        check.stroke()
    }

    private func drawBullet(in range: NSRange) {
        guard let rect = boundingRect(forCharacterRange: range) else { return }
        let side = max(5, min(7, rect.height * 0.22))
        let bullet = NSRect(
            x: rect.minX + 1.5,
            y: rect.midY - side / 2,
            width: side,
            height: side
        )
        NSColor.secondaryLabelColor.setFill()
        NSBezierPath(ovalIn: bullet).fill()
    }

    private func characterIndex(for event: NSEvent) -> Int? {
        guard let layoutManager, let textContainer else { return nil }

        let point = convert(event.locationInWindow, from: nil)
        let containerPoint = NSPoint(
            x: point.x - textContainerOrigin.x,
            y: point.y - textContainerOrigin.y
        )
        let glyphIndex = layoutManager.glyphIndex(for: containerPoint, in: textContainer)
        return layoutManager.characterIndexForGlyph(at: glyphIndex)
    }

    private func boundingRect(forCharacterRange range: NSRange) -> NSRect? {
        guard let layoutManager, let textContainer, range.location < (string as NSString).length else {
            return nil
        }

        let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        guard glyphRange.length > 0 else { return nil }

        var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        rect.origin.x += textContainerOrigin.x
        rect.origin.y += textContainerOrigin.y
        return rect
    }

    private func taskMarker(in line: String, lineRange: NSRange) -> (markerRange: NSRange, checkboxRange: NSRange, isChecked: Bool)? {
        let nsLine = line as NSString
        guard let markerRange = regexMatches(in: line, pattern: #"^\s*(?:[-*+]\s+)?\[( |x|X)\]\s+"#).first,
              let localCheckboxRange = regexMatches(in: nsLine.substring(with: markerRange), pattern: #"\[( |x|X)\]"#).first else {
            return nil
        }

        let checkboxRange = NSRange(
            location: lineRange.location + markerRange.location + localCheckboxRange.location,
            length: localCheckboxRange.length
        )
        let checkbox = nsLine.substring(with: NSRange(
            location: markerRange.location + localCheckboxRange.location,
            length: localCheckboxRange.length
        ))

        return (
            NSRange(location: lineRange.location + markerRange.location, length: markerRange.length),
            checkboxRange,
            checkbox.localizedCaseInsensitiveContains("x")
        )
    }

    private func markerRange(in line: String, lineRange: NSRange, pattern: String) -> NSRange? {
        guard let localRange = regexMatches(in: line, pattern: pattern).first else { return nil }
        return NSRange(location: lineRange.location + localRange.location, length: localRange.length)
    }

    private func regexMatches(in text: String, pattern: String) -> [NSRange] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: text, range: NSRange(location: 0, length: (text as NSString).length)).map(\.range)
    }

    private func replaceText(in range: NSRange, with replacement: String) -> Bool {
        guard shouldChangeText(in: range, replacementString: replacement) else { return false }
        textStorage?.replaceCharacters(in: range, with: replacement)
        didChangeText()
        setSelectedRange(NSRange(location: range.location + (replacement as NSString).length, length: 0))
        return true
    }
}
