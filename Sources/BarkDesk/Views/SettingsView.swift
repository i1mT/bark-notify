import BarkCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 5) {
                    Text("连接设置").font(.title2.weight(.semibold))
                    Text("BarkDesk 会直接连接你的 Bark Server，敏感信息保存在系统钥匙串中。")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 5)
            }

            Section("Bark Server") {
                VStack(alignment: .leading, spacing: 7) {
                    TextField("Server 地址", text: $model.configuration.serverURL, prompt: Text("https://bark.example.com"))
                        .textContentType(.URL)
                        .onSubmit { model.saveConfiguration() }
                    validationLine(issue: model.serverURLIssue, success: "地址格式正确")
                }
                VStack(alignment: .leading, spacing: 7) {
                    SecureField("Device Key", text: $model.credentials.deviceKey)
                    validationLine(issue: model.deviceKeyIssue, success: "Device Key 已填写")
                }
                Picker("认证方式", selection: $model.configuration.authenticationMode) {
                    Text("无需认证").tag(AuthenticationMode.none)
                    Text("Basic Auth").tag(AuthenticationMode.basic)
                }
                if model.configuration.authenticationMode == .basic {
                    TextField("用户名", text: $model.credentials.username)
                    SecureField("密码", text: $model.credentials.password)
                    validationLine(issue: model.authenticationIssue, success: "认证信息已填写")
                }
            }
            .onChange(of: model.configuration.serverURL) { _, _ in resetConnectionState() }
            .onChange(of: model.credentials.deviceKey) { _, _ in resetConnectionState() }

            Section("发送默认值") {
                TextField("默认分组", text: $model.configuration.defaultGroup)
                Picker("默认提醒方式", selection: $model.configuration.defaultLevel) {
                    ForEach(BarkLevel.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                TextField("默认提示音", text: $model.configuration.defaultSound, prompt: Text("使用 Bark 默认提示音"))
                Toggle("默认保存在 Bark 历史记录中", isOn: $model.configuration.archiveMessages)
            }

            Section("命令行工具") {
                switch model.cliInstallationStatus {
                case .checking:
                    LabeledContent("notify") { ProgressView().controlSize(.small) }
                case .missing:
                    LabeledContent("notify", value: "尚未安装")
                    Button("安装 notify") { Task { await model.installCLI() } }
                        .buttonStyle(.borderedProminent)
                case .installed(let url):
                    LabeledContent("notify") {
                        Label("已经安装", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                    LabeledContent("安装位置", value: url.path)
                    if !model.cliInstallDirectoryIsInPath {
                        Text("如果终端找不到 notify，请把它所在的目录加入 shell PATH。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                case .unavailable(let reason):
                    Label(reason, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Button("重新安装") { Task { await model.installCLI() } }
                }
                Button("重新检查") { Task { await model.checkCLIInstallation() } }
            }

            Section("连接检查") {
                if model.connectionResults.isEmpty {
                    Text("保存设置后，可以检查服务器和 Device Key 是否可用。")
                        .foregroundStyle(.secondary)
                }
                ForEach(model.connectionResults) { result in
                    Label(result.label, systemImage: result.success ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundStyle(result.success ? .green : .orange)
                }
                HStack {
                    Button("检查连接") {
                        guard model.saveConfiguration() else { return }
                        Task { await model.testConnection() }
                    }
                    Button("发送测试通知") {
                        guard model.saveConfiguration() else { return }
                        Task { await model.sendTest() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!model.configurationInputIsValid)
                    Spacer()
                    if model.isWorking { ProgressView().controlSize(.small) }
                }
            }

            HStack {
                Spacer()
                Button("保存设置") { model.saveConfiguration() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(!model.configurationInputIsValid)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("设置")
    }

    private func validationLine(issue: String?, success: String) -> some View {
        Label(issue ?? success, systemImage: issue == nil ? "checkmark.circle.fill" : "info.circle")
            .font(.caption)
            .foregroundStyle(issue == nil ? .green : .secondary)
    }

    private func resetConnectionState() {
        model.connectionResults = []
        model.connectionTestPassed = false
    }
}
