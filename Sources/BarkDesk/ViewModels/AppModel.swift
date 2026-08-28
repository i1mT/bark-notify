import AppKit
import BarkCore
import Foundation

enum SidebarItem: String, CaseIterable, Identifiable {
    case notifications = "Notifications"
    case compose = "Compose"
    case integrations = "Integrations"
    case settings = "Settings"

    var id: String { rawValue }
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
            history = try HistoryStore()
            await refreshHistory()
            await checkCLIInstallation()
        } catch {
            showError(error)
            await checkCLIInstallation()
        }
    }

    var cliInstallDirectoryIsInPath: Bool { cliInstaller.installDirectoryIsInPath }

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
            banner = Banner(style: .success, message: "notify installed at \(url.path)")
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

    func saveConfiguration() {
        do {
            try configurationStore.save(
                ResolvedConfiguration(settings: configuration, credentials: credentials)
            )
            banner = Banner(style: .success, message: "Settings saved")
        } catch { showError(error) }
    }

    func sendDraft() async {
        guard !draft.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            banner = Banner(style: .error, message: "Message is required")
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
        defer { isWorking = false }
        do {
            let resolved = try resolvedConfiguration()
            let client = BarkClient(configuration: resolved)
            do {
                try await client.ping()
                connectionResults.append(.init(success: true, label: "Server reachable"))
            } catch {
                connectionResults.append(.init(success: false, label: error.localizedDescription))
                return
            }
            do {
                let info = try await client.info()
                let version = info.fields["version"].map { " (\($0))" } ?? ""
                connectionResults.append(.init(success: true, label: "Server info available\(version)"))
            } catch {
                connectionResults.append(.init(success: false, label: "Info unavailable: \(error.localizedDescription)"))
            }
            do {
                _ = try await client.health()
                connectionResults.append(.init(success: true, label: "Health check passed"))
            } catch {
                connectionResults.append(.init(success: false, label: "Health endpoint unavailable"))
            }
            do {
                _ = try await client.checkDevice(deviceKey: credentials.deviceKey)
                connectionResults.append(.init(success: true, label: "Device registered"))
            } catch {
                connectionResults.append(.init(success: false, label: "Device check unavailable"))
            }
        } catch { showError(error) }
    }

    func sendTest() async {
        let request = BarkPushRequest(
            deviceKey: credentials.deviceKey,
            title: "BarkDesk", body: "Connection successful",
            level: configuration.defaultLevel,
            group: configuration.defaultGroup.nilIfEmpty,
            isArchive: configuration.archiveMessages ? "1" : nil
        )
        await send(request: request, source: .gui)
    }

    func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        banner = Banner(style: .success, message: "Copied")
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
            banner = Banner(style: .success, message: "Notification sent")
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
