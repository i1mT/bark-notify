import SwiftUI

struct IntegrationsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Use your Bark configuration from scripts and developer tools.")
                    .foregroundStyle(.secondary)
                endpointCard(
                    title: "Bark Push URL",
                    description: "Compatible URL for quick GET requests",
                    value: model.endpoint(model.credentials.deviceKey)
                )
                endpointCard(
                    title: "REST API",
                    description: "Recommended Bark API V2 endpoint",
                    value: model.endpoint("push")
                )
                endpointCard(
                    title: "MCP",
                    description: "Use Bark Server's built-in MCP endpoint with AI tools",
                    value: model.endpoint("mcp/\(model.credentials.deviceKey)")
                )

                GroupBox("Examples") {
                    VStack(alignment: .leading, spacing: 16) {
                        example(title: "Shell", text: "some-command && notify \"Done\"")
                        Divider()
                        example(title: "Command wrapper", text: "notify run pnpm build")
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
        .navigationTitle("Integrations")
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
                Button("Copy") { model.copy(value) }
            }
            .padding(8)
        }
    }

    private func example(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack { Text(title).font(.headline); Spacer(); Button("Copy") { model.copy(text) } }
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
          -d '{"device_key":"\(model.credentials.deviceKey)","title":"Hello","body":"World"}'
        """
    }
}
