import AppKit

final class NoteDadScroller: NSScroller {
    override class func scrollerWidth(for controlSize: NSControl.ControlSize, scrollerStyle: NSScroller.Style) -> CGFloat {
        11
    }

    override func drawKnobSlot(in slotRect: NSRect, highlight flag: Bool) {
        // Keep the editor surface quiet; only the rounded thumb is drawn.
    }

    override func drawKnob() {
        let knobRect = rect(for: .knob).insetBy(dx: 2.5, dy: 2.5)
        guard knobRect.width > 2, knobRect.height > 2 else { return }

        NSColor.secondaryLabelColor.withAlphaComponent(0.42).setFill()
        NSBezierPath(
            roundedRect: knobRect,
            xRadius: knobRect.width / 2,
            yRadius: knobRect.width / 2
        ).fill()
    }
}

func applyNoteDadScroller(to scrollView: NSScrollView) {
    scrollView.scrollerStyle = .overlay
    scrollView.autohidesScrollers = true

    if !(scrollView.verticalScroller is NoteDadScroller) {
        let verticalScroller = NoteDadScroller()
        verticalScroller.controlSize = .regular
        scrollView.verticalScroller = verticalScroller
    }
}

func applyNoteDadScrollers(around view: NSView) {
    if let enclosingScrollView = view.firstSuperview(of: NSScrollView.self) {
        applyNoteDadScroller(to: enclosingScrollView)
    }

    let root = view.window?.contentView ?? view
    root.descendants(of: NSScrollView.self).forEach(applyNoteDadScroller)
}

extension NSView {
    func firstSuperview<T: NSView>(of type: T.Type) -> T? {
        if let match = superview as? T {
            return match
        }

        return superview?.firstSuperview(of: type)
    }

    func descendants<T: NSView>(of type: T.Type) -> [T] {
        subviews.flatMap { subview -> [T] in
            var matches = subview.descendants(of: type)
            if let match = subview as? T {
                matches.insert(match, at: 0)
            }
            return matches
        }
    }
}
