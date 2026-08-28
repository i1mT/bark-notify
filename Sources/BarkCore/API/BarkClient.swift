import Foundation

public protocol BarkClientProtocol: Sendable {
    func ping() async throws
    func health() async throws -> BarkEndpointResponse
    func info() async throws -> BarkEndpointResponse
    func checkDevice(deviceKey: String) async throws -> BarkEndpointResponse
    func push(_ request: BarkPushRequest) async throws -> BarkPushResult
}

public struct BarkPushResult: Sendable {
    public let response: BarkPushResponse
    public let httpStatusCode: Int

    public init(response: BarkPushResponse, httpStatusCode: Int) {
        self.response = response
        self.httpStatusCode = httpStatusCode
    }
}

public struct BarkClient: BarkClientProtocol {
    private let configuration: ResolvedConfiguration
    private let session: URLSession

    public init(configuration: ResolvedConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    public func ping() async throws {
        let (data, response) = try await perform(path: "ping", authenticated: false)
        try validate(response, data: data)
    }

    public func health() async throws -> BarkEndpointResponse {
        try await endpoint(path: "healthz", authenticated: false)
    }

    public func info() async throws -> BarkEndpointResponse {
        try await endpoint(path: "info", authenticated: true)
    }

    public func checkDevice(deviceKey: String) async throws -> BarkEndpointResponse {
        let segmentCharacters = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))
        let encodedKey = deviceKey.addingPercentEncoding(withAllowedCharacters: segmentCharacters) ?? deviceKey
        return try await endpoint(path: "register/\(encodedKey)", authenticated: false)
    }

    public func push(_ request: BarkPushRequest) async throws -> BarkPushResult {
        var urlRequest = try makeRequest(path: "push", authenticated: true)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        let (data, response) = try await session.data(for: urlRequest)
        let http = try httpResponse(response)
        let decoded = (try? JSONDecoder().decode(BarkPushResponse.self, from: data))
            ?? BarkPushResponse(code: nil, message: String(data: data, encoding: .utf8), timestamp: nil)
        guard (200..<300).contains(http.statusCode), decoded.code.map({ $0 == 200 }) ?? true else {
            throw BarkClientError.server(statusCode: http.statusCode, message: decoded.message ?? "Unknown response")
        }
        return BarkPushResult(response: decoded, httpStatusCode: http.statusCode)
    }

    private func endpoint(path: String, authenticated: Bool) async throws -> BarkEndpointResponse {
        let (data, response) = try await perform(path: path, authenticated: authenticated)
        let http = try httpResponse(response)
        try validate(response, data: data)
        return BarkEndpointResponse(statusCode: http.statusCode, fields: flattenJSON(data))
    }

    private func perform(path: String, authenticated: Bool) async throws -> (Data, URLResponse) {
        try await session.data(for: makeRequest(path: path, authenticated: authenticated))
    }

    private func makeRequest(path: String, authenticated: Bool) throws -> URLRequest {
        let config = try configuration.validated()
        let base = config.settings.serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(base)/\(path)") else { throw ConfigurationError.invalidServerURL }
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("BarkDesk/1.0", forHTTPHeaderField: "User-Agent")
        if authenticated, config.settings.authenticationMode == .basic {
            let token = Data("\(config.credentials.username):\(config.credentials.password)".utf8).base64EncodedString()
            request.setValue("Basic \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func validate(_ response: URLResponse, data: Data) throws {
        let http = try httpResponse(response)
        guard (200..<300).contains(http.statusCode) else {
            throw BarkClientError.server(
                statusCode: http.statusCode,
                message: String(data: data, encoding: .utf8) ?? "Unknown response"
            )
        }
    }

    private func httpResponse(_ response: URLResponse) throws -> HTTPURLResponse {
        guard let http = response as? HTTPURLResponse else { throw BarkClientError.invalidResponse }
        return http
    }

    private func flattenJSON(_ data: Data) -> [String: String] {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ["response": String(data: data, encoding: .utf8) ?? ""]
        }
        return object.reduce(into: [:]) { result, pair in result[pair.key] = String(describing: pair.value) }
    }
}

public enum BarkClientError: LocalizedError, Sendable {
    case invalidResponse
    case server(statusCode: Int, message: String)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse: "Bark Server 返回了无效的 HTTP 响应。"
        case .server(let statusCode, let message): "Bark 返回 HTTP \(statusCode)：\(message)"
        }
    }
}
