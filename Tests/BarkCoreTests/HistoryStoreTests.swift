import Foundation
import Testing
@testable import BarkCore

@Test("History persists, searches, and deletes records")
func historyLifecycle() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("history.sqlite")
    let store = try HistoryStore(databaseURL: url)
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
    let store = try HistoryStore(databaseURL: directory.appendingPathComponent("history.sqlite"))
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
