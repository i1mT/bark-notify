import Foundation

public struct ConfigurationStore: Sendable {
    private let fileURL: URL
    private let keychain: KeychainStore

    public init(
        fileURL: URL = SharedStorage.configurationURL,
        keychain: KeychainStore = KeychainStore()
    ) {
        self.fileURL = fileURL
        self.keychain = keychain
    }

    public func load() throws -> ResolvedConfiguration {
        let settings: AppConfiguration
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let data = try Data(contentsOf: fileURL)
            settings = try JSONDecoder().decode(AppConfiguration.self, from: data)
        } else {
            settings = AppConfiguration()
        }
        let credentials = BarkCredentials(
            deviceKey: try keychain.read(account: "device-key"),
            username: try keychain.read(account: "basic-username"),
            password: try keychain.read(account: "basic-password")
        )
        return ResolvedConfiguration(settings: settings, credentials: credentials)
    }

    public func save(_ configuration: ResolvedConfiguration) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(configuration.settings)
        try data.write(to: fileURL, options: [.atomic])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
        try keychain.write(configuration.credentials.deviceKey, account: "device-key")
        try keychain.write(configuration.credentials.username, account: "basic-username")
        try keychain.write(configuration.credentials.password, account: "basic-password")
    }
}
