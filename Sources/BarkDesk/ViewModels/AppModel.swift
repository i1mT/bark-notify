import AppKit
import BarkCore
import Foundation

enum SidebarItem: String, CaseIterable, Identifiable {
    case notifications
    case compose
    case integrations
    case settings

    var id: String { rawValue }
    var title: String {
        switch self {
        case .notifications: "通知记录"
        case .compose: "发送通知"
        case .integrations: "开发者接入"
        case .settings: "设置"
        }
    }
    var icon: String {
        switch self {
        case .notifications: "clock"
        case .compose: "square.and.pencil"
        case .integrations: "terminal"
        case .settings: "gearshape"
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var selection = SidebarItem.notifications
    @Published var records: [NotificationRecord] = []
    @Published var selectedRecordID: UUID?
    @Published var searchText = ""
    @Published var draft = ComposeDraft()
    @Published var configuration = AppConfiguration()
    @Published var credentials = BarkCredentials()
    @Published var isWorking = false
    @Published var banner: Banner?
    @Published var connectionResults: [ConnectionResult] = []
    @Published var cliInstallationStatus = CLIInstallationStatus.checking
    @Published var isOnboardingPresented = false
    @Published var connectionTestPassed = false

    private let configurationStore = ConfigurationStore()
    private let cliInstaller = CLIInstaller()
    private var history: HistoryStore?
    private var initialized = false

    var selectedRecord: NotificationRecord? {
        records.first { $0.id == selectedRecordID }
    }

    func start() async {
        guard !initialized else { return }
        initialized = true
        do {
            let loaded = try configurationStore.load()
            configuration = loaded.settings
            credentials = loaded.credentials
            draft.applyDefaults(configuration)
            isOnboardingPresented = !configurationInputIsValid
            history = try HistoryStore()
            await refreshHistory()
            await checkCLIInstallation()
        } catch {
            isOnboardingPresented = true
            showError(error)
            await checkCLIInstallation()
        }
    }

    var cliInstallDirectoryIsInPath: Bool { cliInstaller.installDirectoryIsInPath }

    var configurationInputIsValid: Bool {
        (try? ResolvedConfiguration(settings: configuration, credentials: credentials).validated()) != nil
    }

    var serverURLIssue: String? {
        if configuration.serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "请输入 Bark Server 地址"
        }
        guard let url = URL(string: configuration.serverURL),
              let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              url.host != nil else { return "地址需要以 http:// 或 https:// 开头" }
        return nil
    }

    var deviceKeyIssue: String? {
        credentials.deviceKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "请输入 iPhone Bark 中显示的 Device Key" : nil
    }

    var authenticationIssue: String? {
        guard configuration.authenticationMode == .basic else { return nil }
        return credentials.username.isEmpty || credentials.password.isEmpty
            ? "请同时填写 Basic Auth 用户名和密码" : nil
    }

    func checkCLIInstallation() async {
        cliInstallationStatus = .checking
        let installer = cliInstaller
        cliInstallationStatus = await Task.detached { installer.detect() }.value
    }

    func installCLI() async {
        isWorking = true
        defer { isWorking = false }
        let installer = cliInstaller
        do {
            let url = try await Task.detached { try installer.install() }.value
            cliInstallationStatus = .installed(url)
            banner = Banner(style: .success, message: "notify 已经安装到 \(url.path)")
        } catch {
            cliInstallationStatus = .unavailable(error.localizedDescription)
            showError(error)
        }
    }

    func refreshHistory() async {
        guard let history else { return }
        do {
            records = try await history.records(search: searchText.nilIfEmpty)
            if selectedRecordID == nil { selectedRecordID = records.first?.id }
        } catch { showError(error) }
    }

    @discardableResult
    func saveConfiguration() -> Bool {
        guard configurationInputIsValid else {
            banner = Banner(style: .error, message: serverURLIssue ?? deviceKeyIssue ?? "请检查认证信息")
            return false
        }
        do {
            configuration.serverURL = configuration.serverURL
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            credentials.deviceKey = credentials.deviceKey.trimmingCharacters(in: .whitespacesAndNewlines)
            try configurationStore.save(
                ResolvedConfiguration(settings: configuration, credentials: credentials)
            )
            banner = Banner(style: .success, message: "设置已经保存")
            return true
        } catch {
            showError(error)
            return false
        }
    }

    func finishOnboarding() {
        guard saveConfiguration() else { return }
        isOnboardingPresented = false
        selection = .compose
        draft.applyDefaults(configuration)
    }

    func sendDraft() async {
        guard draft.isValid else {
            banner = Banner(style: .error, message: draft.validationHint ?? "请检查通知内容")
            return
        }
        await send(request: draft.request(deviceKey: credentials.deviceKey), source: .gui)
        if banner?.style == .success {
            var next = ComposeDraft()
            next.applyDefaults(configuration)
            draft = next
        }
    }

    func resend(_ record: NotificationRecord) async {
        let request = BarkPushRequest(
            deviceKey: credentials.deviceKey,
            title: record.title, subtitle: record.subtitle, body: record.body,
            level: record.level, sound: record.sound, icon: record.icon,
            image: record.image, group: record.group,
            isArchive: configuration.archiveMessages ? "1" : nil, url: record.url
        )
        await send(request: request, source: .gui)
    }

    func delete(_ record: NotificationRecord) async {
        guard let history else { return }
        do {
            try await history.delete(id: record.id)
            selectedRecordID = nil
            await refreshHistory()
        } catch { showError(error) }
    }

    func testConnection() async {
        isWorking = true
        connectionResults = []
        connectionTestPassed = false
        defer { isWorking = false }
        do {
            let resolved = try resolvedConfiguration()
            let client = BarkClient(configuration: resolved)
            do {
                try await client.ping()
                connectionTestPassed = true
                connectionResults.append(.init(success: true, label: "服务器连接成功"))
            } catch {
                connectionResults.append(.init(success: false, label: error.localizedDescription))
                return
            }
            do {
                let info = try await client.info()
                let version = info.fields["version"].map { " (\($0))" } ?? ""
                connectionResults.append(.init(success: true, label: "服务器信息可用\(version)"))
            } catch {
                connectionResults.append(.init(success: false, label: "无法读取服务器信息（可能是版本差异）"))
            }
            do {
                _ = try await client.health()
                connectionResults.append(.init(success: true, label: "健康检查通过"))
            } catch {
                connectionResults.append(.init(success: false, label: "服务器未提供健康检查接口"))
            }
            do {
                _ = try await client.checkDevice(deviceKey: credentials.deviceKey)
                connectionResults.append(.init(success: true, label: "Device Key 已经注册"))
            } catch {
                connectionResults.append(.init(success: false, label: "无法验证 Device Key（仍可发送测试通知）"))
            }
        } catch { showError(error) }
    }

    func sendTest() async {
        let request = BarkPushRequest(
            deviceKey: credentials.deviceKey,
            title: "BarkDesk", body: "连接成功，可以开始发送通知了",
            level: configuration.defaultLevel,
            group: configuration.defaultGroup.nilIfEmpty,
            isArchive: configuration.archiveMessages ? "1" : nil
        )
        await send(request: request, source: .gui)
    }

    func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        banner = Banner(style: .success, message: "已经复制")
    }

    func endpoint(_ suffix: String) -> String {
        let base = configuration.serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return "\(base)/\(suffix)"
    }

    private func send(request: BarkPushRequest, source: NotificationSource) async {
        isWorking = true
        defer { isWorking = false }
        do {
            let resolved = try resolvedConfiguration()
            let activeHistory = try history ?? HistoryStore()
            history = activeHistory
            let service = NotificationService(client: BarkClient(configuration: resolved), history: activeHistory)
            try await service.send(request, source: source)
            banner = Banner(style: .success, message: "通知已经发送")
            await refreshHistory()
        } catch { showError(error) }
    }

    private func resolvedConfiguration() throws -> ResolvedConfiguration {
        try ResolvedConfiguration(settings: configuration, credentials: credentials).validated()
    }

    private func showError(_ error: Error) {
        banner = Banner(style: .error, message: error.localizedDescription)
    }
}

struct ConnectionResult: Identifiable {
    let id = UUID()
    let success: Bool
    let label: String
}

struct Banner: Equatable {
    enum Style { case success, error }
    let style: Style
    let message: String
}
