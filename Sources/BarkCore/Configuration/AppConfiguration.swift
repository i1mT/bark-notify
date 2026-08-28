import Foundation

public enum AuthenticationMode: String, Codable, CaseIterable, Sendable {
    case none
    case basic
}

public struct AppConfiguration: Codable, Equatable, Sendable {
    public var serverURL: String
    public var authenticationMode: AuthenticationMode
    public var defaultGroup: String
    public var defaultLevel: BarkLevel
    public var defaultSound: String
    public var archiveMessages: Bool

    public init(
        serverURL: String = "",
        authenticationMode: AuthenticationMode = .none,
        defaultGroup: String = "terminal",
        defaultLevel: BarkLevel = .active,
        defaultSound: String = "",
        archiveMessages: Bool = true
    ) {
        self.serverURL = serverURL
        self.authenticationMode = authenticationMode
        self.defaultGroup = defaultGroup
        self.defaultLevel = defaultLevel
        self.defaultSound = defaultSound
        self.archiveMessages = archiveMessages
    }
}

public struct BarkCredentials: Equatable, Sendable {
    public var deviceKey: String
    public var username: String
    public var password: String

    public init(deviceKey: String = "", username: String = "", password: String = "") {
        self.deviceKey = deviceKey
        self.username = username
        self.password = password
    }
}

public struct ResolvedConfiguration: Sendable {
    public let settings: AppConfiguration
    public let credentials: BarkCredentials

    public init(settings: AppConfiguration, credentials: BarkCredentials) {
        self.settings = settings
        self.credentials = credentials
    }

    public func validated() throws -> ResolvedConfiguration {
        guard let url = URL(string: settings.serverURL),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil else {
            throw ConfigurationError.invalidServerURL
        }
        guard !credentials.deviceKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ConfigurationError.missingDeviceKey
        }
        if settings.authenticationMode == .basic,
           credentials.username.isEmpty || credentials.password.isEmpty {
            throw ConfigurationError.missingBasicAuth
        }
        return self
    }
}

public enum ConfigurationError: LocalizedError {
    case invalidServerURL
    case missingDeviceKey
    case missingBasicAuth

    public var errorDescription: String? {
        switch self {
        case .invalidServerURL: "Please configure a valid Bark Server URL."
        case .missingDeviceKey: "Please configure a Device Key."
        case .missingBasicAuth: "Basic Auth requires both username and password."
        }
    }
}
