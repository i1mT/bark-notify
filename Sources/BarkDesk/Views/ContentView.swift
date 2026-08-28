import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $model.selection) { item in
                Label(item.rawValue, systemImage: item.icon)
                    .tag(item)
            }
            .navigationTitle("BarkDesk")
            .navigationSplitViewColumnWidth(min: 180, ideal: 205)
        } detail: {
            Group {
                switch model.selection {
                case .notifications: NotificationsView()
                case .compose: ComposeView()
                case .integrations: IntegrationsView()
                case .settings: SettingsView()
                }
            }
            .overlay(alignment: .bottom) {
                if let banner = model.banner {
                    BannerView(banner: banner)
                        .padding()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .task {
                            try? await Task.sleep(for: .seconds(3))
                            if model.banner == banner { withAnimation { model.banner = nil } }
                        }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: model.banner)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if model.cliInstallationStatus == .missing {
                CLIInstallPrompt()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: model.cliInstallationStatus)
    }
}

private struct CLIInstallPrompt: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "terminal.fill")
                .font(.title3)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("Install the notify command").fontWeight(.semibold)
                Text("Send Bark notifications from any terminal with a short command.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Install") { Task { await model.installCLI() } }
                .buttonStyle(.borderedProminent)
                .disabled(model.isWorking)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }
}

private struct BannerView: View {
    let banner: Banner

    var body: some View {
        Label(
            banner.message,
            systemImage: banner.style == .success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
        )
        .foregroundStyle(banner.style == .success ? .green : .red)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.regularMaterial, in: Capsule())
        .shadow(radius: 8, y: 3)
    }
}
