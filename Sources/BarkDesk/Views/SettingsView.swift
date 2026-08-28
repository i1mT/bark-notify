import BarkCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section("Bark Server") {
                TextField("Server URL", text: $model.configuration.serverURL, prompt: Text("https://bark.example.com"))
                    .textContentType(.URL)
                SecureField("Device Key", text: $model.credentials.deviceKey)
                Picker("Authentication", selection: $model.configuration.authenticationMode) {
                    Text("None").tag(AuthenticationMode.none)
                    Text("Basic Auth").tag(AuthenticationMode.basic)
                }
                if model.configuration.authenticationMode == .basic {
                    TextField("Username", text: $model.credentials.username)
                    SecureField("Password", text: $model.credentials.password)
                }
            }

            Section("Defaults") {
                TextField("Group", text: $model.configuration.defaultGroup)
                Picker("Level", selection: $model.configuration.defaultLevel) {
                    ForEach(BarkLevel.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                TextField("Sound", text: $model.configuration.defaultSound, prompt: Text("Bark default"))
                Toggle("Archive messages in Bark", isOn: $model.configuration.archiveMessages)
            }

            Section("Command Line Tool") {
                switch model.cliInstallationStatus {
                case .checking:
                    LabeledContent("notify") { ProgressView().controlSize(.small) }
                case .missing:
                    LabeledContent("notify", value: "Not installed")
                    Button("Install notify") { Task { await model.installCLI() } }
                        .buttonStyle(.borderedProminent)
                case .installed(let url):
                    LabeledContent("notify") {
                        Label("Installed", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                    LabeledContent("Path", value: url.path)
                    if !model.cliInstallDirectoryIsInPath {
                        Text("If your terminal cannot find notify, add ~/.local/bin to your shell PATH.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                case .unavailable(let reason):
                    Label(reason, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Button("Try Again") { Task { await model.installCLI() } }
                }
                Button("Check Again") { Task { await model.checkCLIInstallation() } }
            }

            Section("Connection") {
                ForEach(model.connectionResults) { result in
                    Label(result.label, systemImage: result.success ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundStyle(result.success ? .green : .orange)
                }
                HStack {
                    Button("Test Connection") {
                        model.saveConfiguration()
                        Task { await model.testConnection() }
                    }
                    Button("Send Test Notification") {
                        model.saveConfiguration()
                        Task { await model.sendTest() }
                    }
                    .buttonStyle(.borderedProminent)
                    Spacer()
                    if model.isWorking { ProgressView().controlSize(.small) }
                }
            }

            HStack {
                Spacer()
                Button("Save Settings") { model.saveConfiguration() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut("s", modifiers: .command)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
    }
}
