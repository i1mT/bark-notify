import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: AppModel
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            AppSidebar()
                .environmentObject(model)
                .navigationSplitViewColumnWidth(min: 200, ideal: 224, max: 242)
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
                .animation(.easeInOut(duration: 0.18), value: model.banner)
        }
        .navigationSplitViewStyle(.balanced)
        .tint(.barkAccent)
        .controlSize(.large)
        .sheet(isPresented: $model.isOnboardingPresented) {
            OnboardingView().environmentObject(model).tint(.barkAccent)
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

private struct AppSidebar: View {
    @EnvironmentObject private var model: AppModel

    private let mainItems: [SidebarItem] = [.notifications, .compose, .integrations]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            brand
            VStack(spacing: 6) {
                ForEach(mainItems) { item in
                    SidebarNavigationButton(
                        item: item,
                        selected: model.selection == item,
                        count: item == .notifications ? model.records.count : nil
                    ) {
                        withAnimation(.easeOut(duration: 0.15)) { model.selection = item }
                    }
                }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            Spacer(minLength: 24)
            ConnectionPanel()
                .environmentObject(model)
                .padding(12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .background(Color.barkSidebar.ignoresSafeArea())
    }

    private var brand: some View {
        HStack(spacing: 11) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.barkAccent)
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.barkAccentInk)
                }
            Text("BarkDesk")
                .font(.system(size: 19, weight: .bold))
                .tracking(-0.35)
                .foregroundStyle(Color.barkInk)
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .padding(.bottom, 25)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SidebarNavigationButton: View {
    let item: SidebarItem
    let selected: Bool
    let count: Int?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: item.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .symbolVariant(selected ? .fill : .none)
                    .foregroundStyle(selected ? Color.barkAccent : Color.secondary)
                    .frame(width: 20)
                Text(item.title)
                    .font(.callout.weight(selected ? .semibold : .medium))
                    .foregroundStyle(Color.barkInk)
                Spacer(minLength: 6)
                if let count {
                    Text(count, format: .number)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 13)
            .frame(height: 43)
            .frame(maxWidth: .infinity)
            .background(selected ? Color.barkSurface : .clear, in: RoundedRectangle(cornerRadius: 10))
            .overlay(alignment: .leading) {
                if selected {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.barkAccent)
                        .frame(width: 3, height: 21)
                        .padding(.leading, 1)
                }
            }
            .shadow(color: selected ? Color.barkInk.opacity(0.05) : .clear, radius: 8, y: 3)
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

private struct ConnectionPanel: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Button {
            model.selection = .settings
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Circle().fill(statusColor).frame(width: 8, height: 8)
                    Text(statusTitle).font(.system(size: 13, weight: .semibold))
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(serverName)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.barkInk)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(deviceLabel)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Text("连接与设置")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.barkAccent)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.barkSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                if model.selection == .settings {
                    RoundedRectangle(cornerRadius: 14).stroke(Color.barkAccent, lineWidth: 1.5)
                }
            }
            .shadow(color: Color.barkInk.opacity(0.045), radius: 12, y: 5)
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .contextMenu {
            Button("检查连接") {
                guard model.saveConfiguration() else { return }
                Task { await model.testConnection() }
            }
            Button("发送测试通知") {
                guard model.saveConfiguration() else { return }
                Task { await model.sendTest() }
            }
            .disabled(!model.configurationInputIsValid)
        }
    }

    private var statusTitle: String {
        if model.connectionTestPassed { return "Bark 已连接" }
        return model.configurationInputIsValid ? "Bark 已配置" : "需要完成设置"
    }

    private var statusColor: Color {
        if model.connectionTestPassed { return .green }
        return model.configurationInputIsValid ? .barkAccent : .orange
    }

    private var serverName: String {
        URL(string: model.configuration.serverURL)?.host ?? "填写 Bark Server"
    }

    private var deviceLabel: String {
        let key = model.credentials.deviceKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return "Device Key 未填写" }
        return "Device •••• \(key.suffix(4))"
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
        .foregroundStyle(banner.style == .success ? Color.green : Color.orange)
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
        .background(Color.barkSurface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: Color.barkInk.opacity(0.1), radius: 14, y: 6)
    }
}
