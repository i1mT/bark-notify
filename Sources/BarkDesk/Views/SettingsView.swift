import BarkCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(
                    eyebrow: "BarkDesk 设置",
                    title: "连接与你的发送偏好",
                    detail: "BarkDesk 直接连接 Bark Server；Device Key 与认证信息保存在系统钥匙串。"
                )
                connectionCard
                defaultsCard
                cliCard
            }
            .frame(maxWidth: 760)
            .padding(.horizontal, 34)
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity)
        }
        .background(Color.barkCanvas)
        .safeAreaInset(edge: .bottom) { saveBar }
    }

    private var connectionCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 18) {
                cardHeader(
                    icon: "network",
                    title: "Bark Server",
                    detail: "首次启动引导和这里使用同一份配置。"
                )
                VStack(alignment: .leading, spacing: 8) {
                    FieldCaption(title: "Server 地址")
                    TextField("https://bark.example.com", text: $model.configuration.serverURL)
                        .textContentType(.URL)
                        .textFieldStyle(.barkDeskLarge)
                        .onSubmit { model.saveConfiguration() }
                    validationLine(issue: model.serverURLIssue, success: "地址格式正确")
                }
                VStack(alignment: .leading, spacing: 8) {
                    FieldCaption(title: "Device Key")
                    SecureField("Bark 推送地址中域名后的字符", text: $model.credentials.deviceKey)
                        .textFieldStyle(.barkDeskLarge)
                    validationLine(issue: model.deviceKeyIssue, success: "Device Key 已填写")
                }
                Picker("服务器认证", selection: $model.configuration.authenticationMode) {
                    Text("无需认证").tag(AuthenticationMode.none)
                    Text("Basic Auth").tag(AuthenticationMode.basic)
                }
                .pickerStyle(.segmented)
                if model.configuration.authenticationMode == .basic {
                    HStack(spacing: 12) {
                        TextField("用户名", text: $model.credentials.username).textFieldStyle(.barkDeskLarge)
                        SecureField("密码", text: $model.credentials.password).textFieldStyle(.barkDeskLarge)
                    }
                    validationLine(issue: model.authenticationIssue, success: "认证信息已填写")
                }
                Divider()
                connectionActions
            }
        }
        .onChange(of: model.configuration.serverURL) { _, _ in resetConnectionState() }
        .onChange(of: model.credentials.deviceKey) { _, _ in resetConnectionState() }
    }

    private var connectionActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.connectionResults.isEmpty {
                Text("填写并保存后，可以检查服务器与 Device Key，也可以发送一条测试通知。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(model.connectionResults) { result in
                    Label(result.label, systemImage: result.success ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.callout)
                        .foregroundStyle(result.success ? .green : .orange)
                }
            }
            HStack {
                Button("检查连接") {
                    guard model.saveConfiguration() else { return }
                    Task { await model.testConnection() }
                }
                .buttonStyle(.barkSecondary)
                Button("发送测试通知") {
                    guard model.saveConfiguration() else { return }
                    Task { await model.sendTest() }
                }
                .buttonStyle(.barkPrimary)
                .disabled(!model.configurationInputIsValid)
                Spacer()
                if model.isWorking { ProgressView().controlSize(.small) }
            }
        }
    }

    private var defaultsCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 18) {
                cardHeader(
                    icon: "slider.horizontal.3",
                    title: "发送默认值",
                    detail: "每次新建通知时自动填入，发送前仍可修改。"
                )
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 14)], spacing: 14) {
                    TextField("默认分组", text: $model.configuration.defaultGroup)
                        .textFieldStyle(.barkDeskLarge)
                    TextField("默认提示音", text: $model.configuration.defaultSound, prompt: Text("使用 Bark 默认值"))
                        .textFieldStyle(.barkDeskLarge)
                    VStack(alignment: .leading, spacing: 8) {
                        FieldCaption(title: "默认提醒方式")
                        Picker("默认提醒方式", selection: $model.configuration.defaultLevel) {
                            ForEach(BarkLevel.allCases, id: \.self) { Text($0.displayName).tag($0) }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .barkControlSurface()
                    }
                }
                Toggle("默认保存在 Bark 历史记录中", isOn: $model.configuration.archiveMessages)
            }
        }
    }

    private var cliCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 14) {
                cardHeader(
                    icon: "terminal",
                    title: "notify CLI 单独配置",
                    detail: "CLI 通过 npm 独立安装，可在 Linux、macOS 和 Windows 使用，不会读取这里的设置。"
                )
                Text("npm install -g barkdesk-notify")
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.barkAccentSoft, in: RoundedRectangle(cornerRadius: 9))
                HStack {
                    Button("复制安装命令") { model.copy("npm install -g barkdesk-notify") }
                        .buttonStyle(.barkSecondary)
                    Link("查看 npm package", destination: URL(string: "https://www.npmjs.com/package/barkdesk-notify")!)
                        .buttonStyle(.barkSecondary)
                }
            }
        }
    }

    private var saveBar: some View {
        HStack {
            Label(
                model.configurationInputIsValid ? "配置可以保存" : "请先填写完整的连接信息",
                systemImage: model.configurationInputIsValid ? "checkmark.circle.fill" : "info.circle"
            )
            .font(.callout)
            .foregroundStyle(model.configurationInputIsValid ? .green : .secondary)
            Spacer()
            Button("保存设置") { model.saveConfiguration() }
                .buttonStyle(.barkPrimary)
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!model.configurationInputIsValid)
        }
        .frame(maxWidth: 760)
        .padding(.horizontal, 34)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity)
        .barkPanelSurface(radius: 16)
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }

    private func cardHeader(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.barkAccent)
                .frame(width: 38, height: 38)
                .background(Color.barkAccentSoft, in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
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
