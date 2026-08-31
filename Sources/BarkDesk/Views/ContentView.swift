import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(SidebarItem.allCases, selection: $model.selection) { item in
                SidebarRow(item: item, selected: model.selection == item)
                    .tag(item)
            }
            .listStyle(.sidebar)
            .navigationTitle("BarkDesk")
            .navigationSplitViewColumnWidth(min: 205, ideal: 222, max: 250)
            .safeAreaInset(edge: .bottom) {
                SidebarConnectionCard()
                    .environmentObject(model)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
            }
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .bottom) {
                    if let banner = model.banner {
                        BannerView(banner: banner)
                            .padding(18)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .task {
                                try? await Task.sleep(for: .seconds(3))
                                if model.banner == banner { withAnimation { model.banner = nil } }
                            }
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: model.banner)
        }
        .navigationSplitViewStyle(.balanced)
        .tint(.barkRed)
        .sheet(isPresented: $model.isOnboardingPresented) {
            OnboardingView().environmentObject(model).tint(.barkRed)
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch model.selection {
        case .notifications: NotificationsView()
        case .compose: ComposeView()
        case .integrations: IntegrationsView()
        case .settings: SettingsView()
        }
    }
}

private struct SidebarRow: View {
    let item: SidebarItem
    let selected: Bool

    var body: some View {
        Label {
            Text(item.title).fontWeight(selected ? .semibold : .regular)
        } icon: {
            Image(systemName: item.icon)
                .symbolVariant(selected ? .fill : .none)
                .foregroundStyle(selected ? Color.barkRed : Color.secondary)
        }
        .padding(.vertical, 5)
    }
}

private struct SidebarConnectionCard: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Button {
            model.selection = .settings
        } label: {
            HStack(spacing: 10) {
                Circle()
                    .fill(model.configurationInputIsValid ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.configurationInputIsValid ? "Bark 已连接" : "需要完成设置")
                        .font(.caption.weight(.semibold))
                    Text(serverName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(11)
            .contentShape(Rectangle())
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var serverName: String {
        guard let host = URL(string: model.configuration.serverURL)?.host else { return "填写 Server 与 Device Key" }
        return host
    }
}

private struct BannerView: View {
    let banner: Banner

    var body: some View {
        Label(
            banner.message,
            systemImage: banner.style == .success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
        )
        .font(.callout.weight(.medium))
        .foregroundStyle(banner.style == .success ? .green : .red)
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .shadow(color: .black.opacity(0.14), radius: 12, y: 5)
    }
}
