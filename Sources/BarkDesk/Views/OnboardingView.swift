import BarkCore
import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel
    @State private var step = 0
    @FocusState private var focusedField: SetupField?

    var body: some View {
        HStack(spacing: 0) {
            progressPanel
            VStack(spacing: 0) {
                ScrollView {
                    Group {
                        switch step {
                        case 0: welcome
                        case 1: configuration
                        default: connection
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 465, alignment: .center)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
                Divider().overlay(Color.barkBorder)
                actionBar
            }
            .background(Color.barkCanvas)
        }
        .frame(width: 760, height: 570)
        .interactiveDismissDisabled()
        .onChange(of: step) { _, newStep in
            guard newStep == 1 else { focusedField = nil; return }
            DispatchQueue.main.async { focusedField = .server }
        }
    }

    private var progressPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.white)
                    .frame(width: 36, height: 36)
                    .overlay { Image(systemName: "bell.fill").foregroundStyle(Color.barkAccentInk) }
                Text("BarkDesk").font(.headline.weight(.bold)).foregroundStyle(Color.barkAccentInk)
            }
            Spacer()
            Text(String(format: "%02d", step + 1))
                .font(.system(size: 54, weight: .bold, design: .monospaced))
                .tracking(-3)
                .foregroundStyle(Color.barkAccentInk)
            Text(stepTitle)
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.barkAccentInk)
                .padding(.top, 10)
            Text(stepDetail)
                .font(.callout)
                .foregroundStyle(Color.barkAccentInk.opacity(0.72))
                .lineSpacing(4)
                .padding(.top, 8)
            Spacer()
            HStack(spacing: 7) {
                ForEach(0..<3, id: \.self) { index in
                    Rectangle()
                        .fill(index <= step ? Color.barkAccentInk : Color.barkAccentInk.opacity(0.25))
                        .frame(width: index == step ? 28 : 10, height: 4)
                }
            }
        }
        .padding(26)
        .frame(width: 240)
        .background(Color.barkAccent)
    }

    private var actionBar: some View {
        HStack {
            if step > 0 {
                Button("上一步") { withAnimation(.easeOut(duration: 0.18)) { step -= 1 } }
                    .buttonStyle(.barkSecondary)
            }
            Spacer()
            if step == 0 {
                Button("开始设置") { withAnimation(.easeOut(duration: 0.18)) { step = 1 } }
                    .buttonStyle(.barkPrimary)
            } else if step == 1 {
                Button("继续") {
                    if model.saveConfiguration() {
                        withAnimation(.easeOut(duration: 0.18)) { step = 2 }
                    }
                }
                .buttonStyle(.barkPrimary)
                .disabled(!model.configurationInputIsValid)
            } else {
                Button("进入 BarkDesk") { model.finishOnboarding() }
                    .buttonStyle(.barkPrimary)
                    .disabled(!model.configurationInputIsValid || model.isWorking)
            }
        }
        .padding(.horizontal, 22)
        .frame(height: 72)
        .background(Color.barkSurface)
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 9) {
                Text("开始连接 Bark")
                    .font(.system(size: 30, weight: .bold))
                    .tracking(-0.7)
                Text("连接你已经在使用的 Bark Server，不需要部署新的服务。")
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
            }
            VStack(spacing: 12) {
                requirement(icon: "server.rack", title: "Server 地址", detail: "官方服务或自建 Server")
                requirement(icon: "key.fill", title: "Device Key", detail: "在 iPhone Bark App 中查看")
            }
        }
        .padding(44)
    }

    private var configuration: some View {
        VStack(alignment: .leading, spacing: 21) {
            VStack(alignment: .leading, spacing: 6) {
                Text("连接你的 Bark Server").font(.title2.weight(.bold))
                Text("Device Key 和认证信息将保存在系统钥匙串。")
                    .font(.callout).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 8) {
                FieldCaption(title: "Bark Server 地址")
                TextField("https://bark.example.com", text: $model.configuration.serverURL)
                    .accessibilityIdentifier("onboarding.serverURL")
                    .focused($focusedField, equals: .server)
                    .textFieldStyle(.barkDeskLarge)
                validationLine(issue: model.serverURLIssue, success: "地址格式正确")
            }
            VStack(alignment: .leading, spacing: 8) {
                FieldCaption(title: "Device Key")
                SecureField("从 iPhone Bark App 复制", text: $model.credentials.deviceKey)
                    .accessibilityIdentifier("onboarding.deviceKey")
                    .focused($focusedField, equals: .deviceKey)
                    .textFieldStyle(.barkDeskLarge)
                validationLine(issue: model.deviceKeyIssue, success: "Device Key 已填写")
            }
            Picker("服务器认证", selection: $model.configuration.authenticationMode) {
                Text("无需认证").tag(AuthenticationMode.none)
                Text("Basic Auth").tag(AuthenticationMode.basic)
            }
            .pickerStyle(.segmented)
            if model.configuration.authenticationMode == .basic {
                HStack {
                    TextField("用户名", text: $model.credentials.username)
                        .focused($focusedField, equals: .username)
                        .textFieldStyle(.barkDeskLarge)
                    SecureField("密码", text: $model.credentials.password)
                        .focused($focusedField, equals: .password)
                        .textFieldStyle(.barkDeskLarge)
                }
            }
        }
        .padding(.horizontal, 42)
        .padding(.vertical, 30)
    }

    private var connection: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 6) {
                Text("确认连接").font(.title2.weight(.bold))
                Text("先检查服务器和 Device Key，再发送测试通知确认完整链路。")
                    .font(.callout).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 11) {
                if model.connectionResults.isEmpty {
                    Label("尚未检查连接", systemImage: "network")
                        .font(.headline)
                    Text("检查操作不会发送通知。")
                        .font(.callout).foregroundStyle(.secondary)
                } else {
                    ForEach(model.connectionResults) { result in
                        Label(
                            result.label,
                            systemImage: result.success ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
                        )
                        .foregroundStyle(result.success ? .green : .orange)
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
            .background(Color.barkSurface, in: RoundedRectangle(cornerRadius: 12))
            HStack {
                Button("检查连接") {
                    _ = model.saveConfiguration()
                    Task { await model.testConnection() }
                }
                .buttonStyle(.barkPrimary)
                Button("发送测试通知") { Task { await model.sendTest() } }
                    .buttonStyle(.barkSecondary)
                    .disabled(!model.connectionTestPassed || model.isWorking)
                Spacer()
                if model.isWorking { ProgressView().controlSize(.small) }
            }
        }
        .padding(.horizontal, 42)
        .padding(.vertical, 30)
    }

    private func requirement(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.barkAccent)
                .frame(width: 42, height: 42)
                .background(Color.barkAccentSoft, in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).fontWeight(.semibold)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(15)
        .background(Color.barkSurface, in: RoundedRectangle(cornerRadius: 12))
    }

    private func validationLine(issue: String?, success: String) -> some View {
        Label(issue ?? success, systemImage: issue == nil ? "checkmark.circle.fill" : "info.circle")
            .font(.caption)
            .foregroundStyle(issue == nil ? .green : .secondary)
    }

    private var stepTitle: String {
        ["准备开始", "安全连接", "确认可用"][step]
    }

    private var stepDetail: String {
        [
            "准备好 Server 地址与 Device Key，几分钟内完成设置。",
            "敏感信息只保存在这台 Mac 的系统钥匙串中。",
            "检查连接状态，然后发送一条测试通知。"
        ][step]
    }
}

private enum SetupField: Hashable {
    case server
    case deviceKey
    case username
    case password
}
