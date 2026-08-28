import Foundation

public struct NotificationService: Sendable {
    private let client: any BarkClientProtocol
    private let history: HistoryStore

    public init(client: any BarkClientProtocol, history: HistoryStore) {
        self.client = client
        self.history = history
    }

    @discardableResult
    public func send(
        _ request: BarkPushRequest,
        source: NotificationSource,
        metadata: NotificationMetadata? = nil
    ) async throws -> BarkPushResult {
        let result: BarkPushResult
        do {
            result = try await client.push(request)
        } catch {
            let httpCode: Int?
            if case BarkClientError.server(let status, _) = error { httpCode = status } else { httpCode = nil }
            let record = NotificationRecord(
                request: request, source: source, deliveryStatus: .failed,
                httpStatusCode: httpCode, errorMessage: error.localizedDescription, metadata: metadata
            )
            try? await history.insert(record)
            throw error
        }
        let record = NotificationRecord(
            request: request, source: source, deliveryStatus: .success,
            httpStatusCode: result.httpStatusCode, metadata: metadata
        )
        try await history.insert(record)
        return result
    }
}
