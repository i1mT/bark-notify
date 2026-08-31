import SwiftUI

struct IntegrationsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PageHeader(
                    eyebrow: "脚本与自动化",
                    title: "让任务结束时主动通知你",
                    detail: "CLI 与 BarkDesk 分别管理配置。服务器建议安装 notify CLI；临时脚本也可以直接调用 Bark API。"
                )
                cliSetup
                apiAccess
                examples
            }
            .frame(maxWidth: 820)
            .padding(.horizontal, 34)
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("开发者接入")
    }

    private var cliSetup: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 17) {
                sectionHeader(
                    icon: "terminal.fill",
                    title: "推荐：安装 notify CLI",
                    detail: "支持 Linux、macOS 与 Windows，不依赖 BarkDesk App。"
                )
                codeRow(title: "1 · 安装", value: "npm install -g barkdesk-notify")
                codeRow(
                    title: "2 · 配置",
                    value: "notify config set --server \(model.configuration.serverURL) --device YOUR_DEVICE_KEY"
                )
                codeRow(title: "3 · 检查", value: "notify config test")
                Label("BarkDesk 不会把当前 Device Key 自动同步给 CLI，请在 CLI 所在的电脑或服务器上完成配置。", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var apiAccess: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader(
                    icon: "curlybraces",
                    title: "直接调用 Bark API",
                    detail: "适合已有 HTTP 客户端或只需要一次调用的脚本。"
                )
                endpointRow(title: "快捷推送地址", value: model.endpoint(model.credentials.deviceKey))
                Divider()
                endpointRow(title: "REST API V2", value: model.endpoint("push"))
                Divider()
                endpointRow(title: "Bark MCP", value: model.endpoint("mcp/\(model.credentials.deviceKey)"))
            }
        }
    }

    private var examples: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 17) {
                sectionHeader(
                    icon: "text.page",
                    title: "常用示例",
                    detail: "复制以后替换标题、内容或实际命令。"
                )
                codeRow(title: "命令结束提醒", value: "notify run -- pnpm build")
                codeRow(title: "标准输入", value: "echo \"备份完成\" | notify -t \"Server\"")
                codeRow(title: "curl", value: curlExample)
            }
        }
    }

    private func sectionHeader(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.barkRed)
                .frame(width: 40, height: 40)
                .background(Color.barkRedSoft, in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func endpointRow(title: String, value: String) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.subheadline.weight(.medium))
                Text(value)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(2)
            }
            Spacer(minLength: 12)
            Button("复制") { model.copy(value) }
        }
    }

    private func codeRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Button("复制") { model.copy(value) }.buttonStyle(.plain).foregroundStyle(Color.barkRed)
            }
            Text(value)
                .font(.system(.callout, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 11))
        }
    }

    private var curlExample: String {
        """
        curl -X POST "\(model.endpoint("push"))" \\
          -H "Content-Type: application/json" \\
          -d '{"device_key":"YOUR_DEVICE_KEY","title":"测试","body":"你好"}'
        """
    }
}
