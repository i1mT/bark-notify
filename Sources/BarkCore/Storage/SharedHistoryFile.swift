import Darwin
import Foundation

struct SharedHistoryFile {
    let url: URL

    func records() throws -> [NotificationRecord] {
        try lines().compactMap { SharedHistoryRecord.decode(line: $0) }
    }

    func append(_ record: NotificationRecord) throws {
        try withLock {
            let currentLines = try lines()
            guard !currentLines.contains(where: { SharedHistoryRecord.decode(line: $0)?.id == record.id }) else { return }
            try appendLines([try SharedHistoryRecord.encode(record)])
        }
    }

    func merge(_ records: [NotificationRecord]) throws {
        guard !records.isEmpty else { return }
        try withLock {
            let currentLines = try lines()
            let existingIDs = Set(currentLines.compactMap { SharedHistoryRecord.decode(line: $0)?.id })
            let additions = try records.filter { !existingIDs.contains($0.id) }.map(SharedHistoryRecord.encode)
            try appendLines(additions)
        }
    }

    func remove(id: UUID) throws {
        try withLock {
            let retained = try lines().filter { SharedHistoryRecord.decode(line: $0)?.id != id }
            try write(retained.isEmpty ? "" : retained.joined(separator: "\n") + "\n")
        }
    }

    private func lines() throws -> [String] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try String(contentsOf: url, encoding: .utf8).split(separator: "\n").map(String.init)
    }

    private func prepareDirectory() throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
    }

    private func write(_ content: String) throws {
        try Data(content.utf8).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private func appendLines(_ lines: [String]) throws {
        guard !lines.isEmpty else { return }
        try prepareDirectory()
        let descriptor = Darwin.open(url.path, O_WRONLY | O_APPEND | O_CREAT, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }
        defer { Darwin.close(descriptor) }
        for line in lines {
            let data = Data((line + "\n").utf8)
            let written = data.withUnsafeBytes { Darwin.write(descriptor, $0.baseAddress, $0.count) }
            guard written == data.count else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private func withLock<T>(_ operation: () throws -> T) throws -> T {
        try prepareDirectory()
        let lockURL = URL(fileURLWithPath: url.path + ".lock")
        var descriptor: Int32 = -1
        for attempt in 0...80 {
            descriptor = Darwin.open(lockURL.path, O_WRONLY | O_CREAT | O_EXCL, S_IRUSR | S_IWUSR)
            if descriptor >= 0 { break }
            guard errno == EEXIST, attempt < 80 else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }
            if let attributes = try? FileManager.default.attributesOfItem(atPath: lockURL.path),
               let date = attributes[.modificationDate] as? Date,
               date.timeIntervalSinceNow < -30 {
                try? FileManager.default.removeItem(at: lockURL)
            }
            usleep(25_000)
        }
        defer {
            Darwin.close(descriptor)
            try? FileManager.default.removeItem(at: lockURL)
        }
        return try operation()
    }
}

private struct SharedHistoryRecord: Codable {
    let id: String?
    let createdAt: String
    let status: String
    let source: String
    let title: String?
    let subtitle: String?
    let body: String
    let level: String?
    let sound: String?
    let icon: String?
    let image: String?
    let group: String?
    let url: String?
    let httpStatus: Int?
    let error: String?
    let command: String?
    let cwd: String?
    let hostname: String?
    let exitCode: Int?
    let durationSeconds: Double?

    var resolvedID: UUID? { id.flatMap(UUID.init(uuidString:)) }

    static func decode(line: String) -> NotificationRecord? {
        guard let data = line.data(using: .utf8),
              let value = try? JSONDecoder().decode(Self.self, from: data),
              let date = parseDate(value.createdAt) else { return nil }
        let request = BarkPushRequest(
            deviceKey: "", title: value.title, subtitle: value.subtitle, body: value.body,
            level: value.level.flatMap(BarkLevel.init(rawValue:)), sound: value.sound,
            icon: value.icon, image: value.image, group: value.group, url: value.url
        )
        let metadata = NotificationMetadata(
            command: value.command, cwd: value.cwd, hostname: value.hostname,
            exitCode: value.exitCode, duration: value.durationSeconds
        )
        return NotificationRecord(
            id: value.resolvedID ?? deterministicID(line), request: request,
            source: source(value.source), createdAt: date,
            deliveryStatus: value.status == "failure" ? .failed : .success,
            httpStatusCode: value.httpStatus, errorMessage: value.error,
            metadata: [value.command, value.cwd, value.hostname].allSatisfy { $0 == nil }
                && value.exitCode == nil && value.durationSeconds == nil ? nil : metadata
        )
    }

    static func encode(_ record: NotificationRecord) throws -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let value = Self(
            id: record.id.uuidString, createdAt: formatter.string(from: record.createdAt),
            status: record.deliveryStatus == .success ? "success" : "failure",
            source: sharedSource(record.source), title: record.title, subtitle: record.subtitle,
            body: record.body, level: record.level?.rawValue, sound: record.sound,
            icon: record.icon, image: record.image, group: record.group, url: record.url,
            httpStatus: record.httpStatusCode, error: record.errorMessage,
            command: record.metadata?.command, cwd: record.metadata?.cwd,
            hostname: record.metadata?.hostname, exitCode: record.metadata?.exitCode,
            durationSeconds: record.metadata?.duration
        )
        return String(decoding: try JSONEncoder().encode(value), as: UTF8.self)
    }

    private static func parseDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }

    private static func source(_ value: String) -> NotificationSource {
        switch value {
        case "gui": .gui
        case "run": .command
        case "agent-hook": .agentHook
        default: .cli
        }
    }

    private static func sharedSource(_ value: NotificationSource) -> String {
        switch value {
        case .gui: "gui"
        case .cli: "send"
        case .command: "run"
        case .agentHook: "agent-hook"
        }
    }

    private static func deterministicID(_ value: String) -> UUID {
        var first: UInt64 = 0xcbf29ce484222325
        var second: UInt64 = 0x84222325cbf29ce4
        for byte in value.utf8 {
            first = (first ^ UInt64(byte)) &* 0x100000001b3
            second = (second ^ UInt64(byte &+ 31)) &* 0x100000001b3
        }
        var bytes = withUnsafeBytes(of: first.bigEndian, Array.init) + withUnsafeBytes(of: second.bigEndian, Array.init)
        bytes[6] = (bytes[6] & 0x0f) | 0x50
        bytes[8] = (bytes[8] & 0x3f) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
