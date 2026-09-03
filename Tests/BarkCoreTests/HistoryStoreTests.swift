import Foundation
import Testing
@testable import BarkCore

@Test("History persists, searches, and deletes records")
func historyLifecycle() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("history.sqlite")
    let store = try HistoryStore(databaseURL: url, sharedHistoryURL: nil)
    let matching = NotificationRecord(
        request: BarkPushRequest(deviceKey: "key", title: "Build", body: "Deployment completed", group: "release"),
        source: .cli, createdAt: Date(timeIntervalSince1970: 200),
        deliveryStatus: .success, httpStatusCode: 200
    )
    let other = NotificationRecord(
        request: BarkPushRequest(deviceKey: "key", title: "Other", body: "Nothing to see"),
        source: .gui, createdAt: Date(timeIntervalSince1970: 100),
        deliveryStatus: .failed, errorMessage: "Offline"
    )
    try await store.insert(other)
    try await store.insert(matching)

    let all = try await store.records()
    #expect(all.count == 2)
    #expect(all.first?.id == matching.id)
    #expect(all.last?.errorMessage == "Offline")

    let search = try await store.records(search: "release")
    #expect(search.map(\.id) == [matching.id])

    try await store.delete(id: matching.id)
    #expect(try await store.records().map(\.id) == [other.id])
}

private struct FailingClient: BarkClientProtocol {
    func ping() async throws {}
    func health() async throws -> BarkEndpointResponse { .init(statusCode: 200, fields: [:]) }
    func info() async throws -> BarkEndpointResponse { .init(statusCode: 200, fields: [:]) }
    func checkDevice(deviceKey: String) async throws -> BarkEndpointResponse { .init(statusCode: 200, fields: [:]) }
    func push(_ request: BarkPushRequest) async throws -> BarkPushResult {
        throw BarkClientError.server(statusCode: 401, message: "Unauthorized")
    }
}

@Test("Notification service records failed delivery attempts")
func failedDeliveryIsRecorded() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = try HistoryStore(
        databaseURL: directory.appendingPathComponent("history.sqlite"),
        sharedHistoryURL: nil
    )
    let service = NotificationService(client: FailingClient(), history: store)
    let request = BarkPushRequest(deviceKey: "key", body: "Hello")

    await #expect(throws: BarkClientError.self) {
        try await service.send(request, source: .cli)
    }
    let records = try await store.records()
    #expect(records.count == 1)
    #expect(records[0].deliveryStatus == .failed)
    #expect(records[0].httpStatusCode == 401)
}

@Test("BarkDesk and CLI history synchronize through JSONL")
func sharedHistorySynchronization() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let databaseURL = directory.appendingPathComponent("history.sqlite")
    let sharedURL = directory.appendingPathComponent("CLI/history.jsonl")
    let legacyAppRecord = NotificationRecord(
        request: BarkPushRequest(deviceKey: "key", title: "Legacy BarkDesk", body: "Existing app history"),
        source: .gui, createdAt: Date(timeIntervalSince1970: 100), deliveryStatus: .success
    )
    do {
        let legacyStore = try HistoryStore(databaseURL: databaseURL, sharedHistoryURL: nil)
        try await legacyStore.insert(legacyAppRecord)
    }
    try FileManager.default.createDirectory(at: sharedURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    let cliLine = """
    {"createdAt":"2026-09-03T08:56:57.123Z","status":"success","source":"agent-hook","title":"Codex · demo · 任务完成","body":"All tests passed.","group":"terminal"}
    """
    try Data("\(cliLine)\n".utf8).write(to: sharedURL)

    let store = try HistoryStore(databaseURL: databaseURL, sharedHistoryURL: sharedURL)
    let firstRead = try await store.records()
    #expect(firstRead.count == 2)
    let importedCLIRecord = try #require(firstRead.first { $0.source == .agentHook })
    #expect(importedCLIRecord.title == "Codex · demo · 任务完成")
    #expect(try String(contentsOf: sharedURL, encoding: .utf8).contains(legacyAppRecord.id.uuidString))

    let secondRead = try await store.records()
    #expect(secondRead.map(\.id) == firstRead.map(\.id))

    let appRecord = NotificationRecord(
        request: BarkPushRequest(deviceKey: "key", title: "BarkDesk", body: "Sent from app"),
        source: .gui, deliveryStatus: .success, httpStatusCode: 200
    )
    try await store.insert(appRecord)
    let sharedContent = try String(contentsOf: sharedURL, encoding: .utf8)
    #expect(sharedContent.contains("\"id\":\"\(appRecord.id.uuidString)\""))
    #expect(sharedContent.contains("\"source\":\"gui\""))

    try await store.delete(id: importedCLIRecord.id)
    #expect(Set(try await store.records().map(\.id)) == Set([appRecord.id, legacyAppRecord.id]))
}
