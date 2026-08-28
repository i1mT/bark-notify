import Foundation
import Testing
@testable import BarkCore

@Test("Push request uses Bark's expected JSON field names")
func pushRequestEncoding() throws {
    let request = BarkPushRequest(
        deviceKey: "device", title: "Title", body: "Body", markdown: "**Body**",
        level: .timeSensitive, volume: 7, badge: 3, call: "1", autoCopy: "1",
        copy: "copy me", image: "https://example.com/image.png", isArchive: "1", ttl: 60
    )
    let object = try #require(
        JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any]
    )
    #expect(object["device_key"] as? String == "device")
    #expect(object["autoCopy"] as? String == "1")
    #expect(object["isArchive"] as? String == "1")
    #expect(object["level"] as? String == "timeSensitive")
    #expect(object["volume"] as? Int == 7)
    #expect(object["image"] as? String == "https://example.com/image.png")
}

@Test("Configuration rejects incomplete values")
func configurationValidation() {
    let empty = ResolvedConfiguration(settings: AppConfiguration(), credentials: BarkCredentials())
    #expect(throws: ConfigurationError.self) { try empty.validated() }

    let valid = ResolvedConfiguration(
        settings: AppConfiguration(serverURL: "https://example.com/bark/"),
        credentials: BarkCredentials(deviceKey: "key")
    )
    #expect(throws: Never.self) { try valid.validated() }
}
