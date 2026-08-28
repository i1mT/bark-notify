import Foundation

public enum NotificationSource: String, Codable, Sendable {
    case gui
    case cli
    case command
}

public enum DeliveryStatus: String, Codable, Sendable {
    case success
    case failed
}

public struct NotificationMetadata: Codable, Equatable, Sendable {
    public var command: String?
    public var cwd: String?
    public var hostname: String?
    public var exitCode: Int?
    public var duration: TimeInterval?

    public init(
        command: String? = nil,
        cwd: String? = nil,
        hostname: String? = nil,
        exitCode: Int? = nil,
        duration: TimeInterval? = nil
    ) {
        self.command = command
        self.cwd = cwd
        self.hostname = hostname
        self.exitCode = exitCode
        self.duration = duration
    }
}

public struct NotificationRecord: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let title: String?
    public let subtitle: String?
    public let body: String
    public let group: String?
    public let level: BarkLevel?
    public let sound: String?
    public let icon: String?
    public let image: String?
    public let url: String?
    public let source: NotificationSource
    public let createdAt: Date
    public let deliveryStatus: DeliveryStatus
    public let httpStatusCode: Int?
    public let errorMessage: String?
    public let metadata: NotificationMetadata?

    public init(
        id: UUID = UUID(), request: BarkPushRequest, source: NotificationSource,
        createdAt: Date = Date(), deliveryStatus: DeliveryStatus,
        httpStatusCode: Int? = nil, errorMessage: String? = nil,
        metadata: NotificationMetadata? = nil
    ) {
        self.id = id
        self.title = request.title
        self.subtitle = request.subtitle
        self.body = request.markdown ?? request.body
        self.group = request.group
        self.level = request.level
        self.sound = request.sound
        self.icon = request.icon
        self.image = request.image
        self.url = request.url
        self.source = source
        self.createdAt = createdAt
        self.deliveryStatus = deliveryStatus
        self.httpStatusCode = httpStatusCode
        self.errorMessage = errorMessage
        self.metadata = metadata
    }
}
