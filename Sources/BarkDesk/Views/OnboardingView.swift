import BarkCore
import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel
    @State private var step = 0
    @FocusState private var focusedField: SetupField?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 7) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(index <= step ? Color.accentColor : Color.secondary.opacity(0.2))
                        .frame(width: index == step ? 34 : 12, height: 6)
                }
            }
            .padding(.top, 24)

            Group {
                switch step {
                case 0: welcome
                case 1: configuration
                default: connection
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity.combined(with: .move(edge: .trailing)))

            Divider()
            HStack {
                if step > 0 { Button("上一步") { withAnimation { step -= 1 } } }
                Spacer()
                if step == 0 {
                    Button("开始设置") { withAnimation { step = 1 } }
                        .buttonStyle(.borderedProminent)
                } else if step == 1 {
                    Button("继续") {
                        if model.saveConfiguration() { withAnimation { step = 2 } }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!model.configurationInputIsValid)
                } else {
                    Button("进入 BarkDesk") { model.finishOnboarding() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!model.configurationInputIsValid || model.isWorking)
                }
            }
            .controlSize(.large)
            .padding(20)
        }
        .frame(width: 700, height: 570)
        .interactiveDismissDisabled()
        .onChange(of: step) { _, newStep in
            guard newStep == 1 else { focusedField = nil; return }
            DispatchQueue.main.async { focusedField = .server }
        }
    }

    private var welcome: some View {
        VStack(spacing: 24) {
            Image(systemName: "bell.and.waves.left.and.right.fill")
                .font(.system(size: 58))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
            VStack(spacing: 9) {
                Text("欢迎使用 BarkDesk")
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                Text("只需要连接你已经在使用的 Bark Server，\n不需要部署任何新服务。")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
            }
            HStack(spacing: 28) {
                requirement(icon: "server.rack", title: "Server 地址", detail: "例如 https://bark.example.com")
                requirement(icon: "key.fill", title: "Device Key", detail: "在 iPhone Bark App 中查看")
            }
            .padding(.top, 8)
        }
        .padding(42)
    }

    private var configuration: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text("连接你的 Bark Server").font(.title.weight(.semibold))
                Text("这些信息只保存在这台 Mac；Device Key 和认证信息会写入系统钥匙串。")
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 9) {
                Text("Bark Server 地址").fontWeight(.medium)
                TextField("https://bark.example.com", text: $model.configuration.serverURL)
                    .focused($focusedField, equals: .server)
                    .textFieldStyle(.barkDeskLarge)
                validationLine(issue: model.serverURLIssue, success: "地址格式正确")
            }
            VStack(alignment: .leading, spacing: 9) {
                Text("Device Key").fontWeight(.medium)
                SecureField("从 iPhone Bark App 复制", text: $model.credentials.deviceKey)
                    .focused($focusedField, equals: .deviceKey)
                    .textFieldStyle(.barkDeskLarge)
                validationLine(issue: model.deviceKeyIssue, success: "Device Key 已填写")
            }
            Picker("服务器认证", selection: $model.configuration.authenticationMode) {
                Text("无需认证").tag(AuthenticationMode.none)
                Text("Basic Auth").tag(AuthenticationMode.basic)
            }
            if model.configuration.authenticationMode == .basic {
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        TextField("用户名", text: $model.credentials.username)
                            .focused($focusedField, equals: .username)
                            .textFieldStyle(.barkDeskLarge)
                        SecureField("密码", text: $model.credentials.password)
                            .focused($focusedField, equals: .password)
                            .textFieldStyle(.barkDeskLarge)
                    }
                    validationLine(issue: model.authenticationIssue, success: "认证信息已填写")
                }
            }
        }
        .padding(.horizontal, 64)
        .padding(.vertical, 34)
    }

    private var connection: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
                Text("确认连接").font(.title.weight(.semibold))
                Text("先检查服务器和 Device Key，再发送一条测试通知确认完整链路。")
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 10) {
                if model.connectionResults.isEmpty {
                    ContentUnavailableView(
                        "尚未检查连接",
                        systemImage: "network",
                        description: Text("点击下方按钮开始检查，不会发送通知。")
                    )
                    .frame(maxWidth: .infinity, minHeight: 190)
                } else {
                    ForEach(model.connectionResults) { result in
                        Label(result.label, systemImage: result.success ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundStyle(result.success ? .green : .orange)
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))

            HStack {
                Button("检查连接") {
                    _ = model.saveConfiguration()
                    Task { await model.testConnection() }
                }
                .buttonStyle(.borderedProminent)
                Button("发送测试通知") { Task { await model.sendTest() } }
                    .disabled(!model.connectionTestPassed || model.isWorking)
                Spacer()
                if model.isWorking { ProgressView().controlSize(.small) }
            }
        }
        .padding(.horizontal, 64)
        .padding(.vertical, 34)
    }

    private func requirement(icon: String, title: String, detail: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon).font(.title2).foregroundStyle(.secondary)
            Text(title).fontWeight(.semibold)
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
        .frame(width: 230, height: 100)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
    }

    private func validationLine(issue: String?, success: String) -> some View {
        Label(issue ?? success, systemImage: issue == nil ? "checkmark.circle.fill" : "info.circle")
            .font(.caption)
            .foregroundStyle(issue == nil ? .green : .secondary)
    }
}

private enum SetupField: Hashable {
    case server
    case deviceKey
    case username
    case password
}
