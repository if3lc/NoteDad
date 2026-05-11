import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: NoteStore
    @Binding var quickNoteEnabled: Bool

    var body: some View {
        Form {
            Picker("New note format", selection: $store.defaultFormat) {
                ForEach(NoteFormat.allCases) { format in
                    Text(format.displayName).tag(format)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Editor text size")
                    Spacer()
                    Text("\(Int(store.editorFontSize)) pt")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Slider(value: $store.editorFontSize, in: 12...22, step: 1)
            }

            Toggle("Show Quick Note in menu bar", isOn: $quickNoteEnabled)

            HStack {
                Text("Notes folder")
                Spacer()
                Button("Open") {
                    store.openNotesFolder()
                }
            }

            Text(store.rootURL.path)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding(22)
        .frame(width: 420)
    }
}
