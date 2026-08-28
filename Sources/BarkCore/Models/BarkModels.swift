import Foundation

public enum BarkLevel: String, Codable, CaseIterable, Sendable {
    case active
    case timeSensitive
    case passive
    case critical

    public var displayName: String {
        switch self {
        case .active: "普通提醒"
        case .timeSensitive: "时效提醒"
        case .passive: "静默提醒"
        case .critical: "重要警告"
        }
    }
}

public struct BarkPushRequest: Codable, Equatable, Sendable {
    public var deviceKey: String
    public var title: String?
    public var subtitle: String?
    public var body: String
    public var markdown: String?
    public var level: BarkLevel?
    public var volume: Int?
    public var badge: Int?
    public var call: String?
    public var autoCopy: String?
    public var copy: String?
    public var sound: String?
    public var icon: String?
    public var image: String?
    public var group: String?
    public var isArchive: String?
    public var ttl: Int?
    public var url: String?
    public var action: String?
    public var id: String?

    public init(
        deviceKey: String,
        title: String? = nil,
        subtitle: String? = nil,
        body: String,
        markdown: String? = nil,
        level: BarkLevel? = nil,
        volume: Int? = nil,
        badge: Int? = nil,
        call: String? = nil,
        autoCopy: String? = nil,
        copy: String? = nil,
        sound: String? = nil,
        icon: String? = nil,
        image: String? = nil,
        group: String? = nil,
        isArchive: String? = nil,
        ttl: Int? = nil,
        url: String? = nil,
        action: String? = nil,
        id: String? = nil
    ) {
        self.deviceKey = deviceKey
        self.title = title
        self.subtitle = subtitle
        self.body = body
        self.markdown = markdown
        self.level = level
        self.volume = volume
        self.badge = badge
        self.call = call
        self.autoCopy = autoCopy
        self.copy = copy
        self.sound = sound
        self.icon = icon
        self.image = image
        self.group = group
        self.isArchive = isArchive
        self.ttl = ttl
        self.url = url
        self.action = action
        self.id = id
    }

    enum CodingKeys: String, CodingKey {
        case deviceKey = "device_key"
        case title, subtitle, body, markdown, level, volume, badge, call
        case autoCopy, copy, sound, icon, image, group, ttl, url, action, id
        case isArchive
    }
}

public struct BarkPushResponse: Codable, Sendable {
    public let code: Int?
    public let message: String?
    public let timestamp: Int?

    public init(code: Int?, message: String?, timestamp: Int?) {
        self.code = code
        self.message = message
        self.timestamp = timestamp
    }
}

public struct BarkEndpointResponse: Sendable {
    public let statusCode: Int
    public let fields: [String: String]

    public init(statusCode: Int, fields: [String: String]) {
        self.statusCode = statusCode
        self.fields = fields
    }
}
