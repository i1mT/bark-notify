import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(SidebarItem.allCases, selection: $model.selection) { item in
                Label(item.title, systemImage: item.icon)
                    .tag(item)
            }
            .listStyle(.sidebar)
            .padding(.horizontal, 10)
            .navigationTitle("BarkDesk")
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
            VStack(spacing: 0) {
                if model.cliInstallationStatus == .missing { CLIInstallPrompt() }
                Group {
                    switch model.selection {
                    case .notifications: NotificationsView()
                    case .compose: ComposeView()
                    case .integrations: IntegrationsView()
                    case .settings: SettingsView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $model.isOnboardingPresented) {
            OnboardingView().environmentObject(model)
        }
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
                Text("安装 notify 命令").fontWeight(.semibold)
                Text("安装后可以在任意终端中使用简短命令发送通知。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("安装") { Task { await model.installCLI() } }
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
