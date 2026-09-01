import Foundation

enum BarkRuntimeEnvironment {
    #if DEBUG
    static let storageDirectoryName = "BarkDesk Dev"
    static let keychainService = "app.barkdesk.dev"
    #else
    static let storageDirectoryName = "BarkDesk"
    static let keychainService = "app.barkdesk.shared"
    #endif
}

public enum SharedStorage {
    public static var rootDirectory: URL {
        if let override = ProcessInfo.processInfo.environment["BARKDESK_HOME"], !override.isEmpty {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent(BarkRuntimeEnvironment.storageDirectoryName, isDirectory: true)
    }

    public static var databaseURL: URL {
        rootDirectory.appendingPathComponent("barkdesk.sqlite")
    }

    public static var configurationURL: URL {
        rootDirectory.appendingPathComponent("configuration.json")
    }

    public static func prepareDirectory() throws {
        try FileManager.default.createDirectory(
            at: rootDirectory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
    }
}
