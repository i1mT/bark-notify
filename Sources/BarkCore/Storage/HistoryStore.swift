import CSQLite
import Foundation

public actor HistoryStore {
    nonisolated(unsafe) private var database: OpaquePointer?
    private let databaseURL: URL
    private let sharedHistory: SharedHistoryFile?

    public init(
        databaseURL: URL = SharedStorage.databaseURL,
        sharedHistoryURL: URL? = SharedStorage.cliHistoryURL
    ) throws {
        self.databaseURL = databaseURL
        self.sharedHistory = sharedHistoryURL.map(SharedHistoryFile.init(url:))
        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        var openedDatabase: OpaquePointer?
        guard sqlite3_open_v2(
            databaseURL.path,
            &openedDatabase,
            SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX,
            nil
        ) == SQLITE_OK else {
            let message = openedDatabase.flatMap(sqlite3_errmsg).map(String.init(cString:)) ?? "Unknown SQLite error"
            sqlite3_close(openedDatabase)
            throw HistoryStoreError.open(message: message)
        }
        for sql in ["PRAGMA journal_mode=WAL;", "PRAGMA busy_timeout=5000;", Self.schema] {
            guard sqlite3_exec(openedDatabase, sql, nil, nil, nil) == SQLITE_OK else {
                let message = openedDatabase.flatMap(sqlite3_errmsg).map(String.init(cString:)) ?? "Unknown SQLite error"
                sqlite3_close(openedDatabase)
                throw HistoryStoreError.query(message: message)
            }
        }
        database = openedDatabase
    }

    deinit {
        sqlite3_close(database)
    }

    public func insert(_ record: NotificationRecord) throws {
        try insertIntoDatabase(record)
        try sharedHistory?.append(record)
    }

    private func insertIntoDatabase(_ record: NotificationRecord, ignoreExisting: Bool = false) throws {
        let operation = ignoreExisting ? "INSERT OR IGNORE" : "INSERT"
        let sql = """
        \(operation) INTO notifications (
          id, title, subtitle, body, group_name, level, sound, icon, image, url,
          source, created_at, delivery_status, http_status_code, error_message, metadata
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw HistoryStoreError.query(message: databaseMessage)
        }
        defer { sqlite3_finalize(statement) }
        bind(record.id.uuidString, at: 1, to: statement)
        bind(record.title, at: 2, to: statement)
        bind(record.subtitle, at: 3, to: statement)
        bind(record.body, at: 4, to: statement)
        bind(record.group, at: 5, to: statement)
        bind(record.level?.rawValue, at: 6, to: statement)
        bind(record.sound, at: 7, to: statement)
        bind(record.icon, at: 8, to: statement)
        bind(record.image, at: 9, to: statement)
        bind(record.url, at: 10, to: statement)
        bind(record.source.rawValue, at: 11, to: statement)
        sqlite3_bind_double(statement, 12, record.createdAt.timeIntervalSince1970)
        bind(record.deliveryStatus.rawValue, at: 13, to: statement)
        if let code = record.httpStatusCode { sqlite3_bind_int(statement, 14, Int32(code)) }
        else { sqlite3_bind_null(statement, 14) }
        bind(record.errorMessage, at: 15, to: statement)
        let metadata = try record.metadata.map { String(decoding: try JSONEncoder().encode($0), as: UTF8.self) }
        bind(metadata, at: 16, to: statement)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw HistoryStoreError.query(message: databaseMessage)
        }
    }

    public func records(search: String? = nil, limit: Int = 500) throws -> [NotificationRecord] {
        try synchronizeSharedHistory()
        return try queryRecords(search: search, limit: limit)
    }

    private func queryRecords(search: String? = nil, limit: Int = 500) throws -> [NotificationRecord] {
        let hasSearch = !(search?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let predicate = hasSearch
            ? "WHERE title LIKE ? ESCAPE '\\' OR subtitle LIKE ? ESCAPE '\\' OR body LIKE ? ESCAPE '\\' OR group_name LIKE ? ESCAPE '\\'"
            : ""
        let sql = "SELECT * FROM notifications \(predicate) ORDER BY created_at DESC LIMIT ?;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw HistoryStoreError.query(message: databaseMessage)
        }
        defer { sqlite3_finalize(statement) }
        var index: Int32 = 1
        if hasSearch {
            let escaped = search!.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "%", with: "\\%")
                .replacingOccurrences(of: "_", with: "\\_")
            for _ in 0..<4 {
                bind("%\(escaped)%", at: index, to: statement)
                index += 1
            }
        }
        sqlite3_bind_int(statement, index, Int32(max(1, min(limit, 10_000))))
        var results: [NotificationRecord] = []
        var stepResult = sqlite3_step(statement)
        while stepResult == SQLITE_ROW {
            if let record = decode(statement) { results.append(record) }
            stepResult = sqlite3_step(statement)
        }
        guard stepResult == SQLITE_DONE else {
            throw HistoryStoreError.query(message: databaseMessage)
        }
        return results
    }

    public func delete(id: UUID) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "DELETE FROM notifications WHERE id = ?;", -1, &statement, nil) == SQLITE_OK else {
            throw HistoryStoreError.query(message: databaseMessage)
        }
        defer { sqlite3_finalize(statement) }
        bind(id.uuidString, at: 1, to: statement)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw HistoryStoreError.query(message: databaseMessage)
        }
        try sharedHistory?.remove(id: id)
    }

    private func synchronizeSharedHistory() throws {
        guard let sharedHistory else { return }
        if try metadataValue(for: "shared_history_exported") != "1" {
            try sharedHistory.merge(try queryRecords(limit: 10_000))
            try setMetadataValue("1", for: "shared_history_exported")
        }
        for record in try sharedHistory.records() {
            try insertIntoDatabase(record, ignoreExisting: true)
        }
    }

    private func metadataValue(for key: String) throws -> String? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, "SELECT value FROM history_metadata WHERE key = ?;", -1, &statement, nil) == SQLITE_OK else {
            throw HistoryStoreError.query(message: databaseMessage)
        }
        defer { sqlite3_finalize(statement) }
        bind(key, at: 1, to: statement)
        return sqlite3_step(statement) == SQLITE_ROW ? text(statement, 0) : nil
    }

    private func setMetadataValue(_ value: String, for key: String) throws {
        var statement: OpaquePointer?
        let sql = "INSERT OR REPLACE INTO history_metadata (key, value) VALUES (?, ?);"
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw HistoryStoreError.query(message: databaseMessage)
        }
        defer { sqlite3_finalize(statement) }
        bind(key, at: 1, to: statement)
        bind(value, at: 2, to: statement)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw HistoryStoreError.query(message: databaseMessage)
        }
    }

    private func execute(_ sql: String) throws {
        guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
            throw HistoryStoreError.query(message: databaseMessage)
        }
    }

    private func bind(_ value: String?, at index: Int32, to statement: OpaquePointer?) {
        guard let value else { sqlite3_bind_null(statement, index); return }
        sqlite3_bind_text(statement, index, value, -1, Self.sqliteTransient)
    }

    private func text(_ statement: OpaquePointer?, _ index: Int32) -> String? {
        guard let pointer = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: pointer)
    }

    private func decode(_ statement: OpaquePointer?) -> NotificationRecord? {
        guard let idText = text(statement, 0), let id = UUID(uuidString: idText),
              let body = text(statement, 3),
              let sourceText = text(statement, 10), let source = NotificationSource(rawValue: sourceText),
              let statusText = text(statement, 12), let status = DeliveryStatus(rawValue: statusText) else { return nil }
        let request = BarkPushRequest(
            deviceKey: "", title: text(statement, 1), subtitle: text(statement, 2), body: body,
            level: text(statement, 5).flatMap(BarkLevel.init(rawValue:)),
            sound: text(statement, 6), icon: text(statement, 7), image: text(statement, 8),
            group: text(statement, 4), url: text(statement, 9)
        )
        let metadata = text(statement, 15).flatMap { try? JSONDecoder().decode(NotificationMetadata.self, from: Data($0.utf8)) }
        let httpCode = sqlite3_column_type(statement, 13) == SQLITE_NULL ? nil : Int(sqlite3_column_int(statement, 13))
        return NotificationRecord(
            id: id, request: request, source: source,
            createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 11)),
            deliveryStatus: status, httpStatusCode: httpCode,
            errorMessage: text(statement, 14), metadata: metadata
        )
    }

    private var databaseMessage: String {
        database.flatMap(sqlite3_errmsg).map(String.init(cString:)) ?? "Unknown SQLite error"
    }

    private static let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    private static let schema = """
    CREATE TABLE IF NOT EXISTS notifications (
      id TEXT PRIMARY KEY, title TEXT, subtitle TEXT, body TEXT NOT NULL,
      group_name TEXT, level TEXT, sound TEXT, icon TEXT, image TEXT, url TEXT,
      source TEXT NOT NULL, created_at REAL NOT NULL, delivery_status TEXT NOT NULL,
      http_status_code INTEGER, error_message TEXT, metadata TEXT
    );
    CREATE INDEX IF NOT EXISTS notifications_created_at ON notifications(created_at DESC);
    CREATE TABLE IF NOT EXISTS history_metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL);
    """
}

public enum HistoryStoreError: LocalizedError {
    case open(message: String)
    case query(message: String)

    public var errorDescription: String? {
        switch self {
        case .open(let message): "无法打开通知记录数据库：\(message)"
        case .query(let message): "通知记录数据库发生错误：\(message)"
        }
    }
}
