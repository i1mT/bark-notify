import BarkCore
import SwiftUI

struct ComposeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var advancedExpanded = false

    var body: some View {
        Form {
            Section("Notification") {
                TextField("Title", text: $model.draft.title)
                TextField("Subtitle", text: $model.draft.subtitle)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Message")
                        Spacer()
                        Toggle("Markdown", isOn: $model.draft.markdown)
                            .toggleStyle(.checkbox)
                    }
                    TextEditor(text: $model.draft.message)
                        .font(.body)
                        .frame(minHeight: 130)
                        .padding(5)
                        .background(.background, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator))
                }
            }

            Section("Delivery") {
                LabeledContent("Group") { TextField("Optional", text: $model.draft.group).frame(width: 260) }
                Picker("Level", selection: $model.draft.level) {
                    ForEach(BarkLevel.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                LabeledContent("Sound") { TextField("Default", text: $model.draft.sound).frame(width: 260) }
                LabeledContent("Open URL") { TextField("https://…", text: $model.draft.url).frame(width: 360) }
                if model.draft.level == .critical {
                    LabeledContent("Critical Volume") {
                        Slider(value: $model.draft.volume, in: 0...10, step: 1).frame(width: 210)
                        Text("\(Int(model.draft.volume))").monospacedDigit().frame(width: 20)
                    }
                }
            }

            DisclosureGroup("Advanced", isExpanded: $advancedExpanded) {
                LabeledContent("Icon URL") { TextField("https://…", text: $model.draft.icon).frame(width: 360) }
                LabeledContent("Image URL") { TextField("https://…", text: $model.draft.image).frame(width: 360) }
                LabeledContent("Copy Text") { TextField("Optional", text: $model.draft.copy).frame(width: 360) }
                LabeledContent("Badge") { TextField("Number", text: $model.draft.badge).frame(width: 100) }
                Toggle("Repeat ringtone for 30 seconds", isOn: $model.draft.call)
                Toggle("Enable automatic copy", isOn: $model.draft.autoCopy)
                Toggle("Archive in Bark", isOn: $model.draft.archive)
                if model.draft.archive {
                    LabeledContent("Archive TTL") {
                        TextField("Seconds", text: $model.draft.ttl).frame(width: 100)
                    }
                }
                Toggle("Do nothing when notification is tapped", isOn: $model.draft.noAction)
            }

            HStack {
                Spacer()
                Button("Send Notification") { Task { await model.sendDraft() } }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(model.isWorking || model.draft.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("New Notification")
        .toolbar {
            if model.isWorking { ProgressView().controlSize(.small) }
        }
    }
}
