import SwiftUI

struct QuickNoteView: View {
    @ObservedObject var store: NoteStore

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Quick Note")
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

                Button {
                    store.openQuickNoteInMain()
                } label: {
                    Image(systemName: "arrow.up.forward.app")
                }
                .buttonStyle(.borderless)
                .help("Open in NoteDad")
            }
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(.bar)

            NoteTextEditor(
                text: $store.quickNoteContent,
                format: .markdown,
                fontSize: store.editorFontSize,
                focusToken: store.quickNoteFocusRequestID
            )
            .padding(.horizontal, 14)
        }
        .frame(width: 390, height: 320)
        .onAppear {
            do {
                try store.loadQuickNote()
                store.requestQuickNoteFocus()
            } catch {
                store.errorMessage = error.localizedDescription
            }
        }
    }
}
