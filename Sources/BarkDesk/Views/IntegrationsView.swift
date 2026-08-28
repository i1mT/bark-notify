import SwiftUI

struct IntegrationsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("把当前 Bark 配置接入脚本、终端和开发工具。")
                    .foregroundStyle(.secondary)
                endpointCard(
                    title: "Bark 快捷推送地址",
                    description: "适合临时脚本使用的兼容地址",
                    value: model.endpoint(model.credentials.deviceKey)
                )
                endpointCard(
                    title: "REST API",
                    description: "推荐使用的 Bark API V2 地址",
                    value: model.endpoint("push")
                )
                endpointCard(
                    title: "MCP",
                    description: "在 AI 工具中使用 Bark Server 自带的 MCP",
                    value: model.endpoint("mcp/\(model.credentials.deviceKey)")
                )

                GroupBox("调用示例") {
                    VStack(alignment: .leading, spacing: 16) {
                        example(title: "Shell", text: "some-command && notify \"执行完成\"")
                        Divider()
                        example(title: "命令结束提醒", text: "notify run pnpm build")
                        Divider()
                        example(title: "Claude Code", text: "claude mcp add bark --transport http \(model.endpoint("mcp/\(model.credentials.deviceKey)"))")
                        Divider()
                        example(title: "curl", text: curlExample)
                    }
                    .padding(8)
                }
            }
            .padding(28)
        }
        .navigationTitle("开发者接入")
    }

    private func endpointCard(title: String, description: String, value: String) -> some View {
        GroupBox {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.headline)
                    Text(description).font(.caption).foregroundStyle(.secondary)
                    Text(value).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                }
                Spacer()
                Button("复制") { model.copy(value) }
            }
            .padding(8)
        }
    }

    private func example(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack { Text(title).font(.headline); Spacer(); Button("复制") { model.copy(text) } }
            Text(text)
                .font(.system(.callout, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var curlExample: String {
        """
        curl -X POST "\(model.endpoint("push"))" \\
          -H "Content-Type: application/json" \\
          -d '{"device_key":"\(model.credentials.deviceKey)","title":"测试","body":"你好"}'
        """
    }
}
